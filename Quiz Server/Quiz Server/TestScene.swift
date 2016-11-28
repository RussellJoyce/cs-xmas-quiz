//
//  TestScene.swift
//  Quiz Server
//
//  Created by Russell Joyce on 17/11/2015.
//  Copyright © 2015 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import SpriteKit

enum TeamType {
	case christmas
	case academic
	case ibm
}

class TestScene: SKScene {
	
	var leds: QuizLeds?
	fileprivate var setUp = false
	var numTeams = 10
	var buzzerPresses = [Int]()
	
	let eightSound = SKAction.playSoundFileNamed("eight", waitForCompletion: false)
	
	var numbers = [SKLabelNode]()
	var sparksUp = [SKEmitterNode]()
	var sparksDown = [SKEmitterNode]()
	var imageSparks = [[SKEmitterNode]]()
	
	let ibmSparks = ["ibm-i", "ibm-b", "ibm-m"]
	let academicSparks = ["mortarboard", "mortarboard", "mortarboard"]
	let christmasSparks = ["snowflake", "snowflake", "snowflake"]
	
	
	func setUpScene(size: CGSize, leds: QuizLeds?, numTeams: Int) {
		if setUp {
			return
		}
		setUp = true
		
		self.size = size
		self.leds = leds
		self.numTeams = numTeams
		
		self.backgroundColor = NSColor.black
		
		for i in 0..<numTeams {
			
			let xPos = Double(i + 1) * (Double(size.width) / (Double(numTeams) + 1.0));
			
			let numberNode = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
			numberNode.fontSize = 170.0
			numberNode.horizontalAlignmentMode = .center
			numberNode.verticalAlignmentMode = .center
			numberNode.text = String(i + 1)
			numberNode.position = CGPoint(x: xPos, y: 540)
			numberNode.zPosition = 3
			numbers.append(numberNode)
			self.addChild(numberNode)
		
			let sparksUpNode = SKEmitterNode(fileNamed: "SparksUp")!
			sparksUpNode.position = CGPoint(x: xPos, y: 655)
			sparksUpNode.zPosition = 2
			sparksUp.append(sparksUpNode)
			self.addChild(sparksUpNode)

			let sparksDownNode = SKEmitterNode(fileNamed: "SparksDown")!
			sparksDownNode.position = CGPoint(x: xPos, y: 425)
			sparksDownNode.zPosition = 2
			sparksDown.append(sparksDownNode)
			self.addChild(sparksDownNode)
			
			var imageSparksNodes = [SKEmitterNode]()
			
			for j in 0...2 {
				let imageSparksUpNode = SKEmitterNode(fileNamed: "SparksUpImage")!
				imageSparksUpNode.position = CGPoint(x: xPos, y: 655)
				imageSparksUpNode.zPosition = 1
				imageSparksUpNode.particleTexture = SKTexture(imageNamed: christmasSparks[j])
				imageSparksNodes.append(imageSparksUpNode)
				self.addChild(imageSparksUpNode)
				
				let imageSparksDownNode = SKEmitterNode(fileNamed: "SparksDownImage")!
				imageSparksDownNode.position = CGPoint(x: xPos, y: 425)
				imageSparksDownNode.zPosition = 1
				imageSparksDownNode.particleTexture = SKTexture(imageNamed: christmasSparks[j])
				imageSparksNodes.append(imageSparksDownNode)
				self.addChild(imageSparksDownNode)
			}
			
			imageSparks.append(imageSparksNodes)
			
			buzzerPresses.append(0)
		}
	}
	
	func reset() {
		leds?.stringOff()
		leds?.buzzersOn()
		for team in numbers {
			team.fontColor = NSColor.white
		}
		
		for node in sparksUp {
			node.particleBirthRate = 0
		}
		for node in sparksDown {
			node.particleBirthRate = 0
		}
		for team in imageSparks {
			for node in team {
				node.particleBirthRate = 0
			}
		}
		
		buzzerPresses = [Int](repeating: 0, count: numTeams)
	}
	
	func buzzerPressed(team: Int, type: BuzzerType) {
		numbers[team].fontColor = NSColor(calibratedHue: CGFloat(team) / 10.0, saturation: 1.0, brightness: 1.0, alpha: 1.0)
		sparksUp[team].particleBirthRate = 600
		sparksDown[team].particleBirthRate = 600
		leds?.stringTestOn(team: team)
		leds?.buzzerOff(team: team)
		
		for node in imageSparks[team] {
			node.particleBirthRate = 3
		}
		
		if team == 7 {
			self.run(eightSound)
		}
		
		if type == .websocket {
			buzzerPresses[team] += 1
		}
	}
	
	func buzzerReleased(team: Int, type: BuzzerType) {
		if type == .websocket {
			let currentPresses = buzzerPresses[team]
			DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
				if currentPresses == self.buzzerPresses[team] {
					self.numbers[team].fontColor = NSColor.white
					self.sparksUp[team].particleBirthRate = 0
					self.sparksDown[team].particleBirthRate = 0
					self.leds?.stringTestOff(team: team)
					self.leds?.buzzerOn(team: team)
					
					for node in self.imageSparks[team] {
						node.particleBirthRate = 0
					}
				}
			}
		}
		else {
			self.numbers[team].fontColor = NSColor.white
			self.sparksUp[team].particleBirthRate = 0
			self.sparksDown[team].particleBirthRate = 0
			self.leds?.stringTestOff(team: team)
			self.leds?.buzzerOn(team: team)
			
			for node in self.imageSparks[team] {
				node.particleBirthRate = 0
			}
		}
	}
	
	func setTeamType(team: Int, type: TeamType) {
		var images: [String]
		
		switch type {
		case .christmas:
			images = christmasSparks
		case .academic:
			images = academicSparks
		case .ibm:
			images = ibmSparks
		}
		
		for (i, node) in imageSparks[team].enumerated() {
			node.particleTexture = SKTexture(imageNamed: images[i / 2])
		}
	}
}
