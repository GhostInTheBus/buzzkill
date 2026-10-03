// What the game layer is allowed to see of the engine. The Coordinator
// conforms; nothing in Game/ touches it otherwise.

import SceneKit

protocol GameWorld: AnyObject {
    var flies: [Fly] { get set }
    var bounds: CGSize { get }
    var scene: SCNScene { get }
    /// Startle the brain fly (loom override into the real circuit).
    func startle(_ strength: CGFloat)
}
