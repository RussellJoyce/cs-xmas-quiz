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
	private var setUp = false
	
	func setUpScene(size: CGSize, leds: QuizLeds?) {
		if setUp {
			return
		}
		setUp = true
		
		self.size = size
		self.leds = leds
		
		let bgImage = SKSpriteNode(imageNamed: "1")
		bgImage.position = CGPoint(x: self.size.width / 2, y: self.size.height / 2)
		bgImage.size = self.size
		bgImage.zPosition = 0
		snow.position = CGPoint(x: self.size.width / 2, y: self.size.height + 16)
		snow.particleBirthRate = 40
		snow.zPosition = 11
		
		for i in 0...9 {
			let snowmoji = SKEmitterNode(fileNamed: "Snowmoji")!
			snowmoji.particleTexture = SKTexture(imageNamed: "snowmoji\(i)")
			snowmoji.position = CGPoint(x: self.size.width / 2, y: self.size.height + 32)
			snowmoji.zPosition = CGFloat(i + 1)
			snowmojis.append(snowmoji)
		}
		
		let text1 = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		text1.text = "Computer Science"
		text1.fontSize = 140
		text1.horizontalAlignmentMode = .Center
		text1.verticalAlignmentMode = .Center
		text1.position = CGPoint(x: 0, y: 72)
		text1.zPosition = 14
		text1.fontColor = NSColor.whiteColor()
		
		let text2 = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		text2.text = "Christmas Quiz 2015"
		text2.fontSize = 140
		text2.horizontalAlignmentMode = .Center
		text2.verticalAlignmentMode = .Center
		text2.position = CGPoint(x: 0, y: -85)
		text2.zPosition = 14
		text2.fontColor = NSColor.whiteColor()
		
		let text = SKNode()
		text.position = CGPoint(x: 960, y: 820)
		text.zPosition = 14
		text.addChild(text1)
		text.addChild(text2)
		
		let shadowText1 = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		shadowText1.text = "Computer Science"
		shadowText1.fontSize = 140
		shadowText1.fontColor = NSColor(white: 0.0, alpha: 0.8)
		shadowText1.horizontalAlignmentMode = .Center
		shadowText1.verticalAlignmentMode = .Center
		shadowText1.position = CGPoint(x: 0, y: 72)
		shadowText1.zPosition = 13
		
		let shadowText2 = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		shadowText2.text = "Christmas Quiz 2015"
		shadowText2.fontSize = 140
		shadowText2.fontColor = NSColor(white: 0.0, alpha: 0.8)
		shadowText2.horizontalAlignmentMode = .Center
		shadowText2.verticalAlignmentMode = .Center
		shadowText2.position = CGPoint(x: 0, y: -85)
		shadowText2.zPosition = 13
		
		let textShadow = SKEffectNode()
		textShadow.shouldEnableEffects = true
		textShadow.shouldRasterize = true
		textShadow.zPosition = 13
		let filter = CIFilter(name: "CIGaussianBlur")
		filter?.setDefaults()
		filter?.setValue(25, forKey: "inputRadius")
		textShadow.filter = filter;
		textShadow.position = CGPoint(x: 960, y: 820)
		textShadow.addChild(shadowText1)
		textShadow.addChild(shadowText2)
		
		let lights = SKSpriteNode(imageNamed: "lights")
		lights.position = CGPoint(x: 960, y: 985)
		lights.zPosition = 12
		var lightsTextures = [SKTexture]()
		for i in 1...4 {
			lightsTextures.append(SKTexture(imageNamed: "lights\(i)"))
		}
		let lightsAction = SKAction.repeatActionForever(SKAction.animateWithTextures(lightsTextures, timePerFrame: 1.0))
		lights.runAction(lightsAction)
		
		for node in snowmojis {
			self.addChild(node)
		}
		self.addChild(bgImage)
		self.addChild(snow)
		self.addChild(text)
		self.addChild(textShadow)
		self.addChild(lights)
	}
	
	func reset() {
		leds?.stringAnimation(2)
		for node in snowmojis {
			node.particleBirthRate = 0
		}
	}
	
	func buzzerPressed(team: Int) {
		snowmojis[team].particleBirthRate = 20
	}
	
	func buzzerReleased(team: Int) {
		snowmojis[team].particleBirthRate = 0
	}
}
