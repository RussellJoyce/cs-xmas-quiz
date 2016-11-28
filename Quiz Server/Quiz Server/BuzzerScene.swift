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
	fileprivate var setUp = false
	
	var buzzNumber = 0
	var firstBuzzTime: Date?
	var teamEnabled = [Bool](repeating: true, count: 10)
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
		bgImage.zPosition = 0
		bgImage.position = CGPoint(x:self.frame.midX, y:self.frame.midY)
		bgImage.size = self.size
		
		self.addChild(bgImage)
	}
	
	func reset() {
		leds?.buzzersOn()
		teamEnabled = [Bool](repeating: true, count: 10)
		buzzNumber = 0
		buzzes.removeAll()
		nextTeamNumber = 0
		
		for teamBox in teamBoxes {
			teamBox.removeFromParent()
		}
		teamBoxes.removeAll()
	}
	
	func buzzerPressed(team: Int, type: BuzzerType) {
		if teamEnabled[team] && buzzes.count < 5 {
			teamEnabled[team] = false
			leds?.buzzerOff(team: team)
			
			buzzes.append(team)
			
			if buzzNumber == 0 {
				firstBuzzTime = Date()
				self.run(buzzNoise)
				leds?.stringTeamAnimate(team: team)
				nextTeamNumber = 1
				
				let box = BuzzerTeamNode(team: team, width: 1000, height: 200, fontSize: 150, addGlow: true)
				box.position = CGPoint(x: self.centrePoint.x, y: self.size.height - 160)
				box.zPosition = 1
				teamBoxes.append(box)
				self.addChild(box)
				
			} else {
				let box = BuzzerTeamNode(team: team, width: 800, height: 130, fontSize: 100, addGlow: false)
				box.position = CGPoint(x: self.centrePoint.x, y: (self.size.height - 230) - CGFloat(buzzNumber * 175))
				box.zPosition = 1
				teamBoxes.append(box)
				self.addChild(box)
			}
			
			buzzNumber += 1
		}
		
		if buzzes.count == 5 {
			leds?.buzzersOff()
		}
	}
	
	func nextTeam() {
		if nextTeamNumber < buzzes.count {
			teamBoxes[nextTeamNumber-1].run(SKAction.fadeAlpha(to: 0.3, duration: 0.5))
			teamBoxes[nextTeamNumber-1].stopGlow()
			teamBoxes[nextTeamNumber].startGlow()
			let team = buzzes[nextTeamNumber]
			leds?.stringTeamColour(team: team)
			nextTeamNumber += 1
		}
	}
}


extension SKNode {
	var centrePoint: CGPoint {
		return CGPoint(x:self.frame.midX, y:self.frame.midY)
	}
}
