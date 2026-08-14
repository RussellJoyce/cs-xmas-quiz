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

	//MARK: - Geometry
	private let barMargin: CGFloat = 110
	private let barHeight: CGFloat = 180
	private let barCentreY: CGFloat = 600

	/// Markers sit in rows above the bar, moving up a row when they would otherwise collide.
	private let markerBaseY: CGFloat = 745
	private let markerRowSpacing: CGFloat = 92
	private let markerRadius: CGFloat = 42
	private let markerMaxRows = 3

	private var barLeft: CGFloat { barMargin }
	private var barWidth: CGFloat { size.width - (barMargin * 2) }
	private var barTop: CGFloat { barCentreY + (barHeight / 2) }
	private var barBottom: CGFloat { barCentreY - (barHeight / 2) }

	//MARK: - Nodes
	private var bar: SKSpriteNode!
	private var sweepLine: SKShapeNode!
	private var sweepLabel: OutlinedLabelNode!
	/// The revealed markers, keyed by zero-based team number.
	private var markerNodes = [Int: SKNode]()
	private var targetNodes = [SKNode]()
	private var teamStrip: TeamStripNode!
	private var snow: SKEmitterNode?

	//MARK: - Sound
	let blopSound = SKAction.playSoundFileNamed("blop", waitForCompletion: false)
	let revealSound = SKAction.playSoundFileNamed("display_sweep", waitForCompletion: false)
	let landSound = SKAction.playSoundFileNamed("counter_score", waitForCompletion: false)
	/// The run-up under the sweep. An AVAudioPlayer rather than an SKAction because it has
	/// to be cut off the moment the sweep lands, which is the same thing PointlessScene does.
	private var counterPlayer: AVAudioPlayer?


	override func buildScene() {
		let gradientImage = verticalGradientImage(size: self.size,
				colors: [NSColor(calibratedRed: 0.06, green: 0.02, blue: 0.16, alpha: 1), NSColor.black])
		addBackground(texture: SKTexture(image: gradientImage))

		addBar()
		addScale()
		addSweep()

		//Snappier than the idle screen's: the numbers here are bookkeeping during a live
		//round, so they say their piece and get out of the way of the bar
		teamStrip = TeamStripNode(mode: .remaining, width: self.size.width,
								  timing: TeamStripNode.Timing(fadeIn: 0,
															   popScale: 1.25,
															   popDuration: 0.2,
															   colourDelay: 0,
															   colourDuration: 0.4,
															   fadeDelay: 0.8,
															   fadeOut: 1.0))
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

	/// A team has moved their handle
	func teamGuess(team: Int, value: Int) {
		guard !revealed else { return }
		guard team >= 0 && team < teamGuesses.count else { return }
		guard value >= WavelengthScene.minValue && value <= WavelengthScene.maxValue else {
			print("Wavelength guess out of range from team \(team + 1): \(value)")
			return
		}

		let firstAnswer = (teamGuesses[team] == nil)
		teamGuesses[team] = value

		if firstAnswer {
			self.run(blopSound)
			QuizWebSocket.shared?.pulseTeamColour(team)
			teamStrip.trigger(team: team)
		} else {
			//A team fidgeting with their handle should not sound like a new answer
			QuizWebSocket.shared?.pulseTeamColourQuick(team)
		}
	}


	/// Puts every team's number on the bar where they guessed, and stops taking guesses.
	func reveal() {
		guard !revealed else { return }
		revealed = true

		self.run(revealSound)
		QuizWebSocket.shared?.pulseWhite()

		//Ascending, so that the row packing below only ever has to look leftwards
		let guesses = teamGuesses.enumerated()
			.compactMap { (team, value) in value.map { (team: team, value: $0) } }
			.sorted { $0.value < $1.value }

		//Markers that would sit on top of each other are pushed up a row
		var lastXInRow = [CGFloat]()
		let minSeparation = (markerRadius * 2) + 8

		for (order, guess) in guesses.enumerated() {
			let x = xFor(value: guess.value)
			var row = 0
			while row < lastXInRow.count && (x - lastXInRow[row]) < minSeparation {
				row += 1
			}
			if row < lastXInRow.count {
				lastXInRow[row] = x
			} else {
				lastXInRow.append(x)
			}

			addMarker(team: guess.team, value: guess.value, row: row % markerMaxRows, delay: Double(order) * 0.07)
		}
	}


	/// Runs the sweep from the bottom of the bar up to the number the host rolled.
	func score(target: Int) {
		guard target >= WavelengthScene.minValue && target <= WavelengthScene.maxValue else {
			print("Wavelength target out of range: \(target)")
			return
		}
		guard !swept else { return }

		//In case we forgot to reveal
		reveal()
		swept = true

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

			//Smoothstep by hand: customAction does not honour timingMode reliably, and the
			//sweep wants to ease out of the start and into the target
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
		star.addEmitter(named: "locationstar", at: CGPoint(x: x, y: barCentreY), zPosition: 21, autoRemove: false)
		star.addEmitter(named: "location", at: CGPoint(x: x, y: barCentreY), zPosition: 22) {
			$0.particleColor = NSColor.white
			$0.particleColorSequence = nil
			$0.particleSpeed = 220
			$0.particleBirthRate = 4000
			$0.numParticlesToEmit = 2500
		}
	}


	//MARK: - Markers
	//--------------------------------------------------------------------------------------------------------------------------

	/// A team's guess: a numbered disc in the team's colour, sitting above the bar on a stem
	/// that points at the exact value they picked.
	private func addMarker(team: Int, value: Int, row: Int, delay: TimeInterval) {
		let x = xFor(value: value)
		let y = markerBaseY + (CGFloat(row) * markerRowSpacing)
		let colour = Utils.teamColour(team, saturation: 0.85)

		let marker = SKNode()
		marker.position = CGPoint(x: x, y: y)
		marker.zPosition = 15
		marker.alpha = 0
		marker.setScale(0.2)

		//Stem from the bottom of the disc down to the top of the bar, in the marker's own
		//space, so a marker on a higher row simply grows a longer one
		let stem = SKShapeNode(rect: CGRect(x: -2, y: barTop - y, width: 4, height: y - barTop - markerRadius))
		stem.fillColor = colour
		stem.strokeColor = colour
		stem.zPosition = -1
		marker.addChild(stem)

		let disc = SKShapeNode(circleOfRadius: markerRadius)
		disc.fillColor = colour
		disc.strokeColor = NSColor.black
		disc.lineWidth = 4
		marker.addChild(disc)

		let label = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		label.text = "\(team + 1)"
		label.fontSize = 46
		label.fontColor = NSColor.black
		label.horizontalAlignmentMode = .center
		label.verticalAlignmentMode = .center
		label.zPosition = 1
		marker.addChild(label)

		self.addChild(marker)
		markerNodes[team] = marker

		//Markers pop in one after another rather than all at once, so the spread reads
		let appear = SKAction.group([
			SKAction.fadeAlpha(to: 1.0, duration: 0.15),
			SKAction.sequence([SKAction.scale(to: 1.15, duration: 0.15), SKAction.scale(to: 1.0, duration: 0.1)])
		])
		let splash = SKAction.run { [weak self] in
			guard let self = self else { return }
			self.addEmitter(named: "location", at: CGPoint(x: x, y: self.barCentreY), zPosition: 16) {
				$0.particleColor = colour
				$0.particleColorSequence = nil
				$0.particleSpeed = 140
				$0.particleBirthRate = 2500
				$0.numParticlesToEmit = 900
			}
		}
		marker.run(SKAction.sequence([SKAction.wait(forDuration: delay), splash, appear]))
	}

	/// The sweep has just gone past this team's guess.
	private func popMarker(team: Int) {
		guard let marker = markerNodes[team] else { return }

		self.run(blopSound)
		marker.run(SKAction.sequence([
			SKAction.scale(to: 1.35, duration: 0.08),
			SKAction.scale(to: 1.0, duration: 0.15)
		]))
	}


	//MARK: - Housekeeping
	//--------------------------------------------------------------------------------------------------------------------------

	override func reset() {
		QuizWebSocket.shared?.ledsOff()
		self.removeAction(forKey: "sweep")
		counterPlayer?.stop()
		counterPlayer?.currentTime = 0

		revealed = false
		swept = false
		teamGuesses = [Int?](repeating: nil, count: Settings.shared.numTeams)

		markerNodes.values.forEach { $0.removeFromParent() }
		markerNodes.removeAll()
		targetNodes.forEach { $0.removeFromParent() }
		targetNodes.removeAll()

		sweepLabel?.removeAllActions()
		sweepLabel?.setScale(1.0)
		positionSweep(at: CGFloat(WavelengthScene.minValue))
		sweepLabel?.text = ""
		sweepLine?.isHidden = true

		teamStrip.reset()
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
