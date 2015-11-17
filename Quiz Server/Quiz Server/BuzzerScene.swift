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
	var teamBox: BuzzerTeamNode?
	
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
		
		teamBox?.removeFromParent()
		teamBox = nil
	}
	
	func buzzerPressed(team: Int) {
		if teamEnabled[team] && buzzes.count < 8 {
			teamEnabled[team] = false
			leds?.buzzerOff(team)
			
			buzzes.append(team)
			
			if buzzNumber == 0 {
				firstBuzzTime = NSDate()
				self.runAction(buzzNoise)
				leds?.stringTeamAnimate(team)
				nextTeamNumber = 1
				
				teamBox = BuzzerTeamNode(team: team)
				teamBox?.position = self.centrePoint
				teamBox?.zPosition = 10
				self.addChild(teamBox!)
			}
			//            else if let firstBuzzTimeOpt = firstBuzzTime {
			//                let time = -firstBuzzTimeOpt.timeIntervalSinceNow
			//            }
			
			buzzNumber++
		}
	}
	
	func nextTeam() {
		if nextTeamNumber < buzzes.count {
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