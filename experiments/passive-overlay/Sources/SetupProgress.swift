import Foundation

struct SetupProgress {
    enum Step { case welcome, permission, verify }
    var step: Step = .welcome
    private(set) var permissionGranted = false
    private(set) var cursorDetected = false
    var canFinish: Bool { permissionGranted }

    mutating func begin() { step = permissionGranted ? .verify : .permission }
    mutating func updatePermission(_ granted: Bool) {
        permissionGranted = granted
        if !granted {
            cursorDetected = false
            if step == .verify { step = .permission }
        } else if step == .permission { step = .verify }
    }
    mutating func observeCursor() {
        if permissionGranted { cursorDetected = true }
    }
    static func shouldShow(completed: Bool, permissionGranted: Bool) -> Bool {
        !completed || !permissionGranted
    }
}
