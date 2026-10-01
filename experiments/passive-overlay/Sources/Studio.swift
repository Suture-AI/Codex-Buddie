import AppKit

final class StudioController: NSWindowController, NSWindowDelegate {
    var onSelect: ((String) -> Void)?
    var onAgent: (() -> Void)?
    var onDemo: (() -> Void)?
    var onPause: (() -> Void)?
    var onCover: (() -> Void)?
    var onSetup: (() -> Void)?
    var onLoad: (() -> Void)?
    private let hero = BuddieView(frame: CGRect(x: 38, y: 184, width: 244, height: 244))
    private let name = BuddieTheme.label("Mochi", 38, CGRect(x: 293, y: 238, width: 227, height: 54), color: .white, weight: .bold)
    private let characterNote = BuddieTheme.label("Soft edges.\nBig teammate energy.", 15, CGRect(x: 296, y: 298, width: 220, height: 66), color: BuddieTheme.color(0xCEE0CF))
    private let badge = BuddieTheme.label("●  SETUP NEEDED", 11, CGRect(x: 603, y: 48, width: 241, height: 24), color: BuddieTheme.muted, weight: .semibold)
    private let modeNote = BuddieTheme.label("", 13, CGRect(x: 583, y: 285, width: 233, height: 55), color: BuddieTheme.muted)
    private let permissionNote = BuddieTheme.label("", 13, CGRect(x: 583, y: 469, width: 233, height: 54), color: BuddieTheme.muted)
    private let agent = StudioButton(frame: CGRect(x: 581, y: 222, width: 114, height: 43))
    private let demo = StudioButton(frame: CGRect(x: 704, y: 222, width: 114, height: 43))
    private let pause = StudioButton(frame: CGRect(x: 581, y: 351, width: 237, height: 42))
    private let setup = StudioButton(frame: CGRect(x: 581, y: 542, width: 237, height: 43))
    private let cover = NSButton(checkboxWithTitle: "Cover original pointer", target: nil, action: nil)
    private var cards: [PresetButton] = []
    private var timer: Timer?
    private var clickCount = 0

    init() {
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 850, height: 680), styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "Codex Buddie — Studio"
        window.titleVisibility = .hidden
        BuddieTheme.style(window)
        super.init(window: window)
        window.delegate = self
        let content = StudioCanvas(frame: CGRect(x: 0, y: 0, width: 850, height: 680))
        content.addSubview(BuddieTheme.label("buddie", 26, CGRect(x: 28, y: 42, width: 140, height: 38), weight: .heavy))
        content.addSubview(BuddieTheme.label("YOUR DESKTOP, WITH A LITTLE MORE SOUL.", 10, CGRect(x: 164, y: 54, width: 385, height: 22), color: BuddieTheme.muted, weight: .medium))
        content.addSubview(badge)
        content.addSubview(BuddieTheme.label("Good company. Great work.", 33, CGRect(x: 28, y: 104, width: 775, height: 48), weight: .bold))
        content.addSubview(BuddieTheme.label("Pick your tiny teammate. Make the desktop feel a little more you.", 14, CGRect(x: 30, y: 153, width: 760, height: 25), color: BuddieTheme.muted))
        let stage = StudioCard(frame: CGRect(x: 28, y: 197, width: 510, height: 241)); stage.fill = BuddieTheme.forest; stage.dotted = true
        content.addSubview(stage)
        hero.bounds = CGRect(x: 0, y: 0, width: 80, height: 80)
        content.addSubview(hero)
        content.addSubview(BuddieTheme.label("CURRENT SIDEKICK", 10, CGRect(x: 297, y: 221, width: 214, height: 18), color: BuddieTheme.lime, weight: .semibold))
        content.addSubview(name); content.addSubview(characterNote)
        content.addSubview(BuddieTheme.label("✳  HERE FOR THE LITTLE THINGS", 10, CGRect(x: 297, y: 397, width: 217, height: 18), color: BuddieTheme.lime, weight: .medium))
        content.addSubview(BuddieTheme.label("THE CREW", 11, CGRect(x: 30, y: 460, width: 440, height: 24), color: BuddieTheme.muted, weight: .semibold))
        let colors: [UInt32] = [0xF9E8CD, 0xE5EECF, 0xE7E0F2]
        for (i, value) in ["Mochi", "Sprout", "Orbit"].enumerated() {
            let card = PresetButton(frame: CGRect(x: 28+i*175, y: 490, width: 160, height: 136))
            card.name = value; card.character.preset = value; card.title = value
            card.tint = BuddieTheme.color(colors[i]); card.target = self; card.action = #selector(select(_:))
            card.setAccessibilityLabel("Choose \(value)")
            cards.append(card); content.addSubview(card)
        }
        let load = StudioButton(frame: CGRect(x: 28, y: 638, width: 220, height: 30)); load.title = "+  Bring your own character"; load.target = self; load.action = #selector(importPack)
        content.addSubview(load)
        let controlCard = StudioCard(frame: CGRect(x: 561, y: 197, width: 271, height: 216))
        content.addSubview(controlCard)
        for (button, text, action) in [(agent, "Agent cursor", #selector(agentMode)), (demo, "My mouse", #selector(demoMode)), (pause, "Pause buddy", #selector(togglePause)), (setup, "Set up screen access  →", #selector(openSetup))] {
            button.title = text; button.target = self; button.action = action
            content.addSubview(button)
        }
        content.addSubview(modeNote)
        let permissionCard = StudioCard(frame: CGRect(x: 561, y: 431, width: 271, height: 168)); permissionCard.fill = BuddieTheme.color(0xE9EDDF)
        content.addSubview(permissionCard)
        content.addSubview(BuddieTheme.label("A LITTLE HOUSEKEEPING", 10, CGRect(x: 583, y: 450, width: 237, height: 22), color: BuddieTheme.forest, weight: .semibold))
        content.addSubview(permissionNote)
        // Keep the action above its card in the view hierarchy.
        setup.removeFromSuperview(); setup.prominent = true; content.addSubview(setup)
        cover.frame = CGRect(x: 581, y: 313, width: 237, height: 24)
        cover.font = .systemFont(ofSize: 12); cover.target = self; cover.action = #selector(toggleCover)
        cover.toolTip = "Experimental visual coverage. The original cursor is not removed."
        content.addSubview(cover)
        let test = StudioButton(frame: CGRect(x: 562, y: 623, width: 270, height: 40)); test.title = "✦  Click test · 0"; test.target = self; test.action = #selector(testClick(_:))
        content.addSubview(test)
        content.addSubview(BuddieTheme.label("MADE FOR MAC. BUILT FOR COMPANY.", 9, CGRect(x: 270, y: 647, width: 277, height: 18), color: BuddieTheme.muted, weight: .medium))
        window.contentView = content; window.center()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func present() {
        if timer == nil {
            let timer = Timer(timeInterval: 1.0/30, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.hero.time = ProcessInfo.processInfo.systemUptime
                self.hero.reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                self.hero.needsDisplay = true
            }
            self.timer = timer; RunLoop.main.add(timer, forMode: .common)
        }
        showWindow(nil); window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func refresh(preset: String, pack: SpritePack?, demo: Bool, paused: Bool, cover: Bool, permission: Bool, status: String) {
        hero.preset = preset; hero.pack = pack
        name.stringValue = pack?.manifest.name ?? preset
        name.font = .systemFont(ofSize: name.stringValue.count > 12 ? 22 : 38, weight: .bold)
        characterNote.stringValue = pack != nil ? "One of a kind.\nJust like your desktop." : preset == "Sprout" ? "A fresh perspective.\nRoom to grow." : preset == "Orbit" ? "A little out of this world.\nAlways in your corner." : "Soft edges.\nBig teammate energy."
        for card in cards { card.selected = pack == nil && card.name == preset }
        agent.selected = !demo; self.demo.selected = demo
        pause.title = paused ? "Resume buddy" : "Pause buddy"
        self.cover.state = cover ? .on : .off
        badge.stringValue = paused ? "●  TAKING A BREATHER" : demo ? "●  MOUSE DEMO" : permission ? "●  READY FOR COMPUTER USE" : "●  SETUP NEEDED"
        modeNote.stringValue = demo ? "A tiny companion for your mouse." : permission ? (status.isEmpty ? "Ready when your agent is." : status) : "Follows Codex during computer use."
        permissionNote.stringValue = permission ? "Screen access is enabled. Your buddy is ready when Codex is." : "One permission helps Buddie find the agent cursor on your Mac."
        setup.title = permission ? "Setup & permissions  →" : "Set up screen access  →"
    }
    func windowWillClose(_ notification: Notification) { timer?.invalidate(); timer = nil }
    @objc private func select(_ sender: PresetButton) { onSelect?(sender.name) }
    @objc private func agentMode() { onAgent?() }
    @objc private func demoMode() { onDemo?() }
    @objc private func togglePause() { onPause?() }
    @objc private func toggleCover() { onCover?() }
    @objc private func openSetup() { onSetup?() }
    @objc private func importPack() { onLoad?() }
    @objc private func testClick(_ sender: NSButton) { clickCount += 1; sender.title = "✦  Click test · \(clickCount)" }
}
