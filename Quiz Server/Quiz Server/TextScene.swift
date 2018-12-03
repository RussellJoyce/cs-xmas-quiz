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
		
		guessLabel.text = "abcedfghijklmnopqrstuv"
		guessLabel.fontSize = 60
		guessLabel.fontColor = NSColor.black
		guessLabel.horizontalAlignmentMode = .left
		guessLabel.verticalAlignmentMode = .center
		guessLabel.zPosition = 6
		guessLabel.position = CGPoint(x: -((width/2) - 75), y: 30)

		roundLabel.text = "(round number)"
		roundLabel.fontSize = 38
		roundLabel.fontColor = NSColor(calibratedRed: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
		roundLabel.horizontalAlignmentMode = .left
		roundLabel.verticalAlignmentMode = .center
		roundLabel.zPosition = 6
		roundLabel.position = CGPoint(x: -((width/2) - 75), y: -40)
		
		singleLabel.text = "this is an answer answ"
		singleLabel.fontSize = 60
		singleLabel.fontColor = NSColor.black
		singleLabel.horizontalAlignmentMode = .left
		singleLabel.verticalAlignmentMode = .center
		singleLabel.zPosition = 6
		singleLabel.position = CGPoint(x: -((width/2) - 75), y: 0)
		
		teamNoLabel = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		teamNoLabel.text = "\(team + 1)."
		teamNoLabel.fontSize = 60
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
		var teamHue = CGFloat(teamNo) / 8.0
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



class TextScene: SKScene {
	
	var teamGuesses = [(roundid: Int, guess: String)?]()
	var leds: QuizLeds?
	fileprivate var setUp = false
	var numTeams = 10
	var teamBoxes = [TextTeamNode]()
	let blopSound = SKAction.playSoundFileNamed("blop", waitForCompletion: false)
	let hornSound = SKAction.playSoundFileNamed("airhorn", waitForCompletion: false)

	func setUpScene(size: CGSize, leds: QuizLeds?, numTeams: Int) {
		if setUp {
			return
		}
		setUp = true
		
		self.size = size
		self.leds = leds
		self.numTeams = numTeams
		
		let bgImage = SKSpriteNode(imageNamed: "background2")
		bgImage.zPosition = 0
		bgImage.position = CGPoint(x:self.frame.midX, y:self.frame.midY)
		bgImage.size = self.size
		
		self.addChild(bgImage)
		
		for team in 0..<numTeams {
			let yOffset = (team >= 5) ? ((4 - (team - 5)) * 200) : ((4 - team) * 200)
			let position = CGPoint(
				x: (team < 5) ? self.centrePoint.x - 500 : self.centrePoint.x + 500,
				y: CGFloat(160 + yOffset)
			)
			let box = TextTeamNode(team: team, width: 700, height: 150, position: position)
			
			box.zPosition = 1
			teamBoxes.append(box)
			self.addChild(box)
			
			teamGuesses.append(nil)
		}
	}

	func teamGuess(teamid : Int, guess : String, roundid : Int, showroundno : Bool) {
		self.run(blopSound)
		leds?.stringPulseTeamColour(team: teamid)
		teamGuesses[teamid] = (roundid, guess)
		teamBoxes[teamid].resetTextSize()
		if showroundno {
			teamBoxes[teamid].guessLabel.text = "••••••••"
			teamBoxes[teamid].roundLabel.text = "(at Clue \(roundid))"
			teamBoxes[teamid].singleLabel.text = ""
		} else {
			teamBoxes[teamid].guessLabel.text = ""
			teamBoxes[teamid].roundLabel.text = ""
			teamBoxes[teamid].singleLabel.text = "••••••••"
		}
		teamBoxes[teamid].emphasise()
	}
	
	func showGuesses(showroundno : Bool) {
		self.run(hornSound)
		leds?.stringPointlessCorrect()
		
		let emoji = ["tree", "santa", "spaceinvader", "robot", "snowman", "present", "floppydisk", "snowflake"]
		
		for i in 0..<100 {
			let p = SKEmitterNode(fileNamed: "Shower")!
			p.particleTexture = SKTexture(imageNamed: emoji[Int(arc4random_uniform(UInt32(emoji.count)))])
			p.position = CGPoint(x: self.centrePoint.x, y: self.centrePoint.y+100)
			p.zPosition = CGFloat(100 + i)
			p.removeWhenDone()
			self.addChild(p)
		}
		
		for team in 0..<numTeams {
			if let tg = teamGuesses[team] {
				
				if(tg.guess.count) > 13 {
					teamBoxes[team].setTextSize(size: 40)
				} else {
					teamBoxes[team].setTextSize(size: 60)
				}
				
				if showroundno {
					teamBoxes[team].guessLabel.text = "\(tg.guess)"
					teamBoxes[team].roundLabel.text = "(at Clue \(tg.roundid))"
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
	
	func reset() {
		leds?.buzzersOn()
		
		for team in 0..<numTeams {
			teamGuesses[team] = nil
			teamBoxes[team].guessLabel.text = ""
			teamBoxes[team].roundLabel.text = ""
			teamBoxes[team].singleLabel.text = ""
			teamBoxes[team].resetTextSize()
		}
	}

}
