// How the fly carries itself — app-level style, layered on the engine's
// behavior without changing what the brain decides.
//
// Measured with --motionprofile before this existed: walking, idling and
// grooming bouts averaged half a second (about 1.5 state changes a second),
// and "walking" covered 11 px/s — under half a body length a second, median
// 6 px per bout. The fly twitched in place and only really moved by flying.
//
//   * boutHold: once a walking or grooming bout begins it is held for a
//     randomized minimum. Escape, darting, sleep and backward walking still
//     interrupt at once.
//   * strideGain: in motor mode the legs' stepping comes from the MaleCNS
//     circuit; this scales how far the body travels per step so a walk covers
//     ground. The gait is the circuit's; the distance per stride is a choice.
//   * flightArc: flights bow to one side instead of following a ruled line,
//     and the body faces along the curve.
//
// The engine defaults (nil, 1, 0) are upstream's behavior, and are what the
// headless suites run against.

import Foundation

enum MotionStyle {
    static func apply() {
        Fly.boutHold = (walk: 1.2...3.5, groom: 1.8...4.5)
        Fly.strideGain = 6
        Fly.flightArc = 0.22
    }
}
