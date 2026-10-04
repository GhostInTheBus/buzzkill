// A second fruit-fly body: the same proportions and the same FlyModel contract
// as upstream's, restyled toward "stylized-real" — glass wings with veins,
// faceted brick-red eyes, glossy chitin, bristles, tapered dark legs. Purely
// cosmetic; the behavior layer cannot tell the two apart.

import SceneKit

private func image(_ w: Int, _ h: Int, _ draw: (NSRect) -> Void) -> NSImage {
    let img = NSImage(size: NSSize(width: w, height: h))
    img.lockFocus(); draw(NSRect(x: 0, y: 0, width: w, height: h)); img.unlockFocus()
    return img
}
private func gloss(_ diffuse: Any, specular: CGFloat = 0.75, shininess: CGFloat = 0.75) -> SCNMaterial {
    let m = SCNMaterial()
    m.lightingModel = .blinn
    m.diffuse.contents = diffuse
    m.specular.contents = NSColor(white: specular, alpha: 1)
    m.shininess = shininess
    return m
}

/// Tergite bands with soft edges, darkening toward the tip, a pale midline sheen.
private func detailedAbdomenTexture() -> NSImage {
    image(128, 256) { r in
        NSGradient(colors: [NSColor(calibratedRed: 0.80, green: 0.62, blue: 0.34, alpha: 1),
                            NSColor(calibratedRed: 0.62, green: 0.44, blue: 0.22, alpha: 1)])!.draw(in: r, angle: 90)
        let dark = NSColor(calibratedRed: 0.13, green: 0.08, blue: 0.05, alpha: 1)
        // texture v runs tip (0) -> waist (1) on the sphere as upstream maps it
        for (y, h, a) in [(0.0, 54.0, 1.0), (72.0, 22.0, 0.95), (116.0, 20.0, 0.9), (160.0, 17.0, 0.85), (200.0, 13.0, 0.7)] {
            let band = NSRect(x: 0, y: y, width: 128, height: h)
            NSGradient(colors: [dark.withAlphaComponent(0), dark.withAlphaComponent(a), dark.withAlphaComponent(a), dark.withAlphaComponent(0)],
                       atLocations: [0, 0.22, 0.78, 1], colorSpace: .genericRGB)!.draw(in: band.insetBy(dx: 0, dy: -4), angle: 90)
        }
    }
}

/// Warm brown with faint longitudinal stripes and a little speckle.
private func thoraxTexture() -> NSImage {
    image(128, 128) { r in
        NSColor(calibratedRed: 0.47, green: 0.33, blue: 0.18, alpha: 1).setFill(); r.fill()
        NSColor(calibratedRed: 0.30, green: 0.20, blue: 0.11, alpha: 0.55).setFill()
        for x in [26.0, 46.0, 78.0, 98.0] { NSRect(x: x, y: 0, width: 5, height: 128).fill() }
        NSColor(calibratedRed: 0.2, green: 0.13, blue: 0.07, alpha: 0.10).setFill()
        var s: UInt32 = 7
        for _ in 0..<90 {
            s = s &* 1664525 &+ 1013904223; let x = Double(s >> 8 & 127)
            s = s &* 1664525 &+ 1013904223; let y = Double(s >> 8 & 127)
            NSRect(x: x, y: y, width: 1.4, height: 1.4).fill()
        }
    }
}

/// Deep brick red with a hexagonal facet lattice.
private func eyeTexture() -> NSImage {
    image(128, 128) { r in
        NSGradient(colors: [NSColor(calibratedRed: 0.52, green: 0.09, blue: 0.06, alpha: 1),
                            NSColor(calibratedRed: 0.30, green: 0.03, blue: 0.03, alpha: 1)])!.draw(in: r, angle: 60)
        NSColor(calibratedRed: 0.16, green: 0.01, blue: 0.01, alpha: 0.55).setStroke()
        let step = 7.0
        var row = 0
        var y = 0.0
        while y < 132 {
            var x = row % 2 == 0 ? 0.0 : step / 2
            while x < 132 {
                let p = NSBezierPath(ovalIn: NSRect(x: x - step * 0.42, y: y - step * 0.42, width: step * 0.84, height: step * 0.84))
                p.lineWidth = 1.1; p.stroke()
                x += step
            }
            y += step * 0.87; row += 1
        }
    }
}

/// One wing, drawn hinge-up: clear membrane, dark veins, a faint oil-slick tint.
private func wingTexture() -> NSImage {
    let W = 200.0, H = 560.0
    return image(Int(W), Int(H)) { _ in
        // outline: narrow at the hinge (top), broadest two-thirds down, rounded tip
        let o = NSBezierPath()
        o.move(to: NSPoint(x: W * 0.50, y: H - 6))
        o.curve(to: NSPoint(x: W * 0.94, y: H * 0.34), controlPoint1: NSPoint(x: W * 0.66, y: H * 0.93), controlPoint2: NSPoint(x: W * 0.99, y: H * 0.62))
        o.curve(to: NSPoint(x: W * 0.52, y: 8), controlPoint1: NSPoint(x: W * 0.91, y: H * 0.13), controlPoint2: NSPoint(x: W * 0.74, y: 8))
        o.curve(to: NSPoint(x: W * 0.07, y: H * 0.30), controlPoint1: NSPoint(x: W * 0.28, y: 8), controlPoint2: NSPoint(x: W * 0.08, y: H * 0.13))
        o.curve(to: NSPoint(x: W * 0.50, y: H - 6), controlPoint1: NSPoint(x: W * 0.05, y: H * 0.60), controlPoint2: NSPoint(x: W * 0.34, y: H * 0.93))
        o.close()
        NSGraphicsContext.saveGraphicsState()
        o.addClip()
        // membrane: barely there, with a cool-to-warm iridescence
        NSColor(calibratedWhite: 1, alpha: 0.17).setFill(); o.fill()
        NSGradient(colors: [NSColor(calibratedRed: 0.55, green: 0.85, blue: 1.0, alpha: 0.13),
                            NSColor(calibratedRed: 1.0, green: 0.70, blue: 0.90, alpha: 0.10),
                            NSColor(calibratedRed: 0.80, green: 1.0, blue: 0.75, alpha: 0.10)])!
            .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: 70)
        // veins
        NSColor(calibratedRed: 0.20, green: 0.13, blue: 0.08, alpha: 0.50).setStroke()
        func vein(_ pts: [(Double, Double)], _ w: CGFloat) {
            let p = NSBezierPath(); p.lineWidth = w * 2.1; p.lineCapStyle = .round   // wide enough to survive minification
            p.move(to: NSPoint(x: W * pts[0].0, y: H * pts[0].1))
            p.curve(to: NSPoint(x: W * pts[3].0, y: H * pts[3].1),
                    controlPoint1: NSPoint(x: W * pts[1].0, y: H * pts[1].1),
                    controlPoint2: NSPoint(x: W * pts[2].0, y: H * pts[2].1))
            p.stroke()
        }
        let hinge = (0.50, 0.985)
        vein([hinge, (0.72, 0.86), (0.93, 0.62), (0.90, 0.36)], 3.2)   // L1 / costa side
        vein([hinge, (0.62, 0.80), (0.80, 0.45), (0.76, 0.12)], 2.6)   // L2
        vein([hinge, (0.54, 0.75), (0.62, 0.35), (0.56, 0.03)], 2.6)   // L3
        vein([hinge, (0.46, 0.75), (0.42, 0.35), (0.34, 0.06)], 2.4)   // L4
        vein([hinge, (0.36, 0.80), (0.20, 0.55), (0.12, 0.26)], 2.2)   // L5
        vein([(0.585, 0.62), (0.56, 0.615), (0.50, 0.61), (0.455, 0.615)], 2.0)   // anterior crossvein
        vein([(0.43, 0.33), (0.36, 0.34), (0.28, 0.38), (0.215, 0.42)], 2.0)       // posterior crossvein
        NSGraphicsContext.restoreGraphicsState()
        NSColor(calibratedRed: 0.20, green: 0.13, blue: 0.08, alpha: 0.50).setStroke()
        o.lineWidth = 5; o.stroke()
    }
}

// Textures are drawn once and shared by every fly.
private enum DetailedTextures {
    static let abdomen = detailedAbdomenTexture()
    static let thorax = thoraxTexture()
    static let eye = eyeTexture()
    static let wing = wingTexture()
}

func buildDetailedFlyModel() -> FlyModel {
    let root = SCNNode()
    root.scale = SCNVector3(FLY_SCALE, FLY_SCALE, FLY_SCALE)
    // Everything rigid (thorax, head, eyes, antennae, bristles) is built under
    // `rigid` and merged into a few meshes at the end: ~45 draw calls become ~6,
    // which is what lets a 160-fly swarm hold frame rate.
    let rigid = SCNNode()
    let chitinDark = NSColor(calibratedRed: 0.15, green: 0.10, blue: 0.06, alpha: 1)

    // thorax: glossy, striped, with a scutellum behind it
    let thoraxGeo = SCNSphere(radius: 4.6)
    thoraxGeo.segmentCount = 28
    thoraxGeo.materials = [gloss(DetailedTextures.thorax, specular: 0.7, shininess: 0.8)]
    let thorax = SCNNode(geometry: thoraxGeo)
    thorax.position = SCNVector3(0, 2.5, 6.2)
    thorax.scale = SCNVector3(0.95, 1.15, 0.85)
    rigid.addChildNode(thorax)
    let scutGeo = SCNSphere(radius: 2.1)
    scutGeo.materials = [gloss(NSColor(calibratedRed: 0.36, green: 0.24, blue: 0.13, alpha: 1))]
    let scut = SCNNode(geometry: scutGeo)
    scut.position = SCNVector3(0, -2.3, 8.0)
    scut.scale = SCNVector3(1.15, 0.8, 0.55)
    rigid.addChildNode(scut)

    // abdomen: identical placement and pivot to the classic body (it wags)
    let abdGeo = SCNSphere(radius: 5.0)
    abdGeo.segmentCount = 28
    abdGeo.materials = [gloss(DetailedTextures.abdomen, specular: 0.65, shininess: 0.7)]
    let abdomen = SCNNode(geometry: abdGeo)
    abdomen.pivot = SCNMatrix4MakeTranslation(0, 3.5, 0)
    abdomen.position = SCNVector3(0, -1.25, 5.6)
    abdomen.scale = SCNVector3(0.9, 1.5, 0.75)
    root.addChildNode(abdomen)

    // head: a little larger and paler, with a dark stripe of bristles between the eyes
    let headGeo = SCNSphere(radius: 3.15)
    headGeo.materials = [gloss(NSColor(calibratedRed: 0.62, green: 0.48, blue: 0.28, alpha: 1), specular: 0.5, shininess: 0.5)]
    let head = SCNNode(geometry: headGeo)
    head.position = SCNVector3(0, 9.0, 6.0)
    head.scale = SCNVector3(1.0, 0.85, 0.9)
    rigid.addChildNode(head)

    let eyeGeo = SCNSphere(radius: 2.15)
    eyeGeo.segmentCount = 20
    let eyeMat = gloss(DetailedTextures.eye, specular: 1.0, shininess: 0.95)
    eyeMat.diffuse.contentsTransform = SCNMatrix4MakeScale(3, 3, 1)
    eyeMat.diffuse.wrapS = .repeat; eyeMat.diffuse.wrapT = .repeat
    eyeGeo.materials = [eyeMat]
    for side in [CGFloat(-1), 1] {
        let eye = SCNNode(geometry: eyeGeo)
        eye.position = SCNVector3(side * 2.2, 9.6, 6.4)
        eye.scale = SCNVector3(0.82, 1.0, 1.15)
        rigid.addChildNode(eye)
    }

    // antennae: a bulb and a branched arista
    let hairMat = gloss(chitinDark, specular: 0.3, shininess: 0.3)
    func hair(_ len: CGFloat, _ r: CGFloat = 0.11) -> SCNGeometry {
        let g = SCNCone(topRadius: 0.01, bottomRadius: r, height: len)
        g.radialSegmentCount = 5; g.heightSegmentCount = 1
        g.materials = [hairMat]; return g
    }
    for side in [CGFloat(-1), 1] {
        let bulbGeo = SCNSphere(radius: 0.42)
        bulbGeo.materials = [gloss(NSColor(calibratedRed: 0.42, green: 0.28, blue: 0.14, alpha: 1))]
        let bulb = SCNNode(geometry: bulbGeo)
        bulb.position = SCNVector3(side * 0.85, 11.5, 6.2)
        bulb.scale = SCNVector3(1, 1.5, 1)
        rigid.addChildNode(bulb)
        let arista = SCNNode(geometry: hair(2.6, 0.06))
        arista.position = SCNVector3(side * 1.45, 12.4, 6.5)
        arista.eulerAngles = SCNVector3(0, 0, -side * 0.75)
        rigid.addChildNode(arista)
        for k in 0..<3 {
            let b = SCNNode(geometry: hair(0.9, 0.04))
            b.position = SCNVector3(side * (1.2 + 0.32 * CGFloat(k)), 12.2 + 0.28 * CGFloat(k), 6.5)
            b.eulerAngles = SCNVector3(0, 0, -side * 1.9)
            rigid.addChildNode(b)
        }
    }
    let probGeo = SCNCone(topRadius: 0.6, bottomRadius: 0.22, height: 2.4)
    probGeo.materials = [gloss(NSColor(calibratedRed: 0.35, green: 0.26, blue: 0.16, alpha: 1), specular: 0.3, shininess: 0.3)]
    let prob = SCNNode(geometry: probGeo)
    prob.position = SCNVector3(0, 10.4, 4.6)
    prob.eulerAngles = SCNVector3(-0.5, 0, 0)
    rigid.addChildNode(prob)

    // bristles: swept back over the thorax and scutellum, a few on the head
    func bristle(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat, len: CGFloat, back: CGFloat = 1.05, out: CGFloat = 0) {
        let n = SCNNode(geometry: hair(len))
        n.position = SCNVector3(x, y, z)
        n.eulerAngles = SCNVector3(back, 0, out)     // tip leans toward the tail and up
        rigid.addChildNode(n)
    }
    for side in [CGFloat(-1), 1] {
        bristle(side * 1.3, 5.2, 10.1, len: 2.6)
        bristle(side * 2.6, 4.0, 9.6, len: 2.4, out: -side * 0.25)
        bristle(side * 1.4, 2.6, 10.3, len: 3.0)
        bristle(side * 3.0, 1.6, 9.3, len: 2.6, out: -side * 0.3)
        bristle(side * 1.5, 0.2, 10.0, len: 3.2)
        bristle(side * 3.2, -0.6, 8.6, len: 2.4, out: -side * 0.35)
        bristle(side * 1.0, -2.6, 9.0, len: 3.4, back: 1.25)            // scutellar
        bristle(side * 1.0, 9.6, 8.7, len: 1.8, back: 0.7)              // head
        bristle(side * 0.5, 8.4, 8.8, len: 1.6, back: 1.2)
    }

    root.addChildNode(rigid.flattenedClone())

    // legs: slimmer, darker toward the feet (same joints as the classic body)
    var legs: [Leg] = []
    let z: CGFloat = 4.5
    let femurCol = NSColor(calibratedRed: 0.36, green: 0.25, blue: 0.13, alpha: 1)
    let specs: [(CGFloat, SCNVector3, CGFloat, CGFloat, Bool, CGFloat, CGFloat, CGFloat)] = [
        ( 1, SCNVector3( 3.1,  5.3, z),  0.95, 0.0, true,  4.2,  4.8, 3.2),
        (-1, SCNVector3(-3.1,  5.3, z),  0.95, 0.5, true,  4.2,  4.8, 3.2),
        ( 1, SCNVector3( 3.7,  2.0, z), -0.10, 0.5, false, 4.8,  5.6, 3.8),
        (-1, SCNVector3(-3.7,  2.0, z), -0.10, 0.0, false, 4.8,  5.6, 3.8),
        ( 1, SCNVector3( 3.3, -1.2, z), -0.95, 0.0, false, 5.8,  7.0, 4.6),
        (-1, SCNVector3(-3.3, -1.2, z), -0.95, 0.5, false, 5.8,  7.0, 4.6),
    ]
    for (side, attach, yawOff, phase, isFront, f, t, ta) in specs {
        let baseYaw: CGFloat = side > 0 ? yawOff : (.pi - yawOff)
        let leg = buildLeg(attach: attach, baseYaw: baseYaw, swingSign: side, phase: phase,
                           isFront: isFront, femur: f, tibia: t, tarsus: ta, color: femurCol, thickness: 0.78)
        // tibia darker, tarsus near black, dark knee and ankle joints
        leg.knee.childNodes.first(where: { $0.geometry is SCNCapsule })?.geometry?.materials =
            [gloss(NSColor(calibratedRed: 0.24, green: 0.16, blue: 0.09, alpha: 1), specular: 0.4, shininess: 0.4)]
        leg.ankle.childNodes.first(where: { $0.geometry is SCNCapsule })?.geometry?.materials = [gloss(chitinDark, specular: 0.3, shininess: 0.3)]
        for joint in [leg.knee, leg.ankle] {
            let g = SCNSphere(radius: joint === leg.knee ? 0.40 : 0.30); g.segmentCount = 8; g.materials = [gloss(chitinDark, specular: 0.5, shininess: 0.5)]
            joint.addChildNode(SCNNode(geometry: g))
        }
        root.addChildNode(leg.root)
        legs.append(leg)
    }

    // wings: glass with veins. Each beating surface is a hinge node (rotated by the
    // behavior layer) holding a textured plane that hangs down from the hinge.
    let tex = DetailedTextures.wing
    let foldedWings = SCNNode()
    for side in [CGFloat(-1), 1] {
        let hinge = SCNNode()
        hinge.position = SCNVector3(side * 1.6, 0.5, side > 0 ? 10.4 : 10.25)
        hinge.eulerAngles = SCNVector3(0, 0, side * 0.13)
        let plane = SCNPlane(width: 6.6, height: 17.6)
        let m = SCNMaterial()
        m.lightingModel = .blinn
        m.diffuse.contents = tex
        m.diffuse.mipFilter = .linear          // veins must blur, not alias, at desktop size
        m.diffuse.minificationFilter = .linear
        m.diffuse.maxAnisotropy = 8
        if side < 0 { m.diffuse.contentsTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(-1, 1, 1), 1, 0, 0) }
        m.specular.contents = NSColor(calibratedRed: 0.75, green: 0.9, blue: 1.0, alpha: 1)
        m.shininess = 0.95
        m.isDoubleSided = true
        m.writesToDepthBuffer = false
        m.blendMode = .alpha
        plane.materials = [m]
        let membrane = SCNNode(geometry: plane)
        membrane.position = SCNVector3(0, -8.6, 0)
        membrane.renderingOrder = 10
        hinge.addChildNode(membrane)
        foldedWings.addChildNode(hinge)
    }
    root.addChildNode(foldedWings)

    func blurWing(_ side: CGFloat) -> SCNNode {
        let g = SCNSphere(radius: 1.0)
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = NSColor(calibratedRed: 0.86, green: 0.90, blue: 0.95, alpha: 0.20)
        m.isDoubleSided = true
        m.writesToDepthBuffer = false
        g.materials = [m]
        let n = SCNNode(geometry: g)
        n.position = SCNVector3(side * 8.4, -2.8, 10.65)
        n.scale = SCNVector3(5.5, 2.4, 0.3)
        n.eulerAngles = SCNVector3(0, 0, side * -0.45)
        n.isHidden = true
        return n
    }
    let bl = blurWing(-1), br = blurWing(1)
    root.addChildNode(bl)
    root.addChildNode(br)

    return FlyModel(root: root, legs: legs, foldedWings: foldedWings,
                    blurWingL: bl, blurWingR: br, abdomen: abdomen,
                    wingFlightSpread: 1.1)
}
