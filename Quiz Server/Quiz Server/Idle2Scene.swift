//
//  Idle2Scene.swift
//  Quiz Server
//
//  Created by Ian Gray on 2025-10-26.
//  Copyright © 2025 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import SpriteKit
import Starscream

class Idle2Scene: SKScene {
	
	var snowmojis = [SKEmitterNode]()
	fileprivate var setUp = false
	var webSocket: WebSocket?
	private var characterQueue: [Int] = []
	let emoji = ["tree", "santa", "spaceinvader", "robot", "snowman",
				 "present", "floppydisk", "snowflake", "party", "crazy",
				 "ian", "richard", "nootnoot", "cold", "poop", "drunk"]
	
	func setUpScene(size: CGSize, websocket: WebSocket?) {
		if setUp {
			return
		}
		setUp = true
		
		self.size = size
		self.webSocket = websocket;

		let gradientImage = verticalGradientImage(size: self.size, colors: [NSColor.black, NSColor(calibratedRed: 0.10, green: 0, blue: 0.22, alpha: 1)])
		let bgTexture = SKTexture(image: gradientImage)
		let bgImageLayer1 = SKSpriteNode(texture: bgTexture)
		bgImageLayer1.position = self.centrePoint
		bgImageLayer1.size = self.size
		bgImageLayer1.zPosition = 0
		self.addChild(bgImageLayer1)
		
		addSnow(emittername: "SnowBackground", birthRate: 8, particleScale: 0.2, zPosition: 1)
		addSnow(emittername: "Snow", birthRate: 5, particleScale: 0.3, zPosition: 20)
		addSnow(emittername: "Snow", birthRate: 5, particleScale: 0.4, zPosition: 24)
		
		for emojiname in emoji {
			let snowmoji = SKEmitterNode(fileNamed: "Snowmoji")!
			snowmoji.particleTexture = SKTexture(imageNamed: emojiname)
			snowmoji.position = CGPoint(x: self.size.width / 2, y: self.size.height + 80)
			snowmoji.zPosition = 2
			snowmojis.append(snowmoji)
			self.addChild(snowmoji)
		}
		
		/*addSnow(emittername: "Snowmoji", birthRate: 0.042, particleScale: 0.4, zPosition: 11, particleTexture: "ian")
		addSnow(emittername: "Snowmoji", birthRate: 0.036, particleScale: 0.4, zPosition: 11, particleTexture: "richard")
		addSnow(emittername: "Snowmoji", birthRate: 0.018, particleScale: 0.4, zPosition: 11, particleTexture: "oo")
		addSnow(emittername: "Snowmoji", birthRate: 0.022, particleScale: 0.4, zPosition: 11, particleTexture: "nootnoot")
		addSnow(emittername: "Snowmoji", birthRate: 0.031, particleScale: 0.4, zPosition: 11, particleTexture: "cold")
		addSnow(emittername: "Snowmoji", birthRate: 0.005, particleScale: 0.4, zPosition: 11, particleTexture: "poop")
		addSnow(emittername: "Snowmoji", birthRate: 0.02, particleScale: 0.4, zPosition: 11, particleTexture: "drunk")*/
		
		let year = Calendar.current.component(.year, from: Date())
		addText(year: String(year))
		addLights()
		firework()
		addCharacters()
	}
	
	func addSnow(emittername : String, birthRate : CGFloat, particleScale : CGFloat, zPosition : CGFloat, particleTexture : String? = nil) {
		let p = SKEmitterNode(fileNamed: emittername)!
		p.position = CGPoint(x: self.size.width / 2, y: self.size.height + 16)
		p.particleBirthRate = birthRate
		p.particleScale = particleScale
		p.zPosition = zPosition
		p.particleRotationSpeed = 1.0
		if let pt = particleTexture {
			p.particleTexture = SKTexture(imageNamed: pt)
		}
		self.addChild(p)
	}

	func addText(year : String) {
		func makeLabel(text : String, fontSize : CGFloat, x : CGFloat, y : CGFloat) -> (SKLabelNode, SKLabelNode) {
			let lb = SKLabelNode(fontNamed: "Neutra Display Titling")
			lb.text = text
			lb.fontSize = fontSize
			lb.horizontalAlignmentMode = .center
			lb.verticalAlignmentMode = .center
			lb.position = CGPoint(x: x, y: y)
			lb.zPosition = 50
			lb.fontColor = NSColor.white
			
			let shadow = SKLabelNode(fontNamed: "Neutra Display Titling")
			shadow.text = text
			shadow.fontSize = fontSize
			shadow.fontColor = NSColor(white: 0.0, alpha: 1)
			shadow.horizontalAlignmentMode = .center
			shadow.verticalAlignmentMode = .center
			shadow.position = CGPoint(x: x, y: y - 1)
			shadow.zPosition = 49
			return (lb, shadow)
		}
		
		let (text1, shadow1) = makeLabel(text: "Computer Science", fontSize: 140, x: 0, y: 72)
		let (text2, shadow2) = makeLabel(text: "Christmas Quiz \(year)!", fontSize: 140, x: 0, y: -65)
		let text = SKNode()
		text.position = CGPoint(x: 950, y: 800)
		text.zPosition = 50
		text.addChild(text1)
		text.addChild(text2)
		
		let textShadow = SKEffectNode()
		textShadow.shouldEnableEffects = true
		textShadow.shouldRasterize = true
		textShadow.zPosition = 49
		let filter = CIFilter(name: "CIGaussianBlur")
		filter?.setDefaults()
		filter?.setValue(18, forKey: "inputRadius")
		textShadow.filter = filter;
		textShadow.position = CGPoint(x: 950, y: 800)
		textShadow.addChild(shadow1)
		textShadow.addChild(shadow2)
		
		self.addChild(text)
		self.addChild(textShadow)
	}

	func frames(basename : String, numFrames : Int) -> [SKTexture] {
		var frames: [SKTexture] = []
		for i in 1...numFrames {
			frames.append(SKTexture(imageNamed: "\(basename)\(i)"))
		}
		return frames
	}
	
	func addCharacters() {
		let sonic = frames(basename: "sonic", numFrames: 4)
		let sonicroll = frames(basename: "sonicroll", numFrames: 8)
		let threepwood = frames(basename: "threep", numFrames: 6)
		let yoshi = frames(basename: "yoshi", numFrames: 8)
		let kirby = frames(basename: "kirby", numFrames: 10)
		let megaman = frames(basename: "megaman", numFrames: 10)
		let duck = frames(basename: "duck", numFrames: 4)
		let link = frames(basename: "link", numFrames: 4)
		let pacman = frames(basename: "pacman", numFrames: 4)
		let hornet = frames(basename: "hornet", numFrames: 8)
		let alucard = frames(basename: "alucard", numFrames: 16)
		let tails = frames(basename: "tails", numFrames: 2)
		
		let y = CGFloat.random(in: 50...500)
		let rv = Int.random(in: 0...1) == 0 //50/50 chance
		
		if characterQueue.isEmpty {
			characterQueue = Array(0...12).shuffled()
		}
		let charIndex = characterQueue.removeFirst()
		
		switch charIndex {
		case 0: addMario(y: y)
		case 1: addCharBasic(y: y, reverse: rv, size: CGSize(width: 120, height: 120), duration: 3.5, textures: sonic, frametime: 0.1)
		case 2: addCharBasic(y: y, reverse: rv, size: CGSize(width: 120, height: 190), duration: 12.0, textures: threepwood, frametime: 0.1)
		case 3: addCharBasic(y: y, reverse: rv, size: CGSize(width: 100, height: 150), duration: 9.0, textures: yoshi, frametime: 0.1)
		case 4: addCharBasic(y: y, reverse: rv, size: CGSize(width: 100, height: 100), duration: 10.0, textures: kirby, frametime: 0.1)
		case 5: addCharBasic(y: y, reverse: rv, size: CGSize(width: 150, height: 150), duration: 7.5, textures: megaman, frametime: 0.1)
		case 6: addCharBasic(y: y, reverse: rv, size: CGSize(width: 120, height: 120), duration: 10.0, textures: duck, frametime: 0.1)
		case 7: addLemming(y: y, reverse: rv)
		case 8: addCharBasic(y: y, reverse: rv, size: CGSize(width: 120, height: 120), duration: 8.0, textures: link, frametime: 0.1)
		case 9: addCharBasic(y: y, reverse: rv, size: CGSize(width: 120, height: 120), duration: 8.0, textures: pacman, frametime: 0.15)
		case 10: addCharBasic(y: y+150, reverse: rv, size: CGSize(width: 160, height: 160), duration: 10.0, textures: tails, frametime: 0.15)
		//case 10: addCharBasic(y: y, reverse: rv, size: CGSize(width: 310, height: 200), duration: 6.0, textures: hornet, frametime: 0.1, flip: true)
		case 11: addCharBasic(y: y, reverse: rv, size: CGSize(width: 176, height: 200), duration: 10.0, textures: alucard, frametime: 0.05)
		
		default:
			break
		}

		Timer.scheduledTimer(withTimeInterval: Double.random(in: 3.0 ... 6.0), repeats: false) {_ in self.addCharacters()}
	}

	func addCharBasic(y: CGFloat, reverse: Bool, size : CGSize, duration: TimeInterval, textures: [SKTexture], frametime: CGFloat, flip: Bool = false) {
		let char = SKSpriteNode(imageNamed: "sonic1")
		char.size = size
		char.zPosition = 3
		let walk = SKAction.repeatForever(SKAction.animate(with: textures, timePerFrame: frametime))
		char.run(walk)

		let xfrom = CGFloat(reverse ? 2500 : -150)
		let xto = CGFloat(reverse ? -150 : 2500)
		var xscale = CGFloat(reverse ? -1 : 1)
		if flip {
			xscale = xscale * -1
		}
		
		char.position = CGPoint(x: xfrom, y: y)
		char.xScale = xscale
		
		let sequence = SKAction.sequence([SKAction.moveTo(x: xto, duration: duration), SKAction.removeFromParent()])
		char.run(sequence)
		self.addChild(char)
	}
	
	func addMario(y: CGFloat) {
		let mario = SKSpriteNode(imageNamed: "mario1")
		mario.position = CGPoint(x: -150, y: y)
		mario.size = CGSize(width: 150, height: 150)
		mario.zPosition = 1
		self.addChild(mario)
		let walk = SKAction.repeatForever(SKAction.animate(with: [SKTexture(imageNamed: "mario1"), SKTexture(imageNamed: "mario2")], timePerFrame: 0.2))
		mario.run(walk, withKey: "walk")

		// Animation distances
		let startX: CGFloat = -150
		let jumpX = CGFloat.random(in: 500...1200)
		let jumpDistance: CGFloat = 350
		let endX: CGFloat = 2500
		let afterJumpStartX = jumpX + jumpDistance
		let totalDistance = abs(jumpX - startX) + jumpDistance + abs(endX - afterJumpStartX)
		let totalDuration: TimeInterval = 9.0 // Choose the overall speed
		let speed = totalDistance / CGFloat(totalDuration) // points per second

		// Calculate durations
		let beforeJumpDuration = abs(jumpX - startX) / speed
		let jumpDuration = jumpDistance / speed
		let afterJumpDuration = abs(endX - afterJumpStartX) / speed

		let initialMove = SKAction.moveTo(x: jumpX, duration: beforeJumpDuration)
		let removeWalk = SKAction.run { mario.removeAction(forKey: "walk") }
		let jumpHeight: CGFloat = 220
		let jumpPath = CGMutablePath()
		jumpPath.move(to: .zero)
		jumpPath.addQuadCurve(to: CGPoint(x: jumpDistance, y: 0), control: CGPoint(x: jumpDistance/2, y: jumpHeight))
		let jump = SKAction.follow(jumpPath, asOffset: true, orientToPath: false, duration: jumpDuration)
		let restartWalk = SKAction.run { mario.run(walk, withKey: "walk") }
		let afterJumpMove = SKAction.moveTo(x: endX, duration: afterJumpDuration)
		let remove = SKAction.removeFromParent()
		let sequence = SKAction.sequence([initialMove, removeWalk, jump, restartWalk, afterJumpMove, remove])
		mario.run(sequence)
	}
	
	func addLemmingExplosion(at position: CGPoint) {
		if let emitter = SKEmitterNode(fileNamed: "lemming") {
			emitter.position = position
			emitter.zPosition = 30
			self.addChild(emitter)
			emitter.removeWhenDone()
		}
	}
	
	func addLemming(y: CGFloat, reverse: Bool) {
		let frames = frames(basename: "lemming", numFrames: 8)
		let char = SKSpriteNode(imageNamed: "lemming1")
		char.size = CGSize(width: 70, height: 70)
		char.zPosition = 3
		let walk = SKAction.repeatForever(SKAction.animate(with: frames, timePerFrame: 0.1))
		char.run(walk)

		let xfrom = CGFloat(reverse ? 2500 : -150)
		let xto = CGFloat(reverse ? 500 : 1100)
		let xscale = CGFloat(reverse ? -1 : 1)
		
		let explode = SKAction.run { [weak self, weak char] in
			if let self = self, let char = char {
				self.addLemmingExplosion(at: char.position)
			}
		}
		
		char.position = CGPoint(x: xfrom, y: y)
		char.xScale = xscale
		let sequence = SKAction.sequence([SKAction.moveTo(x: xto, duration: 11), explode, SKAction.removeFromParent()])
		char.run(sequence)
		self.addChild(char)
	}
	
	func addLights() {
		let lights = SKSpriteNode(imageNamed: "lights")
		lights.position = CGPoint(x: 960, y: 985)
		lights.zPosition = 25
		var lightsTextures = [SKTexture]()
		for i in 1...4 {
			lightsTextures.append(SKTexture(imageNamed: "lights\(i)"))
		}
		let lightsAction = SKAction.repeatForever(SKAction.animate(with: lightsTextures, timePerFrame: 1.0))
		lights.run(lightsAction)
		self.addChild(lights)	
	}
	
	func firework() {
		let parts = SKEmitterNode(fileNamed: "fireworks")!
		parts.position = CGPoint(x: 20 + Int.random(in: 0..<1880), y: 700 + Int.random(in: 0..<360))
		parts.zPosition = 1
		parts.numParticlesToEmit = 300
		parts.particleColorSequence = SKKeyframeSequence(
			keyframeValues: [SKColor(calibratedHue: CGFloat(Double.random(in: 0 ..< 1.0)), saturation: 1.0, brightness: 1.0, alpha: 1.0)], times: [0]
		)
		parts.removeWhenDone()
		self.addChild(parts)
		Timer.scheduledTimer(withTimeInterval: Double.random(in: 0.1 ... 2.0), repeats: false) {_ in self.firework()}
	}
	
	func reset() {
		webSocket?.megamas()
		for node in snowmojis {
			node.particleBirthRate = 0
		}
	}
	
	func verticalGradientImage(size: CGSize, colors: [NSColor]) -> NSImage {
		let image = NSImage(size: size)
		image.lockFocus()
		guard let context = NSGraphicsContext.current?.cgContext else { return image }
		let colorSpace = CGColorSpaceCreateDeviceRGB()
		let cgColors = colors.map { $0.cgColor } as CFArray
		let gradient = CGGradient(colorsSpace: colorSpace, colors: cgColors, locations: [0.0, 1.0])!
		context.drawLinearGradient(
			gradient,
			start: CGPoint(x: size.width/2, y: size.height),
			end: CGPoint(x: size.width/2, y: 0),
			options: []
		)
		image.unlockFocus()
		return image
	}
	
	func buzzerPressed(team: Int, type: BuzzerType) {
		snowmojis[team % snowmojis.count].particleBirthRate = 20
	}
	
	func buzzerReleased(team: Int, type: BuzzerType) {
		snowmojis[team % snowmojis.count].particleBirthRate = 0
	}
}

