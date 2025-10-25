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
	
	var glow : SKEmitterNode?
	
	convenience init(team: Int, width: Int, height: Int, fontSize: CGFloat,
					 addGlow: Bool = false, glowType: String = "BuzzGlow",
					 entranceFlash: Bool = true, entranceParticles: Bool = false,
					 altText: String? = nil) {
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
		
		let text = SKLabelNode(fontNamed: "Electronic Highway Sign")
		//let text = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
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
		
		let shadowText = SKLabelNode(fontNamed: "Electronic Highway Sign")
		shadowText.text = text.text
		shadowText.fontSize = fontSize
		shadowText.fontColor = NSColor(white: 0, alpha: 1.0)
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
				
		glow = SKEmitterNode(fileNamed: glowType)
		glow?.position = CGPoint.zero
		glow?.particlePositionRange = CGVector(dx: Double(width) * 1.2, dy: Double(height) * 1.2)
		glow?.zPosition = 1
		glow?.particleColor = glowColour
		glow?.particleColorSequence = nil
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
		if entranceFlash {
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
		}
		
		if entranceParticles {
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
			
			self.addChild(particles1)
			self.addChild(particles2)
			self.addChild(particles3)
			self.addChild(particles4)
		}
		
		if(glow != nil) {
			self.addChild(glow!)
		}
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
		if let g = glow {
			g.particleBirthRate = g.particlePositionRange.dx / 10.0
		}
	}
	
	func stopGlow() {
		glow?.particleBirthRate = 0
	}
	
	func runShimmerEffect(width: CGFloat, height: CGFloat) {
	    // Parameters for the shimmer angle and size
	    let shimmerWidth = CGFloat(200)
	    let shimmerHeight = height * 1
	    let texture = BuzzerTeamNode.makeAngledGradientTexture(width: shimmerWidth, height: shimmerHeight)
	    let shimmer = SKSpriteNode(texture: texture, size: CGSize(width: shimmerWidth, height: shimmerHeight))
	    shimmer.alpha = 0.65
	    shimmer.zPosition = 20
	    shimmer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
	    shimmer.position = CGPoint(x: -width/2 + shimmerWidth/2, y: 0)
	    shimmer.blendMode = .add
	    self.addChild(shimmer)

	    // Animate shimmer
		let move = SKAction.moveBy(x: width*0.80, y: 0, duration: 0.3)
		move.timingMode = .easeOut
	    let fade = SKAction.fadeOut(withDuration: 0.7)
	    let group = SKAction.group([move, fade])
	    let sequence = SKAction.sequence([group, SKAction.removeFromParent()])
	    shimmer.run(sequence)
	}

	static func makeAngledGradientTexture(width: CGFloat, height: CGFloat) -> SKTexture {
	    let size = CGSize(width: width, height: height)
	    let image = NSImage(size: size)
	    image.lockFocus()
	    let context = NSGraphicsContext.current!.cgContext
	    let colorSpace = CGColorSpaceCreateDeviceRGB()
	    let colors: [CGColor] = [
	        NSColor.white.withAlphaComponent(0.0).cgColor,
	        NSColor.white.withAlphaComponent(0.95).cgColor,
	        NSColor.white.withAlphaComponent(0.95).cgColor,
	        NSColor.white.withAlphaComponent(0.0).cgColor
	    ]
	    let locations: [CGFloat] = [0.0, 0.2, 0.3, 1.0]
	    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations)!

	    let start = CGPoint(x: 200, y: height/2-10)
	    let end = CGPoint(x: 0, y: height/2)
	    context.drawLinearGradient(gradient, start: start, end: end, options: [])
	    image.unlockFocus()

	    return SKTexture(image: image)
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

