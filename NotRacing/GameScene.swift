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

    // MARK: - Parallax state (for clouds)
    var lastVehicleX: CGFloat? = nil

    // MARK: - Pause / Menu UI
    var isGamePaused = false
    var pauseButton: SKSpriteNode!
    var pauseOverlay: SKSpriteNode?
    var pausePanel: SKSpriteNode?

    // Audio toggles (placeholders)
    var isMusicOn = true
    var isSoundOn = true
    var musicLabel: SKLabelNode?
    var soundLabel: SKLabelNode?

    // MARK: - Pedal colors (for hover/pressed effect)
    let gasBaseColor   = UIColor(red: 0.15, green: 0.80, blue: 0.45, alpha: 1.0)
    let gasPressedColor = UIColor(red: 0.45, green: 1.00, blue: 0.70, alpha: 1.0)

    let brakeBaseColor   = UIColor(red: 0.80, green: 0.25, blue: 0.25, alpha: 1.0)
    let brakePressedColor = UIColor(red: 1.00, green: 0.55, blue: 0.40, alpha: 1.0)

    // MARK: - Scene lifecycle
    override func didMove(to view: SKView) {
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
        backgroundColor = UIColor.fromHex("#98b7ff")   // updated background color

        createInitialTerrain()
        createVehicle()
        setupCamera()
        setupSkyDecorations()
        setupControls()
        setupRPMBar()
        setupHUDLabels()
        setupPauseButton()

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

        rearWheel = createWheel(radius: wheelRadius)
        rearWheel.position = CGPoint(x: 0, y: 830)
        addChild(rearWheel)

        frontWheel = createWheel(radius: wheelRadius)
        frontWheel.position = CGPoint(x: wheelSpacing * 2, y: 830)
        addChild(frontWheel)

        vehicleBody = SKSpriteNode(color: .red, size: CGSize(width: 400, height: 160))
        vehicleBody.position = CGPoint(x: wheelSpacing, y: 800 + 150)
        vehicleBody.physicsBody = SKPhysicsBody(rectangleOf: vehicleBody.size)
        vehicleBody.physicsBody?.allowsRotation = true
        vehicleBody.physicsBody?.mass = 8.0
        vehicleBody.physicsBody?.applyForce(CGVector(dx: 0, dy: -5))
        addChild(vehicleBody)

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

        let sunConfig = (name: "SunPixel", count: 1)
        let cloudConfigs: [(name: String, count: Int)] = [
            ("Cloud1", 2),
            ("Cloud2", 3)
        ]

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

    // MARK: - Controls (pixel-art pedals)
    func setupControls() {
        guard let cameraNode = camera else { return }

        let halfWidth  = size.width / 2
        let halfHeight = size.height / 2
        let pedalBottomY = -halfHeight + 200

        // GAS – vertical, pixel-y block on the right
        gasButton = makePixelPedal(
            size: CGSize(width: 190, height: 260),
            baseColor: gasBaseColor,
            labelText: "GAS",
            labelOffsetY: -90,
            innerBrightness: 0.75,
            rotationDeg: -10,
            name: "gas"
        )
        gasButton.position = CGPoint(x: halfWidth - 220, y: pedalBottomY)
        cameraNode.addChild(gasButton)

        // BRAKE – horizontal, pixel-y block on the left
        brakeButton = makePixelPedal(
            size: CGSize(width: 260, height: 170),
            baseColor: brakeBaseColor,
            labelText: "BRAKE",
            labelOffsetY: -60,
            innerBrightness: 0.65,
            rotationDeg: 0,
            name: "brake"
        )
        brakeButton.position = CGPoint(x: -halfWidth + 260, y: pedalBottomY)

        // Add pixel arrow on brake (reverse hint)
        let arrowPixels = SKNode()
        arrowPixels.name = "brake"
        let pixelSize: CGFloat = 12

        func addArrowPixel(x: Int, y: Int) {
            let node = SKSpriteNode(color: UIColor(white: 1.0, alpha: 0.25),
                                    size: CGSize(width: pixelSize, height: pixelSize))
            node.position = CGPoint(x: CGFloat(x) * pixelSize,
                                    y: CGFloat(y) * pixelSize)
            node.zPosition = 4
            node.name = "brake"
            arrowPixels.addChild(node)
        }

        let arrowCoords: [(Int, Int)] = [
            (2,0),(1,1),(1,0),(1,-1),
            (0,1),(0,0),(0,-1),
            (-1,1),(-1,0),(-1,-1)
        ]
        for (x,y) in arrowCoords { addArrowPixel(x: x, y: y) }

        brakeButton.addChild(arrowPixels)
        cameraNode.addChild(brakeButton)

        updatePedalVisual(button: gasButton, baseColor: gasBaseColor, pressedColor: gasPressedColor, pressed: false)
        updatePedalVisual(button: brakeButton, baseColor: brakeBaseColor, pressedColor: brakePressedColor, pressed: false)
    }

    // Build a chunky pixel-looking pedal
    func makePixelPedal(size: CGSize,
                        baseColor: UIColor,
                        labelText: String,
                        labelOffsetY: CGFloat,
                        innerBrightness: CGFloat,
                        rotationDeg: CGFloat,
                        name: String) -> SKSpriteNode {

        let pedal = SKSpriteNode(color: baseColor, size: size)
        pedal.name = name
        pedal.zPosition = 200
        pedal.zRotation = rotationDeg * .pi / 180

        let borderThickness: CGFloat = 10
        let borderColor = UIColor(white: 0.1, alpha: 1.0)

        func addBorderRect(rectSize: CGSize, pos: CGPoint) {
            let node = SKSpriteNode(color: borderColor, size: rectSize)
            node.position = pos
            node.zPosition = 1
            node.name = name
            pedal.addChild(node)
        }

        addBorderRect(rectSize: CGSize(width: size.width, height: borderThickness),
                      pos: CGPoint(x: 0, y: size.height/2 - borderThickness/2))
        addBorderRect(rectSize: CGSize(width: size.width, height: borderThickness),
                      pos: CGPoint(x: 0, y: -size.height/2 + borderThickness/2))
        addBorderRect(rectSize: CGSize(width: borderThickness, height: size.height),
                      pos: CGPoint(x: -size.width/2 + borderThickness/2, y: 0))
        addBorderRect(rectSize: CGSize(width: borderThickness, height: size.height),
                      pos: CGPoint(x:  size.width/2 - borderThickness/2, y: 0))

        let innerColor = baseColor.withBrightness(innerBrightness)
        let inner = SKSpriteNode(color: innerColor,
                                 size: CGSize(width: size.width - 2*borderThickness,
                                              height: size.height - 2*borderThickness))
        inner.zPosition = 2
        inner.name = name
        pedal.addChild(inner)

        let boltSize: CGFloat = 16
        let boltColor = UIColor(white: 1.0, alpha: 0.7)
        func addBolt(offsetX: CGFloat, offsetY: CGFloat) {
            let bolt = SKSpriteNode(color: boltColor,
                                    size: CGSize(width: boltSize, height: boltSize))
            bolt.position = CGPoint(x: offsetX, y: offsetY)
            bolt.zPosition = 3
            bolt.name = name
            pedal.addChild(bolt)
        }
        let bx = size.width/2 - borderThickness - boltSize/2 - 6
        let by = size.height/2 - borderThickness - boltSize/2 - 6
        addBolt(offsetX: -bx, offsetY:  by)
        addBolt(offsetX:  bx, offsetY:  by)
        addBolt(offsetX: -bx, offsetY: -by)
        addBolt(offsetX:  bx, offsetY: -by)

        let stripeCount = 4
        let pixelStripeHeight: CGFloat = 14
        for i in 0..<stripeCount {
            let stripe = SKSpriteNode(
                color: UIColor(white: 1.0, alpha: 0.15),
                size: CGSize(width: inner.size.width * 0.78, height: pixelStripeHeight)
            )
            stripe.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            let offset = CGFloat(i - stripeCount/2) * (pixelStripeHeight + 6)
            stripe.position = CGPoint(x: 0, y: offset)
            stripe.zPosition = 3
            stripe.name = name
            inner.addChild(stripe)
        }

        let label = SKLabelNode(fontNamed: "Courier-Bold")
        label.text = labelText
        label.fontSize = 30
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: labelOffsetY)
        label.zPosition = 4
        label.name = name
        pedal.addChild(label)

        return pedal
    }

    // MARK: - Pedal visual helper
    func updatePedalVisual(button: SKSpriteNode?,
                           baseColor: UIColor,
                           pressedColor: UIColor,
                           pressed: Bool) {

        guard let button = button else { return }

        let targetColor = pressed ? pressedColor : baseColor
        let targetScale: CGFloat = pressed ? 0.92 : 1.0

        let colorAction = SKAction.colorize(with: targetColor,
                                            colorBlendFactor: 1.0,
                                            duration: 0.08)
        let scaleAction = SKAction.scale(to: targetScale, duration: 0.08)
        let group = SKAction.group([colorAction, scaleAction])

        button.removeAction(forKey: "pedalVisual")
        button.run(group, withKey: "pedalVisual")
    }

    // MARK: - Pause Button UI
    func setupPauseButton() {
        guard let cameraNode = camera else { return }

        let halfWidth  = size.width / 2
        let halfHeight = size.height / 2

        pauseButton = SKSpriteNode(color: .clear, size: CGSize(width: 120, height: 120))
        pauseButton.name = "pauseButton"
        pauseButton.zPosition = 300

        pauseButton.position = CGPoint(
            x: halfWidth - 120,
            y: halfHeight - 120
        )

        let frameNode = SKShapeNode(rectOf: pauseButton.size)
        frameNode.strokeColor = .white
        frameNode.lineWidth = 6
        frameNode.fillColor = UIColor(white: 0.1, alpha: 0.6)
        frameNode.zPosition = 1
        frameNode.name = "pauseButton"
        pauseButton.addChild(frameNode)

        let label = SKLabelNode(fontNamed: "Courier-Bold")
        label.text = "II"
        label.fontSize = 60
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.zPosition = 2
        label.name = "pauseButton"
        pauseButton.addChild(label)

        cameraNode.addChild(pauseButton)
    }

    // MARK: - Pause helpers
    func applyPauseState(_ paused: Bool) {
        isGamePaused = paused
        physicsWorld.speed = paused ? 0 : 1

        gasButton.isHidden = paused
        brakeButton.isHidden = paused
        rpmBarBackground.isHidden = paused
        rpmLabel.isHidden = paused
        speedLabel.isHidden = paused
        pauseButton.isHidden = paused
    }

    // MARK: - Pause Menu
    func showPauseMenu() {
        guard !isGamePaused, let cameraNode = camera else { return }

        applyPauseState(true)

        let overlay = SKSpriteNode(
            color: .black,
            size: CGSize(width: self.size.width * 2, height: self.size.height * 2)
        )
        overlay.name = "pauseOverlay"
        overlay.alpha = 0.6
        overlay.zPosition = 10_000
        overlay.position = .zero
        overlay.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        cameraNode.addChild(overlay)
        pauseOverlay = overlay

        let panelSize = CGSize(width: 700, height: 600)
        let panelColor = UIColor(red: 30/255, green: 30/255, blue: 60/255, alpha: 1)

        let panel = SKSpriteNode(color: panelColor, size: panelSize)
        panel.name = "pausePanel"
        panel.zPosition = 10_100
        panel.position = .zero

        let border = SKShapeNode(rectOf: panelSize)
        border.strokeColor = .white
        border.lineWidth = 8
        border.zPosition = 1
        panel.addChild(border)

        let title = SKLabelNode(fontNamed: "Courier-Bold")
        title.text = "PAUSED"
        title.fontSize = 64
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: panelSize.height / 2 - 90)
        title.zPosition = 2
        panel.addChild(title)

        let buttonWidth: CGFloat = 520
        let buttonHeight: CGFloat = 80
        let verticalSpacing: CGFloat = 26

        func makeButton(name: String, text: String, y: CGFloat) -> SKSpriteNode {
            let btn = SKSpriteNode(
                color: UIColor(white: 0.15, alpha: 0.9),
                size: CGSize(width: buttonWidth, height: buttonHeight)
            )
            btn.name = name
            btn.zPosition = 2
            btn.position = CGPoint(x: 0, y: y)

            let btnBorder = SKShapeNode(rectOf: btn.size)
            btnBorder.strokeColor = .white
            btnBorder.lineWidth = 4
            btnBorder.zPosition = 1
            btnBorder.name = name
            btn.addChild(btnBorder)

            let label = SKLabelNode(fontNamed: "Courier-Bold")
            label.text = text
            label.fontSize = 34
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.zPosition = 3
            label.name = name
            btn.addChild(label)

            return btn
        }

        let resumeButtonY: CGFloat  = title.position.y - 80.0
        let restartButtonY: CGFloat = resumeButtonY - (buttonHeight + verticalSpacing)
        let musicButtonY: CGFloat   = restartButtonY - (buttonHeight + verticalSpacing)
        let soundButtonY: CGFloat   = musicButtonY   - (buttonHeight + verticalSpacing)

        let resumeButton = makeButton(name: "resumeButton", text: "RESUME", y: resumeButtonY)
        panel.addChild(resumeButton)

        let restartButton = makeButton(name: "restartMenuButton", text: "RESTART", y: restartButtonY)
        panel.addChild(restartButton)

        let musicButton = makeButton(
            name: "musicButton",
            text: "MUSIC: \(isMusicOn ? "ON" : "OFF")",
            y: musicButtonY
        )
        panel.addChild(musicButton)
        if let label = musicButton.children.compactMap({ $0 as? SKLabelNode }).first {
            musicLabel = label
        }

        let soundButton = makeButton(
            name: "soundButton",
            text: "SOUND: \(isSoundOn ? "ON" : "OFF")",
            y: soundButtonY
        )
        panel.addChild(soundButton)
        if let label = soundButton.children.compactMap({ $0 as? SKLabelNode }).first {
            soundLabel = label
        }

        cameraNode.addChild(panel)
        pausePanel = panel
    }

    func hidePauseMenu() {
        applyPauseState(false)

        pauseOverlay?.removeFromParent()
        pausePanel?.removeFromParent()
        pauseOverlay = nil
        pausePanel = nil
    }

    func toggleMusic() {
        isMusicOn.toggle()
        musicLabel?.text = "MUSIC: \(isMusicOn ? "ON" : "OFF")"
    }

    func toggleSound() {
        isSoundOn.toggle()
        soundLabel?.text = "SOUND: \(isSoundOn ? "ON" : "OFF")"
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
        let currentX = vehicleBody.position.x

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

        let parallaxFactor: CGFloat = 0.4
        let offsetX = -deltaX * parallaxFactor

        for cloud in cloudNodes {
            cloud.position.x += offsetX

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
            let targetName = node.name ?? node.parent?.name

            if isGamePaused {
                switch targetName {
                case "resumeButton":
                    hidePauseMenu()
                case "restartMenuButton":
                    hidePauseMenu()
                    restartGame()
                case "musicButton":
                    toggleMusic()
                case "soundButton":
                    toggleSound()
                default:
                    break
                }
                continue
            }

            switch targetName {
            case "gas":
                gasPressed = true
                updatePedalVisual(button: gasButton,
                                  baseColor: gasBaseColor,
                                  pressedColor: gasPressedColor,
                                  pressed: true)
            case "brake":
                brakePressed = true
                updatePedalVisual(button: brakeButton,
                                  baseColor: brakeBaseColor,
                                  pressedColor: brakePressedColor,
                                  pressed: true)
            case "pauseButton":
                showPauseMenu()
            default:
                break
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        gasPressed = false
        brakePressed = false

        updatePedalVisual(button: gasButton,
                          baseColor: gasBaseColor,
                          pressedColor: gasPressedColor,
                          pressed: false)
        updatePedalVisual(button: brakeButton,
                          baseColor: brakeBaseColor,
                          pressedColor: brakePressedColor,
                          pressed: false)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    // MARK: - Physics Loop
    override func didSimulatePhysics() {
        if isGamePaused { return }

        if gasPressed { accelerate() }
        if brakePressed { brake() }

        var smoothedRPM: CGFloat = 0

        if let rear = rearWheel.physicsBody {
            let targetRPM = abs(rear.angularVelocity) * 60 / (2 * .pi)
            let clampedRPM = min(targetRPM, 300)
            smoothedRPM = smoothedRPM * 0.90 + clampedRPM * 0.10

            let normalized = smoothedRPM / 300
            rpmBarFill.size.width = normalized * 800

            rpmLabel.text = "RPM: \(Int(smoothedRPM))"
        }

        if let body = vehicleBody.physicsBody {
            let horizontalSpeed = abs(body.velocity.dx)
            let kmh = Int(horizontalSpeed * 3.6)
            speedLabel.text = "\(kmh / 200) km/h"
        }

        cameraNode.position = CGPoint(
            x: vehicleBody.position.x + 600,
            y: vehicleBody.position.y + 200
        )

        checkAndGenerateTerrain()
        updateCloudsParallax()
    }
}

// Small helpers for color
private extension UIColor {
    func withBrightness(_ factor: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: r * factor, green: g * factor, blue: b * factor, alpha: a)
    }

    static func fromHex(_ hex: String) -> UIColor {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }

        guard cleaned.count == 6 else { return .white }

        let rString = String(cleaned.prefix(2))
        let gString = String(cleaned.dropFirst(2).prefix(2))
        let bString = String(cleaned.dropFirst(4).prefix(2))

        let r = CGFloat(Int(rString, radix: 16) ?? 0) / 255.0
        let g = CGFloat(Int(gString, radix: 16) ?? 0) / 255.0
        let b = CGFloat(Int(bString, radix: 16) ?? 0) / 255.0

        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}
