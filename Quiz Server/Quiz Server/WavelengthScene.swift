//
//  WavelengthScene.swift
//  Quiz Server
//
//  Created by Ian Gray on 2026-08-13.


import Foundation
import Cocoa
import SpriteKit
import AVFoundation

class WavelengthScene: QuizScene {

	static let minValue = 1
	static let maxValue = 99
	var teamGuesses = [Int?]()

	private(set) var revealed = false
	private(set) var swept = false
	private(set) var scored = false
	/// The number the sweep actually ran to, which is what scoring is judged against.
	private var sweptTarget: Int?

	/// One team's guess on the bar
	private final class Marker {
		let team: Int
		let value: Int
		let node: SKNode
		let head: SKNode
		let disc: SKShapeNode
		let stem: SKShapeNode
		let colour: NSColor

		init(team: Int, value: Int, node: SKNode, head: SKNode, disc: SKShapeNode, stem: SKShapeNode, colour: NSColor) {
			self.team = team
			self.value = value
			self.node = node
			self.head = head
			self.disc = disc
			self.stem = stem
			self.colour = colour
		}
	}

	/// Where one team's disc ended up. `x` is the disc, which may have been fanned aside to make room
	/// `anchorX` is the guess itself, which the leader line runs back to.
	private struct PlacedMarker {
		let team: Int
		let value: Int
		let row: Int
		var x: CGFloat
		let anchorX: CGFloat
	}

	/// How a scoring team's marker is dressed, best first: gold, silver, bronze, and then
	/// everything else that made the top half.
	private static let tierColours = [
		NSColor(calibratedRed: 1.00, green: 0.84, blue: 0.00, alpha: 1),
		NSColor(calibratedRed: 0.85, green: 0.87, blue: 0.90, alpha: 1),
		NSColor(calibratedRed: 0.80, green: 0.50, blue: 0.20, alpha: 1),
		NSColor.white
	]
	private static let tierScales: [CGFloat] = [1.35, 1.20, 1.10, 1.00]
	private static let tierRingWidths: [CGFloat] = [12, 9, 7, 5]
	private static let tierGlowWidths: [CGFloat] = [10, 6, 3, 0]

	private static let tierNames = ["1st", "2nd", "3rd", "Top half"]
	
	static func tierName(_ tier: Int?) -> String {
		guard let tier = tier, tierNames.indices.contains(tier) else { return "no score" }
		return tierNames[tier]
	}

	/// How one team did, once Score has been pressed a second time. Ordered best first, and
	/// includes teams that did not score, with a nil `tier`.
	struct Placing {
		let team: Int
		let guess: Int
		let distance: Int
		/// 0 closest, 1 and 2 the next two distinct distances, 3 the rest of the top half.
		/// nil for teams outside the top half.
		let tier: Int?
	}

	/// The scoring outcome. Empty until scoring has run.
	private(set) var placings = [Placing]()

	private var participating = [Bool]()

	//MARK: - Geometry
	private let barMargin: CGFloat = 110
	private let barHeight: CGFloat = 180
	private let barCentreY: CGFloat = 600

	/// Markers sit in rows above the bar, moving up a row when they would otherwise collide.
	private let markerBaseY: CGFloat = 745
	private let markerRowSpacing: CGFloat = 92
	private let markerRadius: CGFloat = 42
	private let markerMaxRows = 4
	private let markerEdgeInset: CGFloat = 14

	private var barLeft: CGFloat { barMargin }
	private var barWidth: CGFloat { size.width - (barMargin * 2) }
	private var barTop: CGFloat { barCentreY + (barHeight / 2) }
	private var barBottom: CGFloat { barCentreY - (barHeight / 2) }

	//MARK: - Nodes
	private var bar: SKSpriteNode!
	private var sweepLine: SKShapeNode!
	private var sweepLabel: OutlinedLabelNode!
	/// The revealed markers, keyed by zero-based team number.
	private var markers = [Int: Marker]()
	private var targetNodes = [SKNode]()
	/// Anything scoring adds to the scene itself, cleared on reset.
	private var scoreNodes = [SKNode]()
	private var teamStrip: TeamStripNode!
	private var snow: SKEmitterNode?

	//MARK: - Sound
	let blopSound = SKAction.playSoundFileNamed("blop", waitForCompletion: false)
	let revealSound = SKAction.playSoundFileNamed("display_sweep", waitForCompletion: false)
	let landSound = SKAction.playSoundFileNamed("counter_score", waitForCompletion: false)
	let winnerSound = SKAction.playSoundFileNamed("tada", waitForCompletion: false)
	private var counterPlayer: AVAudioPlayer?


	override func buildScene() {
		let gradientImage = verticalGradientImage(size: self.size,
				colors: [NSColor(calibratedRed: 0.06, green: 0.02, blue: 0.16, alpha: 1), NSColor.black])
		addBackground(texture: SKTexture(image: gradientImage))

		addBar()
		addScale()
		addSweep()

		teamStrip = TeamStripNode(mode: .remaining, width: self.size.width,
					timing: TeamStripNode.Timing(fadeIn: 0, popScale: 1.25,
					popDuration: 0.2, colourDelay: 0, colourDuration: 0.4,
					fadeDelay: 0.8, fadeOut: 1.0))
		self.addChild(teamStrip)

		if let url = Bundle.main.url(forResource: "counter_nosting", withExtension: "wav") {
			do {
				try counterPlayer = AVAudioPlayer(contentsOf: url)
			} catch let error {
				print(error.localizedDescription)
			}
		}
		counterPlayer?.prepareToPlay()

		teamGuesses = [Int?](repeating: nil, count: Settings.shared.numTeams)
	}

	override func didMove(to view: SKView) {
		snow = addSnow(replacing: snow, emitterNamed: "SnowBackground", zPosition: 30) {
			$0.particleBirthRate = 8
			$0.particleScale = 0.2
			$0.particleAlpha = 0.5
		}
	}


	//MARK: - Scale and geometry helpers
	//--------------------------------------------------------------------------------------------------------------------------

	/// Where a guess sits along the bar. `minValue` is the left edge and `maxValue` the right.
	private func xFor(value: CGFloat) -> CGFloat {
		let span = CGFloat(WavelengthScene.maxValue - WavelengthScene.minValue)
		let clamped = min(CGFloat(WavelengthScene.maxValue), max(CGFloat(WavelengthScene.minValue), value))
		return barLeft + ((clamped - CGFloat(WavelengthScene.minValue)) / span) * barWidth
	}

	private func xFor(value: Int) -> CGFloat {
		return xFor(value: CGFloat(value))
	}


	//MARK: - Scene construction
	//--------------------------------------------------------------------------------------------------------------------------

	private func addBar() {
		let barSize = CGSize(width: barWidth, height: barHeight)
		bar = SKSpriteNode(texture: SKTexture(image: horizontalGradientImage(size: barSize)))
		bar.size = barSize
		bar.position = CGPoint(x: barLeft + (barWidth / 2), y: barCentreY)
		bar.zPosition = 5
		self.addChild(bar)

		let border = SKShapeNode(rect: CGRect(x: barLeft, y: barBottom, width: barWidth, height: barHeight), cornerRadius: 12)
		border.fillColor = NSColor.clear
		border.strokeColor = NSColor(white: 1.0, alpha: 0.75)
		border.lineWidth = 5
		border.zPosition = 6
		self.addChild(border)
	}

	/// Tick marks every ten, plus the two end values
	private func addScale() {
		var values = [WavelengthScene.minValue]
		values += stride(from: 10, through: 90, by: 10)
		values += [WavelengthScene.maxValue]

		for value in values {
			let x = xFor(value: value)
			let isEnd = (value == WavelengthScene.minValue || value == WavelengthScene.maxValue)

			let tick = SKShapeNode(rect: CGRect(x: x - 2, y: barBottom - 26, width: 4, height: isEnd ? 26 : 18))
			tick.fillColor = NSColor(white: 1.0, alpha: 0.75)
			tick.strokeColor = NSColor.clear
			tick.zPosition = 6
			self.addChild(tick)

			let label = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
			label.text = "\(value)"
			label.fontSize = isEnd ? 54 : 40
			label.fontColor = NSColor(white: 1.0, alpha: isEnd ? 1.0 : 0.7)
			label.horizontalAlignmentMode = .center
			label.verticalAlignmentMode = .top
			label.position = CGPoint(x: x, y: barBottom - 34)
			label.zPosition = 6
			self.addChild(label)
		}
	}

	/// The sweep marker and its counter, parked off the left edge until `score(target:)` runs.
	private func addSweep() {
		sweepLine = SKShapeNode(rect: CGRect(x: -6, y: barBottom - 40, width: 12, height: barHeight + 80), cornerRadius: 6)
		sweepLine.fillColor = NSColor.white
		sweepLine.strokeColor = NSColor.white
		sweepLine.glowWidth = 14
		sweepLine.zPosition = 20
		sweepLine.isHidden = true
		self.addChild(sweepLine)

		sweepLabel = OutlinedLabelNode(text: "", fontNamed: ".AppleSystemUIFontBold", fontSize: 150, outlineWidth: 6.0)
		sweepLabel.zPosition = 20
		sweepLabel.positionInParent = CGPoint(x: xFor(value: WavelengthScene.minValue), y: 320)
		self.addChild(sweepLabel)
	}

	//MARK: - Round logic
	//--------------------------------------------------------------------------------------------------------------------------

	override func setParticipating(_ teams: [Bool]) {
		participating = teams
		refreshStrip()
	}

	private func isParticipating(_ team: Int) -> Bool {
		return team < participating.count ? participating[team] : true
	}

	/// Lights the number of every team still to guess, and clears the rest.
	private func refreshStrip() {
		teamStrip.setLit { team in
			isParticipating(team) && (team < teamGuesses.count ? teamGuesses[team] == nil : true)
		}
	}

	/// A team has moved their handle
	func teamGuess(team: Int, value: Int) {
		guard !revealed else { return }
		guard team >= 0 && team < teamGuesses.count else { return }
		guard isParticipating(team) else { return }
		guard value >= WavelengthScene.minValue && value <= WavelengthScene.maxValue else {
			print("Wavelength guess out of range from team \(team + 1): \(value)")
			return
		}

		let firstAnswer = (teamGuesses[team] == nil)
		teamGuesses[team] = value
		if firstAnswer {
			QuizWebSocket.shared?.pulseTeamColour(team)
		} else {
			QuizWebSocket.shared?.pulseTeamColourQuick(team)
		}
		teamStrip.trigger(team: team)
	}


	/// Puts every team's number on the bar where they guessed, and stops taking guesses.
	func reveal() {
		guard !revealed else { return }
		revealed = true

		self.run(revealSound)
		QuizWebSocket.shared?.pulseWhite()

		//Ascending, so that the packing only ever has to look leftwards
		let guesses = teamGuesses.enumerated()
			.compactMap { (team, value) in value.map { (team: team, value: $0) } }
			.filter { isParticipating($0.team) }
			.sorted { $0.value < $1.value }

		for (order, placed) in layOutMarkers(guesses).enumerated() {
			addMarker(placed, delay: Double(order) * 0.07)
		}
	}


	/// Works out where each disc goes.
	private func layOutMarkers(_ guesses: [(team: Int, value: Int)]) -> [PlacedMarker] {
		let minSeparation = (markerRadius * 2) + 8
		var placed = [PlacedMarker]()

		//The last true position in each row, which is what says whether the next marker can
		//sit where it belongs without being nudged
		var lastXInRow = [CGFloat](repeating: -.infinity, count: markerMaxRows)
		var countInRow = [Int](repeating: 0, count: markerMaxRows)

		for guess in guesses {
			let anchorX = xFor(value: guess.value)

			var row = (0..<markerMaxRows).first { anchorX - lastXInRow[$0] >= minSeparation }
			if row == nil {
				//Fits nowhere cleanly, so it goes where there is most room and gets fanned.
				//Never wrapped back onto an occupied row, which used to hide a marker entirely.
				row = (0..<markerMaxRows).min { a, b in
					countInRow[a] != countInRow[b] ? countInRow[a] < countInRow[b] : lastXInRow[a] < lastXInRow[b]
				}
			}

			let chosen = row ?? 0
			lastXInRow[chosen] = anchorX
			countInRow[chosen] += 1
			placed.append(PlacedMarker(team: guess.team, value: guess.value, row: chosen,
									   x: anchorX, anchorX: anchorX))
		}

		//Fan each row out so that no two discs overlap
		let low = barLeft + markerRadius + markerEdgeInset
		let high = barLeft + barWidth - markerRadius - markerEdgeInset
		for row in 0..<markerMaxRows {
			let indices = placed.indices.filter { placed[$0].row == row }
			guard !indices.isEmpty else { continue }

			let fanned = fan(anchors: indices.map { placed[$0].anchorX },
							 separation: minSeparation, low: low, high: high)
			for (n, index) in indices.enumerated() {
				placed[index].x = fanned[n]
			}
		}

		return placed
	}

	/// Nudges a row of discs apart so that none overlap, moving each as little as it can from
	/// the guess it belongs to.
	private func fan(anchors: [CGFloat], separation: CGFloat, low: CGFloat, high: CGFloat) -> [CGFloat] {
		let n = anchors.count
		guard n > 1 else {
			return anchors.map { min(max($0, low), high) }
		}

		let targets = (0..<n).map { anchors[$0] - (CGFloat($0) * separation) }

		//Pool adjacent violators: while the last two blocks are out of order, merge them and
		//give the result the weighted average of what they wanted
		var values = [CGFloat]()
		var counts = [Int]()
		for target in targets {
			values.append(target)
			counts.append(1)
			while values.count > 1 && values[values.count - 2] > values[values.count - 1] {
				let (v1, c1) = (values.removeLast(), counts.removeLast())
				let (v0, c0) = (values.removeLast(), counts.removeLast())
				values.append(((v0 * CGFloat(c0)) + (v1 * CGFloat(c1))) / CGFloat(c0 + c1))
				counts.append(c0 + c1)
			}
		}

		var ys = [CGFloat]()
		for (value, count) in zip(values, counts) {
			ys.append(contentsOf: repeatElement(value, count: count))
		}

		//Keep the row on the bar. Clamping a run that never decreases into a range leaves it
		//still never decreasing, so this cannot reintroduce an overlap.
		let highestStart = high - (CGFloat(n - 1) * separation)
		if highestStart >= low {
			ys = ys.map { min(max($0, low), highestStart) }
		}

		return (0..<n).map { ys[$0] + (CGFloat($0) * separation) }
	}


	/// Pressed twice, like the answer reveals in the other rounds: the first press sweeps up
	/// to the rolled number, the second works out who scored and lights them up.
	func score(target: Int) {
		if !swept {
			guard target >= WavelengthScene.minValue && target <= WavelengthScene.maxValue else {
				print("Wavelength target out of range: \(target)")
				return
			}
			runSweep(target: target)
			return
		}

		guard !scored else { return }

		guard self.action(forKey: "sweep") == nil else {
			print("Wavelength: still sweeping, scoring ignored")
			return
		}

		guard let sweptTarget = sweptTarget else { return }
		runScoring(target: sweptTarget)
	}

	/// Runs the sweep from the bottom of the bar up to the number the host rolled.
	private func runSweep(target: Int) {
		//In case we forgot to reveal
		reveal()
		swept = true
		sweptTarget = target

		let duration = 1.2 + (Double(target - WavelengthScene.minValue) * 0.05)
		sweepLine.isHidden = false
		positionSweep(at: CGFloat(WavelengthScene.minValue))
		counterPlayer?.currentTime = 0
		counterPlayer?.play()

		//Which markers the sweep has already gone past, so each one pops exactly once
		var passed = Set<Int>()
		var lastLedValue = -1

		let sweep = SKAction.customAction(withDuration: duration) { [weak self] _, elapsed in
			guard let self = self else { return }

			//Smoothstep by hand: customAction does not handle timingMode reliably
			let t = min(1.0, max(0.0, elapsed / CGFloat(duration)))
			let eased = t * t * (3 - (2 * t))
			let value = CGFloat(WavelengthScene.minValue) + eased * CGFloat(target - WavelengthScene.minValue)

			self.positionSweep(at: value)

			let whole = Int(value.rounded())
			if whole != lastLedValue {
				lastLedValue = whole
				QuizWebSocket.shared?.setCounterValue(self.ledCounter(for: whole))
			}

			for (team, guess) in self.teamGuesses.enumerated() {
				if let guess = guess, guess <= whole, !passed.contains(team) {
					passed.insert(team)
					self.popMarker(team: team)
				}
			}
		}

		self.run(SKAction.sequence([sweep, SKAction.run { [weak self] in self?.landSweep(on: target) }]), withKey: "sweep")
	}

	private func positionSweep(at value: CGFloat) {
		guard let sweepLine = sweepLine, let sweepLabel = sweepLabel else { return }
		let x = xFor(value: value)
		sweepLine.position = CGPoint(x: x, y: 0)
		//The counter is held far enough from the edges that a target of 1 or 99 does not push the digits off the screen
		let inset: CGFloat = 200
		sweepLabel.positionInParent = CGPoint(x: min(size.width - inset, max(inset, x)), y: 320)
		sweepLabel.text = "\(Int(value.rounded()))"
	}

	/// The LED strip runs 0...200, the same full-scale value the true/false round uses.
	private func ledCounter(for value: Int) -> Int {
		let span = Double(WavelengthScene.maxValue - WavelengthScene.minValue)
		return Int((Double(value - WavelengthScene.minValue) / span) * 200.0)
	}

	/// The sweep has arrived. Stop the run-up, plant the target on the bar and make a fuss.
	private func landSweep(on target: Int) {
		counterPlayer?.stop()
		counterPlayer?.currentTime = 0
		self.run(landSound)
		QuizWebSocket.shared?.pulseWhite()

		positionSweep(at: CGFloat(target))
		let x = xFor(value: target)

		//The counter grows into the answer
		sweepLabel.run(SKAction.sequence([
			SKAction.scale(to: 1.5, duration: 0.25),
			SKAction.scale(to: 1.25, duration: 0.15)
		]))

		let star = SKNode()
		star.zPosition = 21
		self.addChild(star)
		targetNodes.append(star)
		star.addEmitter(named: "location", at: CGPoint(x: x, y: barCentreY), zPosition: 22) {
			$0.particleColor = NSColor.white
			$0.particleColorSequence = nil
			$0.particleSpeed = 220
			$0.particleBirthRate = 4000
			$0.numParticlesToEmit = 2500
		}
	}


	//MARK: - Scoring
	//--------------------------------------------------------------------------------------------------------------------------

	/// Which teams scored, and how well, keyed by zero-based team number.
	private func rankTeams(target: Int) -> [Placing] {
		let ranked = teamGuesses.enumerated()
			.compactMap { (team, guess) in guess.map { (team: team, guess: $0, distance: abs($0 - target)) } }
			.filter { isParticipating($0.team) }
			.sorted { $0.distance < $1.distance }
		guard !ranked.isEmpty else { return [] }

		//The top half by count
		var cut = max(1, ranked.count / 2)
		while cut < ranked.count && ranked[cut].distance == ranked[cut - 1].distance {
			cut += 1
		}

		var result = [Placing]()
		var tier = 0
		for i in 0..<ranked.count {
			if i > 0 && ranked[i].distance > ranked[i - 1].distance {
				tier += 1
			}
			result.append(Placing(team: ranked[i].team,
								  guess: ranked[i].guess,
								  distance: ranked[i].distance,
								  tier: i < cut ? min(tier, WavelengthScene.tierColours.count - 1) : nil))
		}
		return result
	}

	/// Shows who scored: a band spreads out from the target to mark how close you had to be
	private func runScoring(target: Int) {
		scored = true

		placings = rankTeams(target: target)
		guard !placings.isEmpty else {
			print("Wavelength: nothing to score, no team guessed")
			return
		}

		var tiers = [Int: Int]()
		for placing in placings {
			if let tier = placing.tier {
				tiers[placing.team] = tier
			}
		}

		//How far out the worst scoring guess was, which is what the band has to reach
		let cutDistance = placings.filter { $0.tier != nil }.map { $0.distance }.max() ?? 0

		var actions: [SKAction] = [growBand(target: target, distance: cutDistance)]

		actions.append(SKAction.run { [weak self] in
			guard let self = self else { return }
			for marker in self.markers.values where tiers[marker.team] == nil {
				self.dimMarker(marker)
			}
		})

		//Lowest tier first, so the display works its way up to the winner rather than down
		for tier in stride(from: WavelengthScene.tierColours.count - 1, through: 0, by: -1) {
			let inTier = markers.values.filter { tiers[$0.team] == tier }
			if inTier.isEmpty {
				continue
			}
			actions.append(SKAction.wait(forDuration: 0.35))
			actions.append(SKAction.run { [weak self] in
				guard let self = self else { return }
				inTier.forEach { self.lightMarker($0, tier: tier) }
			})
		}

		self.run(SKAction.sequence(actions), withKey: "scoring")
	}

	/// A translucent band spreading out from the target as far as the last guess that scored
	private func growBand(target: Int, distance: Int) -> SKAction {
		let band = SKSpriteNode(color: NSColor(white: 1.0, alpha: 0.52),
								size: CGSize(width: 0, height: barHeight))
		band.position = CGPoint(x: xFor(value: target), y: barCentreY)
		band.zPosition = 7 //Over the bar, under the markers and the sweep line
		self.addChild(band)
		scoreNodes.append(band)

		let duration = 0.5
		return SKAction.customAction(withDuration: duration) { [weak self] _, elapsed in
			guard let self = self else { return }
			let fraction = min(1.0, max(0.0, elapsed / CGFloat(duration)))
			let reach = CGFloat(distance) * fraction
			//Taken from the clamping xFor so that a target near either end simply stops at
			//the edge of the bar instead of running off it
			let left = self.xFor(value: CGFloat(target) - reach)
			let right = self.xFor(value: CGFloat(target) + reach)
			band.size.width = right - left
			band.position.x = (left + right) / 2
		}
	}

	private func dimMarker(_ marker: Marker) {
		marker.node.run(SKAction.fadeAlpha(to: 0.25, duration: 0.4))
		let greyed = marker.colour.blended(withFraction: 0.75, of: .darkGray) ?? marker.colour
		marker.disc.run(SKAction.colorTransitionAction(fromColor: marker.colour, toColor: greyed))
		marker.stem.fillColor = greyed
		marker.stem.strokeColor = greyed
	}

	private func lightMarker(_ marker: Marker, tier: Int) {
		marker.disc.strokeColor = WavelengthScene.tierColours[tier]
		marker.disc.lineWidth = WavelengthScene.tierRingWidths[tier]
		marker.disc.glowWidth = WavelengthScene.tierGlowWidths[tier]

		let grow = SKAction.scale(to: WavelengthScene.tierScales[tier], duration: 0.2)
		grow.timingMode = .easeOut
		marker.head.run(SKAction.sequence([
			SKAction.scale(to: WavelengthScene.tierScales[tier] * 1.15, duration: 0.12),
			grow
		]))

		if tier < 3 {
			marker.node.addEmitter(named: "BuzzGlow", at: .zero, zPosition: -2, autoRemove: false) {
				$0.particleColorSequence = nil
				$0.particleColor = WavelengthScene.tierColours[tier]
				$0.particlePositionRange = CGVector(dx: 90, dy: 90)
				$0.particleBirthRate = CGFloat(10 * (3 - tier))
				$0.particleAlpha = 0.5
				$0.particleScale = 0.5
			}
		}

		if tier == 0 {
			self.run(winnerSound)
			QuizWebSocket.shared?.pulseTeamColour(marker.team)
		} else {
			self.run(blopSound)
		}
	}


	//MARK: - Markers
	//--------------------------------------------------------------------------------------------------------------------------

	/// A team's guess: a numbered disc in the team's colour, sitting above the bar on a stem
	/// that points at the exact value they picked.
	private func addMarker(_ placed: PlacedMarker, delay: TimeInterval) {
		let y = markerBaseY + (CGFloat(placed.row) * markerRowSpacing)
		let colour = Utils.teamColour(placed.team, saturation: 0.85)

		let marker = SKNode()
		marker.position = CGPoint(x: placed.x, y: y)
		marker.zPosition = 15
		marker.alpha = 0

		//Where the guess really is, in the marker's own space
		let anchor = CGPoint(x: placed.anchorX - placed.x, y: barTop - y)

		//A leader line rather than a plain stem: the disc may have been fanned aside to make
		//room, so this is what says which value it belongs to
		let path = CGMutablePath()
		path.move(to: CGPoint(x: 0, y: -markerRadius))
		path.addLine(to: anchor)
		let stem = SKShapeNode(path: path)
		stem.strokeColor = colour
		stem.fillColor = colour
		stem.lineWidth = 4
		stem.lineCap = .round
		stem.zPosition = -1
		marker.addChild(stem)

		//The line has to land on something for the eye to trust it
		let anchorDot = SKShapeNode(circleOfRadius: 7)
		anchorDot.position = anchor
		anchorDot.fillColor = colour
		anchorDot.strokeColor = NSColor.black
		anchorDot.lineWidth = 2
		anchorDot.zPosition = -1
		marker.addChild(anchorDot)

		let head = SKNode()
		head.setScale(0.2)
		marker.addChild(head)

		let disc = SKShapeNode(circleOfRadius: markerRadius)
		disc.fillColor = colour
		disc.strokeColor = NSColor.black
		disc.lineWidth = 4
		head.addChild(disc)

		let label = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		label.text = "\(placed.team + 1)"
		label.fontSize = 46
		label.fontColor = NSColor.black
		label.horizontalAlignmentMode = .center
		label.verticalAlignmentMode = .center
		label.zPosition = 1
		head.addChild(label)

		self.addChild(marker)
		markers[placed.team] = Marker(team: placed.team, value: placed.value, node: marker,
									  head: head, disc: disc, stem: stem, colour: colour)

		//Markers pop in one after another rather than all at once, so the spread reads
		let splash = SKAction.run { [weak self] in
			guard let self = self else { return }
			//Fired at the guess, not at the disc, so the splash marks the real value
			self.addEmitter(named: "location", at: CGPoint(x: placed.anchorX, y: self.barCentreY), zPosition: 16) {
				$0.particleColor = colour
				$0.particleColorSequence = nil
				$0.particleSpeed = 140
				$0.particleBirthRate = 2500
				$0.numParticlesToEmit = 900
			}
		}
		marker.run(SKAction.sequence([SKAction.wait(forDuration: delay), splash,
									  SKAction.fadeAlpha(to: 1.0, duration: 0.15)]))
		head.run(SKAction.sequence([SKAction.wait(forDuration: delay),
									SKAction.scale(to: 1.15, duration: 0.15),
									SKAction.scale(to: 1.0, duration: 0.1)]))
	}

	/// The sweep has just gone past this team's guess.
	private func popMarker(team: Int) {
		guard let head = markers[team]?.head else { return }

		//Only the disc pops. Scaling the whole marker would swing the leader line off its value.
		self.run(blopSound)
		head.run(SKAction.sequence([
			SKAction.scale(to: 1.35, duration: 0.08),
			SKAction.scale(to: 1.0, duration: 0.15)
		]))
	}


	//MARK: - Housekeeping
	//--------------------------------------------------------------------------------------------------------------------------

	override func reset() {
		QuizWebSocket.shared?.ledsOff()
		self.removeAction(forKey: "sweep")
		self.removeAction(forKey: "scoring")
		counterPlayer?.stop()
		counterPlayer?.currentTime = 0

		revealed = false
		swept = false
		scored = false
		sweptTarget = nil
		placings.removeAll()
		teamGuesses = [Int?](repeating: nil, count: Settings.shared.numTeams)

		markers.values.forEach { $0.node.removeFromParent() }
		markers.removeAll()
		targetNodes.forEach { $0.removeFromParent() }
		targetNodes.removeAll()
		scoreNodes.forEach { $0.removeFromParent() }
		scoreNodes.removeAll()

		sweepLabel?.removeAllActions()
		sweepLabel?.setScale(1.0)
		positionSweep(at: CGFloat(WavelengthScene.minValue))
		sweepLabel?.text = ""
		sweepLine?.isHidden = true

		refreshStrip()
	}

	override func teardown() {
		counterPlayer?.stop()
		counterPlayer?.currentTime = 0
	}


	//MARK: - Drawing
	//--------------------------------------------------------------------------------------------------------------------------

	private func verticalGradientImage(size: CGSize, colors: [NSColor]) -> NSImage {
		return gradientImage(size: size,
							 colors: colors,
							 locations: [0.0, 1.0],
							 start: CGPoint(x: size.width / 2, y: size.height),
							 end: CGPoint(x: size.width / 2, y: 0))
	}

	/// The bar itself: red at 1, through orange and yellow, to green at 99. Matches the
	/// gradient the teams see on their own sliders.
	private func horizontalGradientImage(size: CGSize) -> NSImage {
		let colours = [
			NSColor(calibratedRed: 0.88, green: 0.12, blue: 0.12, alpha: 1),
			NSColor(calibratedRed: 0.88, green: 0.44, blue: 0.12, alpha: 1),
			NSColor(calibratedRed: 0.88, green: 0.83, blue: 0.12, alpha: 1),
			NSColor(calibratedRed: 0.56, green: 0.80, blue: 0.12, alpha: 1),
			NSColor(calibratedRed: 0.09, green: 0.75, blue: 0.29, alpha: 1)
		]
		return gradientImage(size: size,
							 colors: colours,
							 locations: [0.0, 0.25, 0.5, 0.75, 1.0],
							 start: CGPoint(x: 0, y: size.height / 2),
							 end: CGPoint(x: size.width, y: size.height / 2))
	}

	private func gradientImage(size: CGSize, colors: [NSColor], locations: [CGFloat], start: CGPoint, end: CGPoint) -> NSImage {
		let image = NSImage(size: size)
		image.lockFocus()
		defer { image.unlockFocus() }
		guard let context = NSGraphicsContext.current?.cgContext else { return image }
		let cgColors = colors.map { $0.cgColor } as CFArray
		if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: locations) {
			context.drawLinearGradient(gradient, start: start, end: end, options: [])
		}
		return image
	}
}
