//
//  BuzzerTeamNode.swift
//  SpriteKitTest
//
//  Created by Russell Joyce on 15/11/2015.
//  Copyright © 2015 Russell Joyce. All rights reserved.
//

import Cocoa
import SpriteKit

class BuzzerTeamNode: SKNode {
	
	let glow = SKEmitterNode(fileNamed: "BuzzGlow")!
	
	convenience init(team: Int, width: Int, height: Int, fontSize: CGFloat, addGlow: Bool) {
		self.init()
		
		let teamHue = CGFloat(team) / 10.0
		let particleColour = NSColor(calibratedHue: teamHue, saturation: 0.6, brightness: 1.0, alpha: 1.0)
		let glowColour = NSColor(calibratedHue: teamHue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
		let bgColour = NSColor(calibratedHue: teamHue, saturation: 1.0, brightness: 0.8, alpha: 1.0)
		
		let scale = SKAction.scaleTo(1, duration: 0.2)
		scale.timingMode = .EaseOut
		let fade = SKAction.fadeInWithDuration(0.2)
		fade.timingMode = .EaseOut
		let entranceGroup = SKAction.group([fade, scale])
		
		let mainNode = SKNode()
		mainNode.position = CGPointZero
		
		let bgBox = SKShapeNode(rectOfSize: CGSize(width: width, height: height))
		bgBox.zPosition = 4
		bgBox.position = CGPointZero
		bgBox.fillColor = bgColour
		bgBox.lineWidth = 0.0
		
		let shadow = SKShapeNode(rectOfSize: CGSize(width: width + 20, height: height + 20))
		shadow.zPosition = 3
		shadow.position = CGPointZero
		shadow.fillColor = NSColor(white: 0.1, alpha: 0.5)
		shadow.lineWidth = 0.0
		
		let text = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		text.text = "Team \(team + 1)"
		text.fontSize = fontSize
		text.fontColor = NSColor.whiteColor()
		text.horizontalAlignmentMode = .Center
		text.verticalAlignmentMode = .Center
		text.zPosition = 6
		text.position = CGPointZero
		
		let shadowText = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		shadowText.text = "Team \(team + 1)"
		shadowText.fontSize = fontSize
		shadowText.fontColor = NSColor(white: 0.1, alpha: 0.8)
		shadowText.horizontalAlignmentMode = .Center
		shadowText.verticalAlignmentMode = .Center
		shadowText.zPosition = 5
		shadowText.position = CGPointZero
		
		let textShadow = SKEffectNode()
		textShadow.shouldEnableEffects = true
		textShadow.shouldRasterize = true
		textShadow.zPosition = 5
		let filter = CIFilter(name: "CIGaussianBlur")
		filter?.setDefaults()
		filter?.setValue(fontSize / 5.8, forKey: "inputRadius")
		textShadow.filter = filter;
		textShadow.addChild(shadowText)
		
		let particles1 = SKEmitterNode(fileNamed: "BuzzParticles")!
		particles1.position = CGPoint(x: (width/2)-10, y: 0)
		particles1.zPosition = 2
		particles1.particleColor = particleColour
		particles1.particleColorSequence = nil
		particles1.emissionAngle = 0.0
		particles1.particlePositionRange = CGVector(dx: 0, dy: height)
		particles1.xAcceleration = -450
		particles1.yAcceleration = 0
		particles1.numParticlesToEmit = 200
		particles1.removeWhenDone()
		
		let particles2 = SKEmitterNode(fileNamed: "BuzzParticles")!
		particles2.position = CGPoint(x: -((width/2)-10), y: 0)
		particles2.zPosition = 2
		particles2.particleColor = particleColour
		particles2.particleColorSequence = nil
		particles2.emissionAngle = CGFloat(M_PI)
		particles2.particlePositionRange = CGVector(dx: 0, dy: height)
		particles2.xAcceleration = 450
		particles2.yAcceleration = 0
		particles2.numParticlesToEmit = 200
		particles2.removeWhenDone()
		
		let particles3 = SKEmitterNode(fileNamed: "BuzzParticles")!
		particles3.position = CGPoint(x: 0, y: -((height/2)-10))
		particles3.zPosition = 2
		particles3.particleColor = particleColour
		particles3.particleColorSequence = nil
		particles3.emissionAngle = CGFloat(3.0 * M_PI / 2.0)
		particles3.particlePositionRange = CGVector(dx: width, dy: 0)
		particles3.xAcceleration = 0
		particles3.yAcceleration = 360
		particles3.numParticlesToEmit = 800
		particles3.removeWhenDone()
		
		let particles4 = SKEmitterNode(fileNamed: "BuzzParticles")!
		particles4.position = CGPoint(x: 0, y: (height/2)-10)
		particles4.zPosition = 2
		particles4.particleColor = particleColour
		particles4.particleColorSequence = nil
		particles4.emissionAngle = CGFloat(M_PI / 2.0)
		particles4.particlePositionRange = CGVector(dx: width, dy: 0)
		particles4.xAcceleration = 0
		particles4.yAcceleration = -360
		particles4.numParticlesToEmit = 800
		particles4.removeWhenDone()
		
		glow.position = CGPointZero
		glow.particlePositionRange = CGVector(dx: Double(width) * 1.2, dy: Double(height) * 1.2)
		glow.zPosition = 1
		glow.particleColor = glowColour
		glow.particleColorSequence = nil
		if addGlow {
			startGlow()
		}
		else {
			stopGlow()
		}
		
		mainNode.addChild(bgBox)
		mainNode.addChild(shadow)
		mainNode.addChild(text)
		mainNode.addChild(textShadow)
		mainNode.alpha = 0
		mainNode.setScale(1.3)
		
		self.addChild(mainNode)
		
		mainNode.runAction(entranceGroup)
		
		self.addChild(particles1)
		self.addChild(particles2)
		self.addChild(particles3)
		self.addChild(particles4)
		self.addChild(glow)
	}
	
	func startGlow() {
		glow.particleBirthRate = glow.particlePositionRange.dx / 10.0
	}
	
	func stopGlow() {
		glow.particleBirthRate = 0
	}
}


extension SKEmitterNode {
	func removeWhenDone() {
		if (self.numParticlesToEmit != 0) {
			let ttl = NSTimeInterval((CGFloat(self.numParticlesToEmit) / self.particleBirthRate) + (self.particleLifetime + (self.particleLifetimeRange / 2.0)))
			let removeAction = SKAction.sequence([SKAction.waitForDuration(ttl), SKAction.removeFromParent()])
			self.runAction(removeAction)
		}
	}
}
