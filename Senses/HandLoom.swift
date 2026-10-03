// A hand seen by the camera is a second looming object. Same geometry as the
// cursor loom in Coordinator.computeLoom (planar approach + proximity), plus
// the hand growing in the frame, which is what a swat at the screen looks
// like from the webcam. Pure state machine; the Coordinator owns one.

import Foundation

struct HandLoom {
    private var prevHand: CGPoint?
    private var vel = CGPoint.zero
    private var velRaw = CGPoint.zero
    private var sampleDt: CGFloat = 0
    private var prevExtent: CGFloat = 0
    private var growth: CGFloat = 0      // d(extent)/dt, smoothed; >0 = lunging at the screen

    var speed: CGFloat { hypot(vel.x, vel.y) }

    mutating func compute(fly: Fly, hand: CGPoint?, extent: CGFloat, dt: CGFloat) -> (l: Float, r: Float, puff: Float) {
        guard let h = hand, dt > 0 else {
            prevHand = nil; vel = .zero; velRaw = .zero; growth = 0; prevExtent = 0
            return (0, 0, 0)
        }
        if let ph = prevHand {
            // sampled at ~15 Hz by the camera, consumed per rendered frame
            sampleDt += dt
            if h != ph || sampleDt >= 1.0 / 15 {
                velRaw = CGPoint(x: (h.x - ph.x) / sampleDt, y: (h.y - ph.y) / sampleDt)
                let growthRaw = max(0, (extent - prevExtent) / sampleDt)
                growth += (growthRaw - growth) * 0.5
                prevHand = h; prevExtent = extent
                sampleDt = 0
            }
            let k = lag(24, dt)
            vel.x += (velRaw.x - vel.x) * k
            vel.y += (velRaw.y - vel.y) * k
        } else {
            prevHand = h; prevExtent = extent; sampleDt = 0
        }
        let rel = CGPoint(x: h.x - fly.pos.x, y: h.y - fly.pos.y)
        let dist = max(20, hypot(rel.x, rel.y))
        let approach = -(rel.x * vel.x + rel.y * vel.y) / dist
        var loom = clampf(approach / dist * 6, 0, 1) * clampf(1 - dist / 900, 0, 1)
        loom += clampf(growth / 1.5, 0, 1) * clampf(1 - dist / 700, 0, 1)
        loom = clampf(loom, 0, 1)
        let f = CGPoint(x: cos(fly.heading), y: sin(fly.heading))
        let rd = CGPoint(x: rel.x / dist, y: rel.y / dist)
        let crossZ = f.x * rd.y - f.y * rd.x
        let lw = clampf(0.5 + 0.5 * crossZ, 0.12, 1)
        let rw = clampf(0.5 - 0.5 * crossZ, 0.12, 1)
        let puff = clampf(hypot(vel.x, vel.y) / 1500, 0, 1) * clampf(1 - dist / 600, 0, 1)
        return (Float(loom * lw), Float(loom * rw), Float(puff))
    }
}
