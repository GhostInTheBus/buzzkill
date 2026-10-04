// Offscreen preview of how flies actually look in the overlay: the real scene
// (its lights and shadow catcher) seen top-down, over a desktop-like
// background, zoomed in. One fly standing, one walking, one in flight.
//
//   ./Buzzkill --looktest out.png [--beetle]

import SceneKit

/// The three species side by side, standing and in flight.  ./Buzzkill --speciestest out.png
func runSpeciesTest(path: String) {
    MotionStyle.apply()
    let bounds = CGSize(width: 1400, height: 1000)
    let scene = buildScene(bounds: bounds)
    let bg = NSImage(size: NSSize(width: 64, height: 64))
    bg.lockFocus()
    NSGradient(colors: [NSColor(calibratedRed: 0.36, green: 0.47, blue: 0.62, alpha: 1), NSColor(calibratedRed: 0.78, green: 0.80, blue: 0.84, alpha: 1)])!
        .draw(in: NSRect(x: 0, y: 0, width: 64, height: 64), angle: 20)
    bg.unlockFocus()
    scene.background.contents = bg
    TestRandom.reset("speciestest")
    var flies: [Fly] = []
    for (i, form) in [BodyForm.flyDetailed, .housefly, .mosquito].enumerated() {
        let x = -70 + CGFloat(i) * 70
        let a = Fly(at: CGPoint(x: x, y: 28), form: form); a.heading = 1.75
        a.state = .idle
        for _ in 0..<30 { a.update(dt: 1 / 60, bounds: bounds, mouse: nil, signals: nil); a.pos = CGPoint(x: x, y: 28); a.heading = 1.75; a.state = .idle }
        a.update(dt: 0.0001, bounds: bounds, mouse: nil, signals: nil)
        let b = Fly(at: CGPoint(x: x, y: -32), form: form)
        b.startFlight(bounds: bounds, effort: 0.6)
        for _ in 0..<34 { b.update(dt: 1 / 60, bounds: bounds, mouse: nil, signals: nil) }
        b.pos = CGPoint(x: x, y: -32); b.node.position = SCNVector3(x, -32, b.node.position.z)
        for f in [a, b] { scene.rootNode.addChildNode(f.node); flies.append(f) }
    }
    FlyShadows().update(flies: flies, scene: scene)
    guard let cam = scene.rootNode.childNode(withName: "camera", recursively: false) else { return }
    cam.camera?.orthographicScale = 66
    offscreenRender(scene, camNode: cam, size: CGSize(width: 1300, height: 800), path: path)
}

func runLookTest(path: String) {
    let bounds = CGSize(width: 1400, height: 1000)
    let scene = buildScene(bounds: bounds)
    // a desktop-ish backdrop so shadows and translucency have something to land on
    let bg = NSImage(size: NSSize(width: 64, height: 64))
    bg.lockFocus()
    NSGradient(colors: [NSColor(calibratedRed: 0.36, green: 0.47, blue: 0.62, alpha: 1),
                        NSColor(calibratedRed: 0.78, green: 0.80, blue: 0.84, alpha: 1)])!
        .draw(in: NSRect(x: 0, y: 0, width: 64, height: 64), angle: 20)
    bg.unlockFocus()
    scene.background.contents = bg

    TestRandom.reset("looktest")
    var flies: [Fly] = []
    func place(_ p: CGPoint, heading: CGFloat, _ setup: (Fly) -> Void) {
        let fly = Fly(at: p)
        flies.append(fly)
        fly.heading = heading
        scene.rootNode.addChildNode(fly.node)
        setup(fly)
    }
    place(CGPoint(x: -34, y: 4), heading: 1.9) { f in
        f.state = .idle
        for _ in 0..<30 { f.update(dt: 1 / 60, bounds: bounds, mouse: nil, signals: nil) }
        f.pos = CGPoint(x: -34, y: 4); f.heading = 1.9
        f.update(dt: 0.0001, bounds: bounds, mouse: nil, signals: nil)
    }
    place(CGPoint(x: 6, y: -14), heading: 0.9) { f in
        f.state = .walking
        for _ in 0..<45 { f.update(dt: 1 / 60, bounds: bounds, mouse: nil, signals: nil) }
        f.pos = CGPoint(x: 6, y: -14); f.heading = 0.9
        f.update(dt: 0.0001, bounds: bounds, mouse: nil, signals: nil)
    }
    place(CGPoint(x: 32, y: 14), heading: 2.6) { f in
        f.startFlight(bounds: bounds, effort: 0.8)
        for _ in 0..<26 { f.update(dt: 1 / 60, bounds: bounds, mouse: nil, signals: nil) }
        f.pos = CGPoint(x: 32, y: 14)
        f.node.position = SCNVector3(32, 14, f.node.position.z)
    }
    let shadows = FlyShadows()
    if !CommandLine.arguments.contains("--noshadow") { shadows.update(flies: flies, scene: scene) }
    guard let cam = scene.rootNode.childNode(withName: "camera", recursively: false) else { return }
    if CommandLine.arguments.contains("--actual") {
        // true size on a Retina display: 2 px per point
        cam.camera?.orthographicScale = 60
        offscreenRender(scene, camNode: cam, size: CGSize(width: 348, height: 240), path: path)
    } else {
        cam.camera?.orthographicScale = 34      // ~12x the real desktop scale
        offscreenRender(scene, camNode: cam, size: CGSize(width: 1100, height: 760), path: path)
    }
}

/// Headless motion profile of the brain fly: how it actually spends its time
/// and how fast it moves. 5 minutes of simulated life, no rendering.
///   ./Buzzkill --motionprofile
func runMotionProfile() {
    guard let data = loadBrainData() else { fputs("no data\n", stderr); exit(1) }
    if !CommandLine.arguments.contains("--engine") { MotionStyle.apply() }   // --engine: upstream's raw motion
    let bounds = CGSize(width: 1728, height: 1080)
    let dt: CGFloat = 1.0 / 120.0
    var agg: [String: (time: CGFloat, dist: CGFloat, turn: CGFloat, bouts: Int)] = [:]
    var flights: [(dur: CGFloat, dist: CGFloat)] = []
    var walkBouts: [(dur: CGFloat, dist: CGFloat)] = []
    var walkSpeeds: [CGFloat] = []
    for seed in 0..<3 {
        TestRandom.reset("motion \(seed)")
        let sim = LIFSim(circuit: data.circuit, spikeBus: nil, locomotorCircuit: data.locomotor)
        let builder = SignalBuilder()
        let fly = Fly(at: .zero); fly.state = .idle; fly.speed = 0
        sim.step(400); _ = sim.consumeGF()
        var last = fly.pos, lastHeading = fly.heading, lastState = fly.state
        var boutT: CGFloat = 0, boutD: CGFloat = 0, acc: Double = 0
        var winD: CGFloat = 0, winT: CGFloat = 0
        for _ in 0..<(100 * 120) {
            sim.gaitDrive = Float(fly.walkingIntensity); sim.gaitPhase = Float(fly.gaitPhasePublic); sim.legFeedback = fly.legFeedback
            acc += Double(dt) * 1000; let steps = Int(acc); acc -= Double(steps); sim.step(steps)
            let sig = builder.make(sim, dt: dt)
            fly.update(dt: dt, bounds: bounds, mouse: nil, signals: sig)
            let d = hypot(fly.pos.x - last.x, fly.pos.y - last.y)
            let turn = abs(angleDiff(lastHeading, fly.heading))
            let key = "\(fly.state)"
            var a = agg[key] ?? (0, 0, 0, 0)
            a.time += dt; a.dist += d; a.turn += turn
            if fly.state != lastState {
                a.bouts += 1
                if lastState == .flying { flights.append((boutT, boutD)) }
                if lastState == .walking { walkBouts.append((boutT, boutD)) }
                boutT = 0; boutD = 0
            }
            agg[key] = a
            boutT += dt; boutD += d
            if fly.state == .walking { winD += d; winT += dt; if winT >= 0.5 { walkSpeeds.append(winD / winT); winD = 0; winT = 0 } }
            last = fly.pos; lastHeading = fly.heading; lastState = fly.state
        }
    }
    let total = agg.values.reduce(0) { $0 + $1.time }
    print(String(format: "5 min of fly life (3 seeds x 100 s), body length ~%.0f px", 22 * FLY_SCALE))
    for (k, a) in agg.sorted(by: { $0.value.time > $1.value.time }) {
        print(String(format: "  %-9@ %4.0f%% of time | %3d bouts, mean %.1f s | %6.1f px/s | turn %.0f deg/s",
                     k as NSString, a.time / total * 100, a.bouts, a.time / CGFloat(max(1, a.bouts)), a.dist / max(0.001, a.time), a.turn / max(0.001, a.time) * 180 / .pi))
    }
    walkSpeeds.sort()
    if !walkSpeeds.isEmpty {
        let q = { (p: CGFloat) in walkSpeeds[min(walkSpeeds.count - 1, Int(CGFloat(walkSpeeds.count) * p))] }
        print(String(format: "  walking speed over 0.5 s windows: median %.1f, p90 %.1f, max %.1f px/s (%.2f body lengths/s at the median)",
                     q(0.5), q(0.9), walkSpeeds.last!, q(0.5) / (22 * FLY_SCALE)))
    }
    if !walkBouts.isEmpty {
        let d = walkBouts.map { $0.dist }.sorted()
        print(String(format: "  walk bouts: %d, median travel %.1f px, longest %.1f px", d.count, d[d.count / 2], d.last!))
    }
    if !flights.isEmpty {
        print(String(format: "  flights: %d, mean %.2f s, mean %.0f px, mean speed %.0f px/s", flights.count,
                     flights.map { $0.dur }.reduce(0, +) / CGFloat(flights.count), flights.map { $0.dist }.reduce(0, +) / CGFloat(flights.count),
                     flights.map { $0.dist }.reduce(0, +) / max(0.001, flights.map { $0.dur }.reduce(0, +))))
    }
}


/// Offscreen render of the four splat styles, two of each.  ./Buzzkill --splattest out.png
func runSplatTest(path: String) {
    BODY_FORM = .flyDetailed
    let bounds = CGSize(width: 1400, height: 1000)
    let scene = buildScene(bounds: bounds)
    scene.background.contents = NSColor(calibratedRed: 0.80, green: 0.82, blue: 0.86, alpha: 1)
    TestRandom.reset("splattest")
    let splats = Splats()
    for (row, seedBase) in [(0, UInt32(11)), (1, UInt32(977))] {
        for (col, style) in Splats.Style.allCases.enumerated() {
            let fly = Fly(at: CGPoint(x: -108 + CGFloat(col) * 72, y: 30 - CGFloat(row) * 62))
            fly.update(dt: 0.001, bounds: bounds, mouse: nil, signals: nil)
            splats.preview(style: style, fly: fly, seed: seedBase + UInt32(col) * 131, angle: style == .smear ? (row == 0 ? 0.3 : 2.4) : CGFloat(col) * 1.1, scene: scene)
        }
    }
    FlyShadows().update(flies: [], scene: scene)
    guard let cam = scene.rootNode.childNode(withName: "camera", recursively: false) else { return }
    cam.camera?.orthographicScale = 70
    offscreenRender(scene, camNode: cam, size: CGSize(width: 1200, height: 560), path: path)
}


/// A contact sheet: one fly doing one thing, frozen at eight moments, left to right.
///   ./Buzzkill --posetest out.png groom|takeoff|landing|walk [--cursor]
func runPoseTest(path: String, what: String) {
    BODY_FORM = .flyDetailed
    MotionStyle.apply()
    let bounds = CGSize(width: 1400, height: 1000)
    let scene = buildScene(bounds: bounds)
    scene.background.contents = NSColor(calibratedRed: 0.72, green: 0.76, blue: 0.82, alpha: 1)
    TestRandom.reset("posetest \(what)")
    let fly = Fly(at: .zero); fly.heading = .pi / 2
    let dt: CGFloat = 1.0 / 120
    let cursor: CGPoint? = CommandLine.arguments.contains("--cursor") ? CGPoint(x: 150, y: 60) : nil
    func step(_ n: Int, force: Fly.State? = nil) {
        for _ in 0..<n {
            if let f = force { fly.state = f }
            fly.update(dt: dt, bounds: bounds, mouse: cursor, signals: nil)
            if force != nil { fly.pos = .zero; fly.heading = .pi / 2 }
        }
        if let f = force { fly.state = f }
    }
    var frames: [(SCNNode, String)] = []
    func snap(_ label: String) {
        // freeze this pose: rebuild position so the row is evenly spaced
        fly.update(dt: 0.00001, bounds: bounds, mouse: cursor, signals: nil)
        frames.append((fly.node.clone(), label))
    }
    switch what {
    case "groom":
        // three frames of each gesture: rub, rub, rub | wipe x3 | hind x2
        let env = ProcessInfo.processInfo.environment
        func f(_ k: String, _ d: CGFloat) -> CGFloat { env[k].flatMap { Double($0) }.map { CGFloat($0) } ?? d }
        Fly.groomPose = (f("RA", Fly.groomPose.rubAngle), f("RL", Fly.groomPose.rubLift), f("RK", Fly.groomPose.rubKnee),
                         f("WA", Fly.groomPose.wipeAngle), f("WL", Fly.groomPose.wipeLift), f("WK", Fly.groomPose.wipeKnee),
                         f("HA", Fly.groomPose.hindAngle), f("HL", Fly.groomPose.hindLift), f("HK", Fly.groomPose.hindKnee))
        for (mode, n) in [(0, 3), (2, 3), (3, 2)] {
            Fly.debugGroomMode = mode
            step(40, force: .grooming)
            for _ in 0..<n { step(3, force: .grooming); snap("groom \(mode)") }
        }
    case "takeoff":
        step(30, force: .idle)
        fly.startFlight(bounds: bounds, effort: 0.7)
        for _ in 0..<8 { snap("takeoff"); step(4) }
    case "landing":
        fly.startFlight(bounds: bounds, effort: 0.7)
        var guardN = 0
        while fly.flightT < 0.80 && guardN < 2000 { step(1); guardN += 1 }
        for _ in 0..<8 { snap("landing"); step(9) }
    case "flight":
        // mid-flight wingbeat, frame by frame
        fly.startFlight(bounds: bounds, effort: 0.7)
        var guardN = 0
        while fly.flightT < 0.4 && guardN < 2000 { step(1); guardN += 1 }
        for _ in 0..<8 { snap("flight"); step(1) }
    case "head":
        // the cursor circles the fly; the head should follow it
        for k in 0..<8 {
            let a = CGFloat(k) / 8 * 2 * .pi
            for _ in 0..<40 {
                fly.state = .idle
                fly.update(dt: dt, bounds: bounds, mouse: CGPoint(x: cos(a) * 160, y: sin(a) * 160), signals: nil)
                fly.pos = .zero; fly.heading = .pi / 2; fly.state = .idle
            }
            frames.append((fly.node.clone(), "head"))
        }
    default:
        for _ in 0..<8 { step(14, force: .walking); snap("walk") }
    }
    for (i, f) in frames.enumerated() {
        f.0.position = SCNVector3(-196 + CGFloat(i) * 56, 0, f.0.position.z)
        f.0.eulerAngles = SCNVector3(f.0.eulerAngles.x, f.0.eulerAngles.y, 0)   // all facing up
        scene.rootNode.addChildNode(f.0)
    }
    FlyShadows().update(flies: [], scene: scene)
    guard let cam = scene.rootNode.childNode(withName: "camera", recursively: false) else { return }
    cam.camera?.orthographicScale = 40
    offscreenRender(scene, camNode: cam, size: CGSize(width: 1800, height: 320), path: path)
}
