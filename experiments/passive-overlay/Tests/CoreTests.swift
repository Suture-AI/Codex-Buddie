import Foundation
import CoreGraphics
import ImageIO

@main
struct CoreTests {
    static func main() throws {
        var count = 0
        func check(_ condition: @autoclosure () -> Bool, _ label: String) {
            precondition(condition(), label)
            count += 1
        }
        func sample(_ id: UInt32, _ x: Double, alpha: Double = 1) -> CursorSample {
            CursorSample(id: id, bounds: CGRect(x: x, y: 100, width: 126, height: 126), alpha: alpha)
        }
        var setup = SetupProgress()
        setup.begin()
        check(setup.step == .permission && !setup.canFinish, "new user cannot finish without screen access")
        setup.observeCursor()
        check(!setup.cursorDetected, "cursor observation cannot certify denied access")
        setup.updatePermission(false)
        check(setup.step == .permission, "denial keeps recovery instructions available")
        setup.updatePermission(true)
        check(setup.step == .verify && setup.canFinish && !setup.cursorDetected, "permission does not imply live tracking")
        setup.observeCursor()
        check(setup.cursorDetected, "native cursor confirms live tracking")
        setup.updatePermission(false)
        check(setup.step == .permission && !setup.canFinish && !setup.cursorDetected, "revocation invalidates readiness and cursor confirmation")
        setup.updatePermission(true)
        check(!setup.cursorDetected, "new grant requires fresh cursor evidence")
        check(SetupProgress.shouldShow(completed: true, permissionGranted: false), "revoked permission reopens setup on launch")
        check(!SetupProgress.shouldShow(completed: true, permissionGranted: true), "completed setup stays dismissed")
        check(SetupProgress.shouldShow(completed: false, permissionGranted: true), "existing permission does not skip welcome for new users")
        var tracker = CursorTracker()
        check(tracker.update([], now: 0) == nil, "no cursor means hidden")
        check(tracker.update([sample(1, 20)], now: 1)?.id == 1, "acquire visible cursor")
        check(tracker.update([sample(1, 20)], now: 10)?.id == 1, "retain stationary cursor briefly")
        check(tracker.update([sample(1, 20)], now: 14) == nil, "hide stale cursor")
        check(tracker.update([sample(1, 30)], now: 15)?.id == 1, "movement wakes cursor")
        check(tracker.update([sample(1, 30), sample(2, 10)], now: 16)?.id == 2, "new cursor takes over")
        check(tracker.update([sample(1, 40), sample(2, 10)], now: 17)?.id == 1, "most recently moved cursor wins")
        check(tracker.update([sample(1, 40, alpha: 0), sample(2, 10)], now: 18)?.id == 2, "ignore transparent cursor")
        check(tracker.update([], now: 19) == nil, "hide when cursor disappears")
        check(appKitPoint(fromQuartz: CGPoint(x: 971, y: 202), primaryDisplayHeight: 1117) == CGPoint(x: 971, y: 915), "Quartz to AppKit point conversion")
        check(appKitPoint(fromQuartz: CGPoint(x: -800, y: -300), primaryDisplayHeight: 1117) == CGPoint(x: -800, y: 1417), "preserve negative multi-display coordinates")

        let base: [String: Any] = ["version": 1, "name": "Test", "image": "sprite.png", "frameWidth": 8, "frameHeight": 8,
                                  "columns": 2, "rows": 2, "fps": 8,
                                  "states": ["idle": ["row": 0, "frames": 2], "moving": ["row": 1, "frames": 2]]]
        func manifest(_ data: [String: Any]) throws -> SpriteManifest {
            try JSONDecoder().decode(SpriteManifest.self, from: JSONSerialization.data(withJSONObject: data))
        }
        try manifest(base).validate(); count += 1
        for (key, invalid) in [("version", 2 as Any), ("image", "../secret.png"), ("image", "/tmp/image.png"),
                               ("columns", 1000), ("fps", 0), ("frameWidth", 0), ("rows", 0), ("image", "https://example.com/a.png")] {
            var bad = base; bad[key] = invalid
            do { try manifest(bad).validate(); preconditionFailure("Accepted invalid \(key)") }
            catch { count += 1 }
        }
        var bad = base; bad["states"] = ["idle": ["row": 0, "frames": 3], "moving": ["row": 4, "frames": 1]]
        do { try manifest(bad).validate(); preconditionFailure("Accepted out-of-bounds states") }
        catch { count += 1 }

        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("codex-buddie-tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        // This directory is wholly test-owned and not referenced outside this test.
        defer { try? FileManager.default.removeItem(at: temporary) }
        let context = CGContext(data: nil, width: 16, height: 16, bitsPerComponent: 8, bytesPerRow: 64,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        let output = CGImageDestinationCreateWithURL(temporary.appendingPathComponent("sprite.png") as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(output, context.makeImage()!, nil)
        check(CGImageDestinationFinalize(output), "write test sprite")
        let manifestURL = temporary.appendingPathComponent("pack.json")
        try JSONSerialization.data(withJSONObject: base).write(to: manifestURL)
        let pack = try SpritePack.load(from: manifestURL)
        check(pack.frame(moving: false, time: 0)?.width == 8, "decode and crop idle frame")
        check(pack.frame(moving: true, time: 1.25)?.height == 8, "decode and crop movement frame")
        var mismatch = base; mismatch["frameWidth"] = 7
        try JSONSerialization.data(withJSONObject: mismatch).write(to: manifestURL)
        do { _ = try SpritePack.load(from: manifestURL); preconditionFailure("Accepted dimensions mismatch") }
        catch { count += 1 }
        try FileManager.default.createSymbolicLink(at: temporary.appendingPathComponent("escape.png"), withDestinationURL: URL(fileURLWithPath: "/tmp/outside-buddie.png"))
        var escaped = base; escaped["image"] = "escape.png"
        try JSONSerialization.data(withJSONObject: escaped).write(to: manifestURL)
        do { _ = try SpritePack.load(from: manifestURL); preconditionFailure("Accepted symlink escape") }
        catch { count += 1 }
        print("Passed \(count) checks: onboarding permission lifecycle, cursor lifecycle, multi-display math, sprite validation, PNG decoding and frame cropping.")
    }
}
