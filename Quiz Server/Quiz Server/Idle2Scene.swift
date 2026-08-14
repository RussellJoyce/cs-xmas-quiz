//
//  Idle2Scene.swift
//  Quiz Server
//
//  Created by Ian Gray on 2025-10-26.
//  Copyright © 2025 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import SpriteKit

class Idle2Scene: QuizScene {
	
	var snowmojis = [SKEmitterNode]()
	private var characterQueue: [Int] = []
	let emoji = ["tree", "santa", "spaceinvader", "robot", "snowman",
				 "present", "floppydisk", "snowflake", "party", "crazy",
				 "ian", "richard", "nootnoot", "cold", "poop", "drunk"]
	
	var teamStrip: TeamStripNode!
	var snow1, snow2, snow3 : SKEmitterNode?
	
	private var timeSinceLastSpawn: TimeInterval = 0.0
	private var nextSpawnInterval: TimeInterval = 1.0
	private var lastUpdateTime: TimeInterval = 0
	private var fireworksTimer: Timer?
	
	override func buildScene() {
		let gradientImage = verticalGradientImage(size: self.size, colors: [NSColor.black, NSColor(calibratedRed: 0.10, green: 0, blue: 0.22, alpha: 1)])
		addBackground(texture: SKTexture(image: gradientImage))

		for emojiname in emoji {
			let snowmoji = addEmitter(named: "Snowmoji",
									  at: CGPoint(x: self.size.width / 2, y: self.size.height + 80),
									  zPosition: 2,
									  autoRemove: false) {
				$0.particleTexture = SKTexture(imageNamed: emojiname)
			}
			snowmojis.append(snowmoji)
		}
		
		let year = Calendar.current.component(.year, from: Date())
		addText(year: String(year))
		addLights()
		
		teamStrip = TeamStripNode(mode: .spotlight, width: self.size.width,
						timing: TeamStripNode.Timing(fadeIn: 0.15,
								popScale: 1.2, popDuration: 0.2,
								colourDelay: 0.15, colourDuration: 0.4, fadeDelay: 1.5, fadeOut: 1.5))
		self.addChild(teamStrip)
	}
	
	override func didMove(to view: SKView) {
		snow1 = addSnow(replacing: snow1, emitterNamed: "SnowBackground", zPosition: 1) {
			$0.particleBirthRate = 10
			$0.particleScale = 0.2
			$0.particleRotationSpeed = 1.0
		}
		snow2 = addSnow(replacing: snow2, emitterNamed: "Snow", zPosition: 20) {
			$0.particleBirthRate = 7
			$0.particleScale = 0.3
			$0.particleRotationSpeed = 1.0
		}
		snow3 = addSnow(replacing: snow3, emitterNamed: "Snow", zPosition: 24) {
			$0.particleBirthRate = 7
			$0.particleScale = 0.4
			$0.particleRotationSpeed = 1.0
		}

		//Fireworks re-arm themselves, so start them on entry and stop them in teardown
		fireworksTimer?.invalidate()
		addFireworks()
	}
	
	override func update(_ currentTime: TimeInterval) {
		guard !isPaused else { return }
		if lastUpdateTime == 0 {
			lastUpdateTime = currentTime
		}
		
		let delta = currentTime - lastUpdateTime
		lastUpdateTime = currentTime
		
		timeSinceLastSpawn += delta
		if timeSinceLastSpawn >= nextSpawnInterval {
			addCharacters()
			timeSinceLastSpawn = 0
			nextSpawnInterval = Double.random(in: 3.0 ... 6.0)
		}
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
		let mario = frames(basename: "mario", numFrames: 2)
		let sonic = frames(basename: "sonic", numFrames: 4)
		let sonicroll = frames(basename: "sonicroll", numFrames: 8)
		let threepwood = frames(basename: "threep", numFrames: 6)
		let yoshi = frames(basename: "yoshi", numFrames: 8)
		let kirby = frames(basename: "kirby", numFrames: 10)
		let megaman = frames(basename: "megaman", numFrames: 10)
		let duck = frames(basename: "duck", numFrames: 4)
		let link = frames(basename: "link", numFrames: 4)
		let pacman = frames(basename: "pacman", numFrames: 4)
		//let hornet = frames(basename: "hornet", numFrames: 8)
		let alucard = frames(basename: "alucard", numFrames: 16)
		let tails = frames(basename: "tails", numFrames: 2)
		
		let y = CGFloat.random(in: 50...500)
		let rv = Int.random(in: 0...1) == 0 //50/50 chance
		
		if characterQueue.isEmpty {
			characterQueue = Array(0...11).shuffled()
		}
		let charIndex = characterQueue.removeFirst()
		
		switch charIndex {
		case 0: addJumpingChar(y: y, reverse: rv, size: CGSize(width: 150, height: 150), duration: 7.0, textures: mario, jumptextures: [SKTexture(imageNamed: "mario2")], frametime: 0.2)
		case 1: addJumpingChar(y: y, reverse: rv, size: CGSize(width: 120, height: 120), duration: 3.5, textures: sonic, jumptextures: sonicroll, frametime: 0.1)
		case 2: addCharBasic(y: y, reverse: rv, size: CGSize(width: 120, height: 190), duration: 12.0, textures: threepwood, frametime: 0.1)
		case 3: addCharBasic(y: y, reverse: rv, size: CGSize(width: 100, height: 150), duration: 9.0, textures: yoshi, frametime: 0.1)
		case 4: addCharBasic(y: y, reverse: rv, size: CGSize(width: 100, height: 100), duration: 10.0, textures: kirby, frametime: 0.1)
		case 5: addCharBasic(y: y, reverse: rv, size: CGSize(width: 150, height: 150), duration: 7.5, textures: megaman, frametime: 0.1)
		case 6: addCharBasic(y: y, reverse: rv, size: CGSize(width: 120, height: 120), duration: 10.0, textures: duck, frametime: 0.1)
		case 7: addLemming(y: y, reverse: rv)
		case 8: addCharBasic(y: y, reverse: rv, size: CGSize(width: 120, height: 120), duration: 8.0, textures: link, frametime: 0.1)
		case 9: addCharBasic(y: y, reverse: rv, size: CGSize(width: 120, height: 120), duration: 8.0, textures: pacman, frametime: 0.15)
		case 10: addCharBasic(y: y+150, reverse: rv, size: CGSize(width: 160, height: 160), duration: 10.0, textures: tails, frametime: 0.15)
		case 11: addCharBasic(y: y, reverse: rv, size: CGSize(width: 176, height: 200), duration: 10.0, textures: alucard, frametime: 0.05)
		//case --: addCharBasic(y: y, reverse: rv, size: CGSize(width: 310, height: 200), duration: 6.0, textures: hornet, frametime: 0.1, flip: true)
		
		default:
			break
		}

		//Timer.scheduledTimer(withTimeInterval: Double.random(in: 3.0 ... 6.0), repeats: false) {_ in self.addCharacters()}
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
	
	func addJumpingChar(y: CGFloat, reverse: Bool, size : CGSize, duration: TimeInterval, textures: [SKTexture], jumptextures: [SKTexture], frametime: CGFloat) {
		let char = SKSpriteNode(imageNamed: "mario1")
		char.size = size
		char.zPosition = 1
		self.addChild(char)
		let walk = SKAction.repeatForever(SKAction.animate(with: textures, timePerFrame: frametime))
		let jumpanim = SKAction.repeatForever(SKAction.animate(with: jumptextures, timePerFrame: frametime))
		char.run(walk, withKey: "walk")

		// Animation distances and positions
		let jumpDistance: CGFloat = 450
		let jumpHeight: CGFloat = 220
		let leftEdge: CGFloat = -150
		let rightEdge: CGFloat = 2500
		let startX, jumpX, afterJumpStartX, endX: CGFloat
		
		if !reverse {
			startX = leftEdge
			endX = rightEdge
			jumpX = startX + CGFloat.random(in: 500...1200)
			afterJumpStartX = jumpX + jumpDistance
			char.xScale = 1
		} else {
			startX = rightEdge
			endX = leftEdge
			jumpX = startX - CGFloat.random(in: 500...1200)
			afterJumpStartX = jumpX - jumpDistance
			char.xScale = -1
		}
		
		char.position = CGPoint(x: startX, y: y)

		let totalDistance = abs(jumpX - startX) + jumpDistance + abs(endX - afterJumpStartX)
		let speed = totalDistance / CGFloat(duration) // points per second

		// Calculate durations
		let beforeJumpDuration = abs(jumpX - startX) / speed
		let jumpDuration = jumpDistance / speed
		let afterJumpDuration = abs(endX - afterJumpStartX) / speed
		
		let jumpPath = CGMutablePath()
		jumpPath.move(to: .zero)
		if !reverse {
			jumpPath.addQuadCurve(to: CGPoint(x: jumpDistance, y: 0), control: CGPoint(x: jumpDistance / 2, y: jumpHeight))
		} else {
			jumpPath.addQuadCurve(to: CGPoint(x: -jumpDistance, y: 0), control: CGPoint(x: -jumpDistance / 2, y: jumpHeight))
		}

		char.run(SKAction.sequence([
			SKAction.moveTo(x: jumpX, duration: beforeJumpDuration),
			SKAction.run { char.removeAction(forKey: "walk") },
			SKAction.run { char.run(jumpanim, withKey: "jump") },
			SKAction.follow(jumpPath, asOffset: true, orientToPath: false, duration: jumpDuration),
			SKAction.run { char.removeAction(forKey: "jump") },
			SKAction.run { char.run(walk, withKey: "walk") },
			SKAction.moveTo(x: endX, duration: afterJumpDuration),
			SKAction.removeFromParent()
		]))
	}
	
	func addLemmingExplosion(at position: CGPoint) {
		addEmitter(named: "lemming", at: position, zPosition: 30)
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
	
	func addFireworks() {
		let point = CGPoint(x: 20 + Int.random(in: 0..<1880), y: 700 + Int.random(in: 0..<360))
		addEmitter(named: "fireworks", at: point, zPosition: 1) {
			$0.numParticlesToEmit = 300
			$0.particleColorSequence = SKKeyframeSequence(
				keyframeValues: [SKColor(calibratedHue: CGFloat(Double.random(in: 0 ..< 1.0)), saturation: 1.0, brightness: 1.0, alpha: 1.0)], times: [0]
			)
		}
		fireworksTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 0.1 ... 2.0), repeats: false) {_ in self.addFireworks()}
	}
	
	override func reset() {
		QuizWebSocket.shared?.megamas()
		for node in snowmojis {
			node.particleBirthRate = 0
		}
		teamStrip.reset()
	}

	override func teardown() {
		fireworksTimer?.invalidate()
		fireworksTimer = nil
		//Force the next update() to re-baseline, rather than seeing one huge delta
		//and immediately spawning a character on re-entry
		lastUpdateTime = 0
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
	
	override func buzzerPressed(team: Int, type: BuzzerType, options: BuzzerOptions) {
		snowmojis[team % snowmojis.count].particleBirthRate = 20
		QuizWebSocket.shared?.setTargetTeam(team)
		teamStrip.trigger(team: team)

		DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
			self.snowmojis[team % self.snowmojis.count].particleBirthRate = 0
		}
	}
	

}

