// Squish on click: a grounded fly under the cursor becomes a splat with the
// flattened body in it. Splats stay solid for 2.5 minutes, then fade out
// over the next. You have to earn it — a fast cursor trips the real escape
// circuit before the click lands.

import SceneKit

final class Splats {
    var enabled = true
    var hitRadius: CGFloat = 26
    private var splats: [(node: SCNNode, born: TimeInterval, style: Int, seed: UInt32, angle: CGFloat)] = []
    private var time: TimeInterval = 0
    private var restored = false
    /// Splat marks survive relaunch (goo only; the body is gone). Stored as [x, y, age].
    private func save() {
        let rows = splats.map { [Double($0.node.position.x), Double($0.node.position.y), time - $0.born, Double($0.style), Double($0.seed), Double($0.angle)] }
        UserDefaults.standard.set(rows, forKey: "splats")
    }
    private func restore(world: GameWorld) {
        restored = true
        guard let rows = UserDefaults.standard.array(forKey: "splats") as? [[Double]] else { return }
        for r in rows where r.count >= 3 && r[2] < 210 {
            let style = Style(rawValue: r.count > 3 ? Int(r[3]) : 0) ?? .blot
            let seed = r.count > 4 ? UInt32(r[4]) : 1, angle = r.count > 5 ? CGFloat(r[5]) : 0
            let n = makeSplat(fly: nil, at: CGPoint(x: r[0], y: r[1]), style: style, seed: seed, angle: angle)
            world.scene.rootNode.addChildNode(n)
            splats.append((n, time - r[2], style.rawValue, seed, angle))
        }
    }

    /// Was there a fly near a click that didn't connect? (airborne, or just outside the hitbox)
    func nearMiss(at p: CGPoint, world: GameWorld) -> Bool {
        world.flies.contains { hypot(p.x - $0.pos.x, p.y - $0.pos.y) < 90 }
    }

    /// Removes and splats the first grounded fly within reach. Returns it, or nil.
    func squish(at p: CGPoint, world: GameWorld) -> Fly? {
        guard enabled else { return nil }
        guard let i = world.flies.firstIndex(where: { $0.state != .flying && hypot(p.x - $0.pos.x, p.y - $0.pos.y) < hitRadius * $0.model.sizeScale })
        else { return nil }
        let fly = world.flies.remove(at: i)
        // what kind of mark depends on how you hit it: a moving cursor smears along its
        // path, a dead-center click bursts, a hit near the edge of the hitbox only glances
        let v = world.cursorVelocity, speed = hypot(v.x, v.y)
        let off = hypot(p.x - fly.pos.x, p.y - fly.pos.y) / (hitRadius * fly.model.sizeScale)
        let style: Style, angle: CGFloat
        if speed > 260 { style = .smear; angle = atan2(v.y, v.x) }
        else {
            angle = rnd(0...(2 * CGFloat.pi))
            style = off > 0.72 ? .glance : (off < 0.3 ? .burst : (rnd(0...1) < 0.3 ? .burst : .blot))
        }
        let seed = UInt32(truncatingIfNeeded: Int(rnd(1...4_000_000)))
        let node = makeSplat(fly: fly, at: fly.pos, style: style, seed: seed, angle: angle)
        world.scene.rootNode.addChildNode(node)
        splats.append((node, time, style.rawValue, seed, angle))
        save()
        return fly
    }

    func update(dt: CGFloat, world: GameWorld) {
        time += Double(dt)
        if !restored { restore(world: world) }
        guard !splats.isEmpty else { return }
        var removed = false
        splats.removeAll { sp in
            let age = time - sp.born
            if age > 210 { sp.node.removeFromParentNode(); removed = true; return true }
            sp.node.opacity = age > 150 ? CGFloat(1 - (age - 150) / 60) : 1
            return false
        }
        if removed { save() }
    }

    enum Style: Int, CaseIterable { case blot, smear, burst, glance }

    /// For --splattest: one mark of a given style, with a body in it.
    func preview(style: Style, fly: Fly, seed: UInt32, angle: CGFloat, scene: SCNScene) {
        scene.rootNode.addChildNode(makeSplat(fly: fly, at: fly.pos, style: style, seed: seed, angle: angle))
    }

    /// Every splat is drawn from (style, seed, angle), so a saved mark comes back the same.
    private func makeSplat(fly: Fly?, at p: CGPoint, style: Style, seed: UInt32, angle: CGFloat) -> SCNNode {
        var state = seed | 1
        func r(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat {      // small deterministic generator
            state = state &* 1664525 &+ 1013904223
            return lo + (hi - lo) * CGFloat(state >> 8 & 0xFFFF) / 65535
        }
        let splat = SCNNode()
        splat.name = "splat"
        splat.position = SCNVector3(p.x, p.y, 0.3)
        // hemolymph is clear-yellow; gut contents brown; eye pigment red
        let palette: [NSColor] = [NSColor(calibratedRed: 0.24, green: 0.11, blue: 0.08, alpha: 0.9),
                                  NSColor(calibratedRed: 0.42, green: 0.30, blue: 0.10, alpha: 0.85),
                                  NSColor(calibratedRed: 0.34, green: 0.09, blue: 0.07, alpha: 0.9),
                                  NSColor(calibratedRed: 0.18, green: 0.13, blue: 0.10, alpha: 0.92)]
        // a mosquito is full of someone's blood
        let goo = fly?.ownForm == .mosquito ? NSColor(calibratedRed: 0.55, green: 0.04, blue: 0.05, alpha: 0.92) : palette[Int(r(0, 3.999))]
        let pale = NSColor(calibratedRed: 0.78, green: 0.66, blue: 0.30, alpha: 0.55)
        func blob(_ rad: CGFloat, at o: CGPoint, sx: CGFloat = 1, sy: CGFloat = 1, rot: CGFloat = 0, color: NSColor? = nil) {
            let cyl = SCNCylinder(radius: rad, height: 0.4)
            cyl.radialSegmentCount = 28
            cyl.firstMaterial?.diffuse.contents = color ?? goo
            cyl.firstMaterial?.lightingModel = .constant
            let n = SCNNode(geometry: cyl)
            n.eulerAngles = SCNVector3(CGFloat.pi / 2, 0, 0)   // lie flat on the desktop plane
            let holder = SCNNode()
            holder.position = SCNVector3(o.x, o.y, 0)
            holder.eulerAngles.z = rot
            holder.scale = SCNVector3(sx, sy, 1)
            holder.addChildNode(n)
            splat.addChildNode(holder)
        }
        func leg(at o: CGPoint, rot: CGFloat) {                 // a detached leg
            let c = SCNCapsule(capRadius: 0.5, height: r(5, 9))
            c.firstMaterial?.diffuse.contents = NSColor(calibratedRed: 0.16, green: 0.10, blue: 0.06, alpha: 1)
            c.firstMaterial?.lightingModel = .constant
            let n = SCNNode(geometry: c)
            n.position = SCNVector3(o.x, o.y, 0.1); n.eulerAngles.z = rot
            splat.addChildNode(n)
        }
        var bodyScale: CGFloat = 1.25, bodyOffset = CGPoint.zero
        switch style {
        case .blot:      // the classic: a round blot and a ring of droplets
            blob(13, at: .zero, sx: 1.35)
            blob(8, at: CGPoint(x: r(-3, 3), y: r(-3, 3)), color: pale)
            for _ in 0..<5 { let a = r(0, 2 * .pi), d = r(12, 27); blob(r(2, 4.5), at: CGPoint(x: cos(a) * d, y: sin(a) * d)) }
        case .smear:     // dragged: a long streak that thins out, the body at its head
            let len = r(34, 58)
            for k in 0..<7 {
                let t = CGFloat(k) / 6
                blob(11 * (1 - 0.75 * t), at: CGPoint(x: -len * t, y: r(-1.5, 1.5)), sx: 1.9, sy: 0.8)
            }
            for _ in 0..<4 { blob(r(1.5, 3), at: CGPoint(x: -r(len * 0.4, len * 1.25), y: r(-9, 9))) }
            blob(6, at: CGPoint(x: -len * 0.2, y: 0), sx: 2.2, sy: 0.5, color: pale)
            leg(at: CGPoint(x: -len * r(0.5, 0.9), y: r(-7, 7)), rot: r(0, .pi))
            bodyScale = 1.15
        case .burst:     // hit hard: a big blot with rays and far-flung drops
            blob(17, at: .zero, sx: 1.2)
            blob(10, at: CGPoint(x: r(-2, 2), y: r(-2, 2)), color: pale)
            let rays = Int(r(8, 12.99))
            for k in 0..<rays {
                let a = CGFloat(k) / CGFloat(rays) * 2 * .pi + r(-0.2, 0.2), d = r(18, 34)
                blob(r(1.6, 2.6), at: CGPoint(x: cos(a) * d * 0.62, y: sin(a) * d * 0.62), sx: r(3.5, 6), sy: 0.55, rot: a)
                blob(r(1.5, 3.6), at: CGPoint(x: cos(a) * (d + r(4, 16)), y: sin(a) * (d + r(4, 16))))
            }
            leg(at: CGPoint(x: r(-26, 26), y: r(-26, 26)), rot: r(0, .pi)); leg(at: CGPoint(x: r(-30, 30), y: r(-30, 30)), rot: r(0, .pi))
            bodyScale = 1.45
        case .glance:    // clipped it: a small neat mark, the body thrown a little way off
            blob(7, at: .zero, sx: 1.2, sy: 0.9)
            for _ in 0..<3 { let a = r(0, 2 * .pi), d = r(8, 16); blob(r(1.2, 2.4), at: CGPoint(x: cos(a) * d, y: sin(a) * d)) }
            bodyOffset = CGPoint(x: r(8, 16), y: r(-6, 6)); bodyScale = 1.05
        }
        // the fly itself, flattened into the goo (not for restored marks)
        if let fly {
            let body = fly.node
            body.removeFromParentNode()
            body.position = SCNVector3(bodyOffset.x, bodyOffset.y, 0.25)
            // seen from straight above, "flat" has to be drawn as "spread": wider than
            // long, wings knocked outward, legs bent the wrong way
            let sz = FLY_SCALE * fly.model.sizeScale * bodyScale
            body.scale = SCNVector3(sz * 1.22, sz * 0.94, 0.08)
            body.eulerAngles = SCNVector3(0, 0, r(0, 2 * .pi))
            for (i, wing) in fly.model.foldedWings.childNodes.enumerated() {
                wing.eulerAngles = SCNVector3(0, 0, (i == 0 ? -1 : 1) * r(0.55, 1.5))
            }
            for leg in fly.model.legs {
                leg.root.eulerAngles.z += r(-0.7, 0.7)
                leg.knee.eulerAngles = SCNVector3(0, r(-0.3, 0.3), r(-1.2, 1.2))
            }
            fly.model.abdomen.eulerAngles.z = r(-0.5, 0.5)
            fly.model.blurWingL.isHidden = true; fly.model.blurWingR.isHidden = true
            body.opacity = 0.86
            splat.addChildNode(body)
        }
        splat.eulerAngles.z = angle
        return splat
    }
}
