import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        if let view = self.view as! SKView? {
            let scene = GameScene(size: CGSize(width: 2388, height: 1668)) // iPad Pro 11" logical points
            scene.scaleMode = .aspectFill

            view.presentScene(scene)
            view.ignoresSiblingOrder = true
            view.showsFPS = true
            view.showsNodeCount = true
            // Uncomment to visualize physics shapes:
            view.showsPhysics = true
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
