//
//  IdleScene.swift
//  Quiz Server
//
//  Created by Russell Joyce on 16/11/2015.
//  Copyright © 2015 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import SpriteKit

class IdleScene: SKScene {
	
	var snowmojis = [SKEmitterNode]()
	var leds: QuizLeds?
	fileprivate var setUp = false
	let emoji = ["tree", "santa", "spaceinvader", "robot", "snowman", "present", "floppydisk", "snowflake", "mortarboard", "poop"]
	let clock = ClockNode()
	
	func setUpScene(size: CGSize, leds: QuizLeds?) {
		if setUp {
			return
		}
		setUp = true
		
		self.size = size
		self.leds = leds
		
		let date = Date()
		let calendar = Calendar.current
		let year = calendar.component(.year, from: date)
		
		let bgImageLayer1 = SKSpriteNode(imageNamed: "snowman-background-1")
		bgImageLayer1.position = self.centrePoint
		bgImageLayer1.size = self.size
		bgImageLayer1.zPosition = 0
		let bgImageLayer2 = SKSpriteNode(imageNamed: "snowman-background-2")
		bgImageLayer2.position = self.centrePoint
		bgImageLayer2.size = self.size
		bgImageLayer2.zPosition = 12
		let bgImageLayer3 = SKSpriteNode(imageNamed: "snowman-background-3")
		bgImageLayer3.position = self.centrePoint
		bgImageLayer3.size = self.size
		bgImageLayer3.zPosition = 21
		let bgImageLayer4 = SKSpriteNode(imageNamed: "snowman-background-4")
		bgImageLayer4.position = self.centrePoint
		bgImageLayer4.size = self.size
		bgImageLayer4.zPosition = 23
		
		let snow1 = SKEmitterNode(fileNamed: "SnowBackground")!
		snow1.position = CGPoint(x: self.size.width / 2, y: self.size.height + 16)
		snow1.zPosition = 1
		
		let snow2 = SKEmitterNode(fileNamed: "Snow")!
		snow2.position = CGPoint(x: self.size.width / 2, y: self.size.height + 16)
		snow2.particleBirthRate = 30
		snow2.particleScale = 0.2
		snow2.zPosition = 20
		
		let snow3 = SKEmitterNode(fileNamed: "Snow")!
		snow3.position = CGPoint(x: self.size.width / 2, y: self.size.height + 16)
		snow3.particleBirthRate = 10
		snow2.particleScale = 0.3
		snow3.zPosition = 22
		
		let snow4 = SKEmitterNode(fileNamed: "Snow")!
		snow4.position = CGPoint(x: self.size.width / 2, y: self.size.height + 16)
		snow4.particleBirthRate = 10
		snow2.particleScale = 0.4
		snow4.zPosition = 24
		
		for i in 0...9 {
			let snowmoji = SKEmitterNode(fileNamed: "Snowmoji")!
			snowmoji.particleTexture = SKTexture(imageNamed: emoji[i])
			snowmoji.position = CGPoint(x: self.size.width / 2, y: self.size.height + 80)
			snowmoji.zPosition = 2
			snowmojis.append(snowmoji)
		}
		
//		let quizSnow = SKEmitterNode(fileNamed: "Snowmoji")!
//		quizSnow.particleTexture = SKTexture(imageNamed: "quiz")
//		quizSnow.position = CGPoint(x: self.size.width / 2, y: self.size.height + 80)
//		quizSnow.zPosition = 11
//		quizSnow.particleRotationSpeed = 1.0
//		quizSnow.particleBirthRate = 0.04
		
		let ianSnow = SKEmitterNode(fileNamed: "Snowmoji")!
		ianSnow.particleTexture = SKTexture(imageNamed: "ian")
		ianSnow.position = CGPoint(x: self.size.width / 2, y: self.size.height + 80)
		ianSnow.zPosition = 11
		ianSnow.particleRotationSpeed = 1.0
		ianSnow.particleScale = 0.1
		ianSnow.particleScaleSpeed = 0
		ianSnow.particleScaleRange = 0.05
		ianSnow.particleBirthRate = 0.04
		
		let richardSnow = SKEmitterNode(fileNamed: "Snowmoji")!
		richardSnow.particleTexture = SKTexture(imageNamed: "richard")
		richardSnow.position = CGPoint(x: self.size.width / 2, y: self.size.height + 80)
		richardSnow.zPosition = 11
		richardSnow.particleRotationSpeed = 1.0
		richardSnow.particleBirthRate = 0.04
		
		let eggSnow = SKEmitterNode(fileNamed: "Snowmoji")!
		eggSnow.particleTexture = SKTexture(imageNamed: "egg")
		eggSnow.position = CGPoint(x: self.size.width / 2, y: self.size.height + 80)
		eggSnow.zPosition = 11
		eggSnow.particleRotationSpeed = 1.0
		eggSnow.particleBirthRate = 0.006
		
		let ooSnow = SKEmitterNode(fileNamed: "Snowmoji")!
		ooSnow.particleTexture = SKTexture(imageNamed: "oo")
		ooSnow.position = CGPoint(x: self.size.width / 2, y: self.size.height + 80)
		ooSnow.zPosition = 11
		ooSnow.particleRotationSpeed = 2.0
		ooSnow.particleBirthRate = 0.03
		
		let nootSnow = SKEmitterNode(fileNamed: "Snowmoji")!
		nootSnow.particleTexture = SKTexture(imageNamed: "nootnoot")
		nootSnow.position = CGPoint(x: self.size.width / 2, y: self.size.height + 80)
		nootSnow.zPosition = 11
		nootSnow.particleRotationSpeed = 1.0
		nootSnow.particleBirthRate = 0.009
		
		let text1 = SKLabelNode(fontNamed: "Neutra Display Titling")
		text1.text = "Computer Science"
		text1.fontSize = 140
		text1.horizontalAlignmentMode = .center
		text1.verticalAlignmentMode = .center
		text1.position = CGPoint(x: 0, y: 72)
		text1.zPosition = 50
		text1.fontColor = NSColor.white
		
		let text2 = SKLabelNode(fontNamed: "Neutra Display Titling")
		text2.text = "Christmas Quiz \(year)!"
		text2.fontSize = 140
		text2.horizontalAlignmentMode = .center
		text2.verticalAlignmentMode = .center
		text2.position = CGPoint(x: 0, y: -85)
		text2.zPosition = 50
		text2.fontColor = NSColor.white
		
		let text = SKNode()
		text.position = CGPoint(x: 1100, y: 900)
		text.zPosition = 50
		text.addChild(text1)
		text.addChild(text2)
		
		let shadowText1 = SKLabelNode(fontNamed: "Neutra Display Titling")
		shadowText1.text = "Computer Science"
		shadowText1.fontSize = 140
		shadowText1.fontColor = NSColor(white: 0.0, alpha: 0.8)
		shadowText1.horizontalAlignmentMode = .center
		shadowText1.verticalAlignmentMode = .center
		shadowText1.position = CGPoint(x: 0, y: 72)
		shadowText1.zPosition = 49
		
		let shadowText2 = SKLabelNode(fontNamed: "Neutra Display Titling")
		shadowText2.text = "Christmas Quiz \(year)!"
		shadowText2.fontSize = 140
		shadowText2.fontColor = NSColor(white: 0.0, alpha: 0.8)
		shadowText2.horizontalAlignmentMode = .center
		shadowText2.verticalAlignmentMode = .center
		shadowText2.position = CGPoint(x: 0, y: -85)
		shadowText2.zPosition = 49
		
		let textShadow = SKEffectNode()
		textShadow.shouldEnableEffects = true
		textShadow.shouldRasterize = true
		textShadow.zPosition = 49
		let filter = CIFilter(name: "CIGaussianBlur")
		filter?.setDefaults()
		filter?.setValue(25, forKey: "inputRadius")
		textShadow.filter = filter;
		textShadow.position = CGPoint(x: 1100, y: 900)
		textShadow.addChild(shadowText1)
		textShadow.addChild(shadowText2)
		
//		let lights = SKSpriteNode(imageNamed: "lights")
//		lights.position = CGPoint(x: 960, y: 985)
//		lights.zPosition = 25
//		var lightsTextures = [SKTexture]()
//		for i in 1...4 {
//			lightsTextures.append(SKTexture(imageNamed: "lights\(i)"))
//		}
//		let lightsAction = SKAction.repeatForever(SKAction.animate(with: lightsTextures, timePerFrame: 1.0))
//		lights.run(lightsAction)
		
		clock.position = CGPoint(x: 1450, y: 260)
		clock.zPosition = 50
		clock.updateTime(animated: false)
		
		Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { (timer) in
			self.clock.updateTime(animated: true)
		}
		
		for node in snowmojis {
			self.addChild(node)
		}
		self.addChild(bgImageLayer1)
		self.addChild(bgImageLayer2)
		self.addChild(bgImageLayer3)
		self.addChild(bgImageLayer4)
		self.addChild(snow1)
		self.addChild(snow2)
		self.addChild(snow3)
		self.addChild(snow4)
		self.addChild(text)
		self.addChild(textShadow)
//		self.addChild(lights)
//		self.addChild(quizSnow)
		self.addChild(ianSnow)
		self.addChild(richardSnow)
		self.addChild(eggSnow)
		self.addChild(ooSnow)
		self.addChild(nootSnow)
		self.addChild(clock)
	}
	
	func reset() {
		leds?.stringAnimation(animation: 2)
		for node in snowmojis {
			node.particleBirthRate = 0
		}
	}
	
	func buzzerPressed(team: Int, type: BuzzerType) {
		snowmojis[team].particleBirthRate = 20
	}
	
	func buzzerReleased(team: Int, type: BuzzerType) {
		snowmojis[team].particleBirthRate = 0
	}
}
