import SpriteKit
import GameplayKit

class GameScene: SKScene, SKPhysicsContactDelegate {
    // MARK: - Game Nodes
    var vehicleBody: SKSpriteNode!
    var frontWheel: SKShapeNode!
    var rearWheel: SKShapeNode!
    var gasButton: SKSpriteNode!
    var brakeButton: SKSpriteNode!
    var cameraNode: SKCameraNode!
    
    // MARK: - Terrain System
    var terrainSegments: [SKShapeNode] = []
    var nextTerrainX: CGFloat = -1500
    var lastY: CGFloat = 100
    
    // MARK: - Ground Contact Tracking
    var rearWheelContacts = 0
    var frontWheelContacts = 0
    var rearWheelOnGround: Bool { rearWheelContacts > 0 }
    var frontWheelOnGround: Bool { frontWheelContacts > 0 }
    var anyWheelOnGround: Bool { rearWheelOnGround || frontWheelOnGround }
    
    // MARK: - Control Flags
    var gasPressed = false
    var brakePressed = false
    
    // MARK: - Bitmask Setup
    struct PhysicsCategory {
        static let none: UInt32 = 0
        static let rearWheel: UInt32 = 0x1 << 0
        static let frontWheel: UInt32 = 0x1 << 1
        static let ground: UInt32 = 0x1 << 2
    }

    override func didMove(to view: SKView) {
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
        physicsWorld.contactDelegate = self
        backgroundColor = .cyan
        
        createInitialTerrain()
        createVehicle()
        setupCamera()
        setupControls()
    }
    
    // MARK: - Infinite Terrain
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
        
        let groundSegment = SKShapeNode(path: path)
        groundSegment.strokeColor = .brown
        groundSegment.lineWidth = 10
        groundSegment.physicsBody = SKPhysicsBody(edgeChainFrom: path)
        groundSegment.physicsBody?.isDynamic = false
        groundSegment.physicsBody?.friction = 2.0
        groundSegment.physicsBody?.categoryBitMask = PhysicsCategory.ground
        
        return groundSegment
    }
    
    func checkAndGenerateTerrain() {
        if vehicleBody.position.x + 3000 > nextTerrainX {
            let newSegment = createTerrainSegment(startX: nextTerrainX, width: 4000)
            addChild(newSegment)
            terrainSegments.append(newSegment)
            nextTerrainX += 4000
            
            if terrainSegments.count > 5 {
                let old = terrainSegments.removeFirst()
                old.removeFromParent()
            }
        }
    }
    
    // MARK: - Vehicle Creation
    func createVehicle() {
        let wheelRadius: CGFloat = 80
        let wheelSpacing: CGFloat = 160

        // --- Rear Wheel ---
        rearWheel = createWheel(radius: wheelRadius)
        rearWheel.position = CGPoint(x: 0, y: 800)
        rearWheel.physicsBody?.categoryBitMask = PhysicsCategory.rearWheel
        rearWheel.physicsBody?.contactTestBitMask = PhysicsCategory.ground
        addChild(rearWheel)

        // --- Front Wheel ---
        frontWheel = createWheel(radius: wheelRadius)
        frontWheel.position = CGPoint(x: wheelSpacing * 2, y: 800)
        frontWheel.physicsBody?.categoryBitMask = PhysicsCategory.frontWheel
        frontWheel.physicsBody?.contactTestBitMask = PhysicsCategory.ground
        addChild(frontWheel)

        // --- Vehicle Body ---
        vehicleBody = SKSpriteNode(color: .red, size: CGSize(width: 400, height: 200))
        vehicleBody.position = CGPoint(x: wheelSpacing, y: 800 + 120)
        vehicleBody.physicsBody = SKPhysicsBody(rectangleOf: vehicleBody.size)
        vehicleBody.physicsBody?.allowsRotation = true
        vehicleBody.physicsBody?.mass = 1.0
        vehicleBody.physicsBody?.friction = 0.5
        vehicleBody.physicsBody?.linearDamping = 0.3
        vehicleBody.physicsBody?.angularDamping = 0.5
        addChild(vehicleBody)

        // --- Joints ---
        let rearJoint = SKPhysicsJointPin.joint(
            withBodyA: vehicleBody.physicsBody!,
            bodyB: rearWheel.physicsBody!,
            anchor: rearWheel.position
        )
        physicsWorld.add(rearJoint)

        let frontJoint = SKPhysicsJointPin.joint(
            withBodyA: vehicleBody.physicsBody!,
            bodyB: frontWheel.physicsBody!,
            anchor: frontWheel.position
        )
        physicsWorld.add(frontJoint)
    }
    
    func createWheel(radius: CGFloat) -> SKShapeNode {
        let wheel = SKShapeNode(circleOfRadius: radius)
        wheel.fillColor = .darkGray
        wheel.strokeColor = .black
        wheel.lineWidth = 4

        // Visual spokes
        let spoke1 = SKShapeNode(rectOf: CGSize(width: radius * 1.8, height: 6))
        spoke1.fillColor = .white
        wheel.addChild(spoke1)

        let spoke2 = SKShapeNode(rectOf: CGSize(width: radius * 1.8, height: 6))
        spoke2.fillColor = .white
        spoke2.zRotation = .pi / 2
        wheel.addChild(spoke2)

        // Physics setup
        wheel.physicsBody = SKPhysicsBody(circleOfRadius: radius)
        wheel.physicsBody?.allowsRotation = true
        wheel.physicsBody?.friction = 1.0
        wheel.physicsBody?.restitution = 0.2
        wheel.physicsBody?.linearDamping = 0.3
        wheel.physicsBody?.angularDamping = 0.4
        wheel.physicsBody?.mass = 0.3

        return wheel
    }

    // MARK: - Movement Logic
    func accelerate() {
        // Always spin the rear wheel
        rearWheel.physicsBody?.applyTorque(-70000)

        // If airborne, also tilt the body backward
        if !anyWheelOnGround {
            vehicleBody.physicsBody?.applyAngularImpulse(0.2)
        }
    }

    func brake() {
        // Always spin the rear wheel (reverse torque)
        rearWheel.physicsBody?.applyTorque(70000)

        // If airborne, also tilt the body forward
        if !anyWheelOnGround {
            vehicleBody.physicsBody?.applyAngularImpulse(-0.2)
        }
    }


    // MARK: - Contact Handling
    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA.categoryBitMask
        let b = contact.bodyB.categoryBitMask

        if (a == PhysicsCategory.rearWheel && b == PhysicsCategory.ground) ||
           (b == PhysicsCategory.rearWheel && a == PhysicsCategory.ground) {
            rearWheelContacts += 1
        }

        if (a == PhysicsCategory.frontWheel && b == PhysicsCategory.ground) ||
           (b == PhysicsCategory.frontWheel && a == PhysicsCategory.ground) {
            frontWheelContacts += 1
        }
    }

    func didEnd(_ contact: SKPhysicsContact) {
        let a = contact.bodyA.categoryBitMask
        let b = contact.bodyB.categoryBitMask

        if (a == PhysicsCategory.rearWheel && b == PhysicsCategory.ground) ||
           (b == PhysicsCategory.rearWheel && a == PhysicsCategory.ground) {
            rearWheelContacts = max(0, rearWheelContacts - 1)
        }

        if (a == PhysicsCategory.frontWheel && b == PhysicsCategory.ground) ||
           (b == PhysicsCategory.frontWheel && a == PhysicsCategory.ground) {
            frontWheelContacts = max(0, frontWheelContacts - 1)
        }
    }

    // MARK: - Frame Updates
    override func didSimulatePhysics() {
        let deltaTime: CGFloat = 1.0 / 60.0
        let wheelRadius: CGFloat = 80.0

        if let rearBody = rearWheel.physicsBody {
            let vx = rearBody.velocity.dx
            rearWheel.zRotation += -vx / wheelRadius * deltaTime
        }

        if let frontBody = frontWheel.physicsBody {
            let vx = frontBody.velocity.dx
            frontWheel.zRotation += -vx / wheelRadius * deltaTime
        }

        cameraNode.position = CGPoint(
            x: vehicleBody.position.x + 600,
            y: vehicleBody.position.y + 200
        )

        checkAndGenerateTerrain()
    }
    
    override func update(_ currentTime: TimeInterval) {
        if gasPressed { accelerate() }
        if brakePressed { brake() }
    }

    // MARK: - Camera Setup
    func setupCamera() {
        cameraNode = SKCameraNode()
        camera = cameraNode
        addChild(cameraNode)
    }

    // MARK: - On-Screen Buttons
    func setupControls() {
        let buttonSize = CGSize(width: 160, height: 160)
        
        gasButton = SKSpriteNode(color: .green, size: buttonSize)
        gasButton.name = "gas"
        gasButton.alpha = 0.4
        gasButton.position = CGPoint(x: 700, y: -500)
        
        brakeButton = SKSpriteNode(color: .red, size: buttonSize)
        brakeButton.name = "brake"
        brakeButton.alpha = 0.4
        brakeButton.position = CGPoint(x: -700, y: -500)
        
        cameraNode.addChild(gasButton)
        cameraNode.addChild(brakeButton)
    }
    
    // MARK: - Input Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: cameraNode)
            let node = cameraNode.atPoint(location)
            if node.name == "gas" {
                gasPressed = true
            } else if node.name == "brake" {
                brakePressed = true
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        gasPressed = false
        brakePressed = false
    }
}
