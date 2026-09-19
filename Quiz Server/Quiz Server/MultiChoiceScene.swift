//
//  MultiChoiceScene.swift
//  Quiz Server
//
//  Created by Ian Gray on 2026-08-28.
//  Copyright © 2026 Russell Joyce & Ian Gray. All rights reserved.
//

import Foundation
import Cocoa
import SpriteKit

class MultiChoiceScene: QuizScene {

	static let minOptions = 2
	static let maxOptions = 6
	static let defaultOptions = 4

	static let timeouts = [10, 20, 30]
	static let defaultTimeout = 20

	enum LabelStyle: String {
		case letters = "A"
		case numbers = "1"
		func label(_ option: Int) -> String {
			switch self {
			case .letters: return String(UnicodeScalar(64 + UInt8(option)))
			case .numbers: return String(option)
			}
		}
	}

	private(set) var optionCount = MultiChoiceScene.defaultOptions
	private(set) var labelStyle = LabelStyle.letters
	private(set) var timeout = MultiChoiceScene.defaultTimeout
	private(set) var counting = false
	private(set) var revealed = false

	var teamGuesses = [Int?]()
	private var participating = [Bool]()

	var teamBoxes = [TeamGuessNode]()

	fileprivate var time: Float = Float(MultiChoiceScene.defaultTimeout)
	fileprivate var timer: Timer?
	fileprivate var tickSounds: Bool = true

	let guessSound = SKAction.playSoundFileNamed("notification-1.mp3", waitForCompletion: false)
	let tickSound = SKAction.playSoundFileNamed("notification-2.mp3", waitForCompletion: false)
	let tickEnd = SKAction.playSoundFileNamed("notification-long.mp3", waitForCompletion: false)

	var bg1: SKEmitterNode? = nil
	var bg2: SKEmitterNode? = nil
	
	//MARK: - The timer bar

	/// Geometry of the bar along the bottom. The grid of team boxes gets everything above it.
	private static let barMargin: CGFloat = 120
	private static let barHeight: CGFloat = 44
	private static let barBottom: CGFloat = 56

	private var barTrack: SKShapeNode!
	/// A shape rather than a sprite so that its ends can be rounded like the track's.
	/// Sprites have no corner radius, and a rounded texture stretched to width distorts.
	private var barFill: SKShapeNode!

	private var barWidth: CGFloat {
		self.size.width - (2 * MultiChoiceScene.barMargin)
	}

	private var barCentreY: CGFloat {
		MultiChoiceScene.barBottom + (MultiChoiceScene.barHeight / 2)
	}

	static let barColourStart = NSColor(calibratedHue: 0.33, saturation: 0.75, brightness: 0.9, alpha: 1.0)
	static let barColourMid = NSColor(calibratedHue: 0.13, saturation: 0.85, brightness: 0.95, alpha: 1.0)
	static let barColourEnd = NSColor(calibratedHue: 0.0, saturation: 0.8, brightness: 0.95, alpha: 1.0)

	/// The bar with `fraction` of its time left, as a capsule matching the track's ends.
	///
	/// Once the bar is narrower than it is tall the radius follows the width instead of the
	/// height, so the last moments shrink to a dot rather than to a sliver with square ends.
	private func barPath(fraction: CGFloat) -> CGPath {
		let height = MultiChoiceScene.barHeight
		let width = max(0, barWidth * min(max(fraction, 0), 1))
		let radius = min(height / 2, width / 2)
		return CGPath(roundedRect: CGRect(x: 0, y: -height / 2, width: width, height: height),
					  cornerWidth: radius, cornerHeight: radius, transform: nil)
	}

	/// Green through amber to red, by how much time is left
	private static func barColour(fraction: CGFloat) -> NSColor {
		let gone = 1 - min(max(fraction, 0), 1)
		if gone <= 0.6 {
			return blend(barColourStart, barColourMid, gone / 0.6)
		}
		return blend(barColourMid, barColourEnd, (gone - 0.6) / 0.4)
	}

	private static func blend(_ from: NSColor, _ to: NSColor, _ t: CGFloat) -> NSColor {
		return from.blended(withFraction: min(max(t, 0), 1), of: to) ?? to
	}


	override func buildScene() {
		self.backgroundColor = .black
		bg1 = addBokehBackground(replacing: bg1, textureName: "flake", zPosition: 1)
		bg2 = addBokehBackground(replacing: bg2, textureName: "spark", zPosition: 1)

		//The track the bar drains along, so that the time already gone is still visible.
		barTrack = SKShapeNode(rect: CGRect(x: MultiChoiceScene.barMargin, y: MultiChoiceScene.barBottom, width: barWidth, height: MultiChoiceScene.barHeight),
							   cornerRadius: MultiChoiceScene.barHeight / 2)
		barTrack.fillColor = NSColor(calibratedWhite: 1.0, alpha: 0.12)
		barTrack.strokeColor = NSColor(calibratedWhite: 1.0, alpha: 0.35)
		barTrack.lineWidth = 2.0
		barTrack.zPosition = 4
		self.addChild(barTrack)

		barFill = SKShapeNode()
		barFill.path = barPath(fraction: 1)
		barFill.fillColor = MultiChoiceScene.barColourStart
		barFill.lineWidth = 0
		barFill.strokeColor = .clear
		barFill.position = CGPoint(x: MultiChoiceScene.barMargin, y: barCentreY)
		barFill.zPosition = 5
		self.addChild(barFill)

		let layout = teamSquareGridLayout(top: self.size.height - 90, bottom: MultiChoiceScene.barBottom + MultiChoiceScene.barHeight + 60)
		for team in 0..<Settings.shared.numTeams {
			let box = TeamGuessNode(team: team, width: layout.boxWidth, height: layout.boxHeight, position: layout.positions[team], fontsize: layout.fontSize, outlineColour: .black)
			box.zPosition = 1
			teamBoxes.append(box)
			self.addChild(box)
		}

		reset()
	}


	//MARK: - Set up

	func configure(options: Int, style: LabelStyle, timeout seconds: Int) -> String {
		optionCount = min(max(options, MultiChoiceScene.minOptions), MultiChoiceScene.maxOptions)
		labelStyle = style
		timeout = seconds
		reset()
		return "\(optionCount),\(labelStyle.rawValue)"
	}

	/// The payload for an 'mo' message describing the grid as it stands.
	var optionsMessage: String {
		return "\(optionCount),\(labelStyle.rawValue)"
	}

	override func reset() {
		self.timer?.invalidate()
		self.timer = nil
		QuizWebSocket.shared?.ledsOff()
		self.counting = false
		self.revealed = false
		self.time = Float(timeout)

		teamGuesses = [Int?](repeating: nil, count: Settings.shared.numTeams)

		barFill.removeAllActions()
		barFill.path = barPath(fraction: 1)
		barFill.fillColor = MultiChoiceScene.barColourStart
		barFill.alpha = 1.0

		refreshBoxes()
	}

	override func teardown() {
		timer?.invalidate()
		timer = nil
	}

	override func setParticipating(_ teams: [Bool]) {
		participating = teams
		if revealed {
			showGuesses()
		} else {
			refreshBoxes()
		}
	}

	private func isParticipating(_ team: Int) -> Bool {
		return team < participating.count ? participating[team] : true
	}

	private func refreshBoxes() {
		for team in 0..<min(Settings.shared.numTeams, teamBoxes.count) {
			teamBoxes[team].clearReveal()
			teamBoxes[team].guessLabel.text = String(team + 1)
			teamBoxes[team].setEnabled(isParticipating(team))
		}
	}


	//MARK: - Running

	func start(sounds: Bool) {
		reset()

		tickSounds = sounds
		counting = true
		self.time = Float(timeout)

		timer = Timer(timeInterval: 0.5, target: self, selector: #selector(MultiChoiceScene.tick), userInfo: nil, repeats: true)
		RunLoop.main.add(timer!, forMode: RunLoop.Mode.common)

		self.sparkAtBarEnd()
		
		let total = TimeInterval(timeout)
		barFill.run(SKAction.customAction(withDuration: total) { [weak self] node, elapsed in
			guard let self = self, let shape = node as? SKShapeNode else { return }
			let fraction = 1 - (elapsed / CGFloat(total))
			shape.path = self.barPath(fraction: fraction)
			shape.fillColor = MultiChoiceScene.barColour(fraction: fraction)
		})

		QuizWebSocket.shared?.setCounterValue(200)

		if sounds {
			self.run(self.tickSound)
		}
	}

	/// Ends the question early, as if the time had run out.
	func stop() {
		guard counting else { return }
		time = 0
		finish()
	}

	@objc func tick() {
		self.run(SKAction.run({ () -> Void in
			self.time -= 0.5
			QuizWebSocket.shared?.setCounterValue(Int(200.0 * Float(self.time) / Float(self.timeout)))

			if self.time > 0 {
				self.sparkAtBarEnd()
				if self.tickSounds {
					self.run(self.tickSound)
				}
			} else {
				self.finish()
			}
		}))
	}

	private func sparkAtBarEnd() {
		let fraction = CGFloat(max(0, time)) / CGFloat(max(1, timeout))
		self.addEmitter(named: "SparksPointless", at: CGPoint(x: (MultiChoiceScene.barMargin - 10) + (barWidth * fraction), y: barCentreY), zPosition: 6) {
			$0.numParticlesToEmit = 120
		}
	}

	private func finish() {
		counting = false
		timer?.invalidate()
		timer = nil

		barFill.removeAllActions()
		barFill.path = barPath(fraction: 0)

		if tickSounds {
			self.run(self.tickEnd)
		}
		QuizWebSocket.shared?.pulseWhite()
		QuizWebSocket.shared?.setCounterValue(0)

		showGuesses()
	}


	//MARK: - Answers

	/// A team has picked an option. Ignored unless the question is actually running
	func teamGuess(teamid: Int, option: Int) {
		guard counting,
			  teamid >= 0, teamid < teamGuesses.count,
			  isParticipating(teamid),
			  option >= 1, option <= optionCount else {
			return
		}
		teamGuesses[teamid] = option
		teamBoxes[teamid].setIfGuessed(true)
		teamBoxes[teamid].pulseBox()
		
		if tickSounds {
			self.run(self.guessSound)
		}
	}

	private func showGuesses() {
		revealed = true
		for team in 0..<min(Settings.shared.numTeams, teamBoxes.count) {
			let box = teamBoxes[team]
			box.clearReveal()

			guard isParticipating(team) else {
				box.guessLabel.text = String(team + 1)
				box.setEnabled(false)
				continue
			}

			if let guess = teamGuesses[team] {
				box.guessLabel.text = "\(team + 1): \(labelStyle.label(guess))"
				box.setOptionColour(guess, of: optionCount)
			} else {
				box.guessLabel.text = "\(team + 1): –"
				box.setEnabled(false)
			}
		}
	}

	func showAnswer(option: Int) {
		guard option >= 1, option <= optionCount else {
			return
		}
		if counting {
			stop()
		} else if !revealed {
			showGuesses()
		}

		for team in 0..<min(Settings.shared.numTeams, teamBoxes.count) {
			guard isParticipating(team) else { continue }
			if teamGuesses[team] == option {
				teamBoxes[team].highlightAsCorrect()
			} else {
				teamBoxes[team].fadeAsWrong()
			}
		}

		QuizWebSocket.shared?.pulseGreen()
	}
}


// MARK: - Controller window

class MultiChoicePanel: NSObject, RoundPanel {

	let round = RoundType.multichoice
	weak var host: ControllerWindowController!

	@IBOutlet weak var optionsStepper: NSStepper!
	@IBOutlet weak var optionsNumber: NSTextField!
	@IBOutlet weak var styleToggle: NSButton!
	@IBOutlet weak var sounds: NSButton!
	@IBOutlet weak var startButton: NSButton!
	@IBOutlet weak var teamGuesses: NSTextField!
	@IBOutlet weak var time10: NSButton!
	@IBOutlet weak var time20: NSButton!
	@IBOutlet weak var time30: NSButton!
	@IBOutlet weak var answer1: NSButton!
	@IBOutlet weak var answer2: NSButton!
	@IBOutlet weak var answer3: NSButton!
	@IBOutlet weak var answer4: NSButton!
	@IBOutlet weak var answer5: NSButton!
	@IBOutlet weak var answer6: NSButton!

	/// Seconds on the clock, as chosen by the three time buttons.
	private var timeout = MultiChoiceScene.defaultTimeout

	private var scene: MultiChoiceScene { host.quizDisplay.multiChoiceScene }

	private var answerButtons: [NSButton?] {
		[answer1, answer2, answer3, answer4, answer5, answer6]
	}

	private var timeButtons: [NSButton?] {
		[time10, time20, time30]
	}

	private var style: MultiChoiceScene.LabelStyle {
		(styleToggle?.state ?? .on) == .on ? .letters : .numbers
	}

	func reset(presenting: Bool) {
		if presenting {
			timeout = MultiChoiceScene.defaultTimeout
			syncTimeButtons()
		}
		teamGuesses?.stringValue = ""
		pushOptions()
	}

	var clientRoundState: [String] { ["mo" + scene.optionsMessage] }

	func clientTeamState(team: Int) -> [String] {
		let guesses = scene.teamGuesses
		guard team < guesses.count, let option = guesses[team] else {
			return []
		}
		return ["ms\(option)"]
	}

	@IBAction func optionsStepperChanged(_ sender: Any) {
		pushOptions()
	}

	@IBAction func styleToggled(_ sender: Any) {
		styleToggle.title = style == .letters ? "Letters (A B C)" : "Numbers (1 2 3)"
		pushOptions()
	}

	/// The three time buttons carry the time length as their tag
	@IBAction func timeChanged(_ sender: NSButton) {
		timeout = sender.tag
		syncTimeButtons()
		pushOptions()
	}

	@IBAction func start(_ sender: NSButton) {
		if scene.counting {
			scene.stop()
		} else {
			//The teams' phones still show the last question's selection until they are told
			//otherwise, and 'mo' is what clears them.
			host.socketWriteIfConnected("mo" + scene.optionsMessage)
			teamGuesses?.stringValue = ""
			scene.start(sounds: sounds.state == .on)
		}
		updateStartButton()
	}

	@IBAction func answerPressed(_ sender: NSButton) {
		scene.showAnswer(option: sender.tag)
		updateStartButton()
		updateGuesses()
	}

	/// A team's answer arriving from their phone. Returns the option the round accepted,
	/// or nil if it turned the answer down, in which case the tile is left unlit.
	func teamGuessed(team: Int, option: Int) -> Int? {
		scene.teamGuess(teamid: team, option: option)
		updateGuesses()
		return team < scene.teamGuesses.count ? scene.teamGuesses[team] : nil
	}

	var counting: Bool { scene.counting }

	private func syncTimeButtons() {
		for button in timeButtons {
			button?.state = (button?.tag == timeout) ? .on : .off
		}
	}

	private func pushOptions() {
		if scene.counting {
			print("Multiple choice: ignoring a setup change while the question is running")
			syncControls()
			return
		}

		let options = Int(optionsStepper?.intValue ?? Int32(MultiChoiceScene.defaultOptions))
		let payload = scene.configure(options: options, style: style, timeout: timeout)
		host.socketWriteIfConnected("mo" + payload)
		teamGuesses?.stringValue = ""
		syncControls()
	}

	/// Puts the controls back in step with whatever the scene actually holds.
	private func syncControls() {
		optionsStepper?.intValue = Int32(scene.optionCount)
		optionsNumber?.stringValue = String(scene.optionCount)

		//Only the answers that exist can be the right one
		for (index, button) in answerButtons.enumerated() {
			let option = index + 1
			button?.title = scene.labelStyle.label(option)
			button?.isEnabled = option <= scene.optionCount
		}
		updateStartButton()
	}

	private func updateStartButton() {
		startButton?.title = scene.counting ? "Stop" : "Start"
	}

	private func updateGuesses() {
		teamGuesses?.stringValue = (0..<Settings.shared.numTeams).compactMap { team -> String? in
			guard team < scene.teamGuesses.count, let guess = scene.teamGuesses[team] else {
				return nil
			}
			return "Team \(team + 1): \(scene.labelStyle.label(guess))"
		}.joined(separator: "\n")
	}
}
