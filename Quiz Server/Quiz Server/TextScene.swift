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
	
	var text = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
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
		
		text.text = "this is an answer answ"
		text.fontSize = 60
		text.fontColor = NSColor.black
		text.horizontalAlignmentMode = .left
		text.verticalAlignmentMode = .center
		text.zPosition = 6
		text.position = CGPoint(x: -((width/2) - 75), y: 0)

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
		self.addChild(text)
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func emphasise() {
		var teamHue = CGFloat(teamNo) / 8.0
		if teamHue > 1.0 {
			teamHue -= 1.0
		}
		
		let parts = SKEmitterNode(fileNamed: "BoggleSparksBonus")!
		parts.position = CGPoint(x: -((self.width/2) - 20), y: 0)
		parts.zPosition = 7
		parts.removeWhenDone()
		parts.particleColor = NSColor(calibratedHue: teamHue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
		parts.particleColorSequence = nil
		self.addChild(parts)
		
		let grow = SKAction.scale(to: 1.2, duration: 0.05)
		grow.timingMode = .easeOut
		let shrink = SKAction.scale(to: 1, duration: 0.2)
		shrink.timingMode = .easeIn
		let anim = SKAction.sequence([grow, shrink])
		teamNoLabel.run(anim)
		bgBox.run(anim)
		text.run(anim)
	}
	
}



class TextScene: SKScene {
	
	var teamGuesses = [(roundid: Int, guess: String)?]()
	var leds: QuizLeds?
	fileprivate var setUp = false
	var numTeams = 10
	var teamBoxes = [TextTeamNode]()

	func setUpScene(size: CGSize, leds: QuizLeds?, numTeams: Int) {
		if setUp {
			return
		}
		setUp = true
		
		self.size = size
		self.leds = leds
		self.numTeams = numTeams
		
		let bgImage = SKSpriteNode(imageNamed: "2")
		bgImage.zPosition = 0
		bgImage.position = CGPoint(x:self.frame.midX, y:self.frame.midY)
		bgImage.size = self.size
		
		self.addChild(bgImage)
		
		for team in 0...7 {
			let offset = (team >= 4) ? ((3 - (team - 4)) * 200) : ((3 - team) * 200)
			let position = CGPoint(
				x: (team < 4) ? self.centrePoint.x - 500 : self.centrePoint.x + 500,
				y: CGFloat(250 + offset)
			)
			let box = TextTeamNode(team: team, width: 700, height: 150, position: position)
			
			box.zPosition = 1
			teamBoxes.append(box)
			self.addChild(box)
			
			teamGuesses.append(nil)
		}
	}

	func teamGuess(teamid : Int, guess : String, roundid : Int) {
		teamGuesses[teamid] = (roundid, guess)
		teamBoxes[teamid].text.text = "•••••••• (\(roundid))"
		teamBoxes[teamid].emphasise()
	}
	
	func showGuesses() {
		for team in 0...7 {
			if let tg = teamGuesses[team] {
				teamBoxes[team].text.text = "\(tg.guess) (\(tg.roundid))"
			} else {
				teamBoxes[team].text.text = ""
			}
		}
	}
	
	func reset() {
		leds?.buzzersOn()
		
		for team in 0...7 {
			teamGuesses[team] = nil
			teamBoxes[team].text.text = ""
		}
	}

}
