// Squish on click: a grounded fly under the cursor becomes a splat with the
// flattened body in it. Splats stay solid for 2.5 minutes, then fade out
// over the next. You have to earn it — a fast cursor trips the real escape
// circuit before the click lands.

import SceneKit

final class Splats {
    var enabled = true
    var hitRadius: CGFloat = 26
    private var splats: [(node: SCNNode, born: TimeInterval)] = []
    private var time: TimeInterval = 0
    private var restored = false
    /// Splat marks survive relaunch (goo only; the body is gone). Stored as [x, y, age].
    private func save() {
        let rows = splats.map { [Double($0.node.position.x), Double($0.node.position.y), time - $0.born] }
        UserDefaults.standard.set(rows, forKey: "splats")
    }
    private func restore(world: GameWorld) {
        restored = true
        guard let rows = UserDefaults.standard.array(forKey: "splats") as? [[Double]] else { return }
        for r in rows where r.count == 3 && r[2] < 210 {
            let n = makeSplat(fly: nil, at: CGPoint(x: r[0], y: r[1]))
            world.scene.rootNode.addChildNode(n)
            splats.append((n, time - r[2]))
        }
    }

    /// Was there a fly near a click that didn't connect? (airborne, or just outside the hitbox)
    func nearMiss(at p: CGPoint, world: GameWorld) -> Bool {
        world.flies.contains { hypot(p.x - $0.pos.x, p.y - $0.pos.y) < 90 }
    }

    /// Removes and splats the first grounded fly within reach. Returns it, or nil.
    func squish(at p: CGPoint, world: GameWorld) -> Fly? {
        guard enabled else { return nil }
        guard let i = world.flies.firstIndex(where: { $0.state != .flying && hypot(p.x - $0.pos.x, p.y - $0.pos.y) < hitRadius })
        else { return nil }
        let fly = world.flies.remove(at: i)
        let node = makeSplat(fly: fly, at: fly.pos)
        world.scene.rootNode.addChildNode(node)
        splats.append((node, time))
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

    private func makeSplat(fly: Fly?, at p: CGPoint) -> SCNNode {
        let splat = SCNNode()
        splat.name = "splat"
        splat.position = SCNVector3(p.x, p.y, 0.3)
        let goo = NSColor(calibratedRed: 0.24, green: 0.11, blue: 0.08, alpha: 0.9)
        func blob(_ r: CGFloat, at o: CGPoint, sx: CGFloat = 1) -> SCNNode {
            let cyl = SCNCylinder(radius: r, height: 0.4)
            cyl.firstMaterial?.diffuse.contents = goo
            cyl.firstMaterial?.lightingModel = .constant
            let n = SCNNode(geometry: cyl)
            n.eulerAngles.x = .pi / 2          // lie flat on the desktop plane
            n.position = SCNVector3(o.x, o.y, 0)
            n.scale = SCNVector3(sx, 1, 1)
            return n
        }
        splat.addChildNode(blob(13, at: .zero, sx: 1.35))
        for _ in 0..<5 {
            let a = rnd(0...(2 * CGFloat.pi)), d = rnd(12...27)
            splat.addChildNode(blob(rnd(2...4.5), at: CGPoint(x: cos(a) * d, y: sin(a) * d)))
        }
        // the fly itself, flattened into the goo (not for restored marks)
        if let fly {
            let body = fly.node
            body.removeFromParentNode()
            body.position = SCNVector3(0, 0, 0.25)
            body.scale = SCNVector3(FLY_SCALE * 1.25, FLY_SCALE * 1.25, 0.08)
            body.opacity = 0.9
            splat.addChildNode(body)
        }
        splat.eulerAngles.z = rnd(0...(2 * CGFloat.pi))
        return splat
    }
}
