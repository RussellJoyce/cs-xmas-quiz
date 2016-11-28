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
	
	let snow = SKEmitterNode(fileNamed: "Snow")!
	var snowmojis = [SKEmitterNode]()
	var leds: QuizLeds?
	fileprivate var setUp = false
	let emoji = ["tree", "santa", "snowcloud", "mortarboard", "snowman", "snowflake", "floppydisk", "robot", "present", "poop"]
	
	func setUpScene(size: CGSize, leds: QuizLeds?) {
		if setUp {
			return
		}
		setUp = true
		
		self.size = size
		self.leds = leds
		
		let bgImage = SKSpriteNode(imageNamed: "background1")
		bgImage.position = self.centrePoint
		bgImage.size = self.size
		bgImage.zPosition = 0
		let snowmenImage = SKSpriteNode(imageNamed: "background1-snowmen")
		snowmenImage.position = self.centrePoint
		snowmenImage.size = self.size
		snowmenImage.zPosition = 12
		let snowImage = SKSpriteNode(imageNamed: "background1-snow")
		snowImage.position = self.centrePoint
		snowImage.size = self.size
		snowImage.zPosition = 14
		
		snow.position = CGPoint(x: self.size.width / 2, y: self.size.height + 16)
		snow.particleBirthRate = 40
		snow.zPosition = 13
		
		for i in 0...9 {
			let snowmoji = SKEmitterNode(fileNamed: "Snowmoji")!
			snowmoji.particleTexture = SKTexture(imageNamed: emoji[i])
			snowmoji.position = CGPoint(x: self.size.width / 2, y: self.size.height + 32)
			snowmoji.zPosition = CGFloat(i + 1)
			snowmojis.append(snowmoji)
		}
		
		let garySnow = SKEmitterNode(fileNamed: "Snowmoji")!
		garySnow.particleTexture = SKTexture(imageNamed: "gary")
		garySnow.position = CGPoint(x: self.size.width / 2, y: self.size.height + 32)
		garySnow.zPosition = 11
		garySnow.particleRotationSpeed = 1.0
		garySnow.particleBirthRate = 0.05
		
		let eggSnow = SKEmitterNode(fileNamed: "Snowmoji")!
		eggSnow.particleTexture = SKTexture(imageNamed: "egg")
		eggSnow.position = CGPoint(x: self.size.width / 2, y: self.size.height + 32)
		eggSnow.zPosition = 11
		eggSnow.particleRotationSpeed = 2.0
		eggSnow.particleBirthRate = 0.01
		
		let text1 = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		text1.text = "Computer Science"
		text1.fontSize = 140
		text1.horizontalAlignmentMode = .center
		text1.verticalAlignmentMode = .center
		text1.position = CGPoint(x: 0, y: 72)
		text1.zPosition = 17
		text1.fontColor = NSColor.white
		
		let text2 = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		text2.text = "Christmas Quiz 2016!"
		text2.fontSize = 140
		text2.horizontalAlignmentMode = .center
		text2.verticalAlignmentMode = .center
		text2.position = CGPoint(x: 0, y: -85)
		text2.zPosition = 18
		text2.fontColor = NSColor.white
		
		let text = SKNode()
		text.position = CGPoint(x: 960, y: 820)
		text.zPosition = 17
		text.addChild(text1)
		text.addChild(text2)
		
		let shadowText1 = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		shadowText1.text = "Computer Science"
		shadowText1.fontSize = 140
		shadowText1.fontColor = NSColor(white: 0.0, alpha: 0.8)
		shadowText1.horizontalAlignmentMode = .center
		shadowText1.verticalAlignmentMode = .center
		shadowText1.position = CGPoint(x: 0, y: 72)
		shadowText1.zPosition = 16
		
		let shadowText2 = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		shadowText2.text = "Christmas Quiz 2016!"
		shadowText2.fontSize = 140
		shadowText2.fontColor = NSColor(white: 0.0, alpha: 0.8)
		shadowText2.horizontalAlignmentMode = .center
		shadowText2.verticalAlignmentMode = .center
		shadowText2.position = CGPoint(x: 0, y: -85)
		shadowText2.zPosition = 16
		
		let textShadow = SKEffectNode()
		textShadow.shouldEnableEffects = true
		textShadow.shouldRasterize = true
		textShadow.zPosition = 16
		let filter = CIFilter(name: "CIGaussianBlur")
		filter?.setDefaults()
		filter?.setValue(25, forKey: "inputRadius")
		textShadow.filter = filter;
		textShadow.position = CGPoint(x: 960, y: 820)
		textShadow.addChild(shadowText1)
		textShadow.addChild(shadowText2)
		
		let lights = SKSpriteNode(imageNamed: "lights")
		lights.position = CGPoint(x: 960, y: 985)
		lights.zPosition = 15
		var lightsTextures = [SKTexture]()
		for i in 1...4 {
			lightsTextures.append(SKTexture(imageNamed: "lights\(i)"))
		}
		let lightsAction = SKAction.repeatForever(SKAction.animate(with: lightsTextures, timePerFrame: 1.0))
		lights.run(lightsAction)
		
		for node in snowmojis {
			self.addChild(node)
		}
		self.addChild(bgImage)
		self.addChild(snowmenImage)
		self.addChild(snowImage)
		self.addChild(snow)
		self.addChild(text)
		self.addChild(textShadow)
		self.addChild(lights)
		self.addChild(garySnow)
		self.addChild(eggSnow)
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
