//
//  BuzzerEffects.swift
//  Quiz Server
//
//  Self-contained particle effects for buzzer events.
//  Each effect adds nodes to the provided parent and cleans up automatically.
//

import SpriteKit

enum BuzzerEffects {

	// MARK: - Entrance Selection

	enum Entrance: CaseIterable {
		case edgeBurst
		case confettiShower
		case shockwaveRing
		case lightningCrackle
		case sparklerRun
		case crackAndShatter
		case bumpShockwave

		/// Runs the effect, positioned relative to the centre of a box of the given size.
		func run(at position: CGPoint, color: NSColor, parent: SKNode, size: CGSize) {
			switch self {
			case .edgeBurst:
				BuzzerEffects.edgeBurst(at: position, color: color, parent: parent, size: size)
			case .confettiShower:
				let top = CGPoint(x: position.x, y: position.y + size.height / 2.0)
				BuzzerEffects.confettiShower(at: top, color: color, parent: parent)
			case .shockwaveRing:
				BuzzerEffects.shockwaveRing(at: position, color: color, parent: parent)
			case .lightningCrackle:
				BuzzerEffects.lightningCrackle(at: position, color: color, parent: parent, size: size)
			case .sparklerRun:
				BuzzerEffects.sparklerRun(at: position, color: color, parent: parent, size: size)
			case .crackAndShatter:
				BuzzerEffects.crackAndShatter(at: position, color: color, parent: parent, size: size)
			case .bumpShockwave:
				BuzzerEffects.bumpShockwave(at: position, parent: parent)
			}
		}
	}

	/// Picks one of the entrance effects at random and runs it.
	static func randomEntrance(at position: CGPoint, color: NSColor, parent: SKNode, size: CGSize) {
		guard let effect = Entrance.allCases.randomElement() else { return }
		//let effect = Entrance.bumpShockwave
		effect.run(at: position, color: color, parent: parent, size: size)
	}

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
		let texture = confettiTexture
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

	// MARK: - Sparkler Run

	/// Two bright heads race around the perimeter of the box from opposite corners trailing sparks
	static func sparklerRun(
		at position: CGPoint,
		color: NSColor,
		parent: SKNode,
		size: CGSize = CGSize(width: 1000, height: 200),
		duration: TimeInterval = 0.7
	) {
		let rect = CGRect(
			x: position.x - size.width / 2.0,
			y: position.y - size.height / 2.0,
			width: size.width,
			height: size.height
		)

		// Target is a layer that sits in front of the box
		let sparkLayer = SKNode()
		sparkLayer.zPosition = 4.5
		parent.addChild(sparkLayer)

		for startCorner in [0, 2] {
			let head = SKNode()
			head.position = perimeterCorner(of: rect, index: startCorner)
			head.zPosition = 10
			
			let sparks = makeSparkEmitter(color: color, scale: 1)
			let core = makeSparkEmitter(color: .white, scale: 0.5)
			for emitter in [sparks, core] {
				emitter.targetNode = sparkLayer
				head.addChild(emitter)
			}

			let glow = SKShapeNode(circleOfRadius: 3)
			glow.fillColor = .white
			glow.strokeColor = color
			glow.lineWidth = 2.0
			glow.glowWidth = 8.0
			glow.blendMode = .add
			head.addChild(glow)

			parent.addChild(head)

			let follow = SKAction.follow(
				perimeterPath(of: rect, startCorner: startCorner),
				asOffset: false,
				orientToPath: false,
				duration: duration
			)
			let extinguish = SKAction.run {
				sparks.particleBirthRate = 0
				core.particleBirthRate = 0
				glow.run(SKAction.fadeOut(withDuration: 0.12))
			}
			// Outlive the last spark emitted: removing the head early kills it mid-flight.
			let linger = SKAction.wait(forDuration: sparkLifetime + sparkLifetimeRange)

			head.run(SKAction.sequence([follow, extinguish, linger, SKAction.removeFromParent()]))
		}

		// Outlast the heads, whose last sparks are drawn by this layer
		sparkLayer.run(SKAction.sequence([
			SKAction.wait(forDuration: duration + sparkLifetime + sparkLifetimeRange + 0.2),
			SKAction.removeFromParent(),
		]))
	}

	// MARK: - Bump Shockwave

	/// A punch to the screen itself: the picture bulges out from the box and the wave
	/// races away, dying as it goes. Unlike every other effect here this one adds
	/// nothing to the scene, it distorts what is already drawn.
	static func bumpShockwave(
		at position: CGPoint,
		parent: SKNode,
		duration: TimeInterval = 0.45,
		maxRadius: CGFloat = 900,
		strength: CGFloat = 0.65
	) {
		// An SKEffectNode can only filter its children so the scene's own filter is used
		var filter: CIFilter?
		var restingEffects = false
		var restingCentring = true

		let wave = SKAction.customAction(withDuration: duration) { node, elapsed in
			if filter == nil {
				guard let scene = node.scene, let view = scene.view else { return }
				guard scene.filter == nil, let bump = CIFilter(name: "CIBumpDistortion") else { return }
				bump.setDefaults()
				let scenePoint = parent.convert(position, to: scene)
				let backingPoint = view.convertToBacking(scene.convertPoint(toView: scenePoint))
				bump.setValue(CIVector(x: backingPoint.x, y: backingPoint.y), forKey: kCIInputCenterKey)

				restingEffects = scene.shouldEnableEffects
				restingCentring = scene.shouldCenterFilter
				scene.filter = bump
				scene.shouldEnableEffects = true
				scene.shouldRasterize = false
				scene.shouldCenterFilter = false
				filter = bump
			}
			guard let bump = filter, let view = node.scene?.view else { return }

			// The wave starts already a bit open
			let backingScale = view.convertToBacking(NSSize(width: 1, height: 1)).width
			let t = CGFloat(elapsed) / CGFloat(duration)
			bump.setValue(maxRadius * (0.15 + 0.85 * t) * backingScale, forKey: kCIInputRadiusKey)
			bump.setValue(strength * (1.0 - t) * (1.0 - t), forKey: kCIInputScaleKey)
		}

		let restore = SKAction.run {
			guard filter != nil, let scene = parent.scene else { return }
			scene.filter = nil
			scene.shouldEnableEffects = restingEffects
			scene.shouldCenterFilter = restingCentring
		}

		// Driven by a node of our own, so the effect still tidies up after itself
		let carrier = SKNode()
		parent.addChild(carrier)
		carrier.run(SKAction.sequence([wave, restore, SKAction.removeFromParent()]))
	}

	// MARK: - Crack and Shatter

	/// The face of the box cracks outward from an impact point, then the fragments tip away and fall.
	static func crackAndShatter(
		at position: CGPoint,
		color: NSColor,
		parent: SKNode,
		size: CGSize = CGSize(width: 1000, height: 200),
		shardCount: Int = 18,
		crackDuration: TimeInterval = 0.1,
		fallDuration: TimeInterval = 1
	) {
		let hw = size.width / 2.0
		let hh = size.height / 2.0

		// Off-centre impact, so the shatter is not suspiciously symmetric
		let impact = CGPoint(
			x: CGFloat.random(in: -hw * 0.25...hw * 0.25),
			y: CGFloat.random(in: -hh * 0.3...hh * 0.3)
		)

		// One ray per shard boundary. Jittered, but sorted back into angular order so
		// that each adjacent pair of rays always bounds exactly one shard.
		let step = 2.0 * CGFloat.pi / CGFloat(shardCount)
		let angles = (0..<shardCount)
			.map { normalisedAngle(CGFloat($0) * step + CGFloat.random(in: -step * 0.3...step * 0.3)) }
			.sorted()
		let cracks = angles.map { angle in
			crackPoints(from: impact, to: boxEdgePoint(from: impact, angle: angle, hw: hw, hh: hh))
		}

		let container = SKNode()
		container.position = position
		container.zPosition = 10
		parent.addChild(container)

		// A white core inside a team-coloured glow, as with the lightning bolts
		var glowLines: [SKShapeNode] = []
		var coreLines: [SKShapeNode] = []
		for _ in cracks {
			let glowLine = SKShapeNode()
			glowLine.strokeColor = color
			glowLine.lineWidth = 3.0
			glowLine.glowWidth = 4.0
			glowLine.lineCap = .round
			container.addChild(glowLine)
			glowLines.append(glowLine)

			let coreLine = SKShapeNode()
			coreLine.strokeColor = .white
			coreLine.lineWidth = 1.5
			coreLine.lineCap = .round
			container.addChild(coreLine)
			coreLines.append(coreLine)
		}

		let grow = SKAction.customAction(withDuration: crackDuration) { _, elapsed in
			let fraction = CGFloat(elapsed) / CGFloat(crackDuration)
			for (i, points) in cracks.enumerated() {
				let partial = partialPath(through: points, fraction: fraction)
				glowLines[i].path = partial
				coreLines[i].path = partial
			}
		}

		let shatter = SKAction.run {
			for i in cracks.indices {
				let next = (i + 1) % cracks.count
				let shard = makeShard(
					impact: impact,
					leading: cracks[i],
					trailing: cracks[next],
					between: angles[i],
					and: angles[next],
					hw: hw,
					hh: hh,
					color: color
				)
				// Shards outlive the crack container, so they go straight into the parent
				shard.position = CGPoint(x: position.x + shard.position.x, y: position.y + shard.position.y)
				parent.addChild(shard)

				// Each shard is thrown along its own bearing from the impact point, so the
				// left of the box goes left and the right goes right.
				let away = midpointAngle(angles[i], angles[next])
				let burst = CGFloat.random(in: 110...260)
				let drop = CGFloat.random(in: 300...600)

				// The burst has to be its own quick phase: rolled into the fall it is simply
				// swamped by gravity and every shard drops straight down.
				let burstDuration = fallDuration * 0.20
				let throwOut = SKAction.moveBy(x: cos(away) * burst, y: sin(away) * burst, duration: burstDuration)
				throwOut.timingMode = .easeOut

				// Gravity takes over once the burst is spent, with a little outward drift left
				let fall = SKAction.moveBy(
					x: cos(away) * burst * 0.35,
					y: -drop,
					duration: fallDuration - burstDuration
				)
				fall.timingMode = .easeIn

				let spin = SKAction.rotate(byAngle: CGFloat.random(in: -2.5...2.5), duration: fallDuration)
				// Held at full alpha through the burst, so the shards are seen to fly apart
				let fade = SKAction.sequence([
					SKAction.wait(forDuration: burstDuration),
					SKAction.fadeOut(withDuration: fallDuration - burstDuration),
				])

				shard.run(SKAction.sequence([
					SKAction.group([SKAction.sequence([throwOut, fall]), spin, fade]),
					SKAction.removeFromParent(),
				]))
			}
		}

		container.run(SKAction.sequence([
			grow,
			shatter,
			SKAction.fadeOut(withDuration: 0.35),
			SKAction.removeFromParent(),
		]))
	}

	// MARK: - Private Helpers

	/// Built once and reused
	private static let emberTexture: SKTexture = makeEmberTexture()
	private static let confettiTexture: SKTexture = makeConfettiTexture()

	private static let sparkLifetime: TimeInterval = 0.5
	private static let sparkLifetimeRange: TimeInterval = 0.3

	/// Corners of the box, clockwise from the bottom left.
	private static func perimeterCorner(of rect: CGRect, index: Int) -> CGPoint {
		switch index % 4 {
		case 0:  return CGPoint(x: rect.minX, y: rect.minY)
		case 1:  return CGPoint(x: rect.minX, y: rect.maxY)
		case 2:  return CGPoint(x: rect.maxX, y: rect.maxY)
		default: return CGPoint(x: rect.maxX, y: rect.minY)
		}
	}

	/// A closed lap of the box perimeter, beginning at the given corner. `SKAction.follow`
	/// always starts at the beginning of the path, so the start corner is baked into it.
	private static func perimeterPath(of rect: CGRect, startCorner: Int) -> CGPath {
		let points = (0...4).map { perimeterCorner(of: rect, index: startCorner + $0) }
		let path = CGMutablePath()
		path.addLines(between: points)
		return path
	}

	private static func makeSparkEmitter(color: NSColor, scale: CGFloat) -> SKEmitterNode {
		let emitter = SKEmitterNode()
		emitter.zPosition = 30
		emitter.particleTexture = emberTexture
		emitter.particleBlendMode = .add
		emitter.particleBirthRate = 1500
		emitter.particleLifetime = sparkLifetime
		emitter.particleLifetimeRange = sparkLifetimeRange
		emitter.emissionAngle = 0
		emitter.emissionAngleRange = .pi * 2.0
		emitter.particleSpeed = 150
		emitter.particleSpeedRange = 90
		emitter.particleAlpha = 1.0
		emitter.particleAlphaSpeed = -1.8
		emitter.particleScale = scale
		emitter.particleScaleRange = scale * 0.5
		emitter.particleScaleSpeed = -scale
		emitter.particleColor = color
		emitter.particleColorSequence = nil
		emitter.particleColorBlendFactor = 1.0
		return emitter
	}

	private static func normalisedAngle(_ angle: CGFloat) -> CGFloat {
		let twoPi = 2.0 * CGFloat.pi
		let remainder = angle.truncatingRemainder(dividingBy: twoPi)
		return remainder < 0 ? remainder + twoPi : remainder
	}

	/// The angle half way round from `a` to `b`, going anticlockwise.
	private static func midpointAngle(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
		normalisedAngle(a + normalisedAngle(b - a) / 2.0)
	}

	/// Where a ray leaves the box, which is not simply a radius because the origin is off-centre.
	private static func boxEdgePoint(from origin: CGPoint, angle: CGFloat, hw: CGFloat, hh: CGFloat) -> CGPoint {
		let dx = cos(angle)
		let dy = sin(angle)
		var t = CGFloat.greatestFiniteMagnitude

		if abs(dx) > 1e-6 {
			let tx = ((dx > 0 ? hw : -hw) - origin.x) / dx
			if tx > 0 { t = min(t, tx) }
		}
		if abs(dy) > 1e-6 {
			let ty = ((dy > 0 ? hh : -hh) - origin.y) / dy
			if ty > 0 { t = min(t, ty) }
		}
		guard t.isFinite else { return origin }

		return CGPoint(x: origin.x + dx * t, y: origin.y + dy * t)
	}

	/// A jagged polyline from the impact point out to the edge. Unlike a lightning bolt
	/// the wander is slight, so that the cracks stay recognisably radial.
	private static func crackPoints(from start: CGPoint, to end: CGPoint, segments: Int = 4) -> [CGPoint] {
		let dx = end.x - start.x
		let dy = end.y - start.y
		let length = sqrt(dx * dx + dy * dy)
		guard length > 0 else { return [start, end] }

		let perpX = -dy / length
		let perpY = dx / length
		let wander = length * 0.06

		var points = [start]
		for i in 1..<segments {
			let t = CGFloat(i) / CGFloat(segments)
			let offset = CGFloat.random(in: -wander...wander)
			points.append(CGPoint(
				x: start.x + dx * t + perpX * offset,
				y: start.y + dy * t + perpY * offset
			))
		}
		points.append(end)
		return points
	}

	/// The first `fraction` of a polyline, for drawing a crack as it propagates.
	private static func partialPath(through points: [CGPoint], fraction: CGFloat) -> CGPath {
		let path = CGMutablePath()
		guard let first = points.first else { return path }
		path.move(to: first)
		guard points.count > 1 else { return path }

		let travelled = min(max(fraction, 0), 1) * CGFloat(points.count - 1)
		let whole = min(Int(travelled), points.count - 1)

		if whole >= 1 {
			for i in 1...whole { path.addLine(to: points[i]) }
		}
		if whole < points.count - 1 {
			let t = travelled - CGFloat(whole)
			let from = points[whole]
			let to = points[whole + 1]
			path.addLine(to: CGPoint(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t))
		}
		return path
	}

	/// The corners of the box lying between two rays, in the order they are swept.
	/// Without these the shards would cut across the corners and leave the box uncovered.
	private static func cornersBetween(
		impact: CGPoint,
		from startAngle: CGFloat,
		to endAngle: CGFloat,
		hw: CGFloat,
		hh: CGFloat
	) -> [CGPoint] {
		let corners = [
			CGPoint(x: hw, y: hh),
			CGPoint(x: -hw, y: hh),
			CGPoint(x: -hw, y: -hh),
			CGPoint(x: hw, y: -hh),
		]
		let sweep = normalisedAngle(endAngle - startAngle)

		return corners
			.map { (corner: $0, sweptBy: normalisedAngle(atan2($0.y - impact.y, $0.x - impact.x) - startAngle)) }
			.filter { $0.sweptBy > 0 && $0.sweptBy < sweep }
			.sorted { $0.sweptBy < $1.sweptBy }
			.map(\.corner)
	}

	/// A wedge of the box face bounded by two cracks. Its path is built about its own
	/// centre so that it tumbles about itself rather than swinging about the box.
	private static func makeShard(
		impact: CGPoint,
		leading: [CGPoint],
		trailing: [CGPoint],
		between startAngle: CGFloat,
		and endAngle: CGFloat,
		hw: CGFloat,
		hh: CGFloat,
		color: NSColor
	) -> SKShapeNode {
		let outline = leading
			+ cornersBetween(impact: impact, from: startAngle, to: endAngle, hw: hw, hh: hh)
			+ trailing.reversed()

		let centroid = CGPoint(
			x: outline.map(\.x).reduce(0, +) / CGFloat(outline.count),
			y: outline.map(\.y).reduce(0, +) / CGFloat(outline.count)
		)

		let path = CGMutablePath()
		path.addLines(between: outline.map { CGPoint(x: $0.x - centroid.x, y: $0.y - centroid.y) })
		path.closeSubpath()

		let shard = SKShapeNode(path: path)
		shard.position = centroid
		shard.zPosition = 9
		shard.fillColor = NSColor.white.withAlphaComponent(0.22)
		shard.strokeColor = color
		shard.lineWidth = 1.5
		shard.glowWidth = 1.0
		return shard
	}


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
