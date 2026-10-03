// The camera as the fly's eyes. The only visual inputs in the extracted
// circuit are the LC4/LPLC2 looming detectors, which respond to expansion:
// something getting bigger in the visual field is something approaching. So
// the camera path ignores screen geometry entirely. Motion in the frame is
// the stimulus; how fast the moving region grows is the loom; which half of
// the frame it's in picks the eye; how fast it sweeps across is the air puff.
// Pure state machine; the Coordinator owns one.

import Foundation

struct HandLoom {
    private var prev: CGPoint?
    private var vel = CGPoint.zero
    private var velRaw = CGPoint.zero
    private var sampleDt: CGFloat = 0
    private var prevExtent: CGFloat = 0
    private var extentSmooth: CGFloat = 0
    private var growth: CGFloat = 0      // d(extent)/dt, smoothed; >0 = expanding = approaching

    /// Sweep speed of the moving region, scene px/s (for the spook detector).
    var speed: CGFloat { hypot(vel.x, vel.y) }

    /// `hand`: motion centroid in scene coords (x<0 = the fly's left eye's half
    /// of the frame); `extent`: moving fraction of the frame, ~0..1.
    mutating func compute(fly: Fly, hand: CGPoint?, extent: CGFloat, dt: CGFloat) -> (l: Float, r: Float, puff: Float) {
        guard let h = hand, dt > 0 else {
            prev = nil; vel = .zero; velRaw = .zero; sampleDt = 0
            growth *= 0.8; extentSmooth *= 0.8; prevExtent = 0
            return (0, 0, 0)
        }
        if let ph = prev {
            // sampled at ~15 Hz by the camera, consumed per rendered frame
            sampleDt += dt
            if h != ph || extent != prevExtent || sampleDt >= 1.0 / 15 {
                velRaw = CGPoint(x: (h.x - ph.x) / sampleDt, y: (h.y - ph.y) / sampleDt)
                let growthRaw = (extent - prevExtent) / sampleDt
                growth += (growthRaw - growth) * 0.5
                prev = h; prevExtent = extent
                sampleDt = 0
            }
            let k = lag(24, dt)
            vel.x += (velRaw.x - vel.x) * k
            vel.y += (velRaw.y - vel.y) * k
        } else {
            prev = h; prevExtent = extent; sampleDt = 0
        }
        extentSmooth += (extent - extentSmooth) * lag(12, dt)
        // expansion is the stimulus: a hand wave (~0.3 of our scaled extent) that
        // appears within ~0.3 s reads as growth ~1; a lunge at the screen much more.
        // Something already filling the frame is a big object close by.
        var loom = clampf(max(0, growth) / 1.0, 0, 1)
        loom += clampf((extentSmooth - 0.35) / 0.65, 0, 1) * 0.5
        loom = clampf(loom, 0, 1)
        // which eye: left half of the (mirrored) frame is the fly's left
        let side = clampf(-h.x / 600, -1, 1)              // -1 right edge … +1 left edge
        let lw = clampf(0.5 + 0.5 * side, 0.12, 1)
        let rw = clampf(0.5 - 0.5 * side, 0.12, 1)
        // a fast sweep across the field is wind
        let puff = clampf(hypot(vel.x, vel.y) / 1500, 0, 1) * clampf(extentSmooth * 3, 0, 1)
        return (Float(loom * lw), Float(loom * rw), Float(puff))
    }
}
