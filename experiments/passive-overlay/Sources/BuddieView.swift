import AppKit

final class BuddiePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class BuddieView: NSView {
    override var isOpaque: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    var preset = "Mochi"
    var pack: SpritePack?
    var moving = false
    var time: TimeInterval = 0
    var facing: CGFloat = 1
    var reducedMotion = false

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        if let pack, let frame = pack.frame(moving: moving, time: reducedMotion ? 0 : time) {
            ctx.interpolationQuality = .high
            ctx.draw(frame, in: CGRect(x: 8, y: 8, width: 64, height: 64))
            return
        }
        let bob = reducedMotion ? 0 : sin(time * (moving ? 16 : 3)) * (moving ? 2.5 : 1.2)
        ctx.saveGState()
        ctx.translateBy(x: 40, y: 40 + bob)
        ctx.scaleBy(x: facing, y: 1)
        ctx.setShadow(offset: CGSize(width: 0, height: -2), blur: 5, color: NSColor.black.withAlphaComponent(0.16).cgColor)
        let color: NSColor = preset == "Sprout" ? NSColor(red: 0.67, green: 0.85, blue: 0.51, alpha: 1)
            : preset == "Orbit" ? NSColor(red: 0.73, green: 0.66, blue: 0.96, alpha: 1)
            : NSColor(red: 1, green: 0.91, blue: 0.73, alpha: 1)
        ctx.setFillColor(color.cgColor)
        let body = CGPath(roundedRect: CGRect(x: -25, y: -23, width: 50, height: 48), cornerWidth: preset == "Orbit" ? 13 : 23,
                          cornerHeight: preset == "Orbit" ? 13 : 23, transform: nil)
        ctx.addPath(body); ctx.fillPath()
        ctx.setShadow(offset: .zero, blur: 0)
        ctx.setFillColor(color.blended(withFraction: 0.12, of: .black)!.cgColor)
        ctx.fillEllipse(in: CGRect(x: -21, y: -27, width: 15, height: 9))
        ctx.fillEllipse(in: CGRect(x: 8, y: -27, width: 15, height: 9))
        if preset == "Sprout" {
            ctx.setStrokeColor(NSColor.systemGreen.cgColor); ctx.setLineWidth(3)
            ctx.move(to: CGPoint(x: 0, y: 23)); ctx.addLine(to: CGPoint(x: 0, y: 34)); ctx.strokePath()
            ctx.setFillColor(NSColor(red: 0.3, green: 0.6, blue: 0.25, alpha: 1).cgColor)
            ctx.fillEllipse(in: CGRect(x: -1, y: 27, width: 15, height: 8))
        } else if preset == "Orbit" {
            ctx.setStrokeColor(color.cgColor); ctx.setLineWidth(3)
            ctx.move(to: CGPoint(x: 0, y: 24)); ctx.addLine(to: CGPoint(x: 0, y: 32)); ctx.strokePath()
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fillEllipse(in: CGRect(x: -4, y: 30, width: 8, height: 8))
        }
        ctx.setFillColor(NSColor(red: 0.20, green: 0.19, blue: 0.23, alpha: 1).cgColor)
        let blink = !reducedMotion && time.truncatingRemainder(dividingBy: 4.7) < 0.12
        for x: CGFloat in [-9, 10] {
            ctx.fillEllipse(in: CGRect(x: x, y: 1, width: 5, height: blink ? 1.4 : 7))
        }
        ctx.setLineWidth(1.8); ctx.setLineCap(.round)
        ctx.setStrokeColor(NSColor(red: 0.20, green: 0.19, blue: 0.23, alpha: 1).cgColor)
        ctx.move(to: CGPoint(x: -2, y: -7))
        ctx.addQuadCurve(to: CGPoint(x: 6, y: -7), control: CGPoint(x: 2, y: -12)); ctx.strokePath()
        ctx.setFillColor(NSColor.systemPink.withAlphaComponent(0.27).cgColor)
        ctx.fillEllipse(in: CGRect(x: -17, y: -5, width: 8, height: 4))
        ctx.fillEllipse(in: CGRect(x: 14, y: -5, width: 8, height: 4))
        ctx.restoreGState()
    }
}
