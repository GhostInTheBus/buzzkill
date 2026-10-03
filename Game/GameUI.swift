// Menu items, toggles, persistence and the main-thread side of the game
// layer: camera, sound, Launch at Login, crumb carrying, idle pause.
// Owned by the AppDelegate; menu items target this object.

import Cocoa
import ServiceManagement

final class GameUI: NSObject {
    unowned let app: AppDelegate
    init(app: AppDelegate) { self.app = app }

    private var coordinator: Coordinator { app.coordinator }

    // persisted toggles
    static let attractKey = "attractCursor", squishKey = "squishClick", soundKey = "flySound", cameraKey = "cameraSwat", hearingKey = "hearingMic"
    private(set) var attractOn = false, squishOn = true, soundOn = true, cameraOn = false, hearingOn = false
    private var attractItem, squishItem, soundItem, cameraItem, loginItem, statsItem, hitboxItem, hearingItem: NSMenuItem?
    private var hearing: Hearing?
    // Difficulty dulls or sharpens the fly's senses (what reaches its looming
    // detectors and ears); the hitbox never changes. An easy fly is a dull fly.
    static let difficultyKey = "difficulty"
    private static let difficulties: [(name: String, acuity: Float)] = [("Normal", 1.0), ("Dull senses (easy)", 0.6), ("Sharp senses (hard)", 1.5)]
    private var difficultyIndex = 0

    private var flySound: FlySound?
    private var cameraSense: CameraSense?
    private var holdingCrumb = false

    // idle pause: after a few minutes without input, stop rendering and the sim
    // (GPU/CPU idle) until the display wakes or input returns. The swarm is
    // computed from idle time and streams in on resume, so pausing early costs
    // nothing. Also: 30 fps once the user has been away a minute.
    private(set) var autoPaused = false
    private static let noAutoPause = ProcessInfo.processInfo.environment["BUZZKILL_NO_AUTOPAUSE"] != nil
    static let autoPauseKey = "autoPauseMinutes"
    private static let pauseChoices = [5, 10, 30, 60]
    private var autoPauseMinutes = 10
    private var autoPauseItem: NSMenuItem?
    private var lowFps = false

    // MARK: menu

    func addItems(to menu: NSMenu) {
        func item(_ title: String, _ sel: Selector, _ key: String) -> NSMenuItem {
            let it = NSMenuItem(title: title, action: sel, keyEquivalent: key)
            it.target = self
            return it
        }
        statsItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        menu.addItem(statsItem!)
        let credit = item("Built on desktop-fly by Denis Shiryaev", #selector(openUpstream), "")
        menu.addItem(credit)
        menu.addItem(.separator())
        attractItem = item("Attract to Cursor: Off", #selector(toggleAttract), "t")
        menu.addItem(attractItem!)
        menu.addItem(item("Pick Up a Crumb (click to drop)", #selector(pickUpCrumb), "m"))
        loginItem = item("Launch at Login", #selector(toggleLogin), "l")
        menu.addItem(loginItem!)
        refreshLoginItem()
        soundItem = item("Sound: On", #selector(toggleSound), "u")
        menu.addItem(soundItem!)
        squishItem = item("Squish on Click: On", #selector(toggleSquish), "k")
        menu.addItem(squishItem!)
        hitboxItem = item("Difficulty: Normal", #selector(cycleDifficulty), "x")
        menu.addItem(hitboxItem!)
        cameraItem = item("Camera Swat: Off", #selector(toggleCamera), "c")
        menu.addItem(cameraItem!)
        refreshCameraItem()
        hearingItem = item("Hearing (mic): Off", #selector(toggleHearing), "g")
        menu.addItem(hearingItem!)
        refreshHearingItem()
        autoPauseItem = item("Pause When Idle: 10 min", #selector(cycleAutoPause), "i")
        menu.addItem(autoPauseItem!)
    }

    @objc func cycleAutoPause() {
        let i = GameUI.pauseChoices.firstIndex(of: autoPauseMinutes) ?? 1
        setAutoPause(minutes: GameUI.pauseChoices[(i + 1) % GameUI.pauseChoices.count])
    }
    private func setAutoPause(minutes: Int) {
        autoPauseMinutes = GameUI.pauseChoices.contains(minutes) ? minutes : 10
        UserDefaults.standard.set(autoPauseMinutes, forKey: GameUI.autoPauseKey)
        autoPauseItem?.title = "Pause When Idle: \(autoPauseMinutes) min"
    }

    /// Apply persisted settings at launch.
    func restore() {
        let d = UserDefaults.standard
        if d.bool(forKey: GameUI.attractKey) { setAttract(true) }
        setSquish(d.object(forKey: GameUI.squishKey) as? Bool ?? true)
        setSound(d.object(forKey: GameUI.soundKey) as? Bool ?? true)
        if d.bool(forKey: GameUI.cameraKey), CameraSense.authorization == .authorized { startCamera() }
        if d.bool(forKey: GameUI.hearingKey), Hearing.authorization == .authorized { startHearing() }
        setDifficulty(d.integer(forKey: GameUI.difficultyKey))
        coordinator.enqueue { [weak self] c in
            c.game.onMiss = { lead in DispatchQueue.main.async { self?.showMiss(lead: lead) } }
        }
        setAutoPause(minutes: d.object(forKey: GameUI.autoPauseKey) as? Int ?? 10)
    }

    /// The brain beat you: flash the Giant Fibers in the brain window and pulse the menu bar.
    private var missPulse: DispatchWorkItem?
    private func showMiss(lead: CGFloat?) {
        guard let lead else { return }
        app.brainWC?.showEscape(leadMs: Int((lead * 1000).rounded()))
        app.statusItem.button?.title = "🪰⚡"
        missPulse?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.app.statusItem.button?.title = "🪰" }
        missPulse = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    /// Called when the menu is about to open.
    func refresh() {
        statsItem?.title = coordinator.game.stats.summary
    }

    @objc func cycleDifficulty() { setDifficulty((difficultyIndex + 1) % GameUI.difficulties.count) }
    private func setDifficulty(_ i: Int) {
        difficultyIndex = max(0, min(GameUI.difficulties.count - 1, i))
        let d = GameUI.difficulties[difficultyIndex]
        coordinator.enqueue { c in c.sim?.senseAcuity = d.acuity }
        UserDefaults.standard.set(difficultyIndex, forKey: GameUI.difficultyKey)
        hitboxItem?.title = "Difficulty: \(d.name)"
    }

    // MARK: input routing (main thread)

    /// A global click at scene point p. Returns true if it was spent dropping a crumb.
    func consumeClick(at p: CGPoint) -> Bool {
        guard holdingCrumb else { return false }
        holdingCrumb = false
        coordinator.placeHeldCrumb(at: p)
        return true
    }

    /// Called from the 30 Hz mouse timer. Returns true when the scene is auto-paused
    /// (callers should feed it nothing, so actions don't pile up).
    func idleTick(idleNow: Double) -> Bool {
        if GameUI.noAutoPause { return false }   // BUZZKILL_NO_AUTOPAUSE=1: for unattended test runs
        if !app.paused {
            if !autoPaused && idleNow > Double(autoPauseMinutes * 60) { setAutoPaused(true, idle: idleNow) }
            else if autoPaused && idleNow < 3 { setAutoPaused(false, idle: idleNow) }
            // nobody's watching: half the frames (the sim keeps its own clock)
            let wantLow = idleNow > 60 && !autoPaused
            if wantLow != lowFps { lowFps = wantLow; app.scnView.preferredFramesPerSecond = wantLow ? 30 : 120 }
        }
        return autoPaused
    }

    /// Display woke (lid, key, unlock): resume before the first input so the swarm is visible.
    func onScreensWake() {
        if autoPaused { setAutoPaused(false, idle: userIdleSeconds()) }
    }

    private func setAutoPaused(_ on: Bool, idle: Double) {
        guard on != autoPaused else { return }
        autoPaused = on
        app.scnView.isPlaying = !on
        coordinator.lastTime = nil
        if on {
            if cameraOn { cameraSense?.stop() }
            if hearingOn { hearing?.stop() }
            flySound?.stop()
        } else {
            if cameraOn { cameraSense?.start { _ in } }
            if hearingOn { hearing?.start { _ in } }
            if soundOn { flySound?.start() }
            // let the cap know how long we were gone, then fill in the arrivals
            coordinator.setAmbient(typing: 0, sleepy: false, tempo: thermalTempo(),
                                   activity: circadianActivity(hour: 12), idle: CGFloat(idle))
            coordinator.catchUpArrivals()
        }
    }

    // MARK: toggles

    @objc func openUpstream() {
        if let url = URL(string: "https://github.com/DenisSergeevitch/desktop-fly") { NSWorkspace.shared.open(url) }
    }
    @objc func toggleAttract() { setAttract(!attractOn) }
    @objc func toggleSquish() { setSquish(!squishOn) }
    @objc func toggleSound() { setSound(!soundOn) }
    @objc func pickUpCrumb() {
        holdingCrumb = true
        coordinator.pickUpCrumb()
    }

    func setAttract(_ on: Bool) {
        attractOn = on
        coordinator.setAttract(on)
        UserDefaults.standard.set(on, forKey: GameUI.attractKey)
        attractItem?.title = on ? "Attract to Cursor: On" : "Attract to Cursor: Off"
    }
    func setSquish(_ on: Bool) {
        squishOn = on
        coordinator.setSquish(on)
        UserDefaults.standard.set(on, forKey: GameUI.squishKey)
        squishItem?.title = on ? "Squish on Click: On" : "Squish on Click: Off"
    }
    func setSound(_ on: Bool) {
        soundOn = on
        if on {
            let fs = flySound ?? FlySound()
            flySound = fs
            fs.start()
            coordinator.setSound(fs.running ? fs : nil)
        } else {
            coordinator.setSound(nil)
            flySound?.stop()
        }
        UserDefaults.standard.set(on, forKey: GameUI.soundKey)
        soundItem?.title = on ? "Sound: On" : "Sound: Off"
    }

    // Launch at Login via SMAppService (macOS 13+). Only works from a real .app
    // bundle in /Applications; from a bare binary the item is disabled.
    @objc func toggleLogin() {
        guard #available(macOS 13, *) else { return }
        let svc = SMAppService.mainApp
        do {
            if svc.status == .enabled { try svc.unregister() } else { try svc.register() }
        } catch {
            fputs("launch at login: \(error)\n", stderr)
        }
        refreshLoginItem()
    }
    private func refreshLoginItem() {
        guard #available(macOS 13, *), Bundle.main.bundleIdentifier != nil else {
            loginItem?.isEnabled = false; return
        }
        switch SMAppService.mainApp.status {
        case .enabled: loginItem?.state = .on; loginItem?.title = "Launch at Login"
        case .requiresApproval: loginItem?.state = .mixed; loginItem?.title = "Launch at Login (approve in System Settings)"
        default: loginItem?.state = .off; loginItem?.title = "Launch at Login"
        }
    }

    // MARK: hearing (mic; typing bursts work without it)

    @objc func toggleHearing() {
        if hearingOn {
            hearing?.stop(); hearingOn = false
            coordinator.setHearing(nil)
            UserDefaults.standard.set(false, forKey: GameUI.hearingKey)
            refreshHearingItem(); return
        }
        switch Hearing.authorization {
        case .authorized: startHearing()
        case .notDetermined:
            Hearing.requestAccess { [weak self] ok in if ok { self?.startHearing() } else { self?.refreshHearingItem() } }
        default:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    private func startHearing() {
        let h = hearing ?? Hearing()
        hearing = h
        hearingItem?.title = "Hearing (mic): starting…"
        h.start { [weak self] ok in
            guard let self else { return }
            self.hearingOn = ok
            self.coordinator.setHearing(ok ? h : nil)
            UserDefaults.standard.set(ok, forKey: GameUI.hearingKey)
            self.refreshHearingItem()
        }
    }
    private func refreshHearingItem() {
        switch Hearing.authorization {
        case .denied, .restricted: hearingItem?.title = "Hearing (mic): No Access (open Settings)"
        default: hearingItem?.title = hearingOn ? "Hearing (mic): On" : (hearing?.refusedBluetooth == true ? "Hearing (mic): no built-in mic (Bluetooth refused)" : "Hearing (mic): Off")
        }
    }

    // MARK: camera (a sense that needs a permission)

    @objc func toggleCamera() {
        if cameraOn {
            stopCamera()
            UserDefaults.standard.set(false, forKey: GameUI.cameraKey)
            return
        }
        switch CameraSense.authorization {
        case .authorized: startCamera()
        case .notDetermined:
            CameraSense.requestAccess { [weak self] ok in
                if ok { self?.startCamera() } else { self?.refreshCameraItem() }
            }
        default:
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    private func startCamera() {
        let cs = cameraSense ?? CameraSense()
        cameraSense = cs
        cs.onHand = { [weak self] p, extent in
            guard let self else { return }
            // camera frame -> this display's scene plane (centered, points)
            let sf = self.app.screenFrame
            let scene = p.map { CGPoint(x: ($0.x - 0.5) * sf.width, y: ($0.y - 0.5) * sf.height) }
            self.coordinator.setHand(scene, extent: extent)
        }
        cameraItem?.title = "Camera Swat: starting…"
        cs.start { [weak self] ok in
            guard let self else { return }
            self.cameraOn = ok
            UserDefaults.standard.set(ok, forKey: GameUI.cameraKey)
            self.refreshCameraItem()
        }
    }
    private func stopCamera() {
        cameraSense?.stop()
        cameraOn = false
        refreshCameraItem()
    }
    private func refreshCameraItem() {
        switch CameraSense.authorization {
        case .denied, .restricted: cameraItem?.title = "Camera Swat: No Access (open Settings)"
        default: cameraItem?.title = cameraOn ? "Camera Swat: On" : "Camera Swat: Off"
        }
    }
}
