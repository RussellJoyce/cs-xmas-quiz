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
	
	convenience init(team: Int, width: Int, height: Int, fontSize: CGFloat, addGlow: Bool, altText: String? = nil) {
		self.init()
		
		var teamHue = CGFloat(team) / 10.0
		if teamHue > 1.0 {
			teamHue -= 1.0
		}
		let particleColour = NSColor(calibratedHue: teamHue, saturation: 0.6, brightness: 1.0, alpha: 1.0)
		let glowColour = NSColor(calibratedHue: teamHue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
		let bgColour = NSColor(calibratedHue: teamHue, saturation: 1.0, brightness: 0.8, alpha: 1.0)
		
		let scale = SKAction.scale(to: 1, duration: 0.2)
		scale.timingMode = .easeOut
		let fade = SKAction.fadeIn(withDuration: 0.2)
		fade.timingMode = .easeOut
		let entranceGroup = SKAction.group([fade, scale])
		
		let mainNode = SKNode()
		mainNode.position = CGPoint.zero
		
		let bgBox = SKShapeNode(rectOf: CGSize(width: width, height: height))
		bgBox.zPosition = 4
		bgBox.position = CGPoint.zero
		bgBox.fillColor = bgColour
		bgBox.lineWidth = 0.0
		
		let shadow = SKShapeNode(rectOf: CGSize(width: width + 20, height: height + 20))
		shadow.zPosition = 3
		shadow.position = CGPoint.zero
		shadow.fillColor = NSColor(white: 0.1, alpha: 0.5)
		shadow.lineWidth = 0.0
		
		let text = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		if let at = altText {
			text.text = at;
		} else {
			text.text = "Team \(team + 1)"
		}
		text.fontSize = fontSize
		text.fontColor = NSColor.white
		text.horizontalAlignmentMode = .center
		text.verticalAlignmentMode = .center
		text.zPosition = 6
		text.position = CGPoint.zero
		
		let shadowText = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		shadowText.text = text.text
		shadowText.fontSize = fontSize
		shadowText.fontColor = NSColor(white: 0.1, alpha: 0.8)
		shadowText.horizontalAlignmentMode = .center
		shadowText.verticalAlignmentMode = .center
		shadowText.zPosition = 5
		shadowText.position = CGPoint.zero
		
		let textShadow = SKEffectNode()
		textShadow.shouldEnableEffects = true
		textShadow.shouldRasterize = true
		textShadow.zPosition = 5
		let filter = CIFilter(name: "CIGaussianBlur")
		filter?.setDefaults()
		filter?.setValue(fontSize / 5.8, forKey: "inputRadius")
		textShadow.filter = filter;
		textShadow.addChild(shadowText)
		
		let particles1 = makeEmitter(
			position: CGPoint(x: (width/2)-10, y: 0),
			color: particleColour,
			emissionAngle: 0.0, // right
			positionRange: CGVector(dx: 0, dy: height),
			numParticles: 250
		)
		
		let particles2 = makeEmitter(
			position: CGPoint(x: -((width/2)-10), y: 0),
			color: particleColour,
			emissionAngle: .pi, // left
			positionRange: CGVector(dx: 0, dy: height),
			numParticles: 250
		)
		
		let particles3 = makeEmitter(
			position: CGPoint(x: 0, y: -((height/2)-10)),
			color: particleColour,
			emissionAngle: 3.0 * .pi / 2.0, // down
			positionRange: CGVector(dx: width, dy: 0),
			numParticles: 900
		)
		
		let particles4 = makeEmitter(
			position: CGPoint(x: 0, y: (height/2)-10),
			color: particleColour,
			emissionAngle: .pi / 2.0, // up
			positionRange: CGVector(dx: width, dy: 0),
			numParticles: 900
		)
		
		glow.position = CGPoint.zero
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
		
		mainNode.run(entranceGroup)
		
		// Color flash effect for bgBox
		let flash = SKAction.sequence([
			SKAction.run { bgBox.fillColor = .white },
			SKAction.wait(forDuration: 0.07),
			SKAction.customAction(withDuration: 0.5) { node, elapsedTime in
				guard let shape = node as? SKShapeNode else { return }
				let t = CGFloat(elapsedTime) / 0.5
				shape.fillColor = .white.blended(withFraction: t, of: bgColour) ?? bgColour
			}
		])
		bgBox.run(flash)
		
		self.addChild(particles1)
		self.addChild(particles2)
		self.addChild(particles3)
		self.addChild(particles4)
		self.addChild(glow)
	}
	
	private func makeEmitter(position: CGPoint, color: NSColor, emissionAngle: CGFloat, positionRange: CGVector, numParticles: Int, zPosition: CGFloat = 2) -> SKEmitterNode {
		let emitter = SKEmitterNode(fileNamed: "BuzzParticles")!
		emitter.position = position
		emitter.zPosition = zPosition
		emitter.particleColor = color
		emitter.particleColorSequence = nil
		emitter.emissionAngle = emissionAngle
		emitter.emissionAngleRange = .pi / 2
		emitter.particlePositionRange = positionRange
		emitter.numParticlesToEmit = numParticles
		emitter.removeWhenDone()
		return emitter
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
			let ttl = TimeInterval((CGFloat(self.numParticlesToEmit) / self.particleBirthRate) + (self.particleLifetime + (self.particleLifetimeRange / 2.0)))
			let removeAction = SKAction.sequence([SKAction.wait(forDuration: ttl), SKAction.removeFromParent()])
			self.run(removeAction)
		}
	}
}

