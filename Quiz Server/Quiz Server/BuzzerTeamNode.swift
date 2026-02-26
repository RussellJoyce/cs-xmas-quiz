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
	
	//let font = "Electronic Highway Sign"
	//let font = ".AppleSystemUIFontBold"
	let font = "PT Sans Caption Bold"
	
	var bgBox : SKShapeNode?
	var bgColour : NSColor?
	var teamHue = CGFloat(0.0)
	
	var textLabel: SKLabelNode?
	var shadowLabel: SKLabelNode?
	
	private var width : Int = 0
	private var height : Int = 0
	
	convenience init(team: Int, width: Int, height: Int, fontSize: CGFloat,
					 addGlow: Bool = false, glowType: String = "BuzzGlow",
					 entranceFlash: Bool = true, entranceParticles: Bool = false, entranceShimmer: Bool = false,
					 altText: String? = nil) {
		self.init()
		
		self.width = width
		self.height = height
		
		teamHue = CGFloat(team) / 10.0
		if teamHue > 1.0 {
			teamHue -= 1.0
		}
		let particleColour = NSColor(calibratedHue: teamHue, saturation: 0.6, brightness: 1.0, alpha: 1.0)
		let glowColour = NSColor(calibratedHue: teamHue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
		bgColour = NSColor(calibratedHue: teamHue, saturation: 1.0, brightness: 0.8, alpha: 1.0)
		
		let scale = SKAction.scale(to: 1, duration: 0.2)
		scale.timingMode = .easeOut
		let fade = SKAction.fadeIn(withDuration: 0.2)
		fade.timingMode = .easeOut
		let entranceGroup = SKAction.group([fade, scale])
		
		let mainNode = SKNode()
		mainNode.position = CGPoint.zero
		
		bgBox = SKShapeNode(rectOf: CGSize(width: width, height: height))
		bgBox!.zPosition = 4
		bgBox!.position = CGPoint.zero
		bgBox!.fillColor = bgColour!
		bgBox!.lineWidth = 0.0
		
		let shadow = SKShapeNode(rectOf: CGSize(width: width + 20, height: height + 20))
		shadow.zPosition = 3
		shadow.position = CGPoint.zero
		shadow.fillColor = NSColor(white: 0.1, alpha: 0.5)
		shadow.lineWidth = 0.0
		
		let text = SKLabelNode(fontNamed: font)
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
		
		let shadowText = SKLabelNode(fontNamed: font)
		shadowText.text = text.text
		shadowText.fontSize = fontSize
		shadowText.fontColor = NSColor(white: 0, alpha: 1.0)
		shadowText.horizontalAlignmentMode = .center
		shadowText.verticalAlignmentMode = .center
		shadowText.zPosition = 5
		shadowText.position = CGPoint.zero
		
		self.textLabel = text
		self.shadowLabel = shadowText
		
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
		
		mainNode.addChild(bgBox!)
		mainNode.addChild(shadow)
		mainNode.addChild(text)
		mainNode.addChild(textShadow)
		mainNode.alpha = 0
		mainNode.setScale(1.3)
		
		self.addChild(mainNode)
		
		mainNode.run(entranceGroup)
		
		// Color flash effect for bgBox
		if entranceFlash {
			runEntranceFlash()
		}
		
		if entranceParticles {
			//Pick a buzzer effect
			switch(Int.random(in: 0..<4)) {
			case 0:
				BuzzerEffects.edgeBurst(at: .zero, color: particleColour, parent: self, size: CGSize(width: width, height: height))
			case 1:
				BuzzerEffects.confettiShower(at: CGPoint(x: 0, y: CGFloat(height) / 2.0), color: particleColour, parent: self)
			case 2:
				BuzzerEffects.shockwaveRing(at: .zero, color: particleColour, parent: self)
			case 3:
				BuzzerEffects.lightningCrackle(at: .zero, color: particleColour, parent: self, size: CGSize(width: width, height: height))
			default:
				//Default but should not execute
				BuzzerEffects.risingEmbers(at: .zero, color: particleColour, parent: self, size: CGSize(width: width, height: height))
			}
		}
		
		if(glow != nil) {
			self.addChild(glow!)
		}
		
		if entranceShimmer { runShimmerEffect() }
	}
	
	
	func runEntranceFlash() {
		if let bgBox = bgBox, let bgColour = bgColour {
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
	}
	
	
	func startGlow() {
		if let g = glow {
			g.particleBirthRate = g.particlePositionRange.dx / 10.0
		}
	}
	
	func stopGlow() {
		glow?.particleBirthRate = 0
	}
	
	func runShimmerEffect(shimmerWidth : CGFloat = 200.0, duration : TimeInterval = 0.3) {
	    // Parameters for the shimmer angle and size
		let shimmerHeight = CGFloat(self.height)
	    let texture = BuzzerTeamNode.makeAngledGradientTexture(width: shimmerWidth, height: shimmerHeight)
	    let shimmer = SKSpriteNode(texture: texture, size: CGSize(width: shimmerWidth, height: shimmerHeight))
	    shimmer.alpha = 0.65
	    shimmer.zPosition = 20
	    shimmer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
		shimmer.position = CGPoint(x: -CGFloat(self.width)/2.0 + shimmerWidth/2.0, y: 0)
	    shimmer.blendMode = .add
	    self.addChild(shimmer)

	    // Animate shimmer
		let move = SKAction.moveBy(x: CGFloat(self.width)-shimmerWidth, y: 0, duration: duration)
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

	    let start = CGPoint(x: 200, y: height/2-15)
	    let end = CGPoint(x: 0, y: height/2)
	    context.drawLinearGradient(gradient, start: start, end: end, options: [])
	    image.unlockFocus()

	    return SKTexture(image: image)
	}
	
	func updateText(_ newText: String) {
		textLabel?.text = newText
		shadowLabel?.text = newText
	}
	
	func runPop() {
	    let scaleUp = SKAction.scale(to: 1.25, duration: 0.12)
	    scaleUp.timingMode = .easeOut
	    let scaleDown = SKAction.scale(to: 1.0, duration: 0.18)
	    scaleDown.timingMode = .easeIn
	    let popSequence = SKAction.sequence([scaleUp, scaleDown])
	    textLabel?.run(popSequence)
	    shadowLabel?.run(popSequence)
	}
	
	func fadeBackgroundColor(to targetColor: NSColor, duration: TimeInterval) {
	    guard let bgBox = self.bgBox, let startColor = self.bgColour else { return }
	    // Store the original color so bgColour property remains accurate
	    self.bgColour = targetColor
	    let fadeAction = SKAction.customAction(withDuration: duration) { node, elapsedTime in
	        let fraction = CGFloat(elapsedTime) / CGFloat(duration)
	        let currentColor = startColor.blended(withFraction: fraction, of: targetColor) ?? targetColor
	        bgBox.fillColor = currentColor
	    }
	    bgBox.run(fadeAction)
	}

	func fadeTextColor(to targetColor: NSColor, duration: TimeInterval) {
	    guard let textLabel = self.textLabel, let startTextColor = textLabel.fontColor else { return }
	    let fadeAction = SKAction.customAction(withDuration: duration) { _, elapsedTime in
	        let fraction = CGFloat(elapsedTime) / CGFloat(duration)
	        let newTextColor = startTextColor.blended(withFraction: fraction, of: targetColor) ?? targetColor
	        textLabel.fontColor = newTextColor
	    }
	    textLabel.run(fadeAction)
	}
	
	
	func resetTeamColour() {
		guard let bgBox = self.bgBox, let textLabel = self.textLabel else { return }
		bgBox.fillColor = NSColor(calibratedHue: teamHue, saturation: 1.0, brightness: 0.8, alpha: 1.0)
		self.bgColour = bgBox.fillColor
		textLabel.fontColor = .white
	}
}


