// Who's on the desktop and why: arrivals, swarms while you're away, the
// scatter when you come back, spooking, shooing, and the persisted
// "population pressure" that squishing raises and crumbs lower.

import Foundation

final class Population {
    /// The "appropriate" population when you're at the desk.
    let homeFlies = 4
    /// DESKTOPFLY_SWARM_TEST=N: spawn a fly a second up to N (stress test).
    let swarmTest = ProcessInfo.processInfo.environment["DESKTOPFLY_SWARM_TEST"].flatMap { Int($0) ?? 48 }

    private var spawnTimer: CGFloat = 0
    private lazy var nextSpawnIn: CGFloat = swarmTest != nil ? 1 : rnd(60...240)
    private var wasAway = false
    private var scheduledAway = false   // which regime the pending wait was drawn from
    private var shake: CGFloat = 0
    private(set) var spooked = false
    /// Crumbs draw a crowd: each crumb dropped adds room for three more flies
    /// (up to +12), who arrive within seconds and stay. Fades by one every 5 min.
    private(set) var crumbDraw: CGFloat = 0
    /// Flies the user asked for from the menu. They stay until squished or shooed
    /// off; each one that goes gives its seat back.
    private(set) var invited = 0
    /// The population the desk settles at right now (home + crumb crowd + invited).
    var settled: Int { homeFlies + Int(crumbDraw.rounded(.up)) + invited }

    func invite(_ n: Int, world: GameWorld) {
        let room = max(0, 160 - world.flies.count)
        let k = min(n, room)
        invited += k
        for _ in 0..<k { spawnFromEdge(world: world) }
    }

    func noteCrumbPlaced() {
        crumbDraw = min(12, crumbDraw + 3)
        nextSpawnIn = min(nextSpawnIn, spawnTimer + rnd(1.5...4))   // word gets around fast
    }
    private(set) var idle: CGFloat = 0

    // Squishing slows arrivals, finished crumbs speed them up. Persisted,
    // decays toward 0 over a day.
    private(set) var pressure: CGFloat = {
        let d = UserDefaults.standard
        let p = CGFloat(d.double(forKey: "popPressure"))
        let t = d.double(forKey: "popPressureAt")
        let days = t > 0 ? (Date().timeIntervalSince1970 - t) / 86400 : 0
        return max(0, p - CGFloat(days))
    }()

    func bumpPressure(_ delta: CGFloat) {
        pressure = clampf(pressure + delta, 0, 2)
        UserDefaults.standard.set(Double(pressure), forKey: "popPressure")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "popPressureAt")
    }

    /// Away: the cap climbs with time gone (1.5/min: ~50 after half an hour,
    /// ~95 after an hour, 160 by 1h45) so any extended absence builds a swarm.
    var maxFlies: Int {
        if let n = swarmTest { return n }
        return idle > 60 ? min(160, settled + Int(idle / 60 * 1.5)) : settled
    }

    func scheduleNextSpawn(_ base: ClosedRange<CGFloat>? = nil, count: Int) {
        spawnTimer = 0
        scheduledAway = idle > 60
        if swarmTest != nil { nextSpawnIn = 1; return }
        // at the desk: a new fly every 1.5-4 min. Away: 20-50 s, and flies attract
        // flies — each one present shortens the wait by 8%, floor 5 s.
        let away = idle > 60
        var wait = rnd(base ?? (away ? 20...50 : 90...240)) * (1 + pressure)
        if away { wait = max(5, wait * pow(0.92, CGFloat(count))) }
        // seats opened by a crumb fill quickly, whatever else is going on
        if base == nil && crumbDraw > 0 && count < settled && count >= homeFlies { wait = rnd(3...8) }
        nextSpawnIn = wait
    }

    /// A squish happened: pressure up; a lone fly gone means the next comes sooner.
    func noteSquish(world: GameWorld) {
        bumpPressure(0.25)
        if world.flies.count < settled { invited = max(0, invited - 1) }
        if world.flies.isEmpty { scheduleNextSpawn(8...30, count: 0) }
    }

    /// The user is back: anything beyond the home population scatters off screen.
    func disperse(world: GameWorld, from p: CGPoint?) {
        let extra = world.flies.count - settled
        guard extra > 0 else { return }
        let threat = p ?? .zero
        // keep the brain fly (index 0); send a random `extra` of the rest away
        for fly in Array(world.flies.dropFirst()).shuffled().prefix(extra) where fly.state != .flying {
            fly.forceLeave = true
            fly.startFlight(bounds: world.bounds, awayFrom: threat, escape: true)
        }
        world.startle(0.6)          // the brain fly startles too (but stays)
        scheduleNextSpawn(count: world.flies.count)
    }

    /// Everything leaves; nothing comes back until the user has been idle a while.
    func spook(world: GameWorld, from p: CGPoint?) {
        spooked = true; shake = 0
        let threat = p ?? .zero
        for fly in world.flies where fly.state != .flying {
            fly.forceLeave = true
            fly.startFlight(bounds: world.bounds, awayFrom: threat, escape: true)
        }
        world.startle(0.6)
    }

    /// After an idle pause: the flies that would have arrived meanwhile stream in now.
    func catchUp(world: GameWorld) {
        let want = maxFlies - world.flies.count
        for _ in 0..<max(0, want) { spawnFromEdge(world: world) }
        scheduleNextSpawn(count: world.flies.count)
    }

    func spawnFromEdge(world: GameWorld) {
        let hw = world.bounds.width / 2 - 30, hh = world.bounds.height / 2 - 30
        let p: CGPoint
        switch TestRandom.integer(in: 0..<4) {
        case 0: p = CGPoint(x: -hw, y: rnd(-hh...hh))
        case 1: p = CGPoint(x: hw, y: rnd(-hh...hh))
        case 2: p = CGPoint(x: rnd(-hw...hw), y: -hh)
        default: p = CGPoint(x: rnd(-hw...hw), y: hh)
        }
        let fly = Fly(at: p)
        world.scene.rootNode.addChildNode(fly.node)
        world.flies.append(fly)
        fly.startFlight(bounds: world.bounds)   // arrives on the wing
    }

    /// Per frame. `mouseSpeed`/`handSpeed` in scene px/s.
    func update(world: GameWorld, dt: CGFloat, idle: CGFloat, mouse: CGPoint?, mouseSpeed: CGFloat, handSpeed: CGFloat) {
        self.idle = idle
        crumbDraw = max(0, crumbDraw - dt / 300)
        // shooed flies that made it off screen
        if world.flies.contains(where: { $0.gone }) {
            let before = world.flies.count
            world.flies.removeAll { if $0.gone { $0.node.removeFromParentNode(); return true }; return false }
            invited = max(0, invited - (before - world.flies.count))
            if world.flies.isEmpty { scheduleNextSpawn(8...30, count: 0) }
        }
        // hard cursor shaking (or hand waving) builds up; ~1.2 s of it within a
        // couple of seconds spooks the room
        let fast = mouseSpeed > 1100 || handSpeed > 900
        shake = clampf(shake + (fast ? dt : -dt * 0.6), 0, 3)
        if shake > 1.2 && !spooked { spook(world: world, from: mouse) }
        if spooked && idle > 60 { spooked = false; scheduleNextSpawn(count: world.flies.count) }
        // coming back after being away: the swarm scatters on your first input
        if idle > 60 { wasAway = true }
        else if wasAway && idle < 3 { wasAway = false; disperse(world: world, from: mouse) }
        // a crowd scatters more readily than a lone fly
        let chance = clampf(0.25 + 0.06 * CGFloat(world.flies.count), 0, 0.85)
        for fly in world.flies { fly.leaveChance = chance }
        // the regime flipped (left the desk / came back): redraw the pending wait
        if (idle > 60) != scheduledAway { scheduledAway = idle > 60; scheduleNextSpawn(count: world.flies.count) }
        // arrivals, up to the cap
        spawnTimer += dt
        if !spooked && world.flies.count < maxFlies && spawnTimer >= nextSpawnIn {
            scheduleNextSpawn(count: world.flies.count + 1)
            spawnFromEdge(world: world)
        }
    }
}
