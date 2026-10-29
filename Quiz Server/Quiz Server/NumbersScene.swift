//
//  NumbersScene.swift
//  Quiz Server
//
//  Created by Ian Gray on 13/11/2017.
//  Copyright © 2017 Russell Joyce & Ian Gray. All rights reserved.
//

import Foundation
import Cocoa
import SpriteKit

class NumbersScene: QuizScene {

	var teamGuesses = [Int?]()
	private var teamBoxes = [NumberBoxNode]()
	let blopSound = SKAction.playSoundFileNamed("blop", waitForCompletion: false)
	let hornSound = SKAction.playSoundFileNamed("tada", waitForCompletion: false)
	let landSound = SKAction.playSoundFileNamed("counter_score", waitForCompletion: false)
	private(set) var revealed = false
	private(set) var scored = false
	/// Continuous emitters added by scoring, which have to be cleared on reset.
	private var emitters = [SKEmitterNode]()

	//MARK: - Geometry
	private let lineMargin: CGFloat = 150
	private var lineLeft: CGFloat { lineMargin }
	private var lineRight: CGFloat { size.width - lineMargin }
	private let axisY: CGFloat = 125
	private let panelTop: CGFloat = 395
	/// The boxes fill everything above this.
	private let gridBottom: CGFloat = 430

	/// Markers sit in rows above the line, moving up a row when they would otherwise collide.
	private let markerBaseY: CGFloat = 205
	private let markerRowSpacing: CGFloat = 62
	private let markerRadius: CGFloat = 27
	private let markerMaxRows = 3

	//MARK: - Nodes
	/// The backing, axis, ticks, markers and answer: everything that fades in on the reveal.
	private var linePanel = SKNode()
	private var tickLayer = SKNode()
	private var answerNodes = [SKNode]()

	//MARK: - The scale
	/// The values at either end of the line, and the gap between ticks.
	private struct Scale: Equatable {
		let lo: Double
		let hi: Double
		let step: Double
	}

	/// One team's guess on the line
	private final class Marker {
		let team: Int
		let value: Int
		let node = SKNode()
		let head = SKNode()
		let disc: SKShapeNode
		let stem = SKShapeNode()
		let anchorDot = SKShapeNode(circleOfRadius: 6)
		/// Stands in for the dot when the guess is off the end of the line
		let arrow: SKShapeNode

		init(team: Int, value: Int, radius: CGFloat) {
			self.team = team
			self.value = value
			self.disc = SKShapeNode(circleOfRadius: radius)
			let path = CGMutablePath()
			path.move(to: CGPoint(x: -8, y: -11))
			path.addLine(to: CGPoint(x: 12, y: 0))
			path.addLine(to: CGPoint(x: -8, y: 11))
			path.closeSubpath()
			self.arrow = SKShapeNode(path: path)
		}
	}

	/// `side` is -1 or 1 for a guess pinned off the left or right end of the line, and 0 otherwise.
	private struct Placement {
		var x: CGFloat
		var y: CGFloat
		var anchorX: CGFloat
		var side: Int
	}

	private var scale: Scale?
	private var ticks = [(value: Double, node: SKNode)]()
	/// The revealed markers, keyed by zero-based team number.
	private var markers = [Int: Marker]()
	private var placements = [Int: Placement]()


	override func buildScene() {
		self.revealed = false

		addBackground(imageNamed: "blue-snow")

		let layout = teamSquareGridLayout(top: self.size.height - 50, bottom: gridBottom)
		for team in 0..<Settings.shared.numTeams {
			let box = NumberBoxNode(team: team, size: CGSize(width: layout.boxWidth, height: layout.boxHeight),
									position: layout.positions[team], fontSize: layout.fontSize)
			box.zPosition = 1
			teamBoxes.append(box)
			self.addChild(box)
			teamGuesses.append(nil)
		}

		addLinePanel()
	}

	/// A dark strip across the bottom for the number line, so it reads over the snow
	private func addLinePanel() {
		linePanel.alpha = 0
		linePanel.zPosition = 10
		self.addChild(linePanel)

		let backing = SKShapeNode(rect: CGRect(x: 60, y: 18, width: size.width - 120, height: panelTop - 18), cornerRadius: 22)
		backing.fillColor = NSColor(calibratedWhite: 0.0, alpha: 0.4)
		backing.strokeColor = NSColor(calibratedWhite: 1.0, alpha: 0.25)
		backing.lineWidth = 2
		linePanel.addChild(backing)

		let path = CGMutablePath()
		path.move(to: CGPoint(x: lineLeft, y: axisY))
		path.addLine(to: CGPoint(x: lineRight, y: axisY))
		let axis = SKShapeNode(path: path)
		axis.strokeColor = NSColor(calibratedWhite: 1.0, alpha: 0.85)
		axis.lineWidth = 5
		axis.lineCap = .round
		axis.zPosition = 1
		linePanel.addChild(axis)

		tickLayer.zPosition = 2
		linePanel.addChild(tickLayer)
	}

	/// Which teams are playing, from the enable buttons at the top of the controller window.
	private var participating = [Bool]()

	override func setParticipating(_ teams: [Bool]) {
		participating = teams
		refreshBoxes()
	}

	private func isParticipating(_ team: Int) -> Bool {
		//Defaults to in, for the window before the controller has said anything
		return team < participating.count ? participating[team] : true
	}

	private func refreshBoxes() {
		for team in 0..<min(Settings.shared.numTeams, teamBoxes.count) {
			teamBoxes[team].setPlaying(isParticipating(team))
		}
	}

	/// The guesses that count, which leaves out any team switched off since it answered
	private var countedGuesses: [Int?] {
		teamGuesses.enumerated().map { team, guess in isParticipating(team) ? guess : nil }
	}

	func teamGuess(teamid : Int, guess : Int) {
		guard !revealed else { return }
		if teamid >= 0 && teamid < Settings.shared.numTeams && isParticipating(teamid) {
			self.run(blopSound)
			QuizWebSocket.shared?.pulseTeamColour(teamid)
			teamGuesses[teamid] = guess
			teamBoxes[teamid].showPending()
		}
	}

	/// Pressed twice: the first press shows every guess, the second brings in the answer.
	func showGuesses(actualAnswer : Int) {
		if !revealed {
			reveal()
		} else if !scored {
			score(answer: actualAnswer)
		}
	}


	//MARK: - Reveal
	//--------------------------------------------------------------------------------------------------------------------------

	private func reveal() {
		revealed = true
		self.run(hornSound)
		QuizWebSocket.shared?.pulseWhite()

		let emoji = ["tree", "santa", "spaceinvader", "robot", "snowman", "present", "floppydisk", "snowflake"]
		for i in 0..<80 {
			let point = CGPoint(x: Int(arc4random_uniform(UInt32(self.size.width))), y: Int(arc4random_uniform(UInt32(self.size.height))))
			self.addEmitter(named: "emojsplosion", at: point, zPosition: CGFloat(100 + i)) {
				$0.particleTexture = SKTexture(imageNamed: emoji[Int(arc4random_uniform(UInt32(emoji.count)))])
			}
		}

		let guesses = countedGuesses
		for (team, box) in teamBoxes.enumerated() {
			if let guess = guesses[team] {
				box.showNumber(NumbersScene.format(Double(guess)), delay: Double(team) * 0.04)
			} else {
				box.clear()
			}
		}

		guard let range = NumbersScene.coreRange(of: guesses.compactMap { $0 }) else { return }
		let fitted = NumbersScene.niceScale(lo: range.lo, hi: range.hi)
		scale = fitted
		ticks = makeTicks(fitted)
		placements = layOut(fitted)

		linePanel.run(SKAction.fadeIn(withDuration: 0.3))

		//Left to right, so that the spread reads as it arrives
		let order = placements.sorted { $0.value.anchorX < $1.value.anchorX }.map { $0.key }
		for (n, team) in order.enumerated() {
			guard let guess = guesses[team], let placement = placements[team] else { continue }
			addMarker(team: team, value: guess, at: placement, delay: 0.3 + (Double(n) * 0.07))
		}
	}


	//MARK: - Scoring
	//--------------------------------------------------------------------------------------------------------------------------

	/// Rescales the line to take in the answer if it has to, plants the answer, and then lights the teams that scored from the lowest place up to the winner.
	private func score(answer: Int) {
		scored = true

		let guesses = countedGuesses
		guard scale != nil, let range = NumbersScene.coreRange(of: guesses.compactMap { $0 }) else {
			print("Numbers: nothing to score, no team guessed")
			return
		}
		let target = NumbersScene.niceScale(lo: min(range.lo, Double(answer)), hi: max(range.hi, Double(answer)))

		var actions = [SKAction]()
		if target != scale {
			actions.append(rescale(to: target, duration: 1.2))
			actions.append(SKAction.wait(forDuration: 0.2))
		}
		actions.append(SKAction.run { [weak self] in self?.plantAnswer(answer) })
		actions.append(SKAction.wait(forDuration: 0.8))

		let placings = NumbersScene.placings(guesses: guesses, actualAnswer: answer)
		actions.append(SKAction.run { [weak self] in
			guard let self = self else { return }
			let scoring = Set(placings.filter { $0.place != nil }.map { $0.team })
			for (team, box) in self.teamBoxes.enumerated() where !scoring.contains(team) && box.isPlaying {
				box.dim()
				self.markers[team]?.node.run(SKAction.fadeAlpha(to: 0.3, duration: 0.4))
			}
		})

		//Lowest place first, so the display works its way up to the winner rather than down
		for place in stride(from: NumbersScene.winColours.count - 1, through: 0, by: -1) {
			let teams = placings.filter { $0.place == place }.map { $0.team }
			if teams.isEmpty {
				continue
			}
			actions.append(SKAction.wait(forDuration: 0.45))
			actions.append(SKAction.run { [weak self] in
				teams.forEach { self?.light(team: $0, place: place) }
			})
		}

		self.run(SKAction.sequence(actions), withKey: "scoring")
	}

	/// The answer comes down onto the line as a bright bar, with its value in a tag underneath
	private func plantAnswer(_ answer: Int) {
		guard let scale = scale else { return }
		self.run(landSound)
		QuizWebSocket.shared?.pulseWhite()

		let x = xFor(Double(answer), in: scale)

		let bar = SKShapeNode(rect: CGRect(x: -4, y: 0, width: 8, height: panelTop - 10 - (axisY - 30)), cornerRadius: 4)
		bar.position = CGPoint(x: x, y: axisY - 30)
		bar.fillColor = NSColor.white
		bar.strokeColor = NSColor.white
		bar.glowWidth = 10
		bar.zPosition = 12
		bar.yScale = 0
		linePanel.addChild(bar)
		answerNodes.append(bar)
		let grow = SKAction.scaleY(to: 1, duration: 0.35)
		grow.timingMode = .easeOut
		bar.run(grow)

		let label = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		label.text = NumbersScene.format(Double(answer))
		label.fontSize = 50
		label.fontColor = NSColor.white
		label.horizontalAlignmentMode = .center
		label.verticalAlignmentMode = .center
		label.zPosition = 1

		//Over the tick labels, which it is allowed to hide, but held on the panel at the ends
		let tagWidth = label.frame.width + 44
		let tag = SKShapeNode(rectOf: CGSize(width: tagWidth, height: 72), cornerRadius: 36)
		tag.fillColor = NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.32, alpha: 1)
		tag.strokeColor = NSColor.white
		tag.lineWidth = 4
		tag.zPosition = 13
		tag.position = CGPoint(x: min(max(x, 70 + tagWidth / 2), size.width - 70 - tagWidth / 2), y: 56)
		tag.addChild(label)
		tag.setScale(0.2)
		linePanel.addChild(tag)
		answerNodes.append(tag)
		tag.run(SKAction.sequence([SKAction.scale(to: 1.2, duration: 0.18), SKAction.scale(to: 1.0, duration: 0.12)]))

		linePanel.addEmitter(named: "location", at: CGPoint(x: x, y: axisY), zPosition: 14) {
			$0.particleColor = NSColor.white
			$0.particleColorSequence = nil
			$0.particleSpeed = 200
			$0.particleBirthRate = 4000
			$0.numParticlesToEmit = 2000
		}
	}

	/// Colours a scoring team's box and marker to match its place
	private func light(team: Int, place: Int) {
		let colour = NumbersScene.winColours[place]
		let box = teamBoxes[team]
		box.light(colour)

		self.run(blopSound)
		
		if let marker = markers[team] {
			marker.disc.strokeColor = colour
			marker.disc.lineWidth = 7
			marker.disc.glowWidth = place == 0 ? 8 : 3
			marker.head.run(SKAction.sequence([SKAction.scale(to: 1.4, duration: 0.12),
											   SKAction.scale(to: 1.2, duration: 0.2)]))
		}

		//Give winners some stars
		if place == 0 {
			for _ in 0...3 {
				//Behind the badge, so the team number still shows through
				emitters.append(box.addEmitter(named: "locationstar", at: box.badgePosition, zPosition: 5.5, autoRemove: false))
			}
			QuizWebSocket.shared?.pulseTeamColour(team)
		}

		if place < 2 {
			emitters.append(box.addEmitter(named: "BuzzGlow", at: .zero, zPosition: 4, autoRemove: false) {
				$0.particlePositionRange = CGVector(dx: box.size.width + 40, dy: box.size.height + 30)
				$0.particleSpeed = 10
				$0.particleBirthRate = 70
				$0.particleAlpha = 0.4
				$0.particleScale = 0.8
			})
		}
	}

	/// The box colours for each place in `placings`: winner, second place, top half
	static let winColours = [
		NSColor(calibratedRed: 0.1, green: 1.0, blue: 0.3, alpha: 0.9),
		NSColor(calibratedRed: 1.0, green: 1.0, blue: 0.1, alpha: 0.9),
		NSColor(calibratedRed: 0.6, green: 0.6, blue: 1.0, alpha: 0.9),
	]

	/// Ranks the teams that guessed by how close they came, closest first. `place` is 0 for the
	/// winner(s), 1 for second place, 2 for the rest of roughly the top half, and nil for
	/// everyone else. Shared by the reveal and the controller's live list so they always agree.
	static func placings(guesses: [Int?], actualAnswer: Int) -> [(team: Int, guess: Int, distance: Int, place: Int?)] {
		let sorted = guesses.enumerated()
			.compactMap { team, guess in guess.map { (team: team, guess: $0, distance: abs($0 - actualAnswer)) } }
			.sorted { $0.distance < $1.distance }
		guard let closest = sorted.first else { return [] }

		var places = [Int?](repeating: nil, count: sorted.count)
		//We need to handle draws, so it isn't as easy as saying that index 0 is the winner, index 1 is the second etc.
		var win = 0
		var lastDist = closest.distance //Will be 0 if someone guessed correctly
		for (teNo, entry) in sorted.enumerated() {
			if win == 0 || win == 1 {
				if entry.distance > lastDist {
					win = win + 1
					lastDist = entry.distance
				}
			} else {
				if teNo > (sorted.count / 2 - 1) && entry.distance != sorted[teNo-1].distance {
					break
				}
			}
			places[teNo] = win
		}
		return zip(sorted, places).map { ($0.team, $0.guess, $0.distance, $1) }
	}


	//MARK: - Fitting the line
	//--------------------------------------------------------------------------------------------------------------------------

	/// The range the guesses mostly fall in
	private static func coreRange(of values: [Int]) -> (lo: Double, hi: Double)? {
		let sorted = values.sorted().map(Double.init)
		guard !sorted.isEmpty else { return nil }

		//The middle of the field, with the most extreme guesses at each end set aside
		let trim = Int((Double(sorted.count - 1) * 0.15).rounded())
		let coreLo = sorted[trim]
		let coreHi = sorted[sorted.count - 1 - trim]
		let median = sorted[sorted.count / 2]

		//How far beyond the middle a guess can be and still count. Never less than a quarter of
		//the guesses' own size, so that a field where everyone agrees does not throw out a
		//guess that is only a little different.
		let reach = 1.5 * max(coreHi - coreLo, abs(median) * 0.25, 1)
		let kept = sorted.filter { $0 >= coreLo - reach && $0 <= coreHi + reach }
		return (kept.first!, kept.last!)
	}

	/// Pads a range out a little and rounds its ends to a tick, with ticks on a 1, 2 or 5 step
	private static func niceScale(lo: Double, hi: Double, ticks: Int = 7) -> Scale {
		var lo = lo
		var hi = hi
		let nonNegative = lo >= 0
		if hi - lo < 1 {
			let pad = max(abs(lo) * 0.1, 5)
			lo -= pad
			hi += pad
		}
		let pad = (hi - lo) * 0.06
		lo -= pad
		hi += pad
		//Most numbers questions cannot go negative, so the line should not either
		if nonNegative {
			lo = max(lo, 0)
		}

		let raw = (hi - lo) / Double(ticks)
		let magnitude = pow(10, floor(log10(raw)))
		let step = max(1, [1.0, 2, 5, 10].map { $0 * magnitude }.first { $0 >= raw } ?? (10 * magnitude))
		return Scale(lo: floor(lo / step) * step, hi: ceil(hi / step) * step, step: step)
	}

	/// Where a value sits along the line, clamped to its ends
	private func xFor(_ value: Double, in scale: Scale) -> CGFloat {
		let fraction = (value - scale.lo) / (scale.hi - scale.lo)
		return lineLeft + CGFloat(min(1, max(0, fraction))) * (lineRight - lineLeft)
	}

	private static let formatter: NumberFormatter = {
		let f = NumberFormatter()
		f.numberStyle = .decimal
		return f
	}()

	static func format(_ value: Double) -> String {
		return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
	}

	private func makeTicks(_ scale: Scale) -> [(value: Double, node: SKNode)] {
		return stride(from: scale.lo, through: scale.hi + (scale.step / 2), by: scale.step).map { value in
			let isEnd = (value == scale.lo || value + (scale.step / 2) > scale.hi)
			let node = SKNode()
			node.position = CGPoint(x: xFor(value, in: scale), y: axisY)

			let mark = SKShapeNode(rect: CGRect(x: -2, y: -18, width: 4, height: 18))
			mark.fillColor = NSColor(white: 1.0, alpha: 0.75)
			mark.strokeColor = NSColor.clear
			node.addChild(mark)

			let label = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
			label.text = NumbersScene.format(value)
			label.fontSize = isEnd ? 38 : 32
			label.fontColor = NSColor(white: 1.0, alpha: isEnd ? 1.0 : 0.7)
			label.horizontalAlignmentMode = .center
			label.verticalAlignmentMode = .top
			label.position = CGPoint(x: 0, y: -26)
			node.addChild(label)

			tickLayer.addChild(node)
			return (value, node)
		}
	}

	/// Where every revealed guess goes on a given scale
	private func layOut(_ scale: Scale) -> [Int: Placement] {
		let guesses = countedGuesses.enumerated()
			.compactMap { team, guess in guess.map { (team: team, value: Double($0)) } }
			.sorted { $0.value < $1.value }
		let anchors = guesses.map { xFor($0.value, in: scale) }
		let packed = packMarkers(anchors: anchors, radius: markerRadius, maxRows: markerMaxRows,
								 low: lineLeft - 50, high: lineRight + 50)

		var result = [Int: Placement]()
		for (n, guess) in guesses.enumerated() {
			let side = guess.value < scale.lo ? -1 : (guess.value > scale.hi ? 1 : 0)
			result[guess.team] = Placement(x: packed[n].x,
										   y: markerBaseY + (CGFloat(packed[n].row) * markerRowSpacing),
										   anchorX: anchors[n], side: side)
		}
		return result
	}

	/// Slides the ticks and markers over to a new scale
	private func rescale(to newScale: Scale, duration: TimeInterval) -> SKAction {
		guard let oldScale = scale else { return SKAction.wait(forDuration: 0) }

		let oldTicks = ticks
		let newTicks = makeTicks(newScale)
		newTicks.forEach { $0.node.alpha = 0 }
		let from = placements
		let to = layOut(newScale)

		scale = newScale
		ticks = newTicks
		placements = to

		let move = SKAction.customAction(withDuration: duration) { [weak self] _, elapsed in
			guard let self = self else { return }
			//Smoothstep by hand: customAction does not handle timingMode reliably
			let t = min(1.0, max(0.0, elapsed / CGFloat(duration)))
			let eased = t * t * (3 - (2 * t))
			func slide(_ value: Double) -> CGFloat {
				let a = self.xFor(value, in: oldScale)
				return a + ((self.xFor(value, in: newScale) - a) * eased)
			}

			for tick in oldTicks {
				tick.node.position.x = slide(tick.value)
				tick.node.alpha = 1 - eased
			}
			for tick in newTicks {
				tick.node.position.x = slide(tick.value)
				tick.node.alpha = eased
			}
			for (team, marker) in self.markers {
				guard let a = from[team], let b = to[team] else { continue }
				self.apply(Placement(x: a.x + ((b.x - a.x) * eased),
									 y: a.y + ((b.y - a.y) * eased),
									 anchorX: a.anchorX + ((b.anchorX - a.anchorX) * eased),
									 side: eased < 0.5 ? a.side : b.side), to: marker)
			}
		}
		return SKAction.sequence([move, SKAction.run { oldTicks.forEach { $0.node.removeFromParent() } }])
	}


	//MARK: - Markers
	//--------------------------------------------------------------------------------------------------------------------------

	/// A team's guess: a numbered disc in the team's colour, on a leader line down to the value
	private func addMarker(team: Int, value: Int, at placement: Placement, delay: TimeInterval) {
		let colour = Utils.teamColour(team, saturation: 0.85)
		let marker = Marker(team: team, value: value, radius: markerRadius)
		marker.node.zPosition = 15
		marker.node.alpha = 0

		marker.stem.strokeColor = colour
		marker.stem.lineWidth = 3
		marker.stem.lineCap = .round
		marker.stem.zPosition = -1
		marker.node.addChild(marker.stem)

		for end in [marker.anchorDot, marker.arrow] {
			end.fillColor = colour
			end.strokeColor = NSColor.black
			end.lineWidth = 2
			end.zPosition = -1
			marker.node.addChild(end)
		}

		marker.head.setScale(0.2)
		marker.node.addChild(marker.head)

		marker.disc.fillColor = colour
		marker.disc.strokeColor = NSColor.black
		marker.disc.lineWidth = 3
		marker.head.addChild(marker.disc)

		let label = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		label.text = "\(team + 1)"
		label.fontSize = 30
		label.fontColor = NSColor.black
		label.horizontalAlignmentMode = .center
		label.verticalAlignmentMode = .center
		label.zPosition = 1
		marker.head.addChild(label)

		apply(placement, to: marker)
		linePanel.addChild(marker.node)
		markers[team] = marker

		let splash = SKAction.run { [weak self] in
			guard let self = self, let placement = self.placements[team] else { return }
			self.linePanel.addEmitter(named: "location", at: CGPoint(x: placement.anchorX, y: self.axisY), zPosition: 16) {
				$0.particleColor = colour
				$0.particleColorSequence = nil
				$0.particleSpeed = 100
				$0.particleBirthRate = 2000
				$0.numParticlesToEmit = 500
			}
		}
		marker.node.run(SKAction.sequence([SKAction.wait(forDuration: delay), splash,
										   SKAction.fadeAlpha(to: 1.0, duration: 0.15)]))
		marker.head.run(SKAction.sequence([SKAction.wait(forDuration: delay),
										   SKAction.scale(to: 1.15, duration: 0.15),
										   SKAction.scale(to: 1.0, duration: 0.1)]))
	}

	/// Puts a marker's disc where it goes and redraws its leader line back to the value
	private func apply(_ placement: Placement, to marker: Marker) {
		marker.node.position = CGPoint(x: placement.x, y: placement.y)

		//Where the guess really is, in the marker's own space
		let anchor = CGPoint(x: placement.anchorX - placement.x, y: axisY - placement.y)
		let path = CGMutablePath()
		path.move(to: CGPoint(x: 0, y: -markerRadius))
		path.addLine(to: anchor)
		marker.stem.path = path

		marker.anchorDot.position = anchor
		marker.anchorDot.isHidden = placement.side != 0
		marker.arrow.position = CGPoint(x: anchor.x + (CGFloat(placement.side) * 20), y: anchor.y)
		marker.arrow.xScale = placement.side < 0 ? -1 : 1
		marker.arrow.isHidden = placement.side == 0
	}


	//MARK: - Housekeeping
	//--------------------------------------------------------------------------------------------------------------------------

	override func reset() {
		QuizWebSocket.shared?.ledsOff()
		self.removeAction(forKey: "scoring")
		self.revealed = false
		self.scored = false

		for team in 0..<Settings.shared.numTeams {
			teamGuesses[team] = nil
		}
		teamBoxes.forEach { $0.clear() }
		refreshBoxes()

		scale = nil
		ticks.forEach { $0.node.removeFromParent() }
		ticks.removeAll()
		markers.values.forEach { $0.node.removeFromParent() }
		markers.removeAll()
		placements.removeAll()
		answerNodes.forEach { $0.removeFromParent() }
		answerNodes.removeAll()
		linePanel.removeAllActions()
		linePanel.alpha = 0

		for e in emitters {
			e.removeFromParent()
		}
		emitters.removeAll()
	}

}


/// A team's box in the numbers round
private final class NumberBoxNode: SKNode {

	let team: Int
	let size: CGSize
	let fontSize: CGFloat
	let bgBox: SKShapeNode
	let badge: SKShapeNode
	let numberLabel = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	/// The span the number has to stay within, in the box's own space
	private let numberLeft: CGFloat
	private let numberRight: CGFloat

	static let bgColour = TeamAnswerNode.bgColour
	static let disabledColour = TeamAnswerNode.disabledColour
	static let pendingColour = NSColor(calibratedWhite: 0.5, alpha: 1.0)

	private(set) var isPlaying = true

	var badgePosition: CGPoint { badge.position }

	init(team: Int, size: CGSize, position: CGPoint, fontSize: CGFloat) {
		self.team = team
		self.size = size
		self.fontSize = fontSize

		bgBox = SKShapeNode(rectOf: size, cornerRadius: min(18, size.height * 0.12))
		bgBox.fillColor = NumberBoxNode.bgColour
		bgBox.strokeColor = NSColor.white
		bgBox.lineWidth = 3
		bgBox.zPosition = 5

		let radius = min(size.height * 0.17, 36)
		badge = SKShapeNode(circleOfRadius: radius)
		badge.position = CGPoint(x: -(size.width / 2) + radius + 12, y: (size.height / 2) - radius - 12)
		badge.fillColor = Utils.teamColour(team, saturation: 0.85)
		badge.strokeColor = NSColor.black
		badge.lineWidth = 3
		badge.zPosition = 6

		let badgeLabel = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		badgeLabel.text = "\(team + 1)"
		badgeLabel.fontSize = radius * 1.1
		badgeLabel.fontColor = NSColor.black
		badgeLabel.horizontalAlignmentMode = .center
		badgeLabel.verticalAlignmentMode = .center
		badgeLabel.zPosition = 1
		badge.addChild(badgeLabel)

		//Numbers are centred in the box, but never allowed left of the badge's edge
		numberLeft = badge.position.x + radius + 8
		numberRight = (size.width / 2) - 16
		numberLabel.fontSize = fontSize
		numberLabel.fontColor = NSColor.black
		numberLabel.horizontalAlignmentMode = .center
		numberLabel.verticalAlignmentMode = .center
		numberLabel.position = CGPoint.zero
		numberLabel.zPosition = 6

		super.init()

		self.position = position
		self.addChild(bgBox)
		self.addChild(badge)
		self.addChild(numberLabel)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	/// Greys the whole box out when its team is not playing
	func setPlaying(_ playing: Bool) {
		isPlaying = playing
		bgBox.fillColor = playing ? NumberBoxNode.bgColour : NumberBoxNode.disabledColour
		badge.alpha = playing ? 1.0 : 0.35
	}

	/// Back to an empty box, ready for the next question
	func clear() {
		self.removeAllActions()
		bgBox.removeAllActions()
		self.alpha = 1.0
		self.setScale(1.0)
		numberLabel.text = ""
		bgBox.strokeColor = NSColor.white
		bgBox.lineWidth = 3
		setPlaying(isPlaying)
	}

	/// The team has answered, but nobody gets to see what yet
	func showPending() {
		setText("•••", colour: NumberBoxNode.pendingColour)
		bgBox.strokeColor = Utils.teamColour(team, saturation: 0.85)
		bgBox.lineWidth = 6

		//Sparks fade up into the team's colour and back out again
		let clear = Utils.teamColour(team, alpha: 0.0)
		let opaque = Utils.teamColour(team)
		self.addEmitter(named: "TextSceneSparks", at: badge.position, zPosition: 7) {
			$0.particleColorSequence = SKKeyframeSequence(
				keyframeValues: [clear, clear, opaque, opaque, clear],
				times: [0.0, 0.1, 0.1, 0.3, 0.7]
			)
		}
		pop(to: 1.12)
	}

	func showNumber(_ text: String, delay: TimeInterval) {
		self.run(SKAction.sequence([SKAction.wait(forDuration: delay), SKAction.run { [weak self] in
			self?.setText(text, colour: .black)
			self?.bgBox.strokeColor = NSColor.white
			self?.bgBox.lineWidth = 3
			self?.pop(to: 1.15)
		}]))
	}

	/// Scored: the box takes the colour of its place and stands slightly proud of the rest
	func light(_ colour: NSColor) {
		bgBox.run(SKAction.colorTransitionAction(fromColor: bgBox.fillColor, toColor: colour))
		self.run(SKAction.scale(to: 1.08, duration: 0.4))
	}

	/// Did not score: it sinks back without disappearing, so the room can still read it
	func dim() {
		self.run(SKAction.fadeAlpha(to: 0.45, duration: 0.4))
	}

	/// Shrinks the number until it fits across the box, never growing past the grid's size
	private func setText(_ text: String, colour: NSColor) {
		numberLabel.text = text
		numberLabel.fontColor = colour
		numberLabel.fontSize = fontSize
		while numberLabel.frame.width > (numberRight - numberLeft) && numberLabel.fontSize > 18 {
			numberLabel.fontSize -= 2
		}
		//Centred if it clears the badge, otherwise nudged right just far enough
		numberLabel.position.x = max(0, numberLeft + (numberLabel.frame.width / 2))
	}

	private func pop(to scale: CGFloat) {
		let grow = SKAction.scale(to: scale, duration: 0.05)
		grow.timingMode = .easeOut
		let shrink = SKAction.scale(to: 1, duration: 0.2)
		shrink.timingMode = .easeIn
		self.run(SKAction.sequence([grow, shrink]))
	}
}


// MARK: - Controller window

class NumbersPanel: NSObject, RoundPanel, NSTextFieldDelegate {

	let round = RoundType.numbers
	weak var host: ControllerWindowController!

	@IBOutlet weak var allowAnswers: NSButton!
	@IBOutlet weak var actualAnswer: NSTextField!
	@IBOutlet weak var teamGuesses: NSTextField!

	private var scene: NumbersScene { host.quizDisplay.numbersScene }

	func reset(presenting: Bool) {
		if presenting {
			actualAnswer.intValue = 0
		}
		allowAnswers.state = .on
		teamGuesses.stringValue = ""
	}

	var acceptingTextAnswers: Bool { allowAnswers.state == .on }

	/// Anything that is not a number is simply dropped
	func receive(textGuess: String, from team: Int) {
		if let value = Int(textGuess) {
			scene.teamGuess(teamid: team, guess: value)
		}
		updateGuesses()
	}

	/// Redraws the host's list of what each team has guessed, ranked against whatever is in the answer box right now.
	private func updateGuesses() {
		guard let answer = typedAnswer else {
			teamGuesses.stringValue = (0..<Settings.shared.numTeams).compactMap { team -> String? in
				if let tg = scene.teamGuesses[team] {
					return "Team \(team + 1): \(tg)"
				}
				return nil
			}.joined(separator: "\n")
			return
		}
		let marks = ["🟢", "🟡", "🔵"]
		teamGuesses.stringValue = NumbersScene.placings(guesses: scene.teamGuesses, actualAnswer: answer).map { entry in
			let mark = entry.place.map { marks[$0] } ?? "⚪️"
			return "\(mark) Team \(entry.team + 1): \(entry.guess)  (off by \(entry.distance))"
		}.joined(separator: "\n")
	}

	/// The answer as typed so far, or nil if the box does not hold a number
	private var typedAnswer: Int? {
		let text = actualAnswer.currentEditor()?.string ?? actualAnswer.stringValue
		if let number = (actualAnswer.formatter as? NumberFormatter)?.number(from: text) {
			return number.intValue
		}
		return Int(text)
	}

	func controlTextDidChange(_ obj: Notification) {
		if (obj.object as? NSTextField) === actualAnswer {
			updateGuesses()
		}
	}

	@IBAction func showAnswers(_ sender: NSButton) {
		allowAnswers.state = .off
		scene.showGuesses(actualAnswer: Int(actualAnswer.intValue))
	}
}
