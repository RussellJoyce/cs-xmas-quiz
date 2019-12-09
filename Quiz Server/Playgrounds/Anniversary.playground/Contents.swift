//: A SpriteKit based Playground

import PlaygroundSupport
import SpriteKit

class TenthAnniversary: SKNode {

	override init() {
		super.init()
		setUp()
	}
	
	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		setUp()
	}
	
	func setUp() {
        let text1 = SKLabelNode(fontNamed: "Snowtop Caps")
        text1.text = "10th"
        text1.fontSize = 180
        text1.horizontalAlignmentMode = .center
        text1.verticalAlignmentMode = .bottom
        text1.position = CGPoint(x: 0, y: 60)
        text1.zPosition = 50
        text1.fontColor = NSColor.black
        
        let text2 = SKLabelNode(fontNamed: "Snowtop Caps")
        text2.text = "Anniversary"
        text2.fontSize = 98
        text2.horizontalAlignmentMode = .center
        text2.verticalAlignmentMode = .center
        text2.position = CGPoint(x: 0, y: 0)
        text2.zPosition = 50
        text2.fontColor = NSColor.black
        
        let text3 = SKLabelNode(fontNamed: "Snowtop Caps")
        text3.text = "Special Edition"
        text3.fontSize = 80
        text3.horizontalAlignmentMode = .center
        text3.verticalAlignmentMode = .top
        text3.position = CGPoint(x: 0, y: -60)
        text3.zPosition = 50
        text3.fontColor = NSColor.black
        
        let text = SKNode()
        text.position = CGPoint(x: 0, y: 0)
        text.zPosition = 50
        text.addChild(text1)
        text.addChild(text2)
        text.addChild(text3)
        
        let shadowText1 = SKLabelNode(fontNamed: "Snowtop Caps")
        shadowText1.text = "10th"
        shadowText1.fontSize = 180
        shadowText1.fontColor = NSColor(white: 1.0, alpha: 0.95)
        shadowText1.horizontalAlignmentMode = .center
        shadowText1.verticalAlignmentMode = .bottom
        shadowText1.position = CGPoint(x: 0, y: 60)
        shadowText1.zPosition = 49
        
        let shadowText2 = SKLabelNode(fontNamed: "Snowtop Caps")
        shadowText2.text = "Anniversary"
        shadowText2.fontSize = 98
        shadowText2.fontColor = NSColor(white: 1.0, alpha: 0.95)
        shadowText2.horizontalAlignmentMode = .center
        shadowText2.verticalAlignmentMode = .center
        shadowText2.position = CGPoint(x: 0, y: 0)
        shadowText2.zPosition = 49
        
        let shadowText3 = SKLabelNode(fontNamed: "Snowtop Caps")
        shadowText3.text = "Special Edition"
        shadowText3.fontSize = 80
        shadowText3.fontColor = NSColor(white: 1.0, alpha: 0.95)
        shadowText3.horizontalAlignmentMode = .center
        shadowText3.verticalAlignmentMode = .top
        shadowText3.position = CGPoint(x: 0, y: -60)
        shadowText3.zPosition = 49
        
        let textShadow = SKEffectNode()
        textShadow.shouldEnableEffects = true
        textShadow.shouldRasterize = true
        textShadow.zPosition = 49
        let filter = CIFilter(name: "CIGaussianBlur")
        filter?.setDefaults()
        filter?.setValue(10, forKey: "inputRadius")
        textShadow.filter = filter;
        textShadow.position = CGPoint(x: 0, y: 0)
        textShadow.addChild(shadowText1)
        textShadow.addChild(shadowText2)
        textShadow.addChild(shadowText3)
        
        let sparksLeft = SKEmitterNode(fileNamed: "SparksLeft")!
        sparksLeft.position = CGPoint(x: -180, y: 130)
        sparksLeft.zPosition = 1
        
        let sparksRight = SKEmitterNode(fileNamed: "SparksLeft")!
        sparksRight.emissionAngle = 30.0 * .pi/180.0
        sparksRight.position = CGPoint(x: 180, y: 130)
        sparksRight.zPosition = 1
        
        self.addChild(text)
        self.addChild(textShadow)
        self.addChild(sparksLeft)
        self.addChild(sparksRight)
	}
}


let sceneView = SKView(frame: CGRect(x:0 , y:0, width: 1800, height: 800))
let scene = SKScene(size: CGSize(width: sceneView.frame.width, height: sceneView.frame.height))

scene.backgroundColor = NSColor(white: 0.9, alpha: 1.0)

let centre = CGPoint(x: sceneView.frame.width / 2, y: sceneView.frame.height / 2)

let node = TenthAnniversary()
node.position = centre
scene.addChild(node)

// Present the scene
sceneView.presentScene(scene)

PlaygroundSupport.PlaygroundPage.current.liveView = sceneView
