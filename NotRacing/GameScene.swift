import SpriteKit
import GameplayKit

class GameScene: SKScene {

    // MARK: - Game Nodes
    var vehicleBody: SKSpriteNode!
    var frontWheel: SKShapeNode!
    var rearWheel: SKShapeNode!
    var gasButton: SKSpriteNode!
    var brakeButton: SKSpriteNode!
    var cameraNode: SKCameraNode!
    var restartButton: SKSpriteNode!

    // MARK: - Sky (Sun + Clouds)
    var sunNode: SKSpriteNode!
    var cloudNodes: [SKSpriteNode] = []

    // MARK: - Controls
    var gasPressed = false
    var brakePressed = false
    var anyWheelOnGround = false

    // MARK: - HUD (RPM & Speed)
    var rpmBarBackground: SKSpriteNode!
    var rpmBarFill: SKSpriteNode!
    var rpmLabel: SKLabelNode!
    var speedLabel: SKLabelNode!

    // MARK: - Terrain
    var terrainSegments: [SKShapeNode] = []
    var nextTerrainX: CGFloat = -1500
    var lastY: CGFloat = 100

    // MARK: - Parallax state
    var lastVehicleX: CGFloat? = nil    // remembers car X for cloud parallax

    // MARK: - Scene lifecycle
    override func didMove(to view: SKView) {
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
        backgroundColor = .cyan

        createInitialTerrain()
        createVehicle()
        setupCamera()
        setupSkyDecorations()   // sun + clouds (fixed on screen)
        setupControls()
        setupRPMBar()
        setupHUDLabels()
        setupRestartButton()

        // initialise parallax reference
        lastVehicleX = vehicleBody.position.x
    }

    // MARK: - Terrain System
    func createInitialTerrain() {
        for _ in 0..<3 {
            let segment = createTerrainSegment(startX: nextTerrainX, width: 4000)
            addChild(segment)
            terrainSegments.append(segment)
            nextTerrainX += 4000
        }
    }

    func createTerrainSegment(startX: CGFloat, width: CGFloat) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: startX, y: lastY))

        let endX = startX + width
        var y = lastY

        for i in stride(from: startX, through: endX, by: 100) {
            let noise = sin(Double(i) / 800.0 * .pi) * 50.0
            y = CGFloat(100 + noise)
            path.addLine(to: CGPoint(x: i, y: y))
        }

        lastY = y

        let ground = SKShapeNode(path: path)
        ground.strokeColor = .brown
        ground.lineWidth = 10
        ground.physicsBody = SKPhysicsBody(edgeChainFrom: path)
        ground.physicsBody?.isDynamic = false
        ground.physicsBody?.friction = 1.0

        return ground
    }

    func checkAndGenerateTerrain() {
        if vehicleBody.position.x + 3000 > nextTerrainX {
            let newSeg = createTerrainSegment(startX: nextTerrainX, width: 4000)
            addChild(newSeg)
            terrainSegments.append(newSeg)
            nextTerrainX += 4000

            if terrainSegments.count > 5 {
                terrainSegments.removeFirst().removeFromParent()
            }
        }
    }

    // MARK: - Vehicle
    func createWheel(radius: CGFloat) -> SKShapeNode {
        let wheel = SKShapeNode(circleOfRadius: radius)
        wheel.fillColor = .darkGray
        wheel.strokeColor = .black
        wheel.lineWidth = 4

        let spoke1 = SKShapeNode(rectOf: CGSize(width: radius * 1.2, height: 6))
        spoke1.fillColor = .white
        wheel.addChild(spoke1)

        let spoke2 = SKShapeNode(rectOf: CGSize(width: radius * 1.2, height: 6))
        spoke2.fillColor = .white
        spoke2.zRotation = .pi / 2
        wheel.addChild(spoke2)

        wheel.physicsBody = SKPhysicsBody(circleOfRadius: radius)
        wheel.physicsBody?.allowsRotation = true
        wheel.physicsBody?.friction = 2.0
        wheel.physicsBody?.restitution = 0.2
        wheel.physicsBody?.linearDamping = 0.3
        wheel.physicsBody?.angularDamping = 0.4
        wheel.physicsBody?.mass = 0.1

        return wheel
    }

    func createVehicle() {
        let wheelRadius: CGFloat = 80
        let wheelSpacing: CGFloat = 160

        // --- Wheels ---
        rearWheel = createWheel(radius: wheelRadius)
        rearWheel.position = CGPoint(x: 0, y: 830)
        addChild(rearWheel)

        frontWheel = createWheel(radius: wheelRadius)
        frontWheel.position = CGPoint(x: wheelSpacing * 2, y: 830)
        addChild(frontWheel)

        // --- Car body ---
        vehicleBody = SKSpriteNode(color: .red, size: CGSize(width: 400, height: 160))
        vehicleBody.position = CGPoint(x: wheelSpacing, y: 800 + 150)
        vehicleBody.physicsBody = SKPhysicsBody(rectangleOf: vehicleBody.size)
        vehicleBody.physicsBody?.allowsRotation = true
        vehicleBody.physicsBody?.mass = 8.0
        vehicleBody.physicsBody?.applyForce(CGVector(dx: 0, dy: -5))
        addChild(vehicleBody)

        // --- Suspension for both wheels ---
        addSuspension(body: vehicleBody, wheel: rearWheel, wheelOffsetX: -wheelSpacing)
        addSuspension(body: vehicleBody, wheel: frontWheel, wheelOffsetX: wheelSpacing)
    }

    func addSuspension(body: SKSpriteNode, wheel: SKShapeNode, wheelOffsetX: CGFloat) {
        guard let bodyPhysics = body.physicsBody,
              let wheelPhysics = wheel.physicsBody else { return }

        let pin = SKPhysicsJointPin.joint(
            withBodyA: bodyPhysics,
            bodyB: wheelPhysics,
            anchor: wheel.position
        )
        pin.frictionTorque = 0.0
        physicsWorld.add(pin)

        let anchorA = CGPoint(
            x: wheel.position.x,
            y: wheel.position.y + 80
        )
        let limit = SKPhysicsJointLimit.joint(
            withBodyA: bodyPhysics,
            bodyB: wheelPhysics,
            anchorA: anchorA,
            anchorB: wheel.position
        )
        limit.maxLength = 500000
        physicsWorld.add(limit)

        let spring = SKPhysicsJointSpring.joint(
            withBodyA: bodyPhysics,
            bodyB: wheelPhysics,
            anchorA: body.position,
            anchorB: wheel.position
        )
        spring.frequency = 0.00002
        spring.damping = 0.000005
        physicsWorld.add(spring)
    }

    // MARK: - MOTOR LOGIC
    func accelerate() {
        rearWheel.physicsBody?.applyTorque(-200)

        if !anyWheelOnGround {
            vehicleBody.physicsBody?.applyAngularImpulse(0.0)
        }
    }

    func brake() {
        rearWheel.physicsBody?.applyTorque(400)

        if !anyWheelOnGround {
            vehicleBody.physicsBody?.applyAngularImpulse(-0.0)
        }
    }

    // MARK: - HUD
    func setupRPMBar() {
        rpmBarBackground = SKSpriteNode(color: .darkGray, size: CGSize(width: 800, height: 40))
        rpmBarBackground.position = CGPoint(x: 0, y: -650)
        rpmBarBackground.alpha = 0.6
        rpmBarBackground.zPosition = 50
        cameraNode.addChild(rpmBarBackground)

        rpmBarFill = SKSpriteNode(color: .green, size: CGSize(width: 0, height: 40))
        rpmBarFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        rpmBarFill.position = CGPoint(x: -400, y: 0)
        rpmBarBackground.addChild(rpmBarFill)
    }

    func setupHUDLabels() {
        rpmLabel = SKLabelNode(fontNamed: "Helvetica")
        rpmLabel.fontSize = 36
        rpmLabel.fontColor = .white
        rpmLabel.position = CGPoint(x: 0, y: -600)
        rpmLabel.zPosition = 100
        cameraNode.addChild(rpmLabel)

        speedLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        speedLabel.fontSize = 48
        speedLabel.fontColor = .yellow
        speedLabel.position = CGPoint(x: 0, y: -550)
        speedLabel.zPosition = 100
        cameraNode.addChild(speedLabel)
    }

    // MARK: - Camera
    func setupCamera() {
        cameraNode = SKCameraNode()
        camera = cameraNode
        addChild(cameraNode)
    }

    // MARK: - Sky (Sun + Clouds)
    func setupSkyDecorations() {
        guard let cameraNode = camera else { return }

        let halfWidth  = size.width / 2
        let halfHeight = size.height / 2

        // configuration
        let sunConfig = (name: "SunPixel", count: 1)
        let cloudConfigs: [(name: String, count: Int)] = [
            ("Cloud1", 2),
            ("Cloud2", 3)
        ]

        // sun
        let sunTexture = SKTexture(imageNamed: sunConfig.name)
        for _ in 0..<sunConfig.count {
            let sun = SKSpriteNode(texture: sunTexture)
            sun.setScale(0.35)
            sun.position = CGPoint(
                x: -halfWidth + sun.size.width / 2 + 40,
                y:  halfHeight - sun.size.height / 2 - 40
            )
            sun.zPosition = -5
            cameraNode.addChild(sun)
            sunNode = sun
        }

        // clouds
        let bandTop    = halfHeight - 40
        let bandBottom = halfHeight * 0.25

        for config in cloudConfigs {
            let texture = SKTexture(imageNamed: config.name)

            for _ in 0..<config.count {
                let cloud = SKSpriteNode(texture: texture)
                cloud.setScale(0.40)
                cloud.zPosition = (sunNode?.zPosition ?? 0) + 1

                let randomX = CGFloat.random(in: -halfWidth...halfWidth)
                let randomY = CGFloat.random(in: bandBottom...bandTop)
                cloud.position = CGPoint(x: randomX, y: randomY)

                cameraNode.addChild(cloud)
                cloudNodes.append(cloud)
            }
        }
    }

    // MARK: - Controls
    func setupControls() {
        let size = CGSize(width: 160, height: 160)

        gasButton = SKSpriteNode(color: .green, size: size)
        gasButton.name = "gas"
        gasButton.alpha = 0.4
        gasButton.position = CGPoint(x: 700, y: -500)
        cameraNode.addChild(gasButton)

        brakeButton = SKSpriteNode(color: .red, size: size)
        brakeButton.name = "brake"
        brakeButton.alpha = 0.4
        brakeButton.position = CGPoint(x: -700, y: -500)
        cameraNode.addChild(brakeButton)
    }

    func setupRestartButton() {
        guard let cameraNode = camera else { return }

        let halfWidth = size.width / 2
        let halfHeight = size.height / 2

        restartButton = SKSpriteNode(color: .blue, size: CGSize(width: 150, height: 150))
        restartButton.name = "restart"
        restartButton.alpha = 0.9
        restartButton.zPosition = 9999

        restartButton.position = CGPoint(
            x: halfWidth - 100,
            y: halfHeight - 100
        )

        let icon = SKLabelNode(text: "⟳")
        icon.fontSize = 100
        icon.fontColor = .white
        icon.verticalAlignmentMode = .center
        restartButton.addChild(icon)

        cameraNode.addChild(restartButton)
    }

    func restartGame() {
        if let view = self.view {
            let newScene = GameScene(size: self.size)
            newScene.scaleMode = self.scaleMode

            let transition = SKTransition.fade(withDuration: 0.3)
            view.presentScene(newScene, transition: transition)
        }
    }

    // MARK: - Cloud Parallax (based on car movement)
    func updateCloudsParallax() {
        guard let body = vehicleBody else { return }

        let currentX = body.position.x

        // first frame: just initialise
        guard let lastX = lastVehicleX else {
            lastVehicleX = currentX
            return
        }

        let deltaX = currentX - lastX
        if abs(deltaX) < 0.01 {
            lastVehicleX = currentX
            return
        }

        lastVehicleX = currentX

        let halfWidth  = size.width / 2
        let halfHeight = size.height / 2
        let bandTop: CGFloat    = halfHeight - 40
        let bandBottom: CGFloat = halfHeight * 0.25

        let parallaxFactor: CGFloat = 0.4   // tweak: smaller = slower clouds
        let offsetX = -deltaX * parallaxFactor

        for cloud in cloudNodes {
            cloud.position.x += offsetX

            // recycle on both sides so we always have clouds
            if cloud.position.x < -halfWidth - 200 {
                cloud.position.x = halfWidth + 200
                cloud.position.y = CGFloat.random(in: bandBottom...bandTop)
            } else if cloud.position.x > halfWidth + 200 {
                cloud.position.x = -halfWidth - 200
                cloud.position.y = CGFloat.random(in: bandBottom...bandTop)
            }
        }
    }

    // MARK: - Touch Input
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: cameraNode)
            let node = cameraNode.atPoint(location)

            if node.name == "gas" {
                gasPressed = true
            } else if node.name == "brake" {
                brakePressed = true
            } else if node.name == "restart" {
                restartGame()
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        gasPressed = false
        brakePressed = false
    }

    // MARK: - Physics Loop
    override func didSimulatePhysics() {

        if gasPressed { accelerate() }
        if brakePressed { brake() }

        // ----- UPDATE RPM + BAR -----
        var smoothedRPM: CGFloat = 0

        if let rear = rearWheel.physicsBody {
            let targetRPM = abs(rear.angularVelocity) * 60 / (2 * .pi)
            let clampedRPM = min(targetRPM, 300)
            smoothedRPM = smoothedRPM * 0.90 + clampedRPM * 0.10

            let normalized = smoothedRPM / 300
            rpmBarFill.size.width = normalized * 800

            rpmLabel.text = "RPM: \(Int(smoothedRPM))"
        }

        // ----- REALISTIC SPEED -----
        if let body = vehicleBody.physicsBody {
            let horizontalSpeed = abs(body.velocity.dx)
            let kmh = Int(horizontalSpeed * 3.6)
            speedLabel.text = "\(kmh / 200) km/h"
        }

        // Camera follows
        cameraNode.position = CGPoint(
            x: vehicleBody.position.x + 600,
            y: vehicleBody.position.y + 200
        )

        checkAndGenerateTerrain()

        // clouds react to car movement (forward/back)
        updateCloudsParallax()
    }
}
