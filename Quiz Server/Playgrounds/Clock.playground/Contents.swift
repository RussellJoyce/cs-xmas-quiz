//: A SpriteKit based Playground

import PlaygroundSupport
import SpriteKit

class ClockNode: SKNode {
	
	var hours = 0.0
	var mins = 0.0
	var secs = 0.0
	
	private let hourHand = SKShapeNode()
	private let minHand = SKShapeNode()
	private let secHand = SKShapeNode()
	
	override init() {
		super.init()
		setUp()
	}
	
	required init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
		setUp()
	}
	
	func setUp() {
		let radius = CGFloat(200)
		
		let circle = SKShapeNode(circleOfRadius: radius)
		circle.strokeColor = .black
		circle.lineWidth = 3
		circle.alpha = 1.0
//		self.addChild(circle)
		
		let centreCircle = SKShapeNode(circleOfRadius: 3)
		centreCircle.strokeColor = .red
		centreCircle.fillColor = .white
		centreCircle.lineWidth = 1
		centreCircle.alpha = 1.0
		centreCircle.zPosition = 10
		self.addChild(centreCircle)
		
		//		for i in 0..<12 {
		//			let line = SKShapeNode()
		//			let path = CGMutablePath()
		//			let x = cos(CGFloat(i) * CGFloat.pi/6.0)
		//			let y = sin(CGFloat(i) * CGFloat.pi/6.0)
		//
		//			let length = (i % 3 == 0) ? CGFloat(30) : CGFloat(15)
		//			let innerRadius = radius - length
		//
		//			path.addLines(between: [CGPoint(x: x * innerRadius, y: y * innerRadius), CGPoint(x: x * radius, y: y * radius)])
		//			line.path = path
		//			line.strokeColor = .black
		//			line.lineWidth = 1.0
		//			self.addChild(line)
		//		}
		
		for i in 0..<60 {
			let line = SKShapeNode()
			let path = CGMutablePath()
			let x = cos((CGFloat(i) * CGFloat.pi) / 30.0)
			let y = sin((CGFloat(i) * CGFloat.pi) / 30.0)
			
			let length = (i % 5 == 0) ? (i % 15 == 0) ? CGFloat(30) : CGFloat(25) : CGFloat(10)
			let thickness = (i % 5 == 0) ? (i % 15 == 0) ? CGFloat(2.0) : CGFloat(2.0) : CGFloat(1.0)
			let innerRadius = radius - length
			
			path.addLines(between: [CGPoint(x: x * innerRadius, y: y * innerRadius), CGPoint(x: x * radius, y: y * radius)])
			line.path = path
			line.strokeColor = .black
			line.lineWidth = thickness
			self.addChild(line)
		}
		
		let hourHandPath = CGMutablePath()
		let hourHandLength = radius * 0.5
		hourHandPath.addLines(between: [CGPoint(x: 0.0, y: hourHandLength * -0.15), CGPoint(x: 0.0, y: hourHandLength)])
		hourHand.path = hourHandPath
		hourHand.strokeColor = .black
		hourHand.lineWidth = 5.0
		self.addChild(hourHand)
		
		let minHandPath = CGMutablePath()
		let minHandLength = radius * 0.7
		minHandPath.addLines(between: [CGPoint(x: 0.0, y: minHandLength * -0.15), CGPoint(x: 0.0, y: minHandLength)])
		minHand.path = minHandPath
		minHand.strokeColor = .black
		minHand.lineWidth = 3.0
		self.addChild(minHand)
		
		let secHandPath = CGMutablePath()
		let secHandLength = radius * 0.85
		secHandPath.addLines(between: [CGPoint(x: 0.0, y: secHandLength * -0.2), CGPoint(x: 0.0, y: secHandLength)])
		secHand.path = secHandPath
		secHand.strokeColor = .red
		secHand.lineWidth = 1.0
		let secHandCircle = SKShapeNode(circleOfRadius: 7)
		secHandCircle.fillColor = .red
		secHandCircle.strokeColor = .red
		secHandCircle.lineWidth = 1.0
		secHandCircle.position = CGPoint(x: 0.0, y: secHandLength * -0.2)
		secHand.addChild(secHandCircle)
		self.addChild(secHand)
	}
	
	func setTime(hours: Double, mins: Double, secs: Double, animated: Bool = false) {
		self.hours = hours
		self.mins = mins
		self.secs = secs
		
		let hoursAngle = ((12.0 - CGFloat(hours)) * CGFloat.pi) / 6.0
		let minsAngle = ((60.0 - CGFloat(mins)) * CGFloat.pi) / 30.0
		let secsAngle = ((60.0 - CGFloat(secs)) * CGFloat.pi) / 30.0
		
		if (animated) {
			let minsAction = SKAction.rotate(toAngle: minsAngle, duration: 0.5, shortestUnitArc: true)
			let secsAction = SKAction.rotate(toAngle: secsAngle, duration: 0.5, shortestUnitArc: true)
			minsAction.timingMode = .easeInEaseOut
			secsAction.timingMode = .easeInEaseOut
			minHand.run(minsAction)
			secHand.run(secsAction)
		}
		else {
			minHand.zRotation = minsAngle
			secHand.zRotation = secsAngle
		}
		
		hourHand.zRotation = hoursAngle
	}
	
	func updateTime(animated: Bool = false) {
		let date = Date()
		let calendar = Calendar.current
		let hour = calendar.component(.hour, from: date)
		let minute = calendar.component(.minute, from: date)
		let second = calendar.component(.second, from: date)
		
		let s = Double(second)
		let m = Double(minute) + s / 60.0
		let h = Double(hour) + m / 60.0
		
		setTime(hours: h, mins: m, secs: s, animated: animated)
	}
}


let sceneView = SKView(frame: CGRect(x:0 , y:0, width: 600, height: 600))
let scene = SKScene(size: CGSize(width: 600, height: 600))

scene.backgroundColor = .white

let centre = CGPoint(x: 300, y: 300)

let clock = ClockNode()
clock.position = centre
scene.addChild(clock)

// Present the scene
sceneView.presentScene(scene)

PlaygroundSupport.PlaygroundPage.current.liveView = sceneView


clock.updateTime(animated: false)

let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { (timer) in
	clock.updateTime(animated: true)
}

//let action = SKAction.customAction(withDuration: 1.0) { (node, float) in
//	let date = Date()
//	let calendar = Calendar.current
//	let hour = calendar.component(.hour, from: date)
//	let minute = calendar.component(.minute, from: date)
//	let second = calendar.component(.second, from: date)
//
//	s = Double(second)
//	m = Double(minute) + s / 60.0
//	h = Double(hour) + m / 60.0
//
//	clock.setTime(hours: h, mins: m, secs: s)
//}
//clock.run(action)
