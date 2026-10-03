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
    static let attractKey = "attractCursor", squishKey = "squishClick", soundKey = "flySound", cameraKey = "cameraSwat"
    private(set) var attractOn = false, squishOn = true, soundOn = true, cameraOn = false
    private var attractItem, squishItem, soundItem, cameraItem, loginItem, statsItem, hitboxItem: NSMenuItem?
    static let hitboxKey = "hitbox"
    private static let hitboxes: [(name: String, px: CGFloat)] = [("Normal", 26), ("Forgiving", 34), ("Tiny", 18)]
    private var hitboxIndex = 0

    private var flySound: FlySound?
    private var cameraSense: CameraSense?
    private var holdingCrumb = false

    // idle pause: after an hour without input, stop rendering (GPU) until wake/input
    private(set) var autoPaused = false
    static let autoPauseAfter: Double = 3600

    // MARK: menu

    func addItems(to menu: NSMenu) {
        func item(_ title: String, _ sel: Selector, _ key: String) -> NSMenuItem {
            let it = NSMenuItem(title: title, action: sel, keyEquivalent: key)
            it.target = self
            return it
        }
        statsItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        menu.addItem(statsItem!)
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
        hitboxItem = item("Hitbox: Normal", #selector(cycleHitbox), "x")
        menu.addItem(hitboxItem!)
        cameraItem = item("Camera Swat: Off", #selector(toggleCamera), "c")
        menu.addItem(cameraItem!)
        refreshCameraItem()
    }

    /// Apply persisted settings at launch.
    func restore() {
        let d = UserDefaults.standard
        if d.bool(forKey: GameUI.attractKey) { setAttract(true) }
        setSquish(d.object(forKey: GameUI.squishKey) as? Bool ?? true)
        setSound(d.object(forKey: GameUI.soundKey) as? Bool ?? true)
        if d.bool(forKey: GameUI.cameraKey), CameraSense.authorization == .authorized { startCamera() }
        setHitbox(d.integer(forKey: GameUI.hitboxKey))
    }

    /// Called when the menu is about to open.
    func refresh() {
        statsItem?.title = coordinator.game.stats.summary
    }

    @objc func cycleHitbox() { setHitbox((hitboxIndex + 1) % GameUI.hitboxes.count) }
    private func setHitbox(_ i: Int) {
        hitboxIndex = max(0, min(GameUI.hitboxes.count - 1, i))
        let h = GameUI.hitboxes[hitboxIndex]
        coordinator.enqueue { c in c.game.splats.hitRadius = h.px }
        UserDefaults.standard.set(hitboxIndex, forKey: GameUI.hitboxKey)
        hitboxItem?.title = "Hitbox: \(h.name)"
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
        if !app.paused {
            if !autoPaused && idleNow > GameUI.autoPauseAfter { setAutoPaused(true, idle: idleNow) }
            else if autoPaused && idleNow < 3 { setAutoPaused(false, idle: idleNow) }
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
            flySound?.stop()
        } else {
            if cameraOn { _ = cameraSense?.start() }
            if soundOn { flySound?.start() }
            // let the cap know how long we were gone, then fill in the arrivals
            coordinator.setAmbient(typing: 0, sleepy: false, tempo: thermalTempo(),
                                   activity: circadianActivity(hour: 12), idle: CGFloat(idle))
            coordinator.catchUpArrivals()
        }
    }

    // MARK: toggles

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

    // MARK: camera (the one sense that needs a permission)

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
        cameraOn = cs.start()
        UserDefaults.standard.set(cameraOn, forKey: GameUI.cameraKey)
        refreshCameraItem()
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
