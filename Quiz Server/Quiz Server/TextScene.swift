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

class TextTeamNode: SKNode {
	
	var guessLabel = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	var roundLabel = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	var singleLabel = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	var width : Int = 0
	var height : Int = 0
	var bgBox : SKShapeNode
	var teamNoLabel : SKLabelNode
	var teamNo : Int
	
	init(team: Int, width: Int, height: Int, position : CGPoint) {
		let bgColour = NSColor(calibratedHue: 0, saturation: 0.0, brightness: 0.9, alpha: 0.9)
		
		bgBox = SKShapeNode(rectOf: CGSize(width: width, height: height))
		bgBox.zPosition = 5
		bgBox.position = CGPoint.zero
		bgBox.fillColor = bgColour
		bgBox.lineWidth = 2.0
		
		let bigfontsize : CGFloat = height >= 150 ? 60 : 40
		let smallfontsize : CGFloat = height >= 150 ? 38 : 28
		
		guessLabel.text = "abcedfghijklmnopqrstuv"
		guessLabel.fontSize = bigfontsize
		guessLabel.fontColor = NSColor.black
		guessLabel.horizontalAlignmentMode = .left
		guessLabel.verticalAlignmentMode = .center
		guessLabel.zPosition = 6
		guessLabel.position = CGPoint(x: -((width/2) - 120), y: Int(0.2*Double(height)))

		roundLabel.text = "(round number)"
		roundLabel.fontSize = smallfontsize
		roundLabel.fontColor = NSColor(calibratedRed: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
		roundLabel.horizontalAlignmentMode = .left
		roundLabel.verticalAlignmentMode = .center
		roundLabel.zPosition = 6
		roundLabel.position = CGPoint(x: -((width/2) - 120), y: Int(-0.27*Double(height)))
		
		singleLabel.text = "this is an answer answ"
		singleLabel.fontSize = bigfontsize
		singleLabel.fontColor = NSColor.black
		singleLabel.horizontalAlignmentMode = .left
		singleLabel.verticalAlignmentMode = .center
		singleLabel.zPosition = 6
		singleLabel.position = CGPoint(x: -((width/2) - 120), y: 0)
		
		teamNoLabel = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		teamNoLabel.text = "\(team + 1)."
		teamNoLabel.fontSize = bigfontsize
		teamNoLabel.fontColor = NSColor.black
		teamNoLabel.horizontalAlignmentMode = .left
		teamNoLabel.verticalAlignmentMode = .center
		teamNoLabel.zPosition = 6
		teamNoLabel.position = CGPoint(x: -((width/2) - 20), y: 0)
		
		self.width = width
		self.height = height
		self.teamNo = team
		
		super.init()
		
		self.position = position
		self.addChild(teamNoLabel)
		self.addChild(bgBox)
		self.addChild(guessLabel)
		self.addChild(roundLabel)
		self.addChild(singleLabel)
	}
		
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func setTextSize(size : CGFloat) {
		guessLabel.fontSize = size
		singleLabel.fontSize = size
	}
	
	func resetTextSize() {
		guessLabel.fontSize = 60
		singleLabel.fontSize = 60
	}
	
	func emphasise() {
		var teamHue = CGFloat(teamNo) / 10.0
		if teamHue > 1.0 {
			teamHue -= 1.0
		}
		
		let parts = SKEmitterNode(fileNamed: "TextSceneSparks")!
		parts.position = CGPoint(x: -((self.width/2) - 40), y: 0)
		parts.zPosition = 7
		
		parts.particleColorSequence = SKKeyframeSequence(
			keyframeValues: [
				SKColor(calibratedHue: teamHue, saturation: 1.0, brightness: 1.0, alpha: 0.0),
				SKColor(calibratedHue: teamHue, saturation: 1.0, brightness: 1.0, alpha: 0.0),
				SKColor(calibratedHue: teamHue, saturation: 1.0, brightness: 1.0, alpha: 1.0),
				SKColor(calibratedHue: teamHue, saturation: 1.0, brightness: 1.0, alpha: 1.0),
				SKColor(calibratedHue: teamHue, saturation: 1.0, brightness: 1.0, alpha: 0.0),
			], times: [0.0, 0.1, 0.1, 0.3, 0.7]
		)
		
		parts.removeWhenDone()
		self.addChild(parts)
		
		let grow = SKAction.scale(to: 1.2, duration: 0.05)
		grow.timingMode = .easeOut
		let shrink = SKAction.scale(to: 1, duration: 0.2)
		shrink.timingMode = .easeIn
		let anim = SKAction.sequence([grow, shrink])
		teamNoLabel.run(anim)
		bgBox.run(anim)
		guessLabel.run(anim)
		singleLabel.run(anim)
		roundLabel.run(anim)
	}
	
}



class TextScene: SKScene, QuizRound {
	
	var teamGuesses = [(roundid: Int, guess: String)?]()
	fileprivate var setUp = false
	var teamBoxes = [TextTeamNode]()
	let blopSound = SKAction.playSoundFileNamed("blop", waitForCompletion: false)
	//let hornSound = SKAction.playSoundFileNamed("airhorn", waitForCompletion: false)
	let hornSound = SKAction.playSoundFileNamed("drums", waitForCompletion: false)
	var uniques: [String]?
	var emitters = [SKEmitterNode]()
	
	func setUpScene(size: CGSize) {
		if setUp {
			return
		}
		setUp = true

		self.size = size

		teamGuesses = [(roundid: Int, guess: String)?]()
		
		let bgImage = SKSpriteNode(imageNamed: "background2")
		bgImage.zPosition = 0
		bgImage.position = CGPoint(x:self.frame.midX, y:self.frame.midY)
		bgImage.size = self.size
		
		self.addChild(bgImage)
			
		let halfway = Int((Double(Settings.shared.numTeams) / 2).rounded(.up))
		
		var boxheight : Int = 150
		if(Settings.shared.numTeams > 10) {
			boxheight = 100
		}
	
		for team in 0..<Settings.shared.numTeams {
			var yOffset : Int
			if team >= halfway {
				yOffset = ((halfway-1) - (team - halfway)) * Int(Double(boxheight)*1.3)
			} else {
				yOffset = ((halfway-1) - team) * Int(Double(boxheight)*1.3)
			}
			let position = CGPoint(
				x: (team < halfway) ? self.centrePoint.x - 500 : self.centrePoint.x + 500,
				y: CGFloat((boxheight+10) + yOffset)
			)
			let box = TextTeamNode(team: team, width: 700, height: boxheight, position: position)
			
			box.zPosition = 1
			teamBoxes.append(box)
			self.addChild(box)
			
			teamGuesses.append(nil)
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
		if teamid < Settings.shared.numTeams {
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
		uniques = []
		do {
			let data = try String(contentsOfFile:file, encoding: String.Encoding.ascii)
			uniques = data.components(separatedBy: "\n")
			uniques = uniques!.filter { $0 != "" }
			uniques = uniques!.map { Utils.sanitiseString($0) }
			print("Unique correct answers are: ", uniques!)
		} catch let err as NSError {
			print(err)
		}
	}
	
	func showGuesses(showroundno : Bool) {
		self.run(hornSound)
		QuizWebSocket.shared?.pulseWhite()
		
		let emoji = ["tree", "santa", "spaceinvader", "robot", "snowman", "present", "floppydisk", "snowflake"]
		
		for i in 0..<100 {
			let p = SKEmitterNode(fileNamed: "Shower")!
			p.particleTexture = SKTexture(imageNamed: emoji[Int(arc4random_uniform(UInt32(emoji.count)))])
			p.position = CGPoint(x: self.centrePoint.x, y: self.centrePoint.y+100)
			p.zPosition = CGFloat(100 + i)
			p.removeWhenDone()
			self.addChild(p)
		}
		
		for team in 0..<Settings.shared.numTeams {
			if let tg = teamGuesses[team] {
				
				if(tg.guess.count) > 13 {
					teamBoxes[team].setTextSize(size: 40)
				} else {
					teamBoxes[team].setTextSize(size: 60)
				}
				
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
						teamBoxes[team].bgBox.run(SKAction.colorTransitionAction(fromColor: NumbersTeamNode.bgColour, toColor: NSColor(calibratedRed: 0.1, green: 1.0, blue: 0.3, alpha: 0.9)))
						teamBoxes[team].bgBox.run(SKAction.scale(to: 1.1, duration: 0.5))
						
						if isTeamAnswerUnique(team) {
							let pstar = SKEmitterNode(fileNamed: "locationstar")!
							var starpoint : CGPoint = teamBoxes[team].bgBox.centrePoint
							starpoint.x -= 310
							pstar.position = starpoint
							pstar.zPosition = 5.0
							teamBoxes[team].addChild(pstar)
							emitters.append(pstar)
						}
					} else {
						//team is wrong
						teamBoxes[team].bgBox.run(SKAction.colorTransitionAction(fromColor: NumbersTeamNode.bgColour, toColor: NSColor(calibratedRed: 0.9, green: 0.2, blue: 0.2, alpha: 0.9)))
					}
				} else {
					//team is wrong
				}
			}
		}
	}
	
	func reset() {
		QuizWebSocket.shared?.ledsOff()
		for team in 0..<Settings.shared.numTeams {
			teamGuesses[team] = nil
			teamBoxes[team].guessLabel.text = ""
			teamBoxes[team].roundLabel.text = ""
			teamBoxes[team].singleLabel.text = ""
			teamBoxes[team].resetTextSize()
			teamBoxes[team].bgBox.fillColor = NumbersTeamNode.bgColour
			teamBoxes[team].bgBox.run(SKAction.scale(to: 1, duration: 0.2))
		}
		
		for e in emitters {
			e.removeFromParent()
		}
		emitters.removeAll()
		
		//Quick dirty test code
		if Settings.shared.debug {
			teamGuess(teamid: 0, guess: "let\"s dance", roundid: 3, showroundno: true);
			teamGuess(teamid: 1, guess: "Sound and Vision", roundid: 1, showroundno: true);
			teamGuess(teamid: 2, guess: "sound and vision", roundid: 2, showroundno: true);
			teamGuess(teamid: 3, guess: "let's dance", roundid: 3, showroundno: true);
			teamGuess(teamid: 4, guess: "sss", roundid: 3, showroundno: true);
			teamGuess(teamid: 5, guess: "ddd", roundid: 3, showroundno: true);
			teamGuess(teamid: 6, guess: "def", roundid: 3, showroundno: true);
			teamGuess(teamid: 7, guess: "drive-in saturday", roundid: 4, showroundno: true);
			teamGuess(teamid: 8, guess: "Where Are We Now", roundid: 4, showroundno: true);
			teamGuess(teamid: 11, guess: "Jean Genie", roundid: 3, showroundno: true);
			teamGuess(teamid: 12, guess: "Jean Genie", roundid: 4, showroundno: true);
			teamGuess(teamid: 13, guess: "abc", roundid: 4, showroundno: true);
		}
	}

}
