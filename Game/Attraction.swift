// The cursor (or a crumb) as a sugar drop. There is no gustatory circuit in
// the extracted data, so this is a synthetic input in the same spirit as
// loom: a light drive into the real steering (DNa01/02), forward-walking
// (DNp09) and grooming (DNg11) neurons so the brain window shows the pull
// and the fly grooms on arrival. The approach itself is scripted flight
// (Fly.attractHop): motor-mode walking covers ~1 px/s, measured below.

import Foundation

/// Steer sign by bearing, forward urge by distance, grooming on arrival.
/// Shared by the app loop and --attracttest.
func attractInputs(fly: Fly, target m: CGPoint) -> (turn: Float, drive: Float, groom: Float) {
    let rel = CGPoint(x: m.x - fly.pos.x, y: m.y - fly.pos.y)
    let dist = max(1, hypot(rel.x, rel.y))
    let f = CGPoint(x: cos(fly.heading), y: sin(fly.heading))
    let crossZ = (f.x * rel.y - f.y * rel.x) / dist      // >0: target on the left
    let arrived = dist < 55
    return (Float(clampf(crossZ * 1.5, -1, 1)),
            arrived ? 0 : Float(clampf(dist / 350, 0.4, 1)),
            arrived ? 0.7 : 0)
}

enum Attraction {
    /// Drive one fly toward a target: brain inputs (brain fly only), body
    /// heading bias, and the hop when it's far.
    static func drive(fly: Fly, toward m: CGPoint?, sim: LIFSim?, bounds: CGSize, dt: CGFloat) {
        guard let m, fly.state != .flying else {
            fly.attractTarget = nil
            if let sim { sim.attractTurn = 0; sim.attractDrive = 0; sim.attractGroom = 0 }
            return
        }
        let a = attractInputs(fly: fly, target: m)
        if let sim { sim.attractTurn = a.turn; sim.attractDrive = a.drive; sim.attractGroom = a.groom }
        fly.attractTarget = a.drive > 0 ? m : nil
        _ = fly.attractHop(toward: m, bounds: bounds, dt: dt)
    }
}

/// Headless: does the attractant actually bring the fly to the target with the
/// locomotor circuit driving the legs? Sweeps gains, prints distance over time.
/// Env: FWD, TURN (comma lists), SECS, ATTRACT=0 for a control run.
func runAttractTest() {
    guard let data = loadBrainData() else { fputs("no data/ — run etl.py first\n", stderr); exit(1) }
    let bounds = CGSize(width: 1512, height: 982)
    let dt: CGFloat = 1.0 / 60.0
    let target = CGPoint(x: 500, y: 250)
    let env = ProcessInfo.processInfo.environment
    let fwdGains: [Float] = (env["FWD"] ?? "0.008").split(separator: ",").compactMap { Float($0) }
    let turnGains: [Float] = (env["TURN"] ?? "0.02").split(separator: ",").compactMap { Float($0) }
    let seconds = CGFloat(Double(env["SECS"] ?? "40") ?? 40)
    let attractEnabled = env["ATTRACT"] != "0"
    for fg in fwdGains { for tg in turnGains {
        TestRandom.reset("attract \(fg) \(tg)")
        let sim = LIFSim(circuit: data.circuit, spikeBus: nil, locomotorCircuit: data.locomotor)
        sim.attractFwdGain = fg; sim.attractTurnGain = tg
        let builder = SignalBuilder()
        let fly = Fly(at: .zero); fly.state = .idle; fly.speed = 0; fly.heading = .pi   // facing away
        sim.step(400); _ = sim.consumeGF()
        var line = String(format: "fwd=%.3f turn=%.3f  dist:", fg, tg)
        var walking = 0, grooming = 0, flying = 0, frames = 0, arrivedAt: CGFloat = -1
        var t: CGFloat = 0
        var fwdHz: Float = 0, dnaHz: Float = 0
        var path: CGFloat = 0, lastPos = fly.pos
        while t < seconds {
            Attraction.drive(fly: fly, toward: attractEnabled ? target : nil, sim: sim, bounds: bounds, dt: dt)
            // body -> brain closed loop, as the app does each frame
            sim.gaitDrive = Float(fly.walkingIntensity)
            sim.gaitPhase = Float(fly.gaitPhasePublic)
            sim.legFeedback = fly.legFeedback
            sim.step(Int((dt * 1000).rounded()))
            let sig = builder.make(sim, dt: dt)
            fly.update(dt: dt, bounds: bounds, mouse: nil, signals: sig)
            t += dt; frames += 1
            path += hypot(fly.pos.x - lastPos.x, fly.pos.y - lastPos.y); lastPos = fly.pos
            fwdHz += sim.rateFwd; dnaHz += max(sim.rateDNaL, sim.rateDNaR)
            switch fly.state { case .walking: walking += 1; case .grooming: grooming += 1; case .flying: flying += 1; default: break }
            let d = hypot(target.x - fly.pos.x, target.y - fly.pos.y)
            if d < 55 && arrivedAt < 0 { arrivedAt = t }
            if frames % 600 == 0 { line += String(format: " %.0f", d) }
        }
        line += String(format: "  arrived=%@ path=%.0fpx walk=%d%% groom=%d%% fly=%d%%  fwd=%.0fHz dna=%.0fHz",
                       arrivedAt < 0 ? "no" : String(format: "%.0fs", arrivedAt), path,
                       walking * 100 / frames, grooming * 100 / frames, flying * 100 / frames,
                       fwdHz / Float(frames), dnaHz / Float(frames))
        print(line); fflush(stdout)
    } }
}
