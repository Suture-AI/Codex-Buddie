import Cocoa
import SwiftUI
import ObjectiveC.runtime

// Exercise an actual SwiftUI host. A plain NSView fixture has an immediate
// frame and missed the zero-size failure seen in the real native service.
struct CursorView: View {
    var body: some View { Circle().fill(.gray).frame(width: 126, height: 126) }
}

_ = NSApplication.shared
let runtimeClass: AnyClass = objc_allocateClassPair(NSWindow.self, "ComputerUse.ComputerUseCursor.Window", 0)!
objc_registerClassPair(runtimeClass)
let cursorClass = runtimeClass as! NSWindow.Type
let window = cursorClass.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
let original = NSHostingView(rootView: CursorView())
window.contentView = original
precondition(original.frame.size == .zero, "Fixture must begin before SwiftUI has resolved its frame")
precondition(BuddieReplaceContent(window, original), "Lazy SwiftUI host must be replaced")
precondition(window.contentView is BuddieView)
precondition(original.superview == nil, "Gray artwork must be detached")
precondition(window.frame.size == NSSize(width: 126, height: 126), "Native hosting size must survive replacement")
precondition(window.contentView!.bounds.size == window.frame.size)
let buddy = window.contentView as! BuddieView
precondition(buddy.hotspot == NSPoint(x: 63, y: 63))
precondition(buddy.drawingScale > 0, "Character must have room to draw")
precondition(!BuddieReplaceContent(window, buddy), "Replacement must be idempotent")
window.contentView = nil
print("PASS: actual zero-frame SwiftUI host resolves to 126 x 126; detached artwork, center hotspot, drawable replacement")
