//
//  SnowIdleScene.swift
//  Quiz Server
//
//  Created by Ian Gray on 2026-10-03.
//  Copyright © 2026 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import SpriteKit

/// An idle screen of a snowy village at night, with the title in the sky above it. Snow
/// settles on the letters, the roofs and the trees, and sloughs off again either under its
/// own weight or, for the letters, when a team buzzes.
///
/// Settled snow is not physics. Everything it lands on keeps a height map of the snow along
/// its top surface: falling flakes add to it, and it slumps to an angle of repose, spilling
/// over the edges as new falling flakes. Physics only runs while a cap is being shed, as it
/// breaks into clumps that tumble off. Clumps that come to rest on something else rejoin
/// the snow there. The art itself is in `SnowScenery`.
class SnowIdleScene: QuizScene {

	/// Everything worth playing with while the look is being worked out. The controller's
	/// tuning sliders write straight into this.
	struct Tuning {
		/// New flakes per second across the whole width
		var flakesPerSecond: CGFloat = 90
		/// Snow, in square points, that one average flake adds where it lands
		var flakeVolume: CGFloat = 14
		/// A letter sheds its snow once the cap is this deep anywhere
		var sloughDepth: CGFloat = 26
		/// Steepest slope settled snow will hold, as rise over run
		var repose: CGFloat = 0.6
		/// How deep snow may lie at an edge before it spills over
		var edgeHold: CGFloat = 7
		/// Physics gravity for the clumps, in SpriteKit's metres per second squared. Settled
		/// on, so it no longer has a slider.
		var gravity: CGFloat = 6
		/// How far a letter leans to shed its snow, in degrees
		var tiltDegrees: CGFloat = 3
		/// Typical radius of the pieces a cap breaks into, in points
		var clumpSize: CGFloat = 3
		/// Depth at which snow on the floor melts at `meltRate`. Melting goes with the
		/// fourth power of depth, so shallow drifts barely melt and deep ones go quickly.
		var meltDepth: CGFloat = 300
		/// How fast floor snow `meltDepth` deep melts, in points per second
		var meltRate: CGFloat = 3
		/// Fastest a clump may fall, in points per second: a terminal velocity. Settled on,
		/// so it no longer has a slider.
		var clumpMaxFall: CGFloat = 200
	}
	var tuning = Tuning()

	/// Whether a buzz lights up the team along the bottom of the screen
	var showTeamStrip = true {
		didSet {
			teamStrip.isHidden = !showTeamStrip
			if !showTeamStrip {
				teamStrip.reset()
			}
		}
	}
	/// Whether a buzz shakes the snow off the team's letters
	var shakeLetters = true

	private var teamStrip: TeamStripNode!

	/// Width of one height map column, in points
	fileprivate static let colW: CGFloat = 2
/// How strongly snow on the floor levels itself out (see `SnowCatcher.relax`)
	fileprivate static let floorSettle: CGFloat = 0.1
	/// A step down this big within a letter counts as an edge, not a slope
	fileprivate static let dropThreshold: CGFloat = 6

	/// The chance that a flake crossing a branch across the front of a tree settles on it,
	/// rather than passing in front of or behind it
	private static let ledgeCatchChance: CGFloat = 0.3

	/// Above this many live clumps, a cap breaking up makes powder only, to bound the physics
	private static let maxClumps = 2000

	private static let letterCategory: UInt32 = 1 << 0
	private static let clumpCategory: UInt32 = 1 << 1

	/// The title, letter by letter. Buzzes shake these.
	private var letters = [SnowCatcher]()
	/// Everything snow settles on and can be shed from: the letters, then the houses and trees
	private var catchers = [SnowCatcher]()
	/// The snow along the bottom of the screen. Not one of `catchers`, so it never sheds.
	private var floor: SnowCatcher!
	/// For each `colW`-wide strip of the scene, the catchers with a column in it, so that a
	/// flake only has to be checked against the few beneath it
	private var catchersByStrip = [[Int]]()
	/// Flakes outside this height cannot be landing on anything
	private var landingBand: ClosedRange<CGFloat> = 0...0
	private var flakes = [Flake]()
	private var clumps = [Clump]()

	private var flakeTexture: SKTexture!
	private var clumpTextures = [SKTexture]()
	private var atmosphere: SKEmitterNode?

	private var spawnDebt: CGFloat = 0
	private var lastUpdateTime: TimeInterval = 0
	private var pass = 0

	private struct Flake {
		let node: SKSpriteNode
		var vx: CGFloat
		var vy: CGFloat
		var phase: CGFloat
		var sway: CGFloat
		var volume: CGFloat
		/// The speed it falls at once it is drifting like the rest of the snowfall
		let fallSpeed: CGFloat
		/// 0 for a flake just knocked or spilled off something, rising to 1 as it eases into
		/// drifting like the rest. Fresh snowfall starts at 1.
		var drift: CGFloat
	}

	/// How quickly a flake that came off something sheds its speed and direction and takes up
	/// the snowfall's, per second. Air drag, near enough.
	private static let flakeDrag: CGFloat = 2.5
	/// Seconds for such a flake's sway to fade in fully
	private static let swayFadeIn: CGFloat = 1.2

	private struct Clump {
		let node: SKSpriteNode
		let radius: CGFloat
		/// Once it has been falling this long it breaks up into flakes
		let crumbleAge: TimeInterval
		var age: TimeInterval = 0
		var still: TimeInterval = 0
	}


	//MARK: - Building

	override func buildScene() {
		addBackground(texture: SKTexture(cgImage: SnowScenery.backdrop(size: self.size)))

		physicsWorld.gravity = CGVector(dx: 0, dy: -tuning.gravity)

		flakeTexture = SKTexture(imageNamed: "spark")
		clumpTextures = (0..<4).map { _ in SKTexture(cgImage: SnowIdleScene.clumpImage(diameter: 64)) }

		buildTitle()
		buildVillage()
		catchers = letters + catchers
		indexCatchers()

		floor = SnowCatcher(floorWidth: self.size.width)
		floor.node.zPosition = 25
		self.addChild(floor.node)

		//The same as Idle2Scene's
		teamStrip = TeamStripNode(mode: .spotlight, width: self.size.width,
								  timing: TeamStripNode.Timing(fadeIn: 0.15,
															   popScale: 1.2, popDuration: 0.2,
															   colourDelay: 0.15, colourDuration: 0.4, fadeDelay: 1.5, fadeOut: 1.5))
		teamStrip.isHidden = !showTeamStrip
		self.addChild(teamStrip)
	}

	override func didMove(to view: SKView) {
		super.didMove(to: view)
		//Background snow, behind the letters, that never lands
		atmosphere = addSnow(replacing: atmosphere, emitterNamed: "SnowBackground", zPosition: 1) {
			$0.particleBirthRate = 10
			$0.particleScale = 0.15
			$0.particleAlpha = 0.5
		}
	}

	/// The same two lines as Idle2Scene, but with every glyph its own node so that each
	/// can carry, and shed, its own snow.
	private func buildTitle() {
		let font = NSFont(name: "Neutra Display Titling", size: 140)
			?? NSFontManager.shared.font(withFamily: "Neutra Display", traits: [], weight: 5, size: 140)
			?? NSFont.boldSystemFont(ofSize: 140)
		let year = Calendar.current.component(.year, from: Date())
		//In the sky, clear of the rooftops
		let centre = CGPoint(x: self.size.width / 2, y: self.size.height * 0.72)

		for (text, offset) in [("Computer Science", CGFloat(80)), ("Christmas Quiz \(year)!", CGFloat(-90))] {
			let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font]))
			let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
			let origin = CGPoint(x: centre.x - lineWidth / 2, y: centre.y + offset - font.capHeight / 2)

			for run in CTLineGetGlyphRuns(line) as! [CTRun] {
				let count = CTRunGetGlyphCount(run)
				var glyphs = [CGGlyph](repeating: 0, count: count)
				var positions = [CGPoint](repeating: .zero, count: count)
				CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
				CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
				let attributes = CTRunGetAttributes(run) as NSDictionary
				let runFont = attributes[kCTFontAttributeName as String].map { $0 as! CTFont } ?? (font as CTFont)

				for (glyph, position) in zip(glyphs, positions) {
					guard let path = CTFontCreatePathForGlyph(runFont, glyph, nil), !path.boundingBoxOfPath.isEmpty else {
						continue
					}
					let letter = SnowCatcher(shape: SnowScenery.letter(glyph: path),
											 at: CGPoint(x: origin.x + position.x, y: origin.y + position.y),
											 index: letters.count)
					letter.node.zPosition = 10
					letter.node.physicsBody?.categoryBitMask = SnowIdleScene.letterCategory
					self.addChild(letter.node)
					letters.append(letter)
				}
			}
		}
	}


	/// The houses and trees, which go into `catchers` after the letters, and the smoke from
	/// the chimneys
	private func buildVillage() {
		var scenery = [SnowCatcher]()
		for placement in SnowScenery.village(size: self.size) {
			let catcher = SnowCatcher(shape: placement.shape, at: placement.origin, index: -1)
			catcher.node.zPosition = placement.zPosition
			catcher.node.physicsBody?.categoryBitMask = SnowIdleScene.letterCategory
			self.addChild(catcher.node)
			scenery.append(catcher)

			for line in catcher.ledgeLines {
				let ledge = SnowCatcher(ledge: line, of: catcher, catchChance: SnowIdleScene.ledgeCatchChance)
				ledge.node.zPosition = 3
				catcher.node.addChild(ledge.node)
				catcher.ledges.append(ledge)
				scenery.append(ledge)
			}

			if let chimney = catcher.smokePoint {
				addSmoke(at: catcher.node.convert(chimney, to: self), zPosition: placement.zPosition - 0.5)
			}
			addTwinkles(to: catcher)
		}
		catchers = scenery
	}

	/// A glow over each of a house's fairy lights, brightening and dimming on its own
	private func addTwinkles(to catcher: SnowCatcher) {
		let s = self.size.height / 1080
		for light in catcher.lights {
			let glow = SKSpriteNode(texture: flakeTexture)
			glow.size = CGSize(width: 16 * s, height: 16 * s)
			glow.position = light.point
			glow.zPosition = 1
			glow.color = NSColor(cgColor: light.colour) ?? .white
			glow.colorBlendFactor = 1
			glow.blendMode = .add
			glow.alpha = CGFloat.random(in: 0.3...0.9)
			let dim = SKAction.fadeAlpha(to: CGFloat.random(in: 0.15...0.35), duration: Double.random(in: 0.5...1.4))
			let brighten = SKAction.fadeAlpha(to: CGFloat.random(in: 0.75...1.0), duration: Double.random(in: 0.4...1.0))
			dim.timingMode = .easeInEaseOut
			brighten.timingMode = .easeInEaseOut
			glow.run(SKAction.sequence([SKAction.wait(forDuration: Double.random(in: 0...1.5)),
										SKAction.repeatForever(SKAction.sequence([dim, brighten]))]))
			catcher.node.addChild(glow)
		}
	}

	private func addSmoke(at point: CGPoint, zPosition: CGFloat) {
		let smoke = SKEmitterNode()
		smoke.particleTexture = flakeTexture
		smoke.position = point
		smoke.zPosition = zPosition
		smoke.particleBirthRate = 5
		smoke.particleLifetime = 5
		smoke.particleLifetimeRange = 1
		smoke.particleSpeed = 22
		smoke.particleSpeedRange = 6
		smoke.emissionAngle = .pi / 2
		smoke.emissionAngleRange = 0.25
		smoke.xAcceleration = 3
		smoke.particleScale = 0.35
		smoke.particleScaleSpeed = 0.22
		smoke.particleAlpha = 0.28
		smoke.particleAlphaSpeed = -0.055
		smoke.particleColor = NSColor(calibratedRed: 0.75, green: 0.80, blue: 0.90, alpha: 1)
		smoke.particleColorBlendFactor = 1
		smoke.advanceSimulationTime(5)
		self.addChild(smoke)
	}

	private func indexCatchers() {
		let colW = SnowIdleScene.colW
		catchersByStrip = [[Int]](repeating: [], count: Int(self.size.width / colW) + 1)
		for (index, catcher) in catchers.enumerated() {
			let from = max(0, Int((catcher.origin.x + catcher.left) / colW))
			let to = min(catchersByStrip.count - 1, Int((catcher.origin.x - catcher.left) / colW))
			guard from <= to else { continue }
			for strip in from...to {
				catchersByStrip[strip].append(index)
			}
		}
		let top = catchers.map { $0.origin.y + $0.topY }.max() ?? 0
		//Down to the floor, which flakes can land on anywhere
		landingBand = -10...(top + 150)
	}


	//MARK: - Running

	override func reset() {
		teamStrip.reset()
		clearSnow()
		//Open on a scene that has already been snowed on, as the pictures are
		for catcher in catchers + [floor!] {
			catcher.prefill(repose: tuning.repose, edgeHold: tuning.edgeHold)
		}
	}

	override func teardown() {
		//Force the next update() to re-baseline rather than seeing one huge delta
		lastUpdateTime = 0
	}

	func clearSnow() {
		for flake in flakes {
			flake.node.removeFromParent()
		}
		flakes.removeAll()
		for clump in clumps {
			clump.node.removeFromParent()
		}
		clumps.removeAll()
		for catcher in catchers {
			catcher.clear()
		}
		floor.clear()
	}

	/// Lights the team up on the strip, and shakes the snow off their letters: each team owns
	/// every letter whose index matches theirs, modulo the number of teams. Either can be
	/// turned off from the controller.
	override func buzzerPressed(team: Int, type: BuzzerType, options: BuzzerOptions) {
		if showTeamStrip {
			teamStrip.trigger(team: team)
		}
		if shakeLetters {
			let teams = max(1, Settings.shared.numTeams)
			for letter in letters where letter.index % teams == team {
				slough(letter, kicked: true)
			}
		}
	}

	/// Sheds everything at once, for trying out the effect
	func sloughAll(kicked: Bool) {
		for catcher in catchers {
			slough(catcher, kicked: kicked)
		}
	}

	override func update(_ currentTime: TimeInterval) {
		guard !isPaused else { return }
		if lastUpdateTime == 0 {
			lastUpdateTime = currentTime
		}
		//Clamped so that a hitch never lets a flake step straight through a cap
		let dt = CGFloat(min(currentTime - lastUpdateTime, 1.0 / 20.0))
		lastUpdateTime = currentTime

		physicsWorld.gravity = CGVector(dx: 0, dy: -tuning.gravity)

		spawnFlakes(dt: dt)
		moveFlakes(dt: dt, time: CGFloat(currentTime))

		pass += 1
		for (index, catcher) in catchers.enumerated() where !catcher.sloughing {
			for spill in catcher.relax(repose: tuning.repose, edgeHold: tuning.edgeHold, flakeVolume: tuning.flakeVolume, firstSweep: pass) {
				addFlake(at: catcher.node.convert(spill.point, to: self), volume: tuning.flakeVolume,
						 falling: CGVector(dx: spill.direction * CGFloat.random(in: 8...30), dy: -10))
			}
			//Half the caps redraw each frame: rebuilding their shapes is the costly part
			if (index + pass) % 2 == 0 {
				catcher.redrawIfNeeded()
			}

			if !catcher.sloughPending && catcher.maxDepth > tuning.sloughDepth {
				catcher.sloughPending = true
				catcher.node.run(SKAction.wait(forDuration: Double.random(in: 0.2...1.5))) { [weak self, weak catcher] in
					guard let self = self, let catcher = catcher else { return }
					self.slough(catcher, kicked: false)
				}
			}
		}

		//Spills off the floor go out of shot at the sides, so they need no flakes
		_ = floor.relax(repose: tuning.repose, edgeHold: tuning.edgeHold, flakeVolume: tuning.flakeVolume,
						firstSweep: pass, settle: SnowIdleScene.floorSettle)
		floor.melt(rate: tuning.meltRate, atDepth: tuning.meltDepth, dt: dt)
		if pass % 2 == 0 {
			floor.redrawIfNeeded()
		}

		updateClumps(dt: TimeInterval(dt))
	}


	//MARK: - Falling flakes

	private func spawnFlakes(dt: CGFloat) {
		spawnDebt += tuning.flakesPerSecond * dt
		while spawnDebt >= 1 {
			spawnDebt -= 1
			let x = CGFloat.random(in: -40...(self.size.width + 40))
			addFlake(at: CGPoint(x: x, y: self.size.height + 10), volume: nil, falling: nil)
		}
	}

	/// A new flake. `volume` is nil for fresh snowfall, which takes a random size; spilled
	/// flakes carry exactly the snow that went over the edge. `falling` is nil for snowfall,
	/// which drifts down at a steady speed, and otherwise the starting velocity of snow that
	/// has come off something and falls under gravity.
	private func addFlake(at point: CGPoint, volume: CGFloat?, falling: CGVector?) {
		let spilled = falling != nil
		let diameter = spilled ? CGFloat.random(in: 6...9) : CGFloat.random(in: 4...11)
		let node = SKSpriteNode(texture: flakeTexture)
		node.size = CGSize(width: diameter, height: diameter)
		node.position = point
		node.alpha = spilled ? 1.0 : CGFloat.random(in: 0.7...1.0)
		node.zPosition = 30
		self.addChild(node)

		let fallSpeed = CGFloat.random(in: 55...100) * (0.6 + diameter / 20)
		let flake = Flake(node: node,
						  vx: falling?.dx ?? 0,
						  vy: falling?.dy ?? -fallSpeed,
						  phase: CGFloat.random(in: 0...(2 * .pi)),
						  sway: CGFloat.random(in: 10...35),
						  volume: volume ?? tuning.flakeVolume * (diameter / 7.5) * (diameter / 7.5),
						  fallSpeed: fallSpeed,
						  drift: spilled ? 0 : 1)
		flakes.append(flake)
	}

	private func moveFlakes(dt: CGFloat, time: CGFloat) {
		var i = 0
		while i < flakes.count {
			var flake = flakes[i]
			let from = flake.node.position

			//Eases from however it came off something into falling like the rest, rather
			//than carrying that speed and angle all the way down
			if flake.drift < 1 {
				let ease = min(1, SnowIdleScene.flakeDrag * dt)
				flake.vx += (0 - flake.vx) * ease
				flake.vy += (-flake.fallSpeed - flake.vy) * ease
				flake.drift = min(1, flake.drift + dt / SnowIdleScene.swayFadeIn)
			}
			let to = CGPoint(x: from.x + (flake.vx + flake.drift * flake.sway * sin(time * 1.3 + flake.phase)) * dt,
							 y: from.y + flake.vy * dt)

			if land(from: from, to: to, volume: flake.volume) || to.y < -20 {
				flake.node.removeFromParent()
				flakes.swapAt(i, flakes.count - 1)
				flakes.removeLast()
				continue
			}
			flake.node.position = to
			flakes[i] = flake
			i += 1
		}
	}

	/// Whether a flake travelling `from` → `to` this frame hits settled snow or a letter top,
	/// and if so adds it to the highest one it crossed.
	private func land(from: CGPoint, to: CGPoint, volume: CGFloat) -> Bool {
		let strip = Int(to.x / SnowIdleScene.colW)
		guard landingBand.contains(to.y), strip >= 0, strip < catchersByStrip.count else { return false }

		var best: (letter: SnowCatcher, col: Int, surface: CGFloat)?
		for index in catchersByStrip[strip] {
			let letter = catchers[index]
			guard !letter.sloughing, let col = letter.column(atSceneX: to.x) else { continue }
			let surface = letter.origin.y + letter.ground[col] + letter.depth[col]
			guard from.y >= surface && to.y <= surface && surface > (best?.surface ?? -.infinity) else { continue }
			//A branch only catches some of what crosses it; the rest falls past
			if letter.catchChance >= 1 || CGFloat.random(in: 0..<1) < letter.catchChance {
				best = (letter, col, surface)
			}
		}
		if best == nil, let col = floor.column(atSceneX: to.x) {
			let surface = floor.ground[col] + floor.depth[col]
			if from.y >= surface && to.y <= surface {
				best = (floor, col, surface)
			}
		}
		guard let hit = best else { return false }
		hit.letter.deposit(volume, at: hit.col)
		return true
	}


	//MARK: - Sloughing

	/// Breaks a letter's cap into physics clumps and moves the letter to shed them: a tilt
	/// they slide off under their own weight, or a shake that throws them when `kicked`.
	private func slough(_ letter: SnowCatcher, kicked: Bool) {
		//A branch too heavy with snow shakes its whole tree
		if let tree = letter.parentCatcher {
			letter.sloughPending = false
			slough(tree, kicked: kicked)
			return
		}
		guard !letter.sloughing else { return }
		letter.sloughing = true
		letter.sloughPending = false
		letter.node.removeAllActions()

		//A weight slough slides the cap off one side as a sheet, which breaks up over the
		//edge. The lean is only there to suggest why, as a slope that gentle would not shift
		//it, so the pieces are all set moving the same way.
		let side: CGFloat = Bool.random() ? 1 : -1
		let sheetSpeed = CGFloat.random(in: 55...80)
		for piece in letter.clumpLayout(size: tuning.clumpSize) where clumps.count < SnowIdleScene.maxClumps {
			let velocity: CGVector
			if !letter.kind.moves {
				//Nothing moves a roof, so the snow just starts down whichever way it slopes,
				//off a flat top towards the nearer eave, and gravity does the rest
				let downhill = letter.downhill(atX: piece.centre.x)
				velocity = CGVector(dx: (downhill != 0 ? downhill : (piece.centre.x < 0 ? -1 : 1)) * 30, dy: 0)
			} else if kicked {
				velocity = CGVector(dx: CGFloat.random(in: -140...140), dy: CGFloat.random(in: 120...340))
			} else {
				velocity = CGVector(dx: side * sheetSpeed * CGFloat.random(in: 0.9...1.1), dy: 0)
			}
			addClump(piece, at: letter.node.convert(piece.centre, to: self), velocity: velocity)
		}
		if letter.maxDepth > 0.5 {
			addPowder(over: letter)
		}

		//The cap as it was fades out over the pieces taking its place: moving off with them
		//as a sheet, or quickly when it is shaken apart
		let ghost = letter.capGhost()
		letter.node.addChild(ghost)
		let handover: SKAction = !letter.kind.moves
			? SKAction.fadeOut(withDuration: 0.3)
			: kicked
			? SKAction.fadeOut(withDuration: 0.12)
			: SKAction.group([SKAction.moveBy(x: side * sheetSpeed * 0.35, y: 0, duration: 0.35),
							  SKAction.fadeOut(withDuration: 0.35)])
		ghost.run(SKAction.sequence([handover, SKAction.removeFromParent()]))
		letter.shed()

		let lean = tuning.tiltDegrees * .pi / 180
		let motion: SKAction
		if !letter.kind.moves {
			motion = SKAction.wait(forDuration: 1.2)
		} else if kicked {
			var shakes = [SKAction]()
			for i in 0..<6 {
				let angle = (i % 2 == 0 ? lean : -lean) * (1 - CGFloat(i) / 7)
				shakes.append(SKAction.rotate(toAngle: angle, duration: 0.06))
			}
			shakes.append(SKAction.rotate(toAngle: 0, duration: 0.06))
			let hop = SKAction.sequence([SKAction.moveBy(x: 0, y: 5, duration: 0.1), SKAction.moveBy(x: 0, y: -5, duration: 0.15)])
			motion = SKAction.group([SKAction.sequence(shakes), hop])
		} else {
			//Leans away from where the snow is going, so the top slopes down towards it
			let tilt = SKAction.rotate(toAngle: -side * lean, duration: 0.9)
			tilt.timingMode = .easeInEaseOut
			let back = SKAction.rotate(toAngle: 0, duration: 1.1)
			back.timingMode = .easeInEaseOut
			motion = SKAction.sequence([tilt, SKAction.wait(forDuration: 0.6), back])
		}
		for ledge in letter.ledges {
			shed(ledge, side: side, kicked: kicked)
		}
		letter.node.run(motion) { [weak letter] in
			letter?.sloughing = false
			letter?.ledges.forEach { $0.sloughing = false }
		}
	}

	/// A branch's snow comes off as falling flakes, not physics clumps: it lies inside its
	/// tree's outline, where a clump would start out stuck inside a solid body.
	private func shed(_ ledge: SnowCatcher, side: CGFloat, kicked: Bool) {
		ledge.sloughing = true
		ledge.sloughPending = false
		for (point, volume) in ledge.flakePieces(volume: tuning.flakeVolume, limit: 40) {
			let velocity = kicked
				? CGVector(dx: CGFloat.random(in: -60...60), dy: CGFloat.random(in: 20...100))
				: CGVector(dx: side * CGFloat.random(in: 15...45), dy: -5)
			addFlake(at: ledge.node.convert(point, to: self), volume: volume, falling: velocity)
		}
		let ghost = ledge.capGhost()
		ledge.node.addChild(ghost)
		ghost.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.25), SKAction.removeFromParent()]))
		ledge.shed()
	}

	private func addClump(_ piece: SnowCatcher.Piece, at point: CGPoint, velocity: CGVector) {
		let radius = piece.radius
		let node = SKSpriteNode(texture: clumpTextures.randomElement())
		node.size = piece.drawn
		node.position = point
		node.zRotation = piece.spin ? CGFloat.random(in: 0...(2 * .pi)) : CGFloat.random(in: -0.2...0.2)
		node.zPosition = 20
		node.alpha = 0
		node.run(SKAction.fadeIn(withDuration: 0.15))

		let body = SKPhysicsBody(circleOfRadius: radius * 0.95)
		body.categoryBitMask = SnowIdleScene.clumpCategory
		body.collisionBitMask = SnowIdleScene.letterCategory | SnowIdleScene.clumpCategory
		body.contactTestBitMask = 0
		//Slippery, so that a sliding sheet carries on over the edge
		body.friction = 0.02
		body.restitution = 0.05
		body.linearDamping = 0.2
		body.angularDamping = 0.5
		body.velocity = velocity
		node.physicsBody = body

		self.addChild(node)
		clumps.append(Clump(node: node, radius: radius, crumbleAge: TimeInterval.random(in: 0.6...1.4)))
	}

	/// A puff of fine powder off the top of the letter as the cap breaks up
	private func addPowder(over letter: SnowCatcher) {
		let powder = SKEmitterNode()
		powder.particleTexture = flakeTexture
		powder.position = letter.node.convert(CGPoint(x: 0, y: letter.topY), to: self)
		powder.zPosition = 31
		powder.particlePositionRange = CGVector(dx: letter.width, dy: 12)
		powder.particleBirthRate = 600
		powder.numParticlesToEmit = 70
		powder.particleLifetime = 1.2
		powder.particleLifetimeRange = 0.6
		powder.particleSpeed = 50
		powder.particleSpeedRange = 50
		powder.emissionAngle = .pi / 2
		powder.emissionAngleRange = .pi
		powder.yAcceleration = -220
		powder.particleAlpha = 0.8
		powder.particleAlphaSpeed = -0.6
		powder.particleScale = 0.07
		powder.particleScaleRange = 0.05
		self.addChild(powder)
		powder.run(SKAction.sequence([SKAction.wait(forDuration: 2.5), SKAction.removeFromParent()]))
	}

	/// Retires clumps that have fallen away or come to rest. A clump resting on a letter
	/// turns back into settled snow on it, and one still moving after a while crumbles
	/// into flakes, which carry its snow on down.
	private func updateClumps(dt: TimeInterval) {
		var i = 0
		while i < clumps.count {
			var clump = clumps[i]
			clump.age += dt
			if let body = clump.node.physicsBody, body.velocity.dy < -tuning.clumpMaxFall {
				body.velocity.dy = -tuning.clumpMaxFall
			}
			let v = clump.node.physicsBody?.velocity ?? .zero
			clump.still = hypot(v.dx, v.dy) < 15 ? clump.still + dt : 0

			var done = clump.node.position.y < -60 || clump.age > 10
			if !done && landOnFloor(clump) {
				done = true
			}
			if !done && clump.age > clump.crumbleAge && clump.still == 0 {
				crumble(clump, velocity: v)
				done = true
			}
			//Not straight away, or a sheet still on its own letter would sink back into it
			if !done && clump.age > 1.2 && clump.still > 0.3 {
				if absorb(clump) {
					done = true
				} else if clump.still > 2 {
					done = true
				}
			}

			if done {
				clump.node.removeFromParent()
				clumps.swapAt(i, clumps.count - 1)
				clumps.removeLast()
				continue
			}
			clumps[i] = clump
			i += 1
		}
	}

	private func crumble(_ clump: Clump, velocity: CGVector) {
		let volume = CGFloat.pi * clump.radius * clump.radius
		let pieces = min(max(Int(volume / tuning.flakeVolume), 1), 6)
		for _ in 0..<pieces {
			let jitter = CGPoint(x: CGFloat.random(in: -clump.radius...clump.radius),
								 y: CGFloat.random(in: -clump.radius...clump.radius))
			addFlake(at: CGPoint(x: clump.node.position.x + jitter.x, y: clump.node.position.y + jitter.y),
					 volume: volume / CGFloat(pieces),
					 falling: CGVector(dx: velocity.dx + CGFloat.random(in: -15...15),
									   dy: velocity.dy + CGFloat.random(in: -15...15)))
		}
	}

	/// A clump that has fallen as far as the floor's snow joins it
	private func landOnFloor(_ clump: Clump) -> Bool {
		let p = clump.node.position
		guard let col = floor.column(atSceneX: p.x),
			  p.y - clump.radius <= floor.ground[col] + floor.depth[col] else {
			return false
		}
		floor.deposit(.pi * clump.radius * clump.radius, at: col, spread: Int(clump.radius / SnowIdleScene.colW))
		return true
	}

	private func absorb(_ clump: Clump) -> Bool {
		let p = clump.node.position
		//Clumps fall in front of the branches, so only come to rest on solid things
		for letter in catchers where !letter.sloughing && letter.catchChance >= 1 {
			guard let col = letter.column(atSceneX: p.x) else { continue }
			let surface = letter.origin.y + letter.ground[col] + letter.depth[col]
			if abs((p.y - clump.radius) - surface) < clump.radius * 1.5 {
				letter.deposit(.pi * clump.radius * clump.radius, at: col, spread: Int(clump.radius / SnowIdleScene.colW))
				return true
			}
		}
		return false
	}


	//MARK: - Textures

	/// A lump of snow: a few overlapping blobs, white, faintly blue-grey towards the lower edge.
	/// Random each time, so ask for several.
	private static func clumpImage(diameter: Int) -> CGImage {
		let context = CGContext(data: nil, width: diameter, height: diameter, bitsPerComponent: 8, bytesPerRow: 0,
								space: CGColorSpaceCreateDeviceRGB(),
								bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
		let d = CGFloat(diameter)
		context.addEllipse(in: CGRect(x: d * 0.15, y: d * 0.15, width: d * 0.7, height: d * 0.7))
		for _ in 0..<5 {
			let r = d * CGFloat.random(in: 0.15...0.28)
			let angle = CGFloat.random(in: 0...(2 * .pi))
			let reach = d / 2 - r - 1
			context.addEllipse(in: CGRect(x: d / 2 + cos(angle) * reach - r, y: d / 2 + sin(angle) * reach - r,
										  width: 2 * r, height: 2 * r))
		}
		context.clip()
		let colours = [NSColor(calibratedWhite: 1.0, alpha: 1).cgColor,
					   NSColor(calibratedRed: 0.88, green: 0.92, blue: 0.98, alpha: 1).cgColor] as CFArray
		let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colours, locations: [0.45, 1.0])!
		context.drawRadialGradient(gradient, startCenter: CGPoint(x: d * 0.4, y: d * 0.62), startRadius: 0,
								   endCenter: CGPoint(x: d / 2, y: d / 2), endRadius: d / 2, options: [.drawsAfterEndLocation])
		return context.makeImage()!
	}
}


//MARK: - Something snow settles on

/// A letter, house or tree, or the floor, and the snow lying on it.
///
/// The node sits at the bottom centre of the shape, so a letter or tree tilts on its base,
/// and everything here is in that node's coordinates. Column `i` spans
/// `left + i·colW ..< left + (i+1)·colW`.
private final class SnowCatcher {

	let node: SKSpriteNode
	let kind: SnowCatcherKind
	/// Position in the title, for a letter; -1 otherwise
	let index: Int
	/// Where the shape's smoke comes out, in node space, if it has a chimney
	let smokePoint: CGPoint?
	/// Its fairy lights, in node space
	let lights: [(point: CGPoint, colour: CGColor)]
	/// Its branches' lines, in node space, from which the scene makes `ledges`
	let ledgeLines: [[CGPoint]]
	/// The catchers along its branches, whose nodes are children of this one
	var ledges = [SnowCatcher]()
	/// For a branch, the tree it belongs to
	private(set) weak var parentCatcher: SnowCatcher?
	/// The chance that a flake crossing its surface settles on it: 1 for anything solid
	let catchChance: CGFloat

	/// Where the node is in the scene, while it stands upright. A branch's node is its
	/// tree's child, so it is offset from the tree's.
	var origin: CGPoint {
		guard let tree = parentCatcher else { return node.position }
		return CGPoint(x: tree.node.position.x + node.position.x, y: tree.node.position.y + node.position.y)
	}
	/// Where the node rests, so that a shake cut short cannot leave it out of place
	let home: CGPoint
	let width: CGFloat
	let left: CGFloat
	/// Top of the glyph in each column, or nil where a flake would fall straight past it
	let ground: [CGFloat]
	let hasGround: [Bool]
	var depth: [CGFloat]
	/// Snow that has gone over an edge but not yet amounted to a whole flake
	private var spill: [CGFloat]
	/// Which way the snow on each edge column falls: -1, +1, or 0 if it is not an edge
	private let edgeSide: [CGFloat]

	private let cap = SKShapeNode()
	private var dirty = false

	var sloughing = false
	var sloughPending = false

	var cols: Int { ground.count }
	var maxDepth: CGFloat { depth.max() ?? 0 }
	var topY: CGFloat { zip(ground, hasGround).filter { $0.1 }.map { $0.0 }.max() ?? 0 }

	private static let pad: CGFloat = 3
	/// Room around the shape in the drawn texture for its shadow or glow
	private static let shadowMargin: CGFloat = 24
	private static let scale: CGFloat = 2

	/// `shape` with its origin at `origin` in the scene
	init(shape: SnowShape, at origin: CGPoint, index: Int) {
		self.index = index
		kind = shape.kind
		let colW = SnowIdleScene.colW
		let bounds = shape.parts.map { $0.boundingBoxOfPath }.reduce(CGRect.null) { $0.union($1) }
		let pad = SnowCatcher.pad

		let cols = Int(ceil((bounds.width + 2 * pad) / colW))
		width = CGFloat(cols) * colW
		left = -width / 2
		let height = ceil(bounds.height + 2 * pad)

		//Shape space → node space: bottom centre of the padded bounding box is the origin
		let toNode = CGAffineTransform(translationX: -bounds.midX, y: -(bounds.minY - pad))
		smokePoint = shape.smoke?.applying(toNode)
		lights = shape.lights.map { ($0.point.applying(toNode), $0.colour) }
		ledgeLines = shape.ledges.map { line in line.map { $0.applying(toNode) } }
		catchChance = 1

		//The shape as it is drawn, and a plain silhouette for the physics outline and the
		//height map. Both are twice the shape's height with the shape in the top half, so
		//that the texture's centre, which is where SpriteKit puts the node origin and the
		//physics body, falls on the shape's base.
		let drawn = SnowCatcher.render(width: width, height: height, margin: SnowCatcher.shadowMargin) { context in
			context.concatenate(toNode)
			shape.draw(context)
		}
		let silhouette = SnowCatcher.render(width: width, height: height, margin: 0) { context in
			context.concatenate(toNode)
			context.setFillColor(NSColor.white.cgColor)
			//Each part filled on its own, so that overlapping parts cannot cancel out
			for part in shape.parts {
				context.addPath(part)
				context.fillPath()
			}
		}

		node = SKSpriteNode(texture: SKTexture(cgImage: drawn.image))
		node.size = CGSize(width: width + 2 * SnowCatcher.shadowMargin, height: 2 * (height + SnowCatcher.shadowMargin))
		home = CGPoint(x: origin.x + bounds.midX, y: origin.y + bounds.minY - pad)
		node.position = home

		let body = SKPhysicsBody(texture: SKTexture(cgImage: silhouette.image), alphaThreshold: 0.5,
								 size: CGSize(width: width, height: 2 * height))
		body.isDynamic = false
		body.friction = 0.2
		node.physicsBody = body

		//Height map: scan each column of the silhouette down from the top for the first solid pixel
		var ground = [CGFloat](repeating: 0, count: cols)
		var hasGround = [Bool](repeating: false, count: cols)
		let s = SnowCatcher.scale
		let pixelsHigh = silhouette.height
		for c in 0..<cols {
			let px = min(Int((CGFloat(c) + 0.5) * colW * s), silhouette.width - 1)
			for row in 0..<(pixelsHigh / 2) {
				if silhouette.alpha(x: px, row: row) > 127 {
					ground[c] = (CGFloat(pixelsHigh - row) / s) - height
					hasGround[c] = true
					break
				}
			}
		}
		self.ground = ground
		self.hasGround = hasGround

		edgeSide = SnowCatcher.edgeSides(ground: ground, hasGround: hasGround)
		depth = [CGFloat](repeating: 0, count: cols)
		spill = [CGFloat](repeating: 0, count: cols)
		setUpCap(fill: nil)
	}

	/// The snow along the bottom of the screen: flat, the full width of the scene, with
	/// nothing to draw underneath and no physics outline.
	init(floorWidth: CGFloat) {
		index = -1
		kind = .floor
		smokePoint = nil
		lights = []
		ledgeLines = []
		catchChance = 1
		let cols = Int(ceil(floorWidth / SnowIdleScene.colW))
		width = CGFloat(cols) * SnowIdleScene.colW
		left = -width / 2
		home = CGPoint(x: width / 2, y: 0)
		node = SKSpriteNode(color: .clear, size: .zero)
		node.position = home
		ground = [CGFloat](repeating: 0, count: cols)
		hasGround = [Bool](repeating: true, count: cols)
		edgeSide = SnowCatcher.edgeSides(ground: ground, hasGround: hasGround)
		depth = [CGFloat](repeating: 0, count: cols)
		spill = [CGFloat](repeating: 0, count: cols)
		//A drift is a much bigger expanse of white than a cap, so it is shaded towards the bottom
		setUpCap(fill: SKTexture(cgImage: SnowCatcher.driftShading()))
	}

	/// A branch across the front of `tree`: just a surface, from a line of points in the
	/// tree's node space, with nothing of its own to draw but its snow. Its node goes in
	/// the tree's.
	init(ledge line: [CGPoint], of tree: SnowCatcher, catchChance: CGFloat) {
		index = -1
		kind = .branch
		smokePoint = nil
		lights = []
		ledgeLines = []
		self.catchChance = catchChance
		parentCatcher = tree

		let colW = SnowIdleScene.colW
		let minX = line.first!.x, maxX = line.last!.x
		let cols = max(1, Int(ceil((maxX - minX) / colW)))
		width = CGFloat(cols) * colW
		left = -width / 2
		home = CGPoint(x: minX + width / 2, y: 0)
		node = SKSpriteNode(color: .clear, size: .zero)
		node.position = home

		//The line's height at the middle of each column
		var ground = [CGFloat](repeating: 0, count: cols)
		var segment = 0
		for c in 0..<cols {
			let x = minX + (CGFloat(c) + 0.5) * colW
			while segment < line.count - 2 && line[segment + 1].x < x {
				segment += 1
			}
			let a = line[segment], b = line[min(segment + 1, line.count - 1)]
			let t = b.x > a.x ? min(max((x - a.x) / (b.x - a.x), 0), 1) : 0
			ground[c] = a.y + (b.y - a.y) * t
		}
		self.ground = ground
		hasGround = [Bool](repeating: true, count: cols)
		edgeSide = SnowCatcher.edgeSides(ground: ground, hasGround: hasGround)
		depth = [CGFloat](repeating: 0, count: cols)
		spill = [CGFloat](repeating: 0, count: cols)
		setUpCap(fill: nil)
	}

	private func setUpCap(fill: SKTexture?) {
		cap.fillColor = fill == nil ? NSColor(calibratedRed: 0.97, green: 0.98, blue: 1.0, alpha: 1) : .white
		cap.fillTexture = fill
		cap.strokeColor = .clear
		cap.lineWidth = 0
		cap.zPosition = 2
		node.addChild(cap)
	}

	/// Which way snow goes over each column's edge, if it is one. A column steps down to
	/// nothing, or by more than `dropThreshold`, on an edge side; snow on a column with an
	/// edge both ways picks one at random.
	private static func edgeSides(ground: [CGFloat], hasGround: [Bool]) -> [CGFloat] {
		let cols = ground.count
		var edgeSide = [CGFloat](repeating: 0, count: cols)
		for c in 0..<cols where hasGround[c] {
			let leftDrop = c == 0 || !hasGround[c - 1] || ground[c] - ground[c - 1] > SnowIdleScene.dropThreshold
			let rightDrop = c == cols - 1 || !hasGround[c + 1] || ground[c] - ground[c + 1] > SnowIdleScene.dropThreshold
			if leftDrop && rightDrop {
				edgeSide[c] = Bool.random() ? 1 : -1
			} else if leftDrop {
				edgeSide[c] = -1
			} else if rightDrop {
				edgeSide[c] = 1
			}
		}
		return edgeSide
	}

	/// White at the top fading to a cold blue-grey, stretched over the whole drift
	private static func driftShading() -> CGImage {
		let context = CGContext(data: nil, width: 4, height: 256, bitsPerComponent: 8, bytesPerRow: 0,
								space: CGColorSpaceCreateDeviceRGB(),
								bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
		let colours = [NSColor(calibratedRed: 0.97, green: 0.98, blue: 1.0, alpha: 1).cgColor,
					   NSColor(calibratedRed: 0.66, green: 0.73, blue: 0.88, alpha: 1).cgColor] as CFArray
		let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colours, locations: [0, 1])!
		context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 256), end: CGPoint(x: 0, y: 0), options: [])
		return context.makeImage()!
	}

	/// Melts the snow faster the deeper it lies: `rate` points per second at `atDepth`,
	/// going with the fourth power of depth either side of that.
	func melt(rate: CGFloat, atDepth scale: CGFloat, dt: CGFloat) {
		guard rate > 0, scale > 0 else { return }
		for c in 0..<cols where depth[c] > 0 {
			let d = depth[c] / scale
			depth[c] = max(0, depth[c] - rate * d * d * d * d * dt)
		}
		dirty = true
	}

	private func x(_ col: Int) -> CGFloat {
		left + (CGFloat(col) + 0.5) * SnowIdleScene.colW
	}

	/// Which way the surface slopes down at node-space `x`: -1 to the left, +1 to the
	/// right, or 0 where it is flat
	func downhill(atX x: CGFloat) -> CGFloat {
		let col = Int((x - left) / SnowIdleScene.colW)
		let a = max(0, col - 3), b = min(cols - 1, col + 3)
		guard a < b, hasGround[a], hasGround[b] else { return 0 }
		let fall = ground[a] - ground[b]
		return abs(fall) < 1 ? 0 : (fall > 0 ? 1 : -1)
	}

	/// The column under scene x, if the letter has a top there and is upright
	func column(atSceneX sceneX: CGFloat) -> Int? {
		let local = sceneX - origin.x - left
		guard local >= 0 else { return nil }
		let col = Int(local / SnowIdleScene.colW)
		guard col < cols, hasGround[col] else { return nil }
		return col
	}

	func deposit(_ volume: CGFloat, at col: Int, spread: Int = 3) {
		let reach = max(1, spread)
		var total: CGFloat = 0
		var weights = [(Int, CGFloat)]()
		for c in (col - reach)...(col + reach) where c >= 0 && c < cols && hasGround[c] {
			let w = CGFloat(reach + 1 - abs(c - col))
			weights.append((c, w))
			total += w
		}
		for (c, w) in weights {
			depth[c] += (volume / SnowIdleScene.colW) * (w / total)
		}
		dirty = true
	}

	/// One step of slumping. Snow on any slope steeper than `repose` moves downhill, and
	/// snow piled too high on an edge goes over it. Returns where whole flakes' worth of
	/// spilled snow should start falling from, in node coordinates.
	///
	/// `settle` levels the surface a little whatever its slope, as flakes come to rest in
	/// hollows. Without it, snow landing at random roughens without limit until the whole
	/// surface is at the angle of repose: fine on a letter, but a mountain range on the floor.
	func relax(repose: CGFloat, edgeHold: CGFloat, flakeVolume: CGFloat, firstSweep: Int, settle: CGFloat = 0) -> [(point: CGPoint, direction: CGFloat)] {
		let colW = SnowIdleScene.colW
		let maxDiff = (repose + kind.extraRepose) * colW
		let stick = kind.stick

		//Sweeps alternate direction so that neither way is favoured
		for sweep in firstSweep..<(firstSweep + 3) {
		for step in 0..<max(0, cols - 1) {
			let a = sweep % 2 == 0 ? cols - 2 - step : step
			let b = a + 1
			guard hasGround[a], hasGround[b], abs(ground[a] - ground[b]) <= SnowIdleScene.dropThreshold else { continue }
			var diff = (ground[a] + depth[a]) - (ground[b] + depth[b])
			if settle > 0 && diff != 0 {
				let m = diff > 0 ? min(depth[a], settle * diff / 2) : -min(depth[b], settle * -diff / 2)
				depth[a] -= m
				depth[b] += m
				diff -= 2 * m
				dirty = true
			}
			if diff > maxDiff {
				let m = min(max(0, depth[a] - stick), (diff - maxDiff) / 2)
				if m > 0.001 { depth[a] -= m; depth[b] += m; dirty = true }
			} else if -diff > maxDiff {
				let m = min(max(0, depth[b] - stick), (-diff - maxDiff) / 2)
				if m > 0.001 { depth[b] -= m; depth[a] += m; dirty = true }
			}
		}
		}

		var spills = [(point: CGPoint, direction: CGFloat)]()
		for c in 0..<cols where edgeSide[c] != 0 && depth[c] > edgeHold {
			let excess = depth[c] - edgeHold
			depth[c] -= excess
			spill[c] += excess * colW
			dirty = true
			while spill[c] >= flakeVolume {
				spill[c] -= flakeVolume
				let side = edgeSide[c]
				//Just clear of the column, so it cannot land straight back on it, and half way
				//down the rim, inside the bulge the cap is drawn with there
				spills.append((CGPoint(x: x(c) + side * (colW / 2 + 1), y: ground[c] + depth[c] / 2), side))
			}
		}
		return spills
	}

	/// A piece of a cap that is breaking up: a physics circle of `radius`, small enough
	/// not to overlap its neighbours, drawn at `drawn` size, big enough that it does, so
	/// that together the pieces still look like one mass of snow.
	struct Piece {
		let centre: CGPoint
		let radius: CGFloat
		let drawn: CGSize
		/// Whether it may be drawn at any angle; flat pieces are kept roughly level
		let spin: Bool
	}

	/// Where the clumps go when the cap breaks up: the cap tiled with pieces of about `size`
	/// radius, stacked to the snow's surface where it is deep.
	func clumpLayout(size: CGFloat) -> [Piece] {
		let colW = SnowIdleScene.colW
		let span = max(1, Int((2 * size / colW).rounded()))
		var pieces = [Piece]()
		var i = 0
		while i < cols {
			guard hasGround[i] && depth[i] > 0.8 else { i += 1; continue }
			var j = i
			var surface: CGFloat = 0
			var base: CGFloat = -.infinity
			while j < cols && j < i + span && hasGround[j] && depth[j] > 0.8 {
				surface += ground[j] + depth[j]
				base = max(base, ground[j])
				j += 1
			}
			let top = surface / CGFloat(j - i)
			let thickness = max(1.5, top - base)
			let cx = (x(i) + x(j - 1)) / 2
			let width = CGFloat(j - i) * colW
			let cell = min(2 * size, width)

			if thickness < cell {
				//Thinner than a piece: one flat piece, the depth of the snow
				let radius = max(1.2, thickness / 2 * 0.9)
				pieces.append(Piece(centre: CGPoint(x: cx, y: base + thickness / 2 + 0.5), radius: radius,
									drawn: CGSize(width: width * 1.3, height: thickness * 1.25), spin: false))
			} else {
				//Layers of equal height that fill the snow to its surface
				let layers = max(1, Int(thickness / cell))
				let height = thickness / CGFloat(layers)
				for layer in 0..<layers {
					//Small enough, and wobbling little enough, that no two bodies start out overlapping
					let radius = min(cell, height) / 2 * CGFloat.random(in: 0.65...0.85)
					let wobble = CGFloat.random(in: -0.05...0.05) * cell
					pieces.append(Piece(centre: CGPoint(x: cx + wobble, y: base + height / 2 + 0.5 + CGFloat(layer) * height),
										radius: radius, drawn: CGSize(width: cell * 1.3, height: height * 1.3), spin: true))
				}
			}
			i = j
		}
		return pieces
	}

	/// Its snow divided into about `volume`-sized amounts, at most `limit` of them, each at a
	/// point in the snow spread along the surface in proportion to its depth. Node space.
	func flakePieces(volume: CGFloat, limit: Int) -> [(CGPoint, CGFloat)] {
		let colW = SnowIdleScene.colW
		var total: CGFloat = 0
		for c in 0..<cols where hasGround[c] {
			total += depth[c] * colW
		}
		guard total > volume / 2 else { return [] }
		let count = min(limit, max(1, Int(total / volume)))
		let each = total / CGFloat(count)
		var pieces = [(CGPoint, CGFloat)]()
		var gathered: CGFloat = 0
		for c in 0..<cols where hasGround[c] {
			gathered += depth[c] * colW
			while gathered >= each && pieces.count < count {
				pieces.append((CGPoint(x: x(c), y: ground[c] + depth[c] * CGFloat.random(in: 0.3...1)), each))
				gathered -= each
			}
		}
		return pieces
	}

	/// A copy of the cap as it stands, to fade out over the pieces replacing it
	func capGhost() -> SKShapeNode {
		let ghost = SKShapeNode(path: cap.path ?? CGMutablePath())
		ghost.fillColor = cap.fillColor
		ghost.strokeColor = .clear
		ghost.lineWidth = 0
		ghost.zPosition = cap.zPosition + 1
		return ghost
	}

	/// Lays `kind.startingDepth` of snow everywhere and lets it settle to its natural shape,
	/// throwing away whatever would have spilled over the edges
	///
	/// Branches each get their own amount, lumpy along their length, so that they do not
	/// all start out as the same smooth crescent.
	func prefill(repose: CGFloat, edgeHold: CGFloat) {
		let amount = kind.startingDepth * (kind == .branch ? CGFloat.random(in: 0.4...1.5) : 1)
		let lumps = kind == .branch ? CGFloat(0.45) : 0
		let frequency = CGFloat.random(in: 0.15...0.35), phase = CGFloat.random(in: 0...(2 * .pi))
		for c in 0..<cols where hasGround[c] {
			depth[c] = max(0, amount * (1 + lumps * sin(CGFloat(c) * frequency + phase)))
		}
		for sweep in 0..<120 {
			_ = relax(repose: repose, edgeHold: edgeHold, flakeVolume: .infinity, firstSweep: sweep)
		}
		for c in 0..<cols {
			spill[c] = 0
		}
		dirty = true
		redrawIfNeeded()
	}

	/// Clears the cap after a slough, leaving a light dusting behind
	func shed() {
		for c in 0..<cols {
			depth[c] = min(depth[c], 0.7)
			spill[c] = 0
		}
		dirty = true
		redrawIfNeeded()
	}

	func clear() {
		node.removeAllActions()
		node.zRotation = 0
		node.position = home
		sloughing = false
		sloughPending = false
		for c in 0..<cols {
			depth[c] = 0
			spill[c] = 0
		}
		dirty = true
		redrawIfNeeded()
	}

	/// Redraws the cap as one closed shape per unbroken run of snow, following the snow's
	/// surface along the top and the letter's back along the bottom.
	func redrawIfNeeded() {
		guard dirty else { return }
		dirty = false

		let colW = SnowIdleScene.colW
		let path = CGMutablePath()
		var i = 0
		while i < cols {
			guard hasGround[i] && depth[i] > 0.4 else { i += 1; continue }
			var j = i
			while j < cols && hasGround[j] && depth[j] > 0.4 && (j == i || abs(ground[j] - ground[j - 1]) <= SnowIdleScene.dropThreshold) {
				j += 1
			}
			//Smoothed so the column steps and single flakes do not show
			var tops = [CGPoint]()
			for k in i..<j {
				var sum: CGFloat = 0
				var weight: CGFloat = 0
				for o in -3...3 where k + o >= i && k + o < j {
					let w = CGFloat(4 - abs(o))
					sum += depth[k + o] * w
					weight += w
				}
				tops.append(CGPoint(x: x(k), y: ground[k] + sum / weight))
			}

			//Where the run ends at an edge, the snow bulges a little out over it
			let first = tops[0], last = tops[tops.count - 1]
			let leftEnd = x(i) - colW / 2 - (edgeSide[i] < 0 ? min(depth[i] * 0.4, 4) : 0)
			let rightEnd = x(j - 1) + colW / 2 + (edgeSide[j - 1] > 0 ? min(depth[j - 1] * 0.4, 4) : 0)

			path.move(to: CGPoint(x: x(i) - colW / 2, y: ground[i] - 1))
			path.addQuadCurve(to: first, control: CGPoint(x: leftEnd, y: first.y))
			for top in tops.dropFirst() {
				path.addLine(to: top)
			}
			path.addQuadCurve(to: CGPoint(x: x(j - 1) + colW / 2, y: ground[j - 1] - 1), control: CGPoint(x: rightEnd, y: last.y))
			for k in stride(from: j - 1, through: i, by: -1) {
				path.addLine(to: CGPoint(x: x(k), y: ground[k] - 1))
			}
			path.closeSubpath()
			i = j
		}
		cap.path = path
	}


	//MARK: Rasterising

	struct Raster {
		let image: CGImage
		let data: [UInt8]
		let width: Int
		let height: Int
		let bytesPerRow: Int

		func alpha(x: Int, row: Int) -> UInt8 {
			data[row * bytesPerRow + x * 4 + 3]
		}
	}

	/// A texture twice the shape's height, with the shape in the top half, plus `margin` all
	/// round, drawn by `draw` in node space.
	static func render(width: CGFloat, height: CGFloat, margin: CGFloat, draw: (CGContext) -> Void) -> Raster {
		let pw = Int(ceil((width + 2 * margin) * scale))
		let ph = Int(ceil((2 * height + 2 * margin) * scale))
		let bytesPerRow = pw * 4
		var data = [UInt8](repeating: 0, count: bytesPerRow * ph)

		let image: CGImage = data.withUnsafeMutableBytes { buffer in
			let context = CGContext(data: buffer.baseAddress, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
									space: CGColorSpaceCreateDeviceRGB(),
									bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
			context.scaleBy(x: scale, y: scale)
			//Node origin (the shape's base, centred) to the middle of the texture
			context.translateBy(x: margin + width / 2, y: margin + height)
			draw(context)
			return context.makeImage()!
		}
		return Raster(image: image, data: data, width: pw, height: ph, bytesPerRow: bytesPerRow)
	}
}


// MARK: - Controller window

/// Sliders for tuning the snow while the look is being worked out.
class SnowIdlePanel: NSObject, RoundPanel {

	let round = RoundType.idleSnow
	weak var host: ControllerWindowController!

	/// The tab's view. Each slider's tag indexes `settings`, and its readout is the label
	/// tagged 100 more.
	@IBOutlet weak var settingsView: NSView!
	@IBOutlet weak var teamStripCheck: NSButton!
	@IBOutlet weak var shakeCheck: NSButton!

	private var scene: SnowIdleScene { host.quizDisplay.snowIdleScene }

	private let settings: [WritableKeyPath<SnowIdleScene.Tuning, CGFloat>] = [
		\.flakesPerSecond, \.flakeVolume, \.sloughDepth, \.repose, \.edgeHold,
		\.tiltDegrees, \.clumpSize, \.meltDepth, \.meltRate
	]

	/// The sliders start from the scene's own defaults, not whatever the xib says
	func setUp() {
		for slider in settingsView.subviews.compactMap({ $0 as? NSSlider }) {
			slider.doubleValue = Double(scene.tuning[keyPath: settings[slider.tag]])
			showValue(of: slider)
		}
		teamStripCheck.state = scene.showTeamStrip ? .on : .off
		shakeCheck.state = scene.shakeLetters ? .on : .off
	}

	@IBAction func teamStripToggled(_ sender: NSButton) {
		scene.showTeamStrip = sender.state == .on
	}

	@IBAction func shakeToggled(_ sender: NSButton) {
		scene.shakeLetters = sender.state == .on
	}

	private func showValue(of slider: NSSlider) {
		(settingsView.viewWithTag(100 + slider.tag) as? NSTextField)?.stringValue = String(format: "%.1f", slider.doubleValue)
	}

	@IBAction func sliderMoved(_ sender: NSSlider) {
		scene.tuning[keyPath: settings[sender.tag]] = CGFloat(sender.doubleValue)
		showValue(of: sender)
	}

	@IBAction func slideAll(_ sender: Any) {
		scene.sloughAll(kicked: false)
	}

	@IBAction func shakeAll(_ sender: Any) {
		scene.sloughAll(kicked: true)
	}

	@IBAction func clear(_ sender: Any) {
		scene.clearSnow()
	}
}
