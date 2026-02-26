//
//  BuzzerEffects.swift
//  Quiz Server
//
//  Self-contained particle effects for buzzer events.
//  Each effect adds nodes to the provided parent and cleans up automatically.
//

import SpriteKit

enum BuzzerEffects {

	// MARK: - Shockwave Ring

	/// An expanding glowing ring that radiates outward from a point and fades out.
	static func shockwaveRing(
		at position: CGPoint,
		color: NSColor,
		parent: SKNode,
		initialSize: CGSize = CGSize(width: 300, height: 100),
		scaleTo: CGFloat = 4.0,
		duration: TimeInterval = 0.5
	) {
		let ring = SKShapeNode(ellipseOf: initialSize)
		ring.position = position
		ring.strokeColor = color
		ring.fillColor = .clear
		ring.lineWidth = 3.0
		ring.glowWidth = 6.0
		ring.zPosition = 10
		ring.alpha = 0.85

		let scaleUp = SKAction.scale(to: scaleTo, duration: duration)
		scaleUp.timingMode = .easeOut
		let fadeOut = SKAction.fadeOut(withDuration: duration)
		fadeOut.timingMode = .easeIn
		let group = SKAction.group([scaleUp, fadeOut])

		parent.addChild(ring)
		ring.run(SKAction.sequence([group, SKAction.removeFromParent()]))
	}

	// MARK: - Edge Burst

	/// Particles burst outward from all four edges of a box.
	static func edgeBurst(
		at position: CGPoint,
		color: NSColor,
		parent: SKNode,
		size: CGSize = CGSize(width: 1000, height: 200)
	) {
		let hw = size.width / 2.0 - 10
		let hh = size.height / 2.0 - 10

		let specs: [(CGPoint, CGFloat, CGVector, Int)] = [
			(CGPoint(x: hw, y: 0),  0.0,              CGVector(dx: 0, dy: size.height), 250), // right
			(CGPoint(x: -hw, y: 0), .pi,              CGVector(dx: 0, dy: size.height), 250), // left
			(CGPoint(x: 0, y: -hh), 3.0 * .pi / 2.0, CGVector(dx: size.width, dy: 0),  900), // down
			(CGPoint(x: 0, y: hh),  .pi / 2.0,        CGVector(dx: size.width, dy: 0),  900), // up
		]

		for (offset, angle, range, count) in specs {
			let emitter = makeBuzzEmitter(color: color, emissionAngle: angle, positionRange: range, count: count)
			emitter.position = CGPoint(x: position.x + offset.x, y: position.y + offset.y)
			parent.addChild(emitter)
		}
	}

	// MARK: - Confetti Shower

	/// A burst of small coloured confetti pieces that shoot upward then fall with gravity.
	/// Uses the team colour plus white and gold accents.
	static func confettiShower(
		at position: CGPoint,
		color: NSColor,
		parent: SKNode,
		spread: CGFloat = 800,
		count: Int = 400
	) {
		let texture = makeConfettiTexture()

		let teamCount = Int(Double(count) * 0.55)
		let whiteCount = Int(Double(count) * 0.25)
		let goldCount = count - teamCount - whiteCount
		let gold = NSColor(calibratedHue: 0.12, saturation: 0.9, brightness: 1.0, alpha: 1.0)

		let specs: [(NSColor, Int)] = [
			(color, teamCount),
			(.white, whiteCount),
			(gold, goldCount),
		]

		for (confettiColor, n) in specs {
			let emitter = makeConfettiEmitter(texture: texture, color: confettiColor, spread: spread, count: n)
			emitter.position = position
			emitter.removeWhenDone()
			parent.addChild(emitter)
		}
	}

	// MARK: - Lightning Crackle

	/// Procedural lightning bolts that crackle around the edges of a box, flashing 2-3 times.
	/// Each bolt has a white core with a team-coloured glow.
	static func lightningCrackle(
		at position: CGPoint,
		color: NSColor,
		parent: SKNode,
		size: CGSize = CGSize(width: 1000, height: 200),
		boltCount: Int = 14
	) {
		let hw = size.width / 2.0
		let hh = size.height / 2.0

		// Each flash gets its own container with fresh random bolts
		let containers = (0..<3).map { _ -> SKNode in
			let container = SKNode()
			container.position = position
			container.zPosition = 10
			container.alpha = 0

			for _ in 0..<boltCount {
				let start = randomPerimeterPoint(hw: hw, hh: hh)
				let outwardAngle = atan2(start.y, start.x)
				let length = CGFloat.random(in: 60...160)
				let end = CGPoint(
					x: start.x + cos(outwardAngle) * length,
					y: start.y + sin(outwardAngle) * length
				)
				let path = makeLightningPath(from: start, to: end)

				let glowBolt = SKShapeNode(path: path)
				glowBolt.strokeColor = color
				glowBolt.lineWidth = 3.0
				glowBolt.glowWidth = 4.0
				glowBolt.lineCap = .round
				container.addChild(glowBolt)

				let coreBolt = SKShapeNode(path: path)
				coreBolt.strokeColor = .white
				coreBolt.lineWidth = 1.5
				coreBolt.glowWidth = 1.0
				coreBolt.lineCap = .round
				container.addChild(coreBolt)
			}

			parent.addChild(container)
			return container
		}

		// Staggered flash timing: bright, bright, dimmer
		let flashAlphas: [CGFloat] = [1.0, 1.0, 0.7]
		let gaps: [TimeInterval] = [0.06, 0.09]
		var delay: TimeInterval = 0

		for (i, container) in containers.enumerated() {
			let onDuration = 0.03
			let holdDuration = 0.04
			let offDuration = 0.05

			let sequence = SKAction.sequence([
				SKAction.wait(forDuration: delay),
				SKAction.fadeAlpha(to: flashAlphas[i], duration: onDuration),
				SKAction.wait(forDuration: holdDuration),
				SKAction.fadeOut(withDuration: offDuration),
				SKAction.removeFromParent(),
			])
			container.run(sequence)

			delay += onDuration + holdDuration + offDuration
			if i < gaps.count { delay += gaps[i] }
		}
	}

	// MARK: - Rising Embers

	/// Glowing embers that float upward from beneath the box with gentle horizontal drift, fading over ~2s.
	static func risingEmbers(
		at position: CGPoint,
		color: NSColor,
		parent: SKNode,
		size: CGSize = CGSize(width: 1000, height: 200),
		count: Int = 600
	) {
		let texture = makeEmberTexture()

		// Main team-coloured embers
		let main = makeEmberEmitter(texture: texture, color: color, spread: size.width, count: count)
		main.position = CGPoint(x: position.x, y: position.y - size.height / 2.0)
		main.removeWhenDone()
		parent.addChild(main)

		// Bright white/yellow accent embers
		let accentCount = count / 4
		let accent = makeEmberEmitter(texture: texture, color: .white, spread: size.width * 0.6, count: accentCount)
		accent.position = main.position
		accent.particleScale = 0.6
		accent.particleScaleRange = 0.3
		accent.removeWhenDone()
		parent.addChild(accent)
	}

	// MARK: - Private Helpers

	private static func makeEmberEmitter(texture: SKTexture, color: NSColor, spread: CGFloat, count: Int) -> SKEmitterNode {
		let emitter = SKEmitterNode()
		emitter.zPosition = 10
		emitter.particleTexture = texture

		emitter.particleBirthRate = 120
		emitter.numParticlesToEmit = count
		emitter.particleLifetime = 2.0
		emitter.particleLifetimeRange = 0.8

		emitter.particlePositionRange = CGVector(dx: spread, dy: 0)

		emitter.emissionAngle = .pi / 2.0 // upward
		emitter.emissionAngleRange = .pi / 6.0

		emitter.particleSpeed = 80
		emitter.particleSpeedRange = 40

		emitter.xAcceleration = 0
		emitter.yAcceleration = 20 // gentle upward drift

		emitter.particleAlpha = 0.9
		emitter.particleAlphaSpeed = -0.4

		emitter.particleScale = 1.0
		emitter.particleScaleRange = 0.5
		emitter.particleScaleSpeed = -0.2

		emitter.particleColor = color
		emitter.particleColorSequence = nil
		emitter.particleColorBlendFactor = 1.0
		emitter.particleColorBlendFactorRange = 0.2

		// Gentle horizontal wander via rotation of emission
		emitter.emissionAngleRange = .pi / 4.0

		return emitter
	}

	private static func makeEmberTexture() -> SKTexture {
		let size: CGFloat = 10
		let image = NSImage(size: NSSize(width: size, height: size))
		image.lockFocus()
		let rect = NSRect(x: 0, y: 0, width: size, height: size)
		// Soft radial circle
		let gradient = NSGradient(starting: NSColor.white, ending: NSColor.white.withAlphaComponent(0.0))
		gradient?.draw(in: rect, relativeCenterPosition: .zero)
		image.unlockFocus()
		return SKTexture(image: image)
	}

	private static func randomPerimeterPoint(hw: CGFloat, hh: CGFloat) -> CGPoint {
		let edge = Int.random(in: 0...3)
		switch edge {
		case 0:  return CGPoint(x: CGFloat.random(in: -hw...hw), y: hh)   // top
		case 1:  return CGPoint(x: hw, y: CGFloat.random(in: -hh...hh))   // right
		case 2:  return CGPoint(x: CGFloat.random(in: -hw...hw), y: -hh)  // bottom
		default: return CGPoint(x: -hw, y: CGFloat.random(in: -hh...hh))  // left
		}
	}

	private static func makeLightningPath(from start: CGPoint, to end: CGPoint, segments: Int = 6) -> CGPath {
		let dx = end.x - start.x
		let dy = end.y - start.y
		let length = sqrt(dx * dx + dy * dy)
		guard length > 0 else { return CGMutablePath() }

		let perpX = -dy / length
		let perpY = dx / length
		let displacement = length * 0.3

		let path = CGMutablePath()
		path.move(to: start)

		for i in 1..<segments {
			let t = CGFloat(i) / CGFloat(segments)
			let offset = CGFloat.random(in: -displacement...displacement)
			path.addLine(to: CGPoint(
				x: start.x + dx * t + perpX * offset,
				y: start.y + dy * t + perpY * offset
			))
		}

		path.addLine(to: end)
		return path
	}


	private static func makeConfettiEmitter(texture: SKTexture, color: NSColor, spread: CGFloat, count: Int) -> SKEmitterNode {
		let emitter = SKEmitterNode()
		emitter.zPosition = 10
		emitter.particleTexture = texture

		emitter.particleBirthRate = 500
		emitter.numParticlesToEmit = count
		emitter.particleLifetime = 3.5
		emitter.particleLifetimeRange = 1.0

		emitter.particlePositionRange = CGVector(dx: spread, dy: 0)

		emitter.emissionAngle = .pi / 2.0 // upward
		emitter.emissionAngleRange = .pi
		
		emitter.particleSpeed = 400
		emitter.particleSpeedRange = 200

		emitter.yAcceleration = -500

		emitter.particleAlpha = 1.0
		emitter.particleAlphaSpeed = -0.2

		emitter.particleScale = 1.0
		emitter.particleScaleRange = 0.6

		emitter.particleRotation = 0
		emitter.particleRotationRange = .pi * 2
		emitter.particleRotationSpeed = 3.0

		emitter.particleColor = color
		emitter.particleColorSequence = nil
		emitter.particleColorBlendFactor = 1.0

		return emitter
	}

	private static func makeBuzzEmitter(color: NSColor, emissionAngle: CGFloat, positionRange: CGVector, count: Int) -> SKEmitterNode {
		let emitter = SKEmitterNode(fileNamed: "BuzzParticles")!
		emitter.zPosition = 2
		emitter.particleColor = color
		emitter.particleColorSequence = nil
		emitter.emissionAngle = emissionAngle
		emitter.emissionAngleRange = .pi / 2
		emitter.particlePositionRange = positionRange
		emitter.numParticlesToEmit = count
		emitter.removeWhenDone()
		return emitter
	}

	private static func makeConfettiTexture() -> SKTexture {
		let size = CGSize(width: 12, height: 8)
		let image = NSImage(size: size)
		image.lockFocus()
		NSColor.white.setFill()
		NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
		image.unlockFocus()
		return SKTexture(image: image)
	}
}
