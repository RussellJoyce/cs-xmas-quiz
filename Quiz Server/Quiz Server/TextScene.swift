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

class TextScene: QuizScene {
	
	var teamGuesses = [(roundid: Int, guess: String)?]()
	var teamBoxes = [TeamAnswerNode]()
	let blopSound = SKAction.playSoundFileNamed("blop", waitForCompletion: false)
	//let hornSound = SKAction.playSoundFileNamed("airhorn", waitForCompletion: false)
	let hornSound = SKAction.playSoundFileNamed("drums", waitForCompletion: false)
	var uniques: [String]?
	var emitters = [SKEmitterNode]()
	
	override func buildScene() {
		teamGuesses = [(roundid: Int, guess: String)?]()
		
		addBackground(imageNamed: "background2")

		let layout = teamGridLayout()
		for team in 0..<Settings.shared.numTeams {
			let box = TeamAnswerNode(team: team, width: 700, height: layout.boxHeight,
									 position: layout.positions[team], fontSize: layout.fontSize, showsRoundLabel: true)

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

	func roundPoints(_ roundid : Int) -> String {
		switch(roundid) {
		case 1:
			return "4 pts"
		case 2:
			return "3 pts"
		case 3:
			return "2 pts"
		case 4:
			return "1 pt"
		default:
			return "0 pts"
		}
	}
	
	func teamGuess(teamid : Int, guess : String, roundid : Int, showroundno : Bool) {
		if teamid >= 0 && teamid < Settings.shared.numTeams && isParticipating(teamid) {
			self.run(blopSound)
			QuizWebSocket.shared?.pulseTeamColour(teamid)
			teamGuesses[teamid] = (roundid, guess)
			teamBoxes[teamid].resetTextSize()
			if showroundno {
				teamBoxes[teamid].guessLabel.text = "••••••••"
				teamBoxes[teamid].roundLabel.text = "(at Clue \(roundid) - "  + roundPoints(roundid) + ")"
				teamBoxes[teamid].singleLabel.text = ""
			} else {
				teamBoxes[teamid].guessLabel.text = ""
				teamBoxes[teamid].roundLabel.text = ""
				teamBoxes[teamid].singleLabel.text = "••••••••"
			}
			teamBoxes[teamid].emphasise()
		}
	}
	
	func initUnique(file: String) {
		uniques = nil
		guard let data = Utils.readQuestionFile(file) else {
			return
		}
		uniques = data.components(separatedBy: .newlines)
			.map { Utils.sanitiseString($0) }
			.filter { $0 != "" }
	}
	
	func showGuesses(showroundno : Bool) {
		self.run(hornSound)
		QuizWebSocket.shared?.pulseWhite()
		
		let emoji = ["tree", "santa", "spaceinvader", "robot", "snowman", "present", "floppydisk", "snowflake"]
		
		for i in 0..<100 {
			self.addEmitter(named: "Shower",
							at: CGPoint(x: self.centrePoint.x, y: self.centrePoint.y+100),
							zPosition: CGFloat(100 + i)) {
				$0.particleTexture = SKTexture(imageNamed: emoji[Int(arc4random_uniform(UInt32(emoji.count)))])
			}
		}
		
		for team in 0..<Settings.shared.numTeams {
			if let tg = teamGuesses[team] {
				
				//Long answers shrink so they fit across the box, but nothing grows past the
				//size the grid allows for the current number of teams
				let preferredSize : CGFloat = (tg.guess.count > 13) ? 40 : 60
				teamBoxes[team].setTextSize(size: min(preferredSize, teamBoxes[team].fontSize))
				
				if showroundno {
					teamBoxes[team].guessLabel.text = "\(tg.guess)"
					teamBoxes[team].roundLabel.text = "(at Clue \(tg.roundid) - " + roundPoints(tg.roundid) + ")"
					teamBoxes[team].singleLabel.text = ""
				} else {
					teamBoxes[team].singleLabel.text = "\(tg.guess)"
					teamBoxes[team].guessLabel.text = ""
					teamBoxes[team].roundLabel.text = ""
				}
			} else {
				teamBoxes[team].guessLabel.text = ""
				teamBoxes[team].roundLabel.text = ""
				teamBoxes[team].singleLabel.text = ""
			}
		}
	}
	
	func isTeamAnswerUnique(_ team : Int) -> Bool {
		if let ourguess = teamGuesses[team] {
			for tid in 0..<Settings.shared.numTeams {
				if tid != team {
					if let tg = teamGuesses[tid] {
						if tg.guess == ourguess.guess {
							return false
						}
					}
				}
			}
			return true
		} else {
			return false
		}
	}

	
	func scoreUnique() {
		if let uniques = uniques {
			print("Unique correct answers are: ", uniques)
			
			//Convert team guesses to a comparable format
			for team in 0..<Settings.shared.numTeams {
				if teamGuesses[team] != nil {
					teamGuesses[team]!.guess = Utils.sanitiseString(teamGuesses[team]!.guess);
				}
			}
			
			
			//First mark all correct answers
			for team in 0..<Settings.shared.numTeams {
				if let tg = teamGuesses[team] {
					if uniques.contains(tg.guess)  {
						//team is right but might not be unique
						teamBoxes[team].bgBox.run(SKAction.colorTransitionAction(fromColor: TeamAnswerNode.bgColour, toColor: NSColor(calibratedRed: 0.1, green: 1.0, blue: 0.3, alpha: 0.9)))
						teamBoxes[team].bgBox.run(SKAction.scale(to: 1.1, duration: 0.5))
						
						if isTeamAnswerUnique(team) {
							var starpoint : CGPoint = teamBoxes[team].bgBox.centrePoint
							starpoint.x -= 310
							emitters.append(teamBoxes[team].addEmitter(named: "locationstar", at: starpoint, zPosition: 5.0, autoRemove: false))
						}
					} else {
						//team is wrong
						teamBoxes[team].bgBox.run(SKAction.colorTransitionAction(fromColor: TeamAnswerNode.bgColour, toColor: NSColor(calibratedRed: 0.9, green: 0.2, blue: 0.2, alpha: 0.9)))
					}
				} else {
					//team is wrong
				}
			}
		}
	}
	
	override func reset() {
		QuizWebSocket.shared?.ledsOff()
		for team in 0..<Settings.shared.numTeams {
			teamGuesses[team] = nil
			teamBoxes[team].guessLabel.text = ""
			teamBoxes[team].roundLabel.text = ""
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
