import AppKit
import CoreGraphics

final class OnboardingController: NSWindowController {
    static let completionKey = "buddie.setup.completed.v1"
    private var progress = SetupProgress()
    private var requested = false
    private var notice = ""
    private var checkingExistingAccess = CommandLine.arguments.contains("--check-access")
    var onFinish: (() -> Void)?
    var onPermissionChange: ((Bool) -> Void)?
    private let steps = NSTextField(labelWithString: "")
    private let heading = NSTextField(labelWithString: "")
    private let summary = NSTextField(wrappingLabelWithString: "")
    private let instructions = NSTextField(wrappingLabelWithString: "")
    private let state = NSTextField(wrappingLabelWithString: "")
    private let detail = NSTextField(wrappingLabelWithString: "")
    private let primary = StudioButton(frame: .zero)
    private let secondary = StudioButton(frame: .zero)
    private let tertiary = StudioButton(frame: .zero)
    private let back = StudioButton(frame: .zero)
    private let reveal = StudioButton(frame: .zero)
    private let alreadyEnabled = StudioButton(frame: .zero)

    init() {
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 620, height: 600),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "Welcome to Codex Buddie"
        BuddieTheme.style(window)
        super.init(window: window)
        let content = NSView(frame: window.contentLayoutRect)
        let card = StudioCard(frame: CGRect(x: 20, y: 238, width: 580, height: 166))
        content.addSubview(card)
        let mascot = BuddieView(frame: CGRect(x: 502, y: 466, width: 80, height: 80))
        mascot.reducedMotion = true
        content.addSubview(mascot)
        steps.font = .systemFont(ofSize: 11, weight: .semibold)
        steps.textColor = BuddieTheme.muted
        steps.frame = CGRect(x: 32, y: 541, width: 440, height: 24)
        heading.font = .systemFont(ofSize: 27, weight: .semibold)
        heading.textColor = BuddieTheme.ink
        heading.frame = CGRect(x: 32, y: 480, width: 470, height: 44)
        summary.font = .systemFont(ofSize: 14)
        summary.textColor = BuddieTheme.muted
        summary.frame = CGRect(x: 32, y: 408, width: 550, height: 64)
        instructions.font = .systemFont(ofSize: 13)
        instructions.textColor = BuddieTheme.ink
        instructions.frame = CGRect(x: 32, y: 241, width: 550, height: 156)
        state.font = .systemFont(ofSize: 13, weight: .semibold)
        state.textColor = BuddieTheme.forest
        state.frame = CGRect(x: 32, y: 196, width: 550, height: 40)
        detail.font = .systemFont(ofSize: 12)
        detail.textColor = BuddieTheme.muted
        detail.frame = CGRect(x: 32, y: 149, width: 550, height: 46)
        for label in [steps, heading, summary, instructions, state, detail] { content.addSubview(label) }
        configure(primary, frame: CGRect(x: 342, y: 65, width: 244, height: 36), action: #selector(advance))
        primary.keyEquivalent = "\r"
        primary.prominent = true
        configure(secondary, frame: CGRect(x: 28, y: 65, width: 288, height: 36), action: #selector(alternative))
        configure(tertiary, frame: CGRect(x: 28, y: 23, width: 288, height: 32), action: #selector(extra))
        configure(back, frame: CGRect(x: 494, y: 550, width: 90, height: 28), action: #selector(goBack))
        back.title = "Back"
        configure(reveal, frame: CGRect(x: 342, y: 23, width: 244, height: 32), action: #selector(showApp))
        reveal.title = "Show app in Finder"
        configure(alreadyEnabled, frame: CGRect(x: 28, y: 108, width: 558, height: 34), action: #selector(checkExistingAccess))
        alreadyEnabled.title = "It’s already enabled — check access"
        for button in [primary, secondary, tertiary, back, reveal, alreadyEnabled] { content.addSubview(button) }
        window.contentView = content
        window.center()
        refreshPermission()
        if checkingExistingAccess { checkExistingAccess() }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func configure(_ button: NSButton, frame: CGRect, action: Selector) {
        button.frame = frame; button.bezelStyle = .rounded
        button.target = self; button.action = action
    }
    func present() {
        refreshPermission()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func refreshPermission() {
        let granted = CGPreflightScreenCaptureAccess()
        progress.updatePermission(granted)
        onPermissionChange?(granted)
        render()
    }
    func observeCursor() {
        guard !progress.cursorDetected else { return }
        progress.observeCursor()
        render()
    }
    private func render() {
        primary.isEnabled = true
        back.isHidden = progress.step == .welcome
        secondary.isHidden = progress.step != .permission
        tertiary.isHidden = progress.step != .permission
        reveal.isHidden = progress.step != .permission
        alreadyEnabled.isHidden = progress.step != .permission
        detail.frame = CGRect(x: 32, y: progress.step == .permission ? 149 : 115, width: 550, height: progress.step == .permission ? 46 : 76)
        switch progress.step {
        case .welcome:
            steps.stringValue = "01  WELCOME     /     02  ACCESS     /     03  READY"
            heading.stringValue = "Meet your work buddy."
            summary.stringValue = "Buddie joins the cursor while Codex uses your Mac. Let’s make sure it can find the agent."
            instructions.stringValue = "Screen access is required to use Buddie.\n\nmacOS calls it Screen & System Audio Recording. Buddie uses this access to read the agent cursor’s window name and position.\n\nThis prototype follows or covers the pointer; the original cursor may still be visible."
            state.stringValue = progress.permissionGranted ? "Screen access is already enabled." : "Required to continue: screen access for Codex Buddie."
            detail.stringValue = "Buddie does not record screen pixels or audio, read your conversations, or send data over the network. It does not need Accessibility access. Codex manages its own permissions separately."
            primary.title = "Set up permissions"
        case .permission:
            steps.stringValue = "01  WELCOME     /     02  ACCESS     /     03  READY"
            heading.stringValue = "Let Buddie find the cursor."
            summary.stringValue = "Buddie needs screen access to identify the agent cursor. This running copy hasn’t confirmed access yet."
            instructions.stringValue = requested
                ? "1. Open System Settings and find Codex Buddie under Screen & System Audio Recording.\n\n2. If it’s already enabled, choose It’s already enabled — check access.\n\n3. If access still isn’t confirmed, use Show app in Finder to check that Settings lists this copy."
                : "1. Choose Allow screen access to ask macOS for access.\n\n2. In System Settings → Privacy & Security → Screen & System Audio Recording, enable Codex Buddie if needed.\n\n3. Already enabled? Choose It’s already enabled — check access."
            state.stringValue = notice.isEmpty ? "This running copy hasn’t confirmed screen access." : notice
            detail.stringValue = checkingExistingAccess
                ? "Try Restart Buddie. Still blocked after an update? Remove the old Buddie entry in Settings, add this copy with +, enable access, then restart. Show app in Finder locates this copy."
                : "Already enabled in Settings? Check access below. If macOS hasn’t picked it up yet, restart Buddie. Permission is required to continue."
            primary.title = requested ? "Check again" : "Allow screen access"
            secondary.title = "Open System Settings"
            tertiary.title = "Restart Buddie"
        case .verify:
            steps.stringValue = "01  WELCOME     /     02  ACCESS     /     03  READY"
            heading.stringValue = "You’re ready for company."
            summary.stringValue = "Screen access is enabled. Buddie will appear when the native computer-use cursor is visible."
            instructions.stringValue = "1. Start a computer-use task in Codex, such as clicking the buttons in Calculator.\n\n2. Watch for your buddy beside the agent’s cursor.\n\n3. Choose ◉ Buddie in the menu bar to change characters, pause, or return to Setup & permissions."
            state.stringValue = progress.cursorDetected ? "✓ Agent cursor detected in this session." : "✓ Screen access enabled. Waiting to detect an agent cursor."
            detail.stringValue = "No cursor yet? Make sure Codex is performing native computer use on this Mac. Browser previews and picture-in-picture cursors are not supported by this prototype. You can finish setup while waiting."
            primary.title = "Start using Buddie"
            tertiary.isHidden = true
        }
    }
    @objc private func advance() {
        switch progress.step {
        case .welcome: progress.begin(); render()
        case .permission:
            notice = ""
            if !requested {
                requested = true
                _ = CGRequestScreenCaptureAccess()
            }
            refreshPermission()
        case .verify:
            refreshPermission() // Never persist completion based on an old permission result.
            guard progress.canFinish else { return }
            UserDefaults.standard.set(true, forKey: Self.completionKey)
            close()
            onFinish?()
        }
    }
    @objc private func checkExistingAccess() {
        checkingExistingAccess = true
        requested = true
        notice = ""
        progress.begin()
        refreshPermission()
        if !progress.permissionGranted {
            notice = "The switch may be on; macOS hasn’t confirmed access for this copy."
            render()
        }
    }
    @objc private func alternative() {
        switch progress.step {
        case .welcome: break
        case .permission:
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
            if !NSWorkspace.shared.open(url) {
                notice = "Open System Settings manually, then Privacy & Security → Screen Recording."
                render()
            }
        case .verify: break
        }
    }
    @objc private func extra() {
        guard progress.step == .permission else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        config.arguments = ["--onboarding", "--check-access"]
        primary.isEnabled = false
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { [weak self] app, error in
            DispatchQueue.main.async {
                if app != nil { NSApp.terminate(nil) }
                else {
                    self?.notice = "Couldn’t restart automatically. Quit Buddie and open the app again."
                    self?.render()
                }
            }
        }
    }
    @objc private func goBack() { progress.step = .welcome; render() }
    @objc private func showApp() { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
}
