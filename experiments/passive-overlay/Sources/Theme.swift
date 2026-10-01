import AppKit

enum BuddieTheme {
    static func color(_ hex: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 255)/255, green: CGFloat((hex >> 8) & 255)/255,
                blue: CGFloat(hex & 255)/255, alpha: 1)
    }
    static let canvas = color(0xF4F3ED)
    static let ink = color(0x26332C)
    static let muted = color(0x677269)
    static let line = color(0xDDDFD4)
    static let lime = color(0xD6EEA0)
    static let forest = color(0x263C32)
    static func label(_ text: String, _ size: CGFloat, _ rect: NSRect, color: NSColor = ink, weight: NSFont.Weight = .regular) -> NSTextField {
        let value = NSTextField(wrappingLabelWithString: text)
        value.font = .systemFont(ofSize: size, weight: weight)
        value.textColor = color; value.frame = rect
        return value
    }
    static func style(_ window: NSWindow) {
        window.backgroundColor = canvas
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
    }
}

final class StudioCanvas: NSView {
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) { BuddieTheme.canvas.setFill(); bounds.fill() }
}

final class StudioCard: NSView {
    var fill = NSColor.white
    var dotted = false
    override func draw(_ dirtyRect: NSRect) {
        fill.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 22, yRadius: 22).fill()
        if dotted {
            NSColor.white.withAlphaComponent(0.08).setFill()
            for x in stride(from: 16, to: Int(bounds.width)-8, by: 18) {
                for y in stride(from: 16, to: Int(bounds.height)-8, by: 18) {
                    NSBezierPath(ovalIn: CGRect(x: x, y: y, width: 2, height: 2)).fill()
                }
            }
        }
    }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

class StudioButton: NSButton {
    var drawsTitle = true
    var prominent = false { didSet { needsDisplay = true } }
    var selected = false { didSet { needsDisplay = true } }
    var tint = NSColor.white { didSet { needsDisplay = true } }
    private var hover = false
    private var hoverArea: NSTrackingArea?
    override init(frame: NSRect) {
        super.init(frame: frame)
        isBordered = false; setButtonType(.momentaryPushIn)
        font = .systemFont(ofSize: 13, weight: .semibold)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func updateTrackingAreas() {
        if let hoverArea { removeTrackingArea(hoverArea) }
        hoverArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow], owner: self)
        addTrackingArea(hoverArea!); super.updateTrackingAreas()
    }
    override func mouseEntered(with event: NSEvent) { hover = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hover = false; needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        let base = prominent ? BuddieTheme.forest : (selected ? BuddieTheme.lime : tint)
        let fill = hover || isHighlighted ? base.blended(withFraction: 0.08, of: .black)! : base
        fill.setFill()
        let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 12, yRadius: 12)
        shape.fill()
        (selected ? BuddieTheme.forest : BuddieTheme.line).setStroke()
        shape.lineWidth = selected ? 2 : 1; shape.stroke()
        let style = NSMutableParagraphStyle(); style.alignment = .center
        let attributes: [NSAttributedString.Key: Any] = [.font: font!, .foregroundColor: prominent ? NSColor.white : BuddieTheme.ink, .paragraphStyle: style]
        let height = title.size(withAttributes: attributes).height
        if drawsTitle { title.draw(in: CGRect(x: 10, y: (bounds.height-height)/2, width: bounds.width-20, height: height+2), withAttributes: attributes) }
        if window?.firstResponder === self {
            NSColor.keyboardFocusIndicatorColor.setStroke()
            let focus = NSBezierPath(roundedRect: bounds.insetBy(dx: 3, dy: 3), xRadius: 10, yRadius: 10)
            focus.lineWidth = 2; focus.stroke()
        }
    }
}

final class PresetButton: StudioButton {
    let character = BuddieView(frame: CGRect(x: 40, y: 29, width: 80, height: 80))
    var name: String = "Mochi"
    override init(frame: NSRect) {
        super.init(frame: frame)
        drawsTitle = false
        character.reducedMotion = true
        addSubview(character)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let style = NSMutableParagraphStyle(); style.alignment = .center
        name.draw(in: CGRect(x: 8, y: bounds.height-31, width: bounds.width-16, height: 21),
                  withAttributes: [.font: NSFont.systemFont(ofSize: 14, weight: .semibold), .foregroundColor: BuddieTheme.ink, .paragraphStyle: style])
        if selected {
            "✓".draw(at: CGPoint(x: bounds.width-27, y: 12), withAttributes: [.font: NSFont.systemFont(ofSize: 14, weight: .bold), .foregroundColor: BuddieTheme.forest])
        }
    }
    override var isFlipped: Bool { true }
}
