// The pest game layer, owned by the Coordinator and stepped from its render
// loop. Everything here is scripted; the fly, its brain and body are the
// engine's. See ENGINE.md for the handful of places the engine was touched.

import Foundation

final class Game {
    let population = Population()
    let crumbs = Crumbs()
    let splats = Splats()
    let stats = Stats()
    var attractOn = false
    var sound: FlySound?   // nil = muted (set from the main thread)

    private let attractDebug = ProcessInfo.processInfo.environment["DESKTOPFLY_ATTRACT_DEBUG"] != nil
    private var attractDbgClock: CGFloat = 0

    init() {
        crumbs.onFinished = { [weak self] in self?.population.bumpPressure(-0.15); self?.stats.noteCrumb() }
    }

    /// A click on the desktop: squish if a grounded fly is under it.
    func squish(at p: CGPoint, world: GameWorld) {
        guard splats.squish(at: p, world: world) != nil else {
            // a swing that missed near a fly: it saw you coming. Make that audible.
            if splats.enabled, splats.nearMiss(at: p, world: world) { stats.noteMiss(); sound?.miss() }
            return
        }
        sound?.splat()
        stats.noteKill()
        population.noteSquish(world: world)
    }

    /// Before the brain steps: world housekeeping that doesn't need the sim.
    func preSim(world: GameWorld, dt: CGFloat, mouse: CGPoint?, idle: CGFloat, mouseSpeed: CGFloat, handSpeed: CGFloat) {
        splats.update(dt: dt, world: world)
        crumbs.update(world: world, dt: dt, mouse: mouse)
        buzz(world: world)
        stats.notePopulation(world.flies.count)
        stats.noteIdle(TimeInterval(idle))
        population.update(world: world, dt: dt, idle: idle, mouse: mouse, mouseSpeed: mouseSpeed, handSpeed: handSpeed)
    }

    /// Food targets: crumbs first (every fly), else the cursor if attraction is
    /// on (brain fly only). Sets the sim's attract inputs for the brain fly.
    func drive(sim: LIFSim, world: GameWorld, mouse: CGPoint?, dt: CGFloat) {
        guard let first = world.flies.first else { return }
        let brainTarget = crumbs.nearest(to: first) ?? (attractOn ? mouse : nil)
        Attraction.drive(fly: first, toward: brainTarget, sim: sim, bounds: world.bounds, dt: dt)
        for fly in world.flies.dropFirst() {
            let m = crumbs.nearest(to: fly)
            Attraction.drive(fly: fly, toward: m, sim: nil, bounds: world.bounds, dt: dt)
            // extras don't hop around a crumb they're already on
            if let m, hypot(m.x - fly.pos.x, m.y - fly.pos.y) <= 55 { fly.attractTarget = nil }
        }
        if attractDebug {
            attractDbgClock += dt
            if attractDbgClock >= 1 {
                attractDbgClock = 0
                let m = mouse ?? .zero
                fputs(String(format: "attract on=%d state=%@ fly=(%.0f,%.0f) mouse=(%.0f,%.0f) turn=%.2f drive=%.2f groom=%.2f | DNaL=%.1f DNaR=%.1f fwd=%.1f groomHz=%.1f loom=%.1f legs=%d flies=%d\n",
                             attractOn ? 1 : 0, "\(first.state)", first.pos.x, first.pos.y, m.x, m.y,
                             sim.attractTurn, sim.attractDrive, sim.attractGroom,
                             sim.rateDNaL, sim.rateDNaR, sim.rateFwd, sim.rateGroom, sim.rateLoom,
                             sim.locomotor?.commands != nil ? 1 : 0, world.flies.count), stderr)
            }
        }
    }

    /// Buzz: loudest airborne fly, pitch from its effort, panned to its x.
    private func buzz(world: GameWorld) {
        guard let snd = sound else { return }
        if let f = world.flies.filter({ $0.state == .flying }).max(by: { $0.effortCurrent < $1.effortCurrent }) {
            snd.setBuzz(level: Float(0.45 + 0.55 * f.effortCurrent) * Float(0.6 + 0.4 * f.alt),
                        pitch: Float(0.9 + 0.6 * f.effortCurrent),
                        pan: Float(clampf(f.pos.x / (world.bounds.width / 2), -1, 1)))
        } else {
            snd.setBuzz(level: 0, pitch: 1, pan: 0)
        }
        // the hum of a crowd: nothing at the home population, full at the cap
        let n = world.flies.count
        snd.setDrone(level: n <= population.homeFlies ? 0 : Float(min(1, log(Double(n - population.homeFlies + 1)) / log(157))))
    }
}
