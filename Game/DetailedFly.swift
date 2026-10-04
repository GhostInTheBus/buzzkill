// Detailed insect bodies, all built by one parameterized builder against the
// engine's FlyModel contract (six articulated legs, two beating wing surfaces,
// an abdomen). The fruit fly is upstream's proportions restyled toward
// "stylized-real"; the housefly and mosquito are the same skeleton with
// different proportions, colors and voices. Purely cosmetic — whatever the
// suit, the brain (if it has one) is the fruit-fly connectome.

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
private func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
}

/// Bands across the abdomen with soft edges. Texture v runs tip (0) -> waist (1).
private func bandedAbdomen(light: NSColor, lightTip: NSColor, dark: NSColor,
                           bands: [(y: Double, h: Double, a: Double)], midline: NSColor? = nil) -> NSImage {
    image(128, 256) { r in
        NSGradient(colors: [light, lightTip])!.draw(in: r, angle: 90)
        for b in bands {
            let band = NSRect(x: 0, y: b.y, width: 128, height: b.h)
            NSGradient(colors: [dark.withAlphaComponent(0), dark.withAlphaComponent(b.a), dark.withAlphaComponent(b.a), dark.withAlphaComponent(0)],
                       atLocations: [0, 0.22, 0.78, 1], colorSpace: .genericRGB)!.draw(in: band.insetBy(dx: 0, dy: -4), angle: 90)
        }
        if let m = midline { m.setFill(); NSRect(x: 58, y: 0, width: 12, height: 256).fill() }
    }
}

/// Thorax: a base color, longitudinal stripes, a little speckle.
private func stripedThorax(base: NSColor, stripe: NSColor, xs: [Double], width: Double) -> NSImage {
    image(128, 128) { r in
        base.setFill(); r.fill()
        stripe.setFill()
        for x in xs { NSRect(x: x, y: 0, width: width, height: 128).fill() }
        NSColor(calibratedWhite: 0, alpha: 0.10).setFill()
        var s: UInt32 = 7
        for _ in 0..<90 {
            s = s &* 1664525 &+ 1013904223; let x = Double(s >> 8 & 127)
            s = s &* 1664525 &+ 1013904223; let y = Double(s >> 8 & 127)
            NSRect(x: x, y: y, width: 1.4, height: 1.4).fill()
        }
    }
}

/// Compound eye: a two-tone ground with a hexagonal facet lattice.
private func facetedEye(_ a: NSColor, _ b: NSColor, lattice: NSColor) -> NSImage {
    image(128, 128) { r in
        NSGradient(colors: [a, b])!.draw(in: r, angle: 60)
        lattice.setStroke()
        let step = 7.0
        var row = 0, y = 0.0
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
/// `narrow` gives the mosquito's long strap of a wing with a fringe of scales.
private func wingImage(tint: CGFloat, vein: NSColor, narrow: Bool) -> NSImage {
    let W = 200.0, H = 560.0
    return image(Int(W), Int(H)) { _ in
        let o = NSBezierPath()
        if narrow {
            o.move(to: NSPoint(x: W * 0.50, y: H - 6))
            o.curve(to: NSPoint(x: W * 0.80, y: H * 0.30), controlPoint1: NSPoint(x: W * 0.62, y: H * 0.93), controlPoint2: NSPoint(x: W * 0.84, y: H * 0.60))
            o.curve(to: NSPoint(x: W * 0.52, y: 8), controlPoint1: NSPoint(x: W * 0.78, y: H * 0.10), controlPoint2: NSPoint(x: W * 0.66, y: 8))
            o.curve(to: NSPoint(x: W * 0.22, y: H * 0.28), controlPoint1: NSPoint(x: W * 0.38, y: 8), controlPoint2: NSPoint(x: W * 0.24, y: H * 0.10))
            o.curve(to: NSPoint(x: W * 0.50, y: H - 6), controlPoint1: NSPoint(x: W * 0.19, y: H * 0.60), controlPoint2: NSPoint(x: W * 0.40, y: H * 0.93))
        } else {
            o.move(to: NSPoint(x: W * 0.50, y: H - 6))
            o.curve(to: NSPoint(x: W * 0.94, y: H * 0.34), controlPoint1: NSPoint(x: W * 0.66, y: H * 0.93), controlPoint2: NSPoint(x: W * 0.99, y: H * 0.62))
            o.curve(to: NSPoint(x: W * 0.52, y: 8), controlPoint1: NSPoint(x: W * 0.91, y: H * 0.13), controlPoint2: NSPoint(x: W * 0.74, y: 8))
            o.curve(to: NSPoint(x: W * 0.07, y: H * 0.30), controlPoint1: NSPoint(x: W * 0.28, y: 8), controlPoint2: NSPoint(x: W * 0.08, y: H * 0.13))
            o.curve(to: NSPoint(x: W * 0.50, y: H - 6), controlPoint1: NSPoint(x: W * 0.05, y: H * 0.60), controlPoint2: NSPoint(x: W * 0.34, y: H * 0.93))
        }
        o.close()
        NSGraphicsContext.saveGraphicsState()
        o.addClip()
        NSColor(calibratedWhite: narrow ? 0.75 : 1, alpha: tint).setFill(); o.fill()
        NSGradient(colors: [rgb(0.55, 0.85, 1.0, 0.13), rgb(1.0, 0.70, 0.90, 0.10), rgb(0.80, 1.0, 0.75, 0.10)])!
            .draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: 70)
        vein.setStroke()
        func line(_ pts: [(Double, Double)], _ w: CGFloat) {
            let p = NSBezierPath(); p.lineWidth = w * 2.1; p.lineCapStyle = .round   // wide enough to survive minification
            p.move(to: NSPoint(x: W * pts[0].0, y: H * pts[0].1))
            p.curve(to: NSPoint(x: W * pts[3].0, y: H * pts[3].1),
                    controlPoint1: NSPoint(x: W * pts[1].0, y: H * pts[1].1),
                    controlPoint2: NSPoint(x: W * pts[2].0, y: H * pts[2].1))
            p.stroke()
        }
        let hinge = (0.50, 0.985)
        if narrow {
            line([hinge, (0.60, 0.80), (0.74, 0.45), (0.70, 0.14)], 2.6)
            line([hinge, (0.53, 0.75), (0.58, 0.35), (0.54, 0.04)], 2.6)
            line([hinge, (0.46, 0.75), (0.42, 0.35), (0.40, 0.05)], 2.4)
            line([hinge, (0.40, 0.80), (0.30, 0.50), (0.27, 0.20)], 2.2)
        } else {
            line([hinge, (0.72, 0.86), (0.93, 0.62), (0.90, 0.36)], 3.2)   // L1 / costa side
            line([hinge, (0.62, 0.80), (0.80, 0.45), (0.76, 0.12)], 2.6)   // L2
            line([hinge, (0.54, 0.75), (0.62, 0.35), (0.56, 0.03)], 2.6)   // L3
            line([hinge, (0.46, 0.75), (0.42, 0.35), (0.34, 0.06)], 2.4)   // L4
            line([hinge, (0.36, 0.80), (0.20, 0.55), (0.12, 0.26)], 2.2)   // L5
            line([(0.585, 0.62), (0.56, 0.615), (0.50, 0.61), (0.455, 0.615)], 2.0)   // anterior crossvein
            line([(0.43, 0.33), (0.36, 0.34), (0.28, 0.38), (0.215, 0.42)], 2.0)       // posterior crossvein
        }
        NSGraphicsContext.restoreGraphicsState()
        vein.setStroke()
        o.lineWidth = narrow ? 8 : 5; o.stroke()
    }
}

/// Everything that distinguishes one insect from another.
struct InsectSpec {
    var sizeScale: CGFloat = 1          // relative to the fruit fly
    var voice: CGFloat = 1              // wingbeat pitch multiplier
    var thoraxTex: NSImage
    var thoraxScale = SCNVector3(0.95, 1.15, 0.85)
    var scutellum: NSColor
    var abdomenTex: NSImage
    var abdomenScale = SCNVector3(0.9, 1.5, 0.75)
    var headRadius: CGFloat = 3.15
    var headColor: NSColor
    var headY: CGFloat = 9.0
    var eyeTex: NSImage
    var eyeRadius: CGFloat = 2.15
    var eyeSpread: CGFloat = 2.2
    var proboscisLength: CGFloat = 2.4  // > 5 = a forward needle
    var plumose = false                 // feathery antennae instead of an arista
    var bristles: CGFloat = 1           // 0 none, 1 fruit fly, >1 longer and denser
    var hair: NSColor
    var legLength: CGFloat = 1
    var legThickness: CGFloat = 0.78
    var legColors: (femur: NSColor, tibia: NSColor, tarsus: NSColor)
    var wingTex: NSImage
    var wingSize = CGSize(width: 6.6, height: 17.6)
    var wingRest: CGFloat = 0.13        // fold angle at rest
    var wingSpread: CGFloat = 1.1       // flight spread

    static let fruitFly = InsectSpec(
        thoraxTex: stripedThorax(base: rgb(0.47, 0.33, 0.18), stripe: rgb(0.30, 0.20, 0.11, 0.55), xs: [26, 46, 78, 98], width: 5),
        scutellum: rgb(0.36, 0.24, 0.13),
        abdomenTex: bandedAbdomen(light: rgb(0.80, 0.62, 0.34), lightTip: rgb(0.62, 0.44, 0.22), dark: rgb(0.13, 0.08, 0.05),
                                  bands: [(0, 54, 1.0), (72, 22, 0.95), (116, 20, 0.9), (160, 17, 0.85), (200, 13, 0.7)]),
        headColor: rgb(0.62, 0.48, 0.28),
        eyeTex: facetedEye(rgb(0.52, 0.09, 0.06), rgb(0.30, 0.03, 0.03), lattice: rgb(0.16, 0.01, 0.01, 0.55)),
        hair: rgb(0.15, 0.10, 0.06),
        legColors: (rgb(0.36, 0.25, 0.13), rgb(0.24, 0.16, 0.09), rgb(0.15, 0.10, 0.06)),
        wingTex: wingImage(tint: 0.17, vein: rgb(0.20, 0.13, 0.08, 0.50), narrow: false))

    /// Musca domestica: half again as big, grey with four black stripes, a
    /// checkered yellowish abdomen, huge red-brown eyes, wings held in a V.
    static let housefly = InsectSpec(
        sizeScale: 1.5, voice: 0.72,
        thoraxTex: stripedThorax(base: rgb(0.34, 0.34, 0.35), stripe: rgb(0.06, 0.06, 0.07, 0.9), xs: [20, 44, 76, 100], width: 8),
        thoraxScale: SCNVector3(1.02, 1.15, 0.9),
        scutellum: rgb(0.22, 0.22, 0.23),
        abdomenTex: bandedAbdomen(light: rgb(0.62, 0.55, 0.36), lightTip: rgb(0.42, 0.38, 0.28), dark: rgb(0.08, 0.08, 0.08),
                                  bands: [(0, 60, 0.95), (84, 26, 0.6), (140, 24, 0.55), (196, 20, 0.5)], midline: rgb(0.07, 0.07, 0.07, 0.85)),
        abdomenScale: SCNVector3(0.98, 1.35, 0.8),
        headRadius: 3.3, headColor: rgb(0.30, 0.29, 0.28),
        eyeTex: facetedEye(rgb(0.40, 0.11, 0.07), rgb(0.20, 0.04, 0.03), lattice: rgb(0.10, 0.01, 0.01, 0.6)),
        eyeRadius: 2.6, eyeSpread: 2.0,
        bristles: 1.5, hair: rgb(0.03, 0.03, 0.03),
        legThickness: 0.9,
        legColors: (rgb(0.10, 0.10, 0.10), rgb(0.07, 0.07, 0.07), rgb(0.03, 0.03, 0.03)),
        wingTex: wingImage(tint: 0.20, vein: rgb(0.10, 0.09, 0.08, 0.55), narrow: false),
        wingSize: CGSize(width: 7.2, height: 17.0), wingRest: 0.34)

    /// A mosquito: slight, dark, humped; stilt legs; a needle; a whine.
    static let mosquito = InsectSpec(
        sizeScale: 1.1, voice: 3.1,
        thoraxTex: stripedThorax(base: rgb(0.22, 0.17, 0.13), stripe: rgb(0.50, 0.44, 0.34, 0.5), xs: [40, 60, 82], width: 4),
        thoraxScale: SCNVector3(0.70, 0.95, 0.95),
        scutellum: rgb(0.16, 0.12, 0.09),
        abdomenTex: bandedAbdomen(light: rgb(0.72, 0.66, 0.52), lightTip: rgb(0.60, 0.55, 0.44), dark: rgb(0.10, 0.08, 0.07),
                                  bands: [(0, 34, 1), (44, 30, 1), (84, 30, 1), (124, 30, 1), (164, 30, 1), (204, 30, 1)]),
        abdomenScale: SCNVector3(0.46, 1.95, 0.46),
        headRadius: 2.0, headColor: rgb(0.16, 0.12, 0.10), headY: 8.0,
        eyeTex: facetedEye(rgb(0.10, 0.20, 0.14), rgb(0.03, 0.06, 0.05), lattice: rgb(0, 0, 0, 0.6)),
        eyeRadius: 1.45, eyeSpread: 1.25,
        proboscisLength: 8.5, plumose: true,
        bristles: 0, hair: rgb(0.10, 0.08, 0.07),
        legLength: 1.85, legThickness: 0.40,
        legColors: (rgb(0.16, 0.12, 0.10), rgb(0.10, 0.08, 0.07), rgb(0.55, 0.50, 0.42)),
        wingTex: wingImage(tint: 0.22, vein: rgb(0.12, 0.10, 0.09, 0.6), narrow: true),
        wingSize: CGSize(width: 5.4, height: 18.5), wingRest: 0.07, wingSpread: 1.0)
}

func buildDetailedFlyModel() -> FlyModel { buildInsect(.fruitFly) }
func buildHouseflyModel() -> FlyModel { buildInsect(.housefly) }
func buildMosquitoModel() -> FlyModel { buildInsect(.mosquito) }

func buildInsect(_ spec: InsectSpec) -> FlyModel {
    let root = SCNNode()
    let S = FLY_SCALE * spec.sizeScale
    root.scale = SCNVector3(S, S, S)
    // Everything rigid (thorax, scutellum, bristles) is built under `rigid` and
    // merged into a few meshes at the end: ~45 draw calls become ~6, which is
    // what lets a 160-fly swarm hold frame rate.
    let rigid = SCNNode()
    // The head is its own flattened mesh on a neck joint, so it can turn.
    let neck = SCNVector3(0, spec.headY - 2.1, 6.0)
    let headParts = SCNNode()
    func onHead(_ n: SCNNode) {
        n.position = SCNVector3(n.position.x - neck.x, n.position.y - neck.y, n.position.z - neck.z)
        headParts.addChildNode(n)
    }
    let chitinDark = spec.hair

    // thorax: glossy, striped, with a scutellum behind it
    let thoraxGeo = SCNSphere(radius: 4.6)
    thoraxGeo.segmentCount = 28
    thoraxGeo.materials = [gloss(spec.thoraxTex, specular: 0.7, shininess: 0.8)]
    let thorax = SCNNode(geometry: thoraxGeo)
    thorax.position = SCNVector3(0, 2.5, 6.2)
    thorax.scale = spec.thoraxScale
    rigid.addChildNode(thorax)
    let scutGeo = SCNSphere(radius: 2.1)
    scutGeo.materials = [gloss(spec.scutellum)]
    let scut = SCNNode(geometry: scutGeo)
    scut.position = SCNVector3(0, -2.3, 8.0)
    scut.scale = SCNVector3(1.15 * spec.thoraxScale.x / 0.95, 0.8, 0.55)
    rigid.addChildNode(scut)

    // abdomen: identical placement and pivot to the classic body (it wags)
    let abdGeo = SCNSphere(radius: 5.0)
    abdGeo.segmentCount = 28
    abdGeo.materials = [gloss(spec.abdomenTex, specular: 0.65, shininess: 0.7)]
    let abdomen = SCNNode(geometry: abdGeo)
    abdomen.pivot = SCNMatrix4MakeTranslation(0, 3.5, 0)
    abdomen.position = SCNVector3(0, -1.25, 5.6)
    abdomen.scale = spec.abdomenScale
    root.addChildNode(abdomen)

    // head
    let headGeo = SCNSphere(radius: spec.headRadius)
    headGeo.materials = [gloss(spec.headColor, specular: 0.5, shininess: 0.5)]
    let head = SCNNode(geometry: headGeo)
    head.position = SCNVector3(0, spec.headY, 6.0)
    head.scale = SCNVector3(1.0, 0.85, 0.9)
    onHead(head)

    let eyeGeo = SCNSphere(radius: spec.eyeRadius)
    eyeGeo.segmentCount = 20
    let eyeMat = gloss(spec.eyeTex, specular: 1.0, shininess: 0.95)
    eyeMat.diffuse.contentsTransform = SCNMatrix4MakeScale(3, 3, 1)
    eyeMat.diffuse.wrapS = .repeat; eyeMat.diffuse.wrapT = .repeat
    eyeGeo.materials = [eyeMat]
    for side in [CGFloat(-1), 1] {
        let eye = SCNNode(geometry: eyeGeo)
        eye.position = SCNVector3(side * spec.eyeSpread, spec.headY + 0.6, 6.4)
        eye.scale = SCNVector3(0.82, 1.0, 1.15)
        onHead(eye)
    }

    let hairMat = gloss(chitinDark, specular: 0.3, shininess: 0.3)
    func hair(_ len: CGFloat, _ r: CGFloat = 0.11) -> SCNGeometry {
        let g = SCNCone(topRadius: 0.01, bottomRadius: r, height: len)
        g.radialSegmentCount = 5; g.heightSegmentCount = 1
        g.materials = [hairMat]; return g
    }
    // antennae: a bulb and a branched arista — or the mosquito's feathery plume
    let ay = spec.headY + 2.5
    for side in [CGFloat(-1), 1] {
        let bulbGeo = SCNSphere(radius: spec.plumose ? 0.34 : 0.42)
        bulbGeo.materials = [gloss(spec.scutellum.blended(withFraction: 0.2, of: .white) ?? spec.scutellum)]
        let bulb = SCNNode(geometry: bulbGeo)
        bulb.position = SCNVector3(side * 0.85 * spec.headRadius / 3.15, ay, 6.2)
        bulb.scale = SCNVector3(1, 1.5, 1)
        onHead(bulb)
        if spec.plumose {
            let stem = SCNNode(geometry: hair(5.2, 0.07))
            stem.position = SCNVector3(side * 1.5, ay + 2.2, 6.4)
            stem.eulerAngles = SCNVector3(0, 0, -side * 0.42)
            onHead(stem)
            for k in 0..<6 {
                for dir in [CGFloat(-1), 1] {
                    let b = SCNNode(geometry: hair(1.5, 0.035))
                    b.position = SCNVector3(side * (0.75 + 0.26 * CGFloat(k)) + dir * 0.45, ay + 0.6 + 0.62 * CGFloat(k), 6.4)
                    b.eulerAngles = SCNVector3(0, 0, -side * 0.42 - dir * 1.25)
                    onHead(b)
                }
            }
        } else {
            let arista = SCNNode(geometry: hair(2.6, 0.06))
            arista.position = SCNVector3(side * 1.45, ay + 0.9, 6.5)
            arista.eulerAngles = SCNVector3(0, 0, -side * 0.75)
            onHead(arista)
            for k in 0..<3 {
                let b = SCNNode(geometry: hair(0.9, 0.04))
                b.position = SCNVector3(side * (1.2 + 0.32 * CGFloat(k)), ay + 0.7 + 0.28 * CGFloat(k), 6.5)
                b.eulerAngles = SCNVector3(0, 0, -side * 1.9)
                onHead(b)
            }
        }
    }
    if spec.proboscisLength > 5 {
        // a needle, straight ahead
        let g = SCNCone(topRadius: 0.05, bottomRadius: 0.24, height: spec.proboscisLength)
        g.radialSegmentCount = 6
        g.materials = [gloss(chitinDark, specular: 0.4, shininess: 0.5)]
        let prob = SCNNode(geometry: g)
        prob.position = SCNVector3(0, spec.headY + 1.4 + spec.proboscisLength / 2, 5.6)
        onHead(prob)
    } else {
        let probGeo = SCNCone(topRadius: 0.6, bottomRadius: 0.22, height: spec.proboscisLength)
        probGeo.materials = [gloss(spec.headColor.blended(withFraction: 0.45, of: .black) ?? spec.headColor, specular: 0.3, shininess: 0.3)]
        let prob = SCNNode(geometry: probGeo)
        prob.position = SCNVector3(0, spec.headY + 1.4, 4.6)
        prob.eulerAngles = SCNVector3(-0.5, 0, 0)
        onHead(prob)
    }

    // bristles: swept back over the thorax and scutellum, a few on the head
    if spec.bristles > 0 {
        let L = spec.bristles
        func bristle(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat, len: CGFloat, back: CGFloat = 1.05, out: CGFloat = 0) {
            let n = SCNNode(geometry: hair(len * L))
            n.position = SCNVector3(x * spec.thoraxScale.x / 0.95, y, z)
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
            if L > 1.2 {                                                    // a bristlier animal
                bristle(side * 2.0, 5.6, 9.7, len: 2.2, out: -side * 0.2)
                bristle(side * 2.2, 0.8, 9.9, len: 2.8, out: -side * 0.2)
                bristle(side * 0.6, 3.8, 10.5, len: 2.4)
            }
            for (x, y, z, len, back) in [(side * 1.0, spec.headY + 0.6, 8.7, 1.8, 0.7), (side * 0.5, spec.headY - 0.6, 8.8, 1.6, 1.2)] as [(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat)] {
                let n = SCNNode(geometry: hair(len * L))
                n.position = SCNVector3(x, y, z); n.eulerAngles = SCNVector3(back, 0, 0)
                onHead(n)                                                    // head bristles turn with the head
            }
        }
    }
    root.addChildNode(rigid.flattenedClone())
    let headNode = SCNNode()
    headNode.position = neck
    headNode.addChildNode(headParts.flattenedClone())
    root.addChildNode(headNode)

    // legs: slim, darker toward the feet (same joints as the classic body)
    var legs: [Leg] = []
    let z: CGFloat = 4.5, k = spec.legLength, tx = spec.thoraxScale.x / 0.95
    let specs: [(CGFloat, SCNVector3, CGFloat, CGFloat, Bool, CGFloat, CGFloat, CGFloat)] = [
        ( 1, SCNVector3( 3.1 * tx,  5.3, z),  0.95, 0.0, true,  4.2,  4.8, 3.2),
        (-1, SCNVector3(-3.1 * tx,  5.3, z),  0.95, 0.5, true,  4.2,  4.8, 3.2),
        ( 1, SCNVector3( 3.7 * tx,  2.0, z), -0.10, 0.5, false, 4.8,  5.6, 3.8),
        (-1, SCNVector3(-3.7 * tx,  2.0, z), -0.10, 0.0, false, 4.8,  5.6, 3.8),
        ( 1, SCNVector3( 3.3 * tx, -1.2, z), -0.95, 0.0, false, 5.8,  7.0, 4.6),
        (-1, SCNVector3(-3.3 * tx, -1.2, z), -0.95, 0.5, false, 5.8,  7.0, 4.6),
    ]
    for (side, attach, yawOff, phase, isFront, f, t, ta) in specs {
        let baseYaw: CGFloat = side > 0 ? yawOff : (.pi - yawOff)
        let leg = buildLeg(attach: attach, baseYaw: baseYaw, swingSign: side, phase: phase,
                           isFront: isFront, femur: f * k, tibia: t * k, tarsus: ta * k,
                           color: spec.legColors.femur, thickness: spec.legThickness)
        leg.knee.childNodes.first(where: { $0.geometry is SCNCapsule })?.geometry?.materials = [gloss(spec.legColors.tibia, specular: 0.4, shininess: 0.4)]
        leg.ankle.childNodes.first(where: { $0.geometry is SCNCapsule })?.geometry?.materials = [gloss(spec.legColors.tarsus, specular: 0.3, shininess: 0.3)]
        for joint in [leg.knee, leg.ankle] {
            let g = SCNSphere(radius: (joint === leg.knee ? 0.40 : 0.30) * spec.legThickness / 0.78); g.segmentCount = 8
            g.materials = [gloss(chitinDark, specular: 0.5, shininess: 0.5)]
            joint.addChildNode(SCNNode(geometry: g))
        }
        root.addChildNode(leg.root)
        legs.append(leg)
    }

    // wings: glass with veins. Each beating surface is a hinge node (rotated by the
    // behavior layer) holding a textured plane that hangs down from the hinge.
    let foldedWings = SCNNode()
    for side in [CGFloat(-1), 1] {
        let hinge = SCNNode()
        hinge.position = SCNVector3(side * 1.6 * tx, 0.5, side > 0 ? 10.4 : 10.25)
        hinge.eulerAngles = SCNVector3(0, 0, side * spec.wingRest)
        let plane = SCNPlane(width: spec.wingSize.width, height: spec.wingSize.height)
        let m = SCNMaterial()
        m.lightingModel = .blinn
        m.diffuse.contents = spec.wingTex
        m.diffuse.mipFilter = .linear          // veins must blur, not alias, at desktop size
        m.diffuse.minificationFilter = .linear
        m.diffuse.maxAnisotropy = 8
        if side < 0 { m.diffuse.contentsTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(-1, 1, 1), 1, 0, 0) }
        m.specular.contents = rgb(0.20, 0.25, 0.30)   // a glint, not a strobe
        m.shininess = 0.6
        m.isDoubleSided = true
        m.writesToDepthBuffer = false
        m.blendMode = .alpha
        plane.materials = [m]
        let membrane = SCNNode(geometry: plane)
        membrane.position = SCNVector3(0, -spec.wingSize.height / 2 + 0.2, 0)
        membrane.renderingOrder = 10
        hinge.addChildNode(membrane)
        foldedWings.addChildNode(hinge)
    }
    root.addChildNode(foldedWings)

    func blurWing(_ side: CGFloat) -> SCNNode {
        let g = SCNSphere(radius: 1.0)
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = rgb(0.86, 0.90, 0.95, 0.20)
        m.isDoubleSided = true
        m.writesToDepthBuffer = false
        g.materials = [m]
        let n = SCNNode(geometry: g)
        n.position = SCNVector3(side * 8.4, -2.8, 10.65)
        n.scale = SCNVector3(5.5 * spec.wingSize.height / 17.6, 2.4 * spec.wingSize.width / 6.6, 0.3)
        n.eulerAngles = SCNVector3(0, 0, side * -0.45)
        n.isHidden = true
        return n
    }
    let bl = blurWing(-1), br = blurWing(1)
    root.addChildNode(bl)
    root.addChildNode(br)

    var model = FlyModel(root: root, legs: legs, foldedWings: foldedWings,
                         blurWingL: bl, blurWingR: br, abdomen: abdomen,
                         wingFlightSpread: spec.wingSpread, head: headNode)
    model.sizeScale = spec.sizeScale
    model.voice = spec.voice
    model.wingRest = spec.wingRest
    return model
}
