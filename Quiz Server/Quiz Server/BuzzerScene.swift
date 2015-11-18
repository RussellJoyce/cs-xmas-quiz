//
//  BuzzerScene.swift
//  Quiz Server
//
//  Created by Russell Joyce on 17/11/2015.
//  Copyright © 2015 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import SpriteKit

class BuzzerScene: SKScene {
	
	var leds: QuizLeds?
	private var setUp = false
	
	var buzzNumber = 0
	var firstBuzzTime: NSDate?
	var teamEnabled = [Bool](count: 10, repeatedValue: true)
	var buzzes = [Int]()
	var nextTeamNumber = 0
	let buzzNoise = SKAction.playSoundFileNamed("buzzer", waitForCompletion: false)
	var teamBoxes = [BuzzerTeamNode]()
	
	func setUpScene(size: CGSize, leds: QuizLeds?) {
		if setUp {
			return
		}
		setUp = true
		
		self.size = size
		self.leds = leds
		
		let bgImage = SKSpriteNode(imageNamed: "2")
		bgImage.zPosition = -1.0
		bgImage.position = CGPoint(x:CGRectGetMidX(self.frame), y:CGRectGetMidY(self.frame))
		bgImage.size = self.size
		
		self.addChild(bgImage)
	}
	
	func reset() {
		leds?.buzzersOn()
		teamEnabled = [Bool](count: 10, repeatedValue: true)
		buzzNumber = 0
		buzzes.removeAll()
		nextTeamNumber = 0
		
		for teamBox in teamBoxes {
			teamBox.removeFromParent()
		}
		teamBoxes.removeAll()
	}
	
	func buzzerPressed(team: Int) {
		if teamEnabled[team] && buzzes.count < 5 {
			teamEnabled[team] = false
			leds?.buzzerOff(team)
			
			buzzes.append(team)
			
			if buzzNumber == 0 {
				firstBuzzTime = NSDate()
				self.runAction(buzzNoise)
				leds?.stringTeamAnimate(team)
				nextTeamNumber = 1
				
				let box = BuzzerTeamNode(team: team, width: 900, height: 200, fontSize: 150, addGlow: true)
				box.position = CGPoint(x: self.centrePoint.x, y: self.size.height - 200)
				box.zPosition = 10
				teamBoxes.append(box)
				self.addChild(box)
				
			} else {
				let box = BuzzerTeamNode(team: team, width: 800, height: 130, fontSize: 100, addGlow: false)
				box.position = CGPoint(x: self.centrePoint.x, y: (self.size.height - 300) - CGFloat(buzzNumber * 160))
				box.zPosition = 9
				teamBoxes.append(box)
				self.addChild(box)
			}
			
			buzzNumber++
		}
	}
	
	func nextTeam() {
		if nextTeamNumber < buzzes.count {
			teamBoxes[nextTeamNumber-1].runAction(SKAction.fadeAlphaTo(0.3, duration: 0.5))
			let team = buzzes[nextTeamNumber]
			leds?.stringTeamColour(team)
			nextTeamNumber++
		}
	}
}


extension SKNode {
	var centrePoint: CGPoint {
		return CGPoint(x:CGRectGetMidX(self.frame), y:CGRectGetMidY(self.frame))
	}
}