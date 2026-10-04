// Offscreen preview of how flies actually look in the overlay: the real scene
// (its lights and shadow catcher) seen top-down, over a desktop-like
// background, zoomed in. One fly standing, one walking, one in flight.
//
//   ./Buzzkill --looktest out.png [--beetle]

import SceneKit

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
