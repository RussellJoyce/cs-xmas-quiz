//
//  TextScene.swift
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
	var teamBoxes = [TeamAnswerNode]()
	let blopSound = SKAction.playSoundFileNamed("blop", waitForCompletion: false)
	let hornSound = SKAction.playSoundFileNamed("tada", waitForCompletion: false)
	var revealed = false
	var emitters = [SKEmitterNode]()

	override func buildScene() {
		self.revealed = false
		
		addBackground(imageNamed: "blue-snow")

		let layout = teamGridLayout()
		for team in 0..<Settings.shared.numTeams {
			let box = TeamAnswerNode(team: team, width: 700, height: layout.boxHeight, position: layout.positions[team], fontSize: layout.fontSize)
			box.zPosition = 1
			teamBoxes.append(box)
			self.addChild(box)
			teamGuesses.append(nil)
		}
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

	func teamGuess(teamid : Int, guess : Int) {
		if teamid >= 0 && teamid < Settings.shared.numTeams && isParticipating(teamid) {
			self.run(blopSound)
			QuizWebSocket.shared?.pulseTeamColour(teamid)
			teamGuesses[teamid] = guess
			teamBoxes[teamid].resetTextSize()
			teamBoxes[teamid].guessLabel.text = ""
			teamBoxes[teamid].singleLabel.text = "••••••••"
			
			teamBoxes[teamid].emphasise()
		}
	}
	
	func showGuesses(actualAnswer : Int) {
		//First press just plays a big honk and shows everything
		if(!revealed) {
			self.run(hornSound)
			QuizWebSocket.shared?.pulseWhite()
			
			let emoji = ["tree", "santa", "spaceinvader", "robot", "snowman", "present", "floppydisk", "snowflake"]
			
			for i in 0..<80 {
				let point = CGPoint(x: Int(arc4random_uniform(UInt32(self.size.width))), y: Int(arc4random_uniform(UInt32(self.size.height))))
				self.addEmitter(named: "emojsplosion", at: point, zPosition: CGFloat(100 + i)) {
					$0.particleTexture = SKTexture(imageNamed: emoji[Int(arc4random_uniform(UInt32(emoji.count)))])
				}
			}
			
			for team in 0..<Settings.shared.numTeams {
				if let tg = teamGuesses[team] {
					teamBoxes[team].resetTextSize()
					teamBoxes[team].singleLabel.text = "\(tg)"
					teamBoxes[team].guessLabel.text = ""
				} else {
					teamBoxes[team].guessLabel.text = ""
					teamBoxes[team].singleLabel.text = ""
				}
			}
			
			revealed = true
			
		}
		//Second press colours everything to show team scores
		else {
			//Scored on what the boxes show, so a guess that arrives after the reveal does not count
			let revealedGuesses = teamBoxes.map { Int($0.singleLabel.text ?? "") }

			for entry in NumbersScene.placings(guesses: revealedGuesses, actualAnswer: actualAnswer) {
				guard let win = entry.place else { continue }

				//Animate the team box to the target colour to indicate "win level"
				teamBoxes[entry.team].bgBox.run(SKAction.colorTransitionAction(fromColor: TeamAnswerNode.bgColour, toColor: NumbersScene.winColours[win]))
				teamBoxes[entry.team].bgBox.run(SKAction.scale(to: 1.1, duration: 0.5))

				//Give winners some stars
				if win == 0 {
					for _ in 0...5 {
						var starpoint : CGPoint = teamBoxes[entry.team].bgBox.centrePoint
						//starpoint.y += CGFloat(Int.random(in: -70...70))
						starpoint.x -= 310
						emitters.append(teamBoxes[entry.team].addEmitter(named: "locationstar", at: starpoint, zPosition: 5.0, autoRemove: false))
					}
				}

				if win < 2 {
					addGlowParticles(team: entry.team)
				}
			}
		}
	}

	/// The box colours for each place in `placings`: winner, second place, top half
	static let winColours = [
		NSColor(calibratedRed: 0.1, green: 1.0, blue: 0.3, alpha: 0.9),
		NSColor(calibratedRed: 1.0, green: 1.0, blue: 0.1, alpha: 0.9),
		NSColor(calibratedRed: 0.6, green: 0.6, blue: 1.0, alpha: 0.9),
	]

	/// Ranks the teams that guessed by how close they came, closest first. `place` is 0 for the
	/// winner(s), 1 for second place, 2 for the rest of roughly the top half, and nil for everyone else.
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
	
	func addGlowParticles(team : Int) {
		let pstar = teamBoxes[team].addEmitter(named: "BuzzGlow",
											   at: teamBoxes[team].bgBox.centrePoint,
											   zPosition: 5.0,
											   autoRemove: false) {
			$0.particlePositionRange = CGVector(dx: 750, dy: 130)
			$0.particleSpeed = 10
			$0.particleBirthRate = 70
			$0.particleAlpha = 0.4
			$0.particleScale = 0.8
		}
		emitters.append(pstar)
	}
	

	override func reset() {
		QuizWebSocket.shared?.ledsOff()
		self.revealed = false
		
		for team in 0..<Settings.shared.numTeams {
			teamGuesses[team] = nil
			teamBoxes[team].guessLabel.text = ""
			teamBoxes[team].singleLabel.text = ""
			teamBoxes[team].resetTextSize()
			teamBoxes[team].bgBox.fillColor = TeamAnswerNode.bgColour
			teamBoxes[team].bgBox.run(SKAction.scale(to: 1, duration: 0.2))
		}
		refreshBoxes()

		for e in emitters {
			e.removeFromParent()
		}
		emitters.removeAll()
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
