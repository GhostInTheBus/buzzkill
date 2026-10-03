// Headless checks of the game rules, so they can be verified without staring
// at the screen for an hour. No SceneKit rendering: a stub world with a
// scene node graph but no view.
//
//   ./DesktopFly --populationtest

import SceneKit

private final class StubWorld: GameWorld {
    var flies: [Fly] = []
    let bounds = CGSize(width: 1512, height: 982)
    let scene = SCNScene()
    var startles = 0
    var brainEscapeAge: CGFloat = 99
    func startle(_ strength: CGFloat) { startles += 1 }
}

func runPopulationTest() {
    var failures = 0
    func check(_ name: String, _ ok: Bool, _ detail: String) {
        print((ok ? "PASS " : "FAIL ") + name + ": " + detail); if !ok { failures += 1 }
    }
    // isolate from the user's real persisted pressure
    UserDefaults.standard.removeObject(forKey: "popPressure")
    UserDefaults.standard.removeObject(forKey: "popPressureAt")
    let dt: CGFloat = 1.0 / 60.0

    // --- cap curve ---
    do {
        let p = Population()
        let w = StubWorld()
        func cap(afterIdle s: CGFloat) -> Int { p.update(world: w, dt: dt, idle: s, mouse: nil, mouseSpeed: 0, handSpeed: 0); return p.maxFlies }
        let c0 = cap(afterIdle: 0), c30 = cap(afterIdle: 30 * 60), c60 = cap(afterIdle: 60 * 60), c3h = cap(afterIdle: 3 * 3600)
        check("cap: 4 at the desk, ~50 after 30 min, ~95 after 1 h, 160 ceiling",
              c0 == 4 && (45...55).contains(c30) && (90...100).contains(c60) && c3h == 160,
              "\(c0) / \(c30) / \(c60) / \(c3h)")
    }

    // --- arrivals accelerate with the crowd while away, and stop at the cap ---
    do {
        TestRandom.reset("population arrivals")
        let p = Population(); let w = StubWorld()
        var t: CGFloat = 0, firstAt: CGFloat = -1, tenAt: CGFloat = -1
        while t < 1800 {
            p.update(world: w, dt: 0.1, idle: 3600 + t, mouse: nil, mouseSpeed: 0, handSpeed: 0)
            // flies arrive flying; land them so counts are stable
            for f in w.flies where f.state == .flying { f.update(dt: 5, bounds: w.bounds, mouse: nil, signals: nil) }
            if firstAt < 0 && w.flies.count >= 1 { firstAt = t }
            if tenAt < 0 && w.flies.count >= 10 { tenAt = t }
            t += 0.1
        }
        check("arrivals: first within 60 s of leaving, ten within 6 min, never above the cap",
              firstAt >= 0 && firstAt < 60 && tenAt >= 0 && tenAt < 360 && w.flies.count <= p.maxFlies,
              String(format: "first %.0fs, ten %.0fs, count %d, cap %d", firstAt, tenAt, w.flies.count, p.maxFlies))
    }

    // --- disperse: coming back leaves exactly the home population (brain fly kept) ---
    do {
        TestRandom.reset("population disperse")
        let p = Population(); let w = StubWorld()
        for _ in 0..<30 { p.spawnFromEdge(world: w) }
        for f in w.flies { f.update(dt: 5, bounds: w.bounds, mouse: nil, signals: nil) }   // land them
        let brain = w.flies.first!
        p.update(world: w, dt: dt, idle: 600, mouse: nil, mouseSpeed: 0, handSpeed: 0)     // away
        p.update(world: w, dt: dt, idle: 1, mouse: .zero, mouseSpeed: 0, handSpeed: 0)     // back
        let leaving = w.flies.filter { $0.state == .flying }.count
        check("disperse: 26 of 30 take off, brain fly stays, brain startled",
              leaving == 26 && brain.state != .flying && w.startles == 1,
              "leaving \(leaving), brain \(brain.state), startles \(w.startles)")
        // let them fly out; they must be removed and not come back while active
        for _ in 0..<600 {
            for f in w.flies where f.state == .flying { f.update(dt: dt, bounds: w.bounds, mouse: nil, signals: nil) }
            p.update(world: w, dt: dt, idle: 1, mouse: .zero, mouseSpeed: 0, handSpeed: 0)
        }
        check("disperse: the leavers are gone, 4 remain", w.flies.count == 4, "count \(w.flies.count)")
    }

    // --- spook: hard shaking empties the room; nothing returns until idle ---
    do {
        TestRandom.reset("population spook")
        let p = Population(); let w = StubWorld()
        for _ in 0..<6 { p.spawnFromEdge(world: w) }
        for f in w.flies { f.update(dt: 5, bounds: w.bounds, mouse: nil, signals: nil) }
        for _ in 0..<90 { p.update(world: w, dt: dt, idle: 1, mouse: .zero, mouseSpeed: 2000, handSpeed: 0) }  // 1.5 s of shaking
        let airborne = w.flies.filter { $0.state == .flying }.count
        check("spook: all six take off after ~1.2 s of hard shaking", p.spooked && airborne == 6, "spooked \(p.spooked), airborne \(airborne)")
        for _ in 0..<1200 {
            for f in w.flies where f.state == .flying { f.update(dt: dt, bounds: w.bounds, mouse: nil, signals: nil) }
            p.update(world: w, dt: dt, idle: 1, mouse: .zero, mouseSpeed: 0, handSpeed: 0)
        }
        check("spook: room stays empty while the user is active (20 s)", w.flies.isEmpty && p.spooked, "count \(w.flies.count), spooked \(p.spooked)")
        p.update(world: w, dt: dt, idle: 61, mouse: nil, mouseSpeed: 0, handSpeed: 0)
        check("spook: lifts once idle", !p.spooked, "spooked \(p.spooked)")
    }

    // --- squish + pressure ---
    do {
        TestRandom.reset("population squish")
        let g = Game(); let w = StubWorld()
        g.population.spawnFromEdge(world: w)
        let f = w.flies[0]; f.update(dt: 5, bounds: w.bounds, mouse: nil, signals: nil)
        let before = g.population.pressure
        g.squish(at: CGPoint(x: f.pos.x + 40, y: f.pos.y), world: w)
        let missed = w.flies.count == 1
        g.squish(at: CGPoint(x: f.pos.x + 10, y: f.pos.y), world: w)
        let hit = w.flies.isEmpty && w.scene.rootNode.childNodes.contains { $0.name == "splat" }
        check("squish: 40 px misses (hitbox 26), 10 px hits and leaves a splat, pressure +0.25",
              missed && hit && abs(g.population.pressure - before - 0.25) < 1e-6,
              "missed \(missed), hit \(hit), pressure \(before) -> \(g.population.pressure)")
    }

    // --- crumbs: picked up, placed, eaten, pressure relief ---
    do {
        TestRandom.reset("population crumbs")
        let g = Game(); let w = StubWorld()
        g.population.bumpPressure(1.0)
        let before = g.population.pressure
        g.crumbs.pickUp(world: w, at: .zero)
        g.crumbs.place(world: w, at: CGPoint(x: 100, y: 100))
        for _ in 0..<3 { g.population.spawnFromEdge(world: w) }
        for f in w.flies { f.update(dt: 5, bounds: w.bounds, mouse: nil, signals: nil); f.pos = CGPoint(x: 100, y: 100) }   // land, then sit on it
        var t: CGFloat = 0
        while !g.crumbs.crumbs.isEmpty && t < 200 { g.crumbs.update(world: w, dt: 0.1, mouse: nil); t += 0.1 }
        check("crumbs: three flies finish a crumb in ~27 s, pressure -0.15",
              (20...40).contains(t) && abs(before - g.population.pressure - 0.15) < 1e-6,
              String(format: "%.0f s, pressure %.2f -> %.2f", t, before, g.population.pressure))
    }

    // --- "the brain beat you" is only claimed when true ---
    do {
        TestRandom.reset("population miss")
        let g = Game(); let w = StubWorld()
        g.population.spawnFromEdge(world: w)            // arrives flying
        let brain = w.flies[0]
        var got: [CGFloat?] = []
        g.onMiss = { got.append($0) }
        w.brainEscapeAge = 0.3
        g.squish(at: CGPoint(x: brain.pos.x + 60, y: brain.pos.y), world: w)   // airborne, GF fired 0.3 s ago
        w.brainEscapeAge = 99
        g.squish(at: CGPoint(x: brain.pos.x + 60, y: brain.pos.y), world: w)   // airborne, but no GF spike
        let ok = got.count == 2 && got[0] != nil && abs(got[0]! - 0.3) < 1e-6 && got[1] == nil
        check("miss: lead time reported only when the Giant Fiber really fired", ok,
              "callbacks \(got.map { $0.map { String(format: "%.1f", $0) } ?? "nil" })")
    }

    // --- hearing primes the Giant Fiber without ever firing it by itself ---
    if let data = loadBrainData() {
        func gfFires(alert: Float, loom: Float) -> Bool {
            TestRandom.reset("hearing \(alert) \(loom)")
            let sim = LIFSim(circuit: data.circuit, spikeBus: nil)
            sim.step(400); _ = sim.consumeGF()
            sim.alert = alert
            sim.step(4000)                      // 4 s of a loud room, nothing approaching
            let quiet = !sim.consumeGF()
            sim.loomL = loom; sim.loomR = loom  // then an abrupt, modest loom
            sim.step(60)
            return !quiet ? true : sim.consumeGF() ? true : false
        }
        let restFires = !(["x"].isEmpty) && { () -> Bool in
            TestRandom.reset("hearing rest"); let sim = LIFSim(circuit: data.circuit, spikeBus: nil)
            sim.step(400); _ = sim.consumeGF(); sim.alert = 1; sim.step(4000); return sim.consumeGF() }()
        // find the smallest loom that tips GF, primed vs. not
        func threshold(alert: Float) -> Float {
            for l in stride(from: Float(0.05), through: 1.0, by: 0.05) where gfFires(alert: alert, loom: l) { return l }
            return 2
        }
        let tQuiet = threshold(alert: 0), tLoud = threshold(alert: 1)
        check("hearing: a loud room alone never fires GF (4 s)", !restFires, "fired \(restFires)")
        check("hearing: primed GF needs a smaller loom", tLoud < tQuiet,
              String(format: "loom threshold quiet %.2f -> loud %.2f", tQuiet, tLoud))
        // population statistic: escapes at a marginal loom over 40 seeds, quiet vs loud,
        // and GF activity from sound alone (20 s x 5 seeds, counted in 100 ms windows)
        func escapes(alert: Float, loom: Float) -> Int {
            var n = 0
            for seed in 0..<40 {
                TestRandom.reset("hearing stat \(seed)")
                let sim = LIFSim(circuit: data.circuit, spikeBus: nil)
                sim.step(400); _ = sim.consumeGF()
                sim.alert = alert; sim.step(600); _ = sim.consumeGF()
                sim.loomL = loom; sim.loomR = loom; sim.step(400)
                if sim.consumeGF() { n += 1 }
            }
            return n
        }
        var marginal: Float = 0.05, bestGap = 99
        for l in stride(from: Float(0.02), through: 0.20, by: 0.02) {
            let gap = abs(escapes(alert: 0, loom: l) - 20)
            if gap < bestGap { bestGap = gap; marginal = l }
        }
        let eq = escapes(alert: 0, loom: marginal), el = escapes(alert: 1, loom: marginal)
        var spurious = 0
        for seed in 0..<5 {
            TestRandom.reset("hearing alone \(seed)")
            let sim = LIFSim(circuit: data.circuit, spikeBus: nil)
            sim.step(400); _ = sim.consumeGF(); sim.alert = 1
            for _ in 0..<200 { sim.step(100); if sim.consumeGF() { spurious += 1 } }
        }
        check("hearing: more escapes at a marginal loom when the room is loud; sound alone stays near silent",
              el > eq + 4 && spurious <= 10,   // measured: 24 -> 34 of 40; ~6 windows per 100 s of max noise
              String(format: "loom %.2f: %d/40 quiet -> %d/40 loud; sound alone: %d GF windows in 100 s", marginal, eq, el, spurious))
    }

    UserDefaults.standard.removeObject(forKey: "popPressure")
    UserDefaults.standard.removeObject(forKey: "popPressureAt")
    print(failures == 0 ? "ALL POPULATION TESTS PASS" : "\(failures) POPULATION FAILURES")
    exit(failures == 0 ? 0 : 1)
}
