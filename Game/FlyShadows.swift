// Contact shadows and lighting. A soft blob under every fly grounds it on the
// desktop; in flight the shadow slides away from the body and fades, which is
// the strongest depth cue a top-down overlay has. Also rebalances the scene's
// lights once: less ambient, a more raking key, a cool rim — so bodies have a
// shaded side.

import SceneKit

final class FlyShadows {
    private var nodes: [ObjectIdentifier: SCNNode] = [:]
    private var lit = false
    private lazy var texture: NSImage = {
        let img = NSImage(size: NSSize(width: 128, height: 128))
        img.lockFocus()
        // a true radial falloff: dense under the body, gone well before the edge
        NSGradient(colors: [NSColor(calibratedWhite: 0, alpha: 0.66), NSColor(calibratedWhite: 0, alpha: 0.36),
                            NSColor(calibratedWhite: 0, alpha: 0.09), NSColor(calibratedWhite: 0, alpha: 0)],
                   atLocations: [0, 0.38, 0.72, 1], colorSpace: .genericRGB)!
            .draw(fromCenter: NSPoint(x: 64, y: 64), radius: 0, toCenter: NSPoint(x: 64, y: 64), radius: 62, options: [])
        img.unlockFocus()
        return img
    }()

    private func relight(_ scene: SCNScene) {
        lit = true
        for n in scene.rootNode.childNodes {
            guard let l = n.light else { continue }
            if l.type == .ambient { l.intensity = 330 }
            if l.type == .directional { l.intensity = 1050; n.eulerAngles = SCNVector3(-0.62, 0.50, 0) }
        }
        let rim = SCNLight()
        rim.type = .directional
        rim.intensity = 420
        rim.color = NSColor(calibratedRed: 0.72, green: 0.84, blue: 1.0, alpha: 1)
        let rimNode = SCNNode()
        rimNode.light = rim
        rimNode.eulerAngles = SCNVector3(0.75, -0.65, 0)
        scene.rootNode.addChildNode(rimNode)
    }

    func update(flies: [Fly], scene: SCNScene) {
        if !lit { relight(scene) }
        var live = Set<ObjectIdentifier>()
        for fly in flies {
            let id = ObjectIdentifier(fly)
            live.insert(id)
            let node: SCNNode
            if let n = nodes[id] { node = n } else {
                let plane = SCNPlane(width: 1, height: 1)
                let m = SCNMaterial()
                m.lightingModel = .constant
                m.diffuse.contents = texture
                m.writesToDepthBuffer = false
                m.blendMode = .alpha
                plane.materials = [m]
                node = SCNNode(geometry: plane)
                node.name = "shadow"
                node.renderingOrder = -10
                scene.rootNode.addChildNode(node)
                nodes[id] = node
            }
            let alt = fly.state == .flying ? fly.alt : 0
            // light comes from the upper left: the shadow falls down and to the right, further with height
            // the body's long axis runs from the head (+) to the abdomen tip (-); center the blob on it
            let back = CGPoint(x: -cos(fly.heading) * 2.5 * FLY_SCALE, y: -sin(fly.heading) * 2.5 * FLY_SCALE)
            node.position = SCNVector3(fly.pos.x + back.x + 3.0 + alt * 40, fly.pos.y + back.y - 4.2 - alt * 52, 0.05)
            node.eulerAngles = SCNVector3(0, 0, fly.heading - .pi / 2)
            let grow = 1 + alt * 0.7
            let sz = FLY_SCALE * fly.model.sizeScale
            node.scale = SCNVector3(21 * sz * grow, 34 * sz * grow, 1)
            node.opacity = fly.node.isHidden ? 0 : (1 - 0.6 * alt)
        }
        for (id, n) in nodes where !live.contains(id) { n.removeFromParentNode(); nodes[id] = nil }
    }
}
