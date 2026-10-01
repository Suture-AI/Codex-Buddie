import Foundation
import CoreGraphics
import ImageIO

struct CursorSample {
    let id: UInt32
    let bounds: CGRect
    let alpha: Double
    var point: CGPoint { CGPoint(x: bounds.midX, y: bounds.midY) }
}

/// Window metadata gives a visual anchor, not a guaranteed input hotspot.
/// Never infer click/typing/success from movement alone.
struct CursorTracker {
    private var previous: [UInt32: CGPoint] = [:]
    private var activity: [UInt32: TimeInterval] = [:]
    private var selected: UInt32?
    let idleTimeout: TimeInterval = 12

    mutating func update(_ samples: [CursorSample], now: TimeInterval) -> CursorSample? {
        let visible = samples.filter { $0.alpha > 0.05 && $0.bounds.width > 0 && $0.bounds.height > 0 }
        let ids = Set(visible.map(\.id))
        activity = activity.filter { ids.contains($0.key) }
        for sample in visible {
            if let old = previous[sample.id] {
                if hypot(sample.point.x - old.x, sample.point.y - old.y) > 0.5 {
                    activity[sample.id] = now
                }
            } else {
                activity[sample.id] = now
            }
        }
        previous = Dictionary(uniqueKeysWithValues: visible.map { ($0.id, $0.point) })
        // Prefer actual movement, retaining the current selection on ties.
        let ranked = visible.sorted {
            let left = activity[$0.id] ?? -.infinity
            let right = activity[$1.id] ?? -.infinity
            if left != right { return left > right }
            if $0.id == selected { return true }
            if $1.id == selected { return false }
            return $0.id > $1.id
        }
        guard let best = ranked.first, now - (activity[best.id] ?? 0) <= idleTimeout else {
            selected = nil
            return nil
        }
        selected = best.id
        return best
    }
}

func appKitPoint(fromQuartz point: CGPoint, primaryDisplayHeight: CGFloat) -> CGPoint {
    // Quartz uses a top-left origin; AppKit uses the primary display's bottom-left.
    // Do not use NSScreen.main (it changes with focus), or scale by Retina pixels.
    CGPoint(x: point.x, y: primaryDisplayHeight - point.y)
}

struct SpriteState: Decodable {
    let row: Int
    let frames: Int
}

struct SpriteManifest: Decodable {
    let version: Int
    let name: String
    let image: String
    let frameWidth: Int
    let frameHeight: Int
    let columns: Int
    let rows: Int
    let fps: Double
    let states: [String: SpriteState]

    func validate() throws {
        guard version == 1, !name.isEmpty, name.count <= 80,
              frameWidth > 0, frameHeight > 0, frameWidth <= 512, frameHeight <= 512,
              (1...32).contains(columns), (1...16).contains(rows),
              frameWidth * columns <= 4096, frameHeight * rows <= 4096,
              fps.isFinite, fps >= 1, fps <= 30,
              states["idle"] != nil, states["moving"] != nil,
              states.values.allSatisfy({ $0.row >= 0 && $0.row < rows && $0.frames > 0 && $0.frames <= columns })
        else { throw BuddieError.invalidPack("Invalid sprite dimensions, timing, version, or states.") }
        guard !image.hasPrefix("/"), !image.contains("://"), !image.split(separator: "/").contains(".."),
              URL(fileURLWithPath: image).pathExtension.lowercased() == "png"
        else { throw BuddieError.invalidPack("The image must be a PNG inside the pack folder.") }
    }
}

enum BuddieError: LocalizedError {
    case invalidPack(String)
    var errorDescription: String? {
        switch self { case .invalidPack(let message): return message }
    }
}

struct SpritePack {
    let manifest: SpriteManifest
    let image: CGImage

    static func load(from manifestURL: URL) throws -> SpritePack {
        let values = try manifestURL.resourceValues(forKeys: [.fileSizeKey])
        guard (values.fileSize ?? Int.max) <= 65_536 else {
            throw BuddieError.invalidPack("Pack manifest exceeds 64 KB.")
        }
        let manifest = try JSONDecoder().decode(SpriteManifest.self, from: Data(contentsOf: manifestURL))
        try manifest.validate()
        let root = manifestURL.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
        let imageURL = root.appendingPathComponent(manifest.image).resolvingSymlinksInPath().standardizedFileURL
        guard imageURL.path.hasPrefix(root.path + "/") else {
            throw BuddieError.invalidPack("The image resolves outside the pack folder.")
        }
        let size = try imageURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? Int.max
        guard size <= 20 * 1024 * 1024,
              let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              CGImageSourceGetType(source) as String? == "public.png",
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
              let height = properties[kCGImagePropertyPixelHeight as String] as? Int,
              width == manifest.frameWidth * manifest.columns,
              height == manifest.frameHeight * manifest.rows,
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { throw BuddieError.invalidPack("PNG dimensions must match the manifest; maximum file size is 20 MB.") }
        return SpritePack(manifest: manifest, image: image)
    }

    func frame(moving: Bool, time: TimeInterval) -> CGImage? {
        let state = manifest.states[moving ? "moving" : "idle"]!
        let index = Int(max(0, time) * manifest.fps) % state.frames
        return image.cropping(to: CGRect(x: index * manifest.frameWidth, y: state.row * manifest.frameHeight,
                                        width: manifest.frameWidth, height: manifest.frameHeight))
    }
}
