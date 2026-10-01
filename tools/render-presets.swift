import AppKit

@main
struct RenderPresets {
    static func main() throws {
        _ = NSApplication.shared
        let canvas = NSView(frame: CGRect(x: 0, y: 0, width: 900, height: 360))
        canvas.wantsLayer = true
        canvas.layer?.backgroundColor = NSColor(red: 0.96, green: 0.95, blue: 0.92, alpha: 1).cgColor
        func label(_ text: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: NSFont.Weight) {
            let field = NSTextField(labelWithString: text)
            field.font = .systemFont(ofSize: size, weight: weight)
            field.textColor = NSColor(red: 0.18, green: 0.20, blue: 0.19, alpha: 1)
            field.frame = CGRect(x: x, y: y, width: 280, height: 36)
            field.alignment = .center
            canvas.addSubview(field)
        }
        for (index, name) in ["Mochi", "Sprout", "Orbit"].enumerated() {
            let x = CGFloat(index * 300)
            let buddy = BuddieView(frame: CGRect(x: x + 70, y: 105, width: 160, height: 160))
            buddy.bounds = CGRect(x: 0, y: 0, width: 80, height: 80)
            buddy.preset = name; buddy.time = 1; buddy.reducedMotion = true
            canvas.addSubview(buddy)
            label(name, x: x + 10, y: 62, size: 23, weight: .semibold)
        }
        label("CODEX BUDDIE", x: 310, y: 294, size: 15, weight: .medium)
        let bitmap = canvas.bitmapImageRepForCachingDisplay(in: canvas.bounds)!
        canvas.cacheDisplay(in: canvas.bounds, to: bitmap)
        let destination = CommandLine.arguments.dropFirst().first ?? "docs/presets.png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination))
        print(destination)
    }
}
