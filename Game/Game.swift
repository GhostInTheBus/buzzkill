// The pest game layer, owned by the Coordinator and stepped from its render
// loop. Everything here is scripted; the fly, its brain and body are the
// engine's. See ENGINE.md for the handful of places the engine was touched.

import Foundation

final class Game {
    let population = Population()
    let crumbs = Crumbs()
    let splats = Splats()
    let stats = Stats()
    let shadows = FlyShadows()
    var attractOn = false
    var sound: FlySound?   // nil = muted (set from the main thread)
    var hearing: Hearing?  // nil = mic off (set from the main thread)
    /// Render thread. Called on a swing that missed near a fly: the lead time (s)
    /// by which the brain fly's Giant Fiber beat the click, or nil when the
    /// getaway wasn't a real GF escape (a brainless fly, or just a bad aim).
    var onMiss: ((CGFloat?) -> Void)?
    private var selfSoundMute: CGFloat = 0   // the mic shouldn't hear our own splat/zip

    /// Sound in the room, 0..1: a typing burst or the mic over ambient.
    func alert(typing: CGFloat) -> Float {
        let keys = Float(clampf((typing - 0.5) * 2, 0, 1))
        return max(keys, selfSoundMute > 0 ? 0 : (hearing?.read() ?? 0))
    }

    private let attractDebug = ProcessInfo.processInfo.environment["DESKTOPFLY_ATTRACT_DEBUG"] != nil
    private var attractDbgClock: CGFloat = 0

    init() {
        crumbs.onFinished = { [weak self] in self?.population.bumpPressure(-0.15); self?.stats.noteCrumb() }
        crumbs.onPlaced = { [weak self] in self?.population.noteCrumbPlaced() }
    }

    /// A click on the desktop: squish if a grounded fly is under it.
    func squish(at p: CGPoint, world: GameWorld) {
        guard splats.squish(at: p, world: world) != nil else {
            // a swing that missed near a fly: it saw you coming. Make that audible.
            if splats.enabled, splats.nearMiss(at: p, world: world) {
                stats.noteMiss(); sound?.miss(); selfSoundMute = 0.4
                // only claim "the brain beat you" when it's true
                var lead: CGFloat? = nil
                if let brain = world.flies.first, brain.state == .flying,
                   hypot(p.x - brain.pos.x, p.y - brain.pos.y) < 260, world.brainEscapeAge < 1.5 {
                    lead = world.brainEscapeAge
                }
                onMiss?(lead)
            }
            return
        }
        sound?.splat(); selfSoundMute = 0.4
        stats.noteKill()
        population.noteSquish(world: world)
    }

    /// Before the brain steps: world housekeeping that doesn't need the sim.
    func preSim(world: GameWorld, dt: CGFloat, mouse: CGPoint?, idle: CGFloat, mouseSpeed: CGFloat, handSpeed: CGFloat) {
        selfSoundMute = max(0, selfSoundMute - dt)
        splats.update(dt: dt, world: world)
        crumbs.update(world: world, dt: dt, mouse: mouse)
        buzz(world: world)
        shadows.update(flies: world.flies, scene: world.scene)
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
            // a housefly drones lower, a mosquito whines
            snd.setBuzz(level: Float(0.45 + 0.55 * f.effortCurrent) * Float(0.6 + 0.4 * f.alt) * (f.model.voice > 2 ? 0.55 : 1),
                        pitch: Float((0.9 + 0.6 * f.effortCurrent) * f.model.voice),
                        pan: Float(clampf(f.pos.x / (world.bounds.width / 2), -1, 1)))
        } else {
            snd.setBuzz(level: 0, pitch: 1, pan: 0)
        }
        // the hum of a crowd: nothing at the home population, full at the cap
        let n = world.flies.count
        snd.setDrone(level: n <= population.homeFlies ? 0 : Float(min(1, log(Double(n - population.homeFlies + 1)) / log(157))))
    }
}
