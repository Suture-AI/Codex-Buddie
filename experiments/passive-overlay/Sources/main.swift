import AppKit
import CoreGraphics
import UniformTypeIdentifiers

final class BuddieApp: NSObject, NSApplicationDelegate {
    private var status: NSStatusItem!
    private var statusLine: NSMenuItem!
    private var panel: BuddiePanel!
    private let buddy = BuddieView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
    private var timer: Timer?
    private var tracker = CursorTracker()
    private var followHuman = CommandLine.arguments.contains("--demo")
    private var paused = false
    private var cover = CommandLine.arguments.contains("--cover")
    private var lastPoint: CGPoint?
    private var lastMotion: TimeInterval = 0
    private var tick = 0
    private var source: CursorSample?
    private var activeID: UInt32?
    private var helperPIDs: Set<Int32> = []
    private var lastStatus = ""
    private var studio: StudioController?
    private var onboarding: OnboardingController?
    private var permissionGranted = false
    private let started = ProcessInfo.processInfo.systemUptime
    private let trace = CommandLine.arguments.contains("--trace")

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        panel = BuddiePanel(contentRect: buddy.bounds, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Codex Buddie Overlay"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.contentView = buddy
        // No promise of capture exclusion: modern ScreenCaptureKit can still include overlays.
        panel.sharingType = .none
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.title = "◉ Buddie"
        status.button?.toolTip = "Codex Buddie — experimental cursor companion"
        permissionGranted = CGPreflightScreenCaptureAccess()
        rebuildMenu()
        let needsSetup = SetupProgress.shouldShow(completed: UserDefaults.standard.bool(forKey: OnboardingController.completionKey), permissionGranted: permissionGranted)
        if CommandLine.arguments.contains("--onboarding") || needsSetup { showSetup() }
        else { showPreview() }
        timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in self?.update() }
        RunLoop.main.add(timer!, forMode: .common)
        if let i = CommandLine.arguments.firstIndex(of: "--quit-after"), i + 1 < CommandLine.arguments.count,
           let seconds = Double(CommandLine.arguments[i + 1]), seconds > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { NSApp.terminate(nil) }
        }
        if trace { print("Buddie started; Screen Recording permission: \(CGPreflightScreenCaptureAccess())"); fflush(stdout) }
    }

    private func item(_ title: String, _ action: Selector, checked: Bool = false) -> NSMenuItem {
        let value = NSMenuItem(title: title, action: action, keyEquivalent: "")
        value.target = self; value.state = checked ? .on : .off
        return value
    }

    private var needsSetup: Bool {
        SetupProgress.shouldShow(completed: UserDefaults.standard.bool(forKey: OnboardingController.completionKey), permissionGranted: permissionGranted)
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        statusLine = NSMenuItem(title: "Waiting for computer use…", action: nil, keyEquivalent: "")
        menu.addItem(statusLine)
        menu.addItem(.separator())
        if needsSetup {
            statusLine.title = "Screen access required to continue"
            menu.addItem(item("Continue setup…", #selector(showSetup)))
            menu.addItem(item("Quit Codex Buddie", #selector(quit)))
            status.menu = menu
            lastStatus = ""
            return
        }
        for name in ["Mochi", "Sprout", "Orbit"] {
            menu.addItem(item(name, #selector(selectPreset(_:)), checked: buddy.pack == nil && buddy.preset == name))
        }
        if let pack = buddy.pack { menu.addItem(NSMenuItem(title: "Custom: \(pack.manifest.name)", action: nil, keyEquivalent: "")) }
        menu.addItem(item("Load sprite pack…", #selector(loadPack)))
        menu.addItem(item("Open Buddie Studio", #selector(showPreview)))
        menu.addItem(.separator())
        menu.addItem(item("Follow agent cursor", #selector(agentMode), checked: !followHuman))
        menu.addItem(item("Demo: follow my mouse", #selector(demoMode), checked: followHuman))
        menu.addItem(item("Cover gray cursor (experimental)", #selector(toggleCover), checked: cover))
        menu.addItem(item(paused ? "Resume" : "Pause", #selector(togglePause)))
        menu.addItem(item("Setup & permissions…", #selector(showSetup)))
        menu.addItem(.separator())
        menu.addItem(item("Quit Codex Buddie", #selector(quit)))
        status.menu = menu
        lastStatus = ""
        syncStudio()
    }

    @objc private func selectPreset(_ sender: NSMenuItem) { buddy.preset = sender.title; buddy.pack = nil; rebuildMenu() }
    @objc private func agentMode() {
        followHuman = false; resetTracking(); rebuildMenu()
        if !CGPreflightScreenCaptureAccess() { showSetup() }
    }
    @objc private func demoMode() {
        guard !needsSetup else { showSetup(); return }
        followHuman = true; resetTracking(); rebuildMenu()
    }
    @objc private func toggleCover() { cover.toggle(); rebuildMenu() }
    @objc private func togglePause() { paused.toggle(); rebuildMenu() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func showPreview() {
        guard !needsSetup else { showSetup(); return }
        if studio == nil {
            let controller = StudioController()
            controller.onSelect = { [weak self] name in
                self?.buddy.preset = name; self?.buddy.pack = nil; self?.rebuildMenu()
            }
            controller.onAgent = { [weak self] in self?.agentMode() }
            controller.onDemo = { [weak self] in self?.demoMode() }
            controller.onPause = { [weak self] in self?.togglePause() }
            controller.onCover = { [weak self] in self?.toggleCover() }
            controller.onSetup = { [weak self] in self?.showSetup() }
            controller.onLoad = { [weak self] in self?.loadPack() }
            studio = controller
        }
        syncStudio()
        studio?.present()
    }
    private func syncStudio() {
        studio?.refresh(preset: buddy.preset, pack: buddy.pack, demo: followHuman, paused: paused,
                        cover: cover, permission: permissionGranted, status: lastStatus)
    }
    @objc private func showSetup() {
        if onboarding == nil {
            let setup = OnboardingController()
            setup.onPermissionChange = { [weak self] granted in
                guard let self else { return }
                let changed = self.permissionGranted != granted
                self.permissionGranted = granted
                if changed { self.rebuildMenu() }
                self.syncStudio()
            }
            setup.onFinish = { [weak self] in self?.agentMode(); self?.showPreview() }
            onboarding = setup
        }
        onboarding?.present()
    }
    func applicationDidBecomeActive(_ notification: Notification) {
        let granted = CGPreflightScreenCaptureAccess()
        let changed = granted != permissionGranted
        permissionGranted = granted
        if changed { rebuildMenu() }
        onboarding?.refreshPermission(); syncStudio()
    }
    @objc private func loadPack() {
        guard !needsSetup else { showSetup(); return }
        let picker = NSOpenPanel()
        picker.allowedContentTypes = [.json]
        picker.message = "Choose a pack.json file. Its PNG stays in the same folder."
        NSApp.activate(ignoringOtherApps: true)
        guard picker.runModal() == .OK, let url = picker.url else { return }
        do { buddy.pack = try SpritePack.load(from: url); rebuildMenu() }
        catch { let alert = NSAlert(); alert.messageText = "Couldn’t load this buddy"; alert.informativeText = error.localizedDescription; alert.runModal() }
    }

    private func resetTracking() { tracker = CursorTracker(); source = nil; activeID = nil; lastPoint = nil }

    private func setStatus(_ text: String) {
        guard text != lastStatus else { return }
        lastStatus = text; statusLine.title = text
        syncStudio()
        if trace { print(text); fflush(stdout) }
    }

    private func samples() -> [CursorSample] {
        // Validate ownership by bundle ID. Window titles alone are not sufficient.
        if tick % 30 == 0 {
            helperPIDs = Set(NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == "com.openai.sky.CUAService" }.map(\.processIdentifier))
        }
        guard !helperPIDs.isEmpty else { return [] }
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.compactMap { w in
            guard let pid = w[kCGWindowOwnerPID as String] as? Int32, helperPIDs.contains(pid),
                  let title = w[kCGWindowName as String] as? String,
                  ["Software Cursor", "Computer Use Cursor"].contains(title),
                  let id = w[kCGWindowNumber as String] as? UInt32,
                  let raw = w[kCGWindowBounds as String] as? [String: Any],
                  let rect = CGRect(dictionaryRepresentation: raw as CFDictionary),
                  rect.width > 0, rect.width <= 512, rect.height > 0, rect.height <= 512
            else { return nil }
            return CursorSample(id: id, bounds: rect, alpha: w[kCGWindowAlpha as String] as? Double ?? 0)
        }
    }

    private func update() {
        let now = ProcessInfo.processInfo.systemUptime
        defer { tick += 1 }
        if tick % 30 == 0 {
            let previousPermission = permissionGranted
            permissionGranted = CGPreflightScreenCaptureAccess()
            if previousPermission != permissionGranted { rebuildMenu() }
            if onboarding?.window?.isVisible == true { onboarding?.refreshPermission() }
            syncStudio()
        }
        if needsSetup {
            panel.orderOut(nil)
            if studio?.window?.isVisible == true { studio?.close() }
            resetTracking()
            setStatus("Screen access required — complete setup to continue")
            if onboarding?.window?.isVisible != true { showSetup() }
            return
        }
        if paused { panel.orderOut(nil); setStatus("Paused"); return }
        let point: CGPoint
        if followHuman {
            point = NSEvent.mouseLocation
            setStatus("Demo — following your mouse")
        } else {
            // Window enumeration is relatively expensive; poll at 15 Hz, animate at 30 Hz.
            // Discover helpers at most once a second. Profile before shipping.
            if tick % 2 == 0 { source = tracker.update(samples(), now: now) }
            guard let sample = source else {
                panel.orderOut(nil); lastPoint = nil
                setStatus(permissionGranted ? "Waiting for agent cursor…" : "Screen access needed — open Setup & permissions")
                return
            }
            let primaryHeight = CGFloat(CGDisplayBounds(CGMainDisplayID()).height)
            point = appKitPoint(fromQuartz: sample.point, primaryDisplayHeight: primaryHeight)
            if activeID != sample.id {
                activeID = sample.id
                if trace { print("Tracking cursor window \(sample.id); bounds \(sample.bounds)"); fflush(stdout) }
            }
            setStatus("Following agent cursor")
            onboarding?.observeCursor()
        }
        if let previous = lastPoint, hypot(point.x - previous.x, point.y - previous.y) > 0.5 {
            lastMotion = now
            if abs(point.x - previous.x) > 1 { buddy.facing = point.x > previous.x ? 1 : -1 }
            if trace { print("Anchor \(point.x),\(point.y)"); fflush(stdout) }
        }
        lastPoint = point
        buddy.moving = now - lastMotion < 0.25
        buddy.time = now - started
        buddy.reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let origin = CGPoint(x: point.x - 40 + (cover ? 0 : 38), y: point.y - 40 + (cover ? 0 : 22))
        panel.setFrameOrigin(origin)
        if !panel.isVisible { panel.orderFrontRegardless() }
        buddy.needsDisplay = true
    }
}

let app = NSApplication.shared
let delegate = BuddieApp()
app.delegate = delegate
app.run()
