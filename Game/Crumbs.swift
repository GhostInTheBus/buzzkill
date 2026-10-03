// Crumbs: food the user carries on the cursor and drops with a click. Every
// fly converges on the nearest crumb and feeds; a crumb lasts ~80 s per fly.

import SceneKit

final class Crumbs {
    private(set) var crumbs: [(node: SCNNode, pos: CGPoint, amount: CGFloat)] = []
    private var held: SCNNode?
    /// Called once per crumb eaten to nothing.
    var onFinished: (() -> Void)?

    var isHolding: Bool { held != nil }

    func pickUp(world: GameWorld, at p: CGPoint) {
        guard held == nil else { return }
        let n = makeNode()
        n.position = SCNVector3(p.x, p.y, 0.3)
        world.scene.rootNode.addChildNode(n)
        held = n
    }

    func place(world: GameWorld, at p: CGPoint) {
        guard let n = held else { return }
        n.position = SCNVector3(p.x, p.y, 0.3)
        crumbs.append((n, p, 1))
        held = nil
    }

    func nearest(to fly: Fly) -> CGPoint? {
        crumbs.min { hypot($0.pos.x - fly.pos.x, $0.pos.y - fly.pos.y) < hypot($1.pos.x - fly.pos.x, $1.pos.y - fly.pos.y) }?.pos
    }

    func update(world: GameWorld, dt: CGFloat, mouse: CGPoint?) {
        if let h = held, let m = mouse { h.position = SCNVector3(m.x, m.y, 0.3) }
        guard !crumbs.isEmpty else { return }
        // feeding: each grounded fly within reach eats
        for i in crumbs.indices {
            let eaters = world.flies.filter { $0.state != .flying && hypot($0.pos.x - crumbs[i].pos.x, $0.pos.y - crumbs[i].pos.y) < 60 }.count
            if eaters > 0 { crumbs[i].amount -= dt * 0.0125 * CGFloat(eaters) }
            let sc = max(0.15, crumbs[i].amount)
            crumbs[i].node.scale = SCNVector3(sc, sc, 1)
        }
        for g in crumbs where g.amount <= 0.1 { g.node.removeFromParentNode(); onFinished?() }
        crumbs.removeAll { $0.amount <= 0.1 }
    }

    private func makeNode() -> SCNNode {
        let crumb = SCNNode()
        crumb.name = "crumb"
        let tone = NSColor(calibratedRed: 0.86, green: 0.72, blue: 0.46, alpha: 1)
        for k in 0..<4 {
            let cyl = SCNCylinder(radius: k == 0 ? 7 : rnd(2.5...4.5), height: 1.2)
            cyl.firstMaterial?.diffuse.contents = tone
            let n = SCNNode(geometry: cyl)
            n.eulerAngles.x = .pi / 2
            let a = rnd(0...(2 * CGFloat.pi)), d: CGFloat = k == 0 ? 0 : rnd(4...9)
            n.position = SCNVector3(cos(a) * d, sin(a) * d, 0)
            crumb.addChildNode(n)
        }
        return crumb
    }
}
