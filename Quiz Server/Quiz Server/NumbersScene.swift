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

	func teamGuess(teamid : Int, guess : Int) {
		if teamid < Settings.shared.numTeams {
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
			//Work out which is closest to the actual answer
			var teamDistances = [(team : Int, distance : Int)]()
			
			for team in 0..<Settings.shared.numTeams {
				if let teamGuessText = teamBoxes[team].singleLabel.text {
					if let teamGuessInt = Int(teamGuessText) {
						let dist = abs(teamGuessInt - actualAnswer)
						teamDistances.append((team, dist))
					}
				}
			}
			
			teamDistances = teamDistances.sorted(by: {$0.distance < $1.distance})

			if teamDistances.count == 0 {
				return
			}
			
			let winColours = [
				NSColor(calibratedRed: 0.1, green: 1.0, blue: 0.3, alpha: 0.9),
				NSColor(calibratedRed: 1.0, green: 1.0, blue: 0.1, alpha: 0.9),
				NSColor(calibratedRed: 0.6, green: 0.6, blue: 1.0, alpha: 0.9),
			]
			
			//We need to handle draws, so it isn't as easy as saying that index 0 is the winner, index 1 is the second etc.
			var win = 0 //This is the "rank" we are at. 0 is "winner", 1 is "second place", 2 is "top half", higher is "loser"
			var teNo = 0
			var lastDist : Int = teamDistances[teNo].distance //Will be 0 if someone guessed correctly
			while win < winColours.count {
				if teNo >= teamDistances.count {
					break
				}
				
				if win == 0 || win == 1 {
					if teamDistances[teNo].distance > lastDist {
						win = win + 1
						lastDist = teamDistances[teNo].distance
					}
				} else {
					if teNo > (teamDistances.count / 2 - 1) && teamDistances[teNo].distance != teamDistances[teNo-1].distance {
						break
					}
				}
				
				//Animate the team box to the target colour to indicate "win level"
				teamBoxes[teamDistances[teNo].team].bgBox.run(SKAction.colorTransitionAction(fromColor: TeamAnswerNode.bgColour, toColor: winColours[win]))
				teamBoxes[teamDistances[teNo].team].bgBox.run(SKAction.scale(to: 1.1, duration: 0.5))
				
				//Give winners some stars
				if win == 0 {
					for _ in 0...5 {
						var starpoint : CGPoint = teamBoxes[teamDistances[teNo].team].bgBox.centrePoint
						//starpoint.y += CGFloat(Int.random(in: -70...70))
						starpoint.x -= 310
						emitters.append(teamBoxes[teamDistances[teNo].team].addEmitter(named: "locationstar", at: starpoint, zPosition: 5.0, autoRemove: false))
					}
				}
				
				if win < 2 {
					addGlowParticles(team: teamDistances[teNo].team)
				}
				
				teNo = teNo + 1
			}
		}
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
		
		for e in emitters {
			e.removeFromParent()
		}
		emitters.removeAll()
	}

}
