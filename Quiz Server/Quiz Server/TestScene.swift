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
	case Christmas
	case Academic
	case Ibm
}

class TestScene: SKScene {
	
	var leds: QuizLeds?
	private var setUp = false
	
	let eightSound = SKAction.playSoundFileNamed("eight", waitForCompletion: false)
	
	var numbers = [SKLabelNode]()
	var sparksUp = [SKEmitterNode]()
	var sparksDown = [SKEmitterNode]()
	var imageSparks = [[SKEmitterNode]]()
	
	let ibmSparks = ["ibm-i", "ibm-b", "ibm-m"]
	let academicSparks = ["mortarboard", "floppydisk", "thinking"]
	let christmasSparks = ["tree", "santa", "present"]
	
	
	func setUpScene(size: CGSize, leds: QuizLeds?) {
		if setUp {
			return
		}
		setUp = true
		
		self.size = size
		self.leds = leds
		
		self.backgroundColor = NSColor.blackColor()
		
		for i in 0...9 {
			let numberNode = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
			numberNode.fontSize = 170.0
			numberNode.horizontalAlignmentMode = .Center
			numberNode.verticalAlignmentMode = .Center
			numberNode.text = String(i + 1)
			numberNode.position = CGPoint(x: (i * 190) + 105, y: 540)
			numberNode.zPosition = 3
			numbers.append(numberNode)
			self.addChild(numberNode)
		
			let sparksUpNode = SKEmitterNode(fileNamed: "SparksUp")!
			sparksUpNode.position = CGPoint(x: (i * 190) + 105, y: 655)
			sparksUpNode.zPosition = 2
			sparksUp.append(sparksUpNode)
			self.addChild(sparksUpNode)

			let sparksDownNode = SKEmitterNode(fileNamed: "SparksDown")!
			sparksDownNode.position = CGPoint(x: (i * 190) + 105, y: 425)
			sparksDownNode.zPosition = 2
			sparksDown.append(sparksDownNode)
			self.addChild(sparksDownNode)
			
			var imageSparksNodes = [SKEmitterNode]()
			
			for j in 0...2 {
				let imageSparksUpNode = SKEmitterNode(fileNamed: "SparksUpImage")!
				imageSparksUpNode.position = CGPoint(x: (i * 190) + 105, y: 655)
				imageSparksUpNode.zPosition = 1
				imageSparksUpNode.particleTexture = SKTexture(imageNamed: christmasSparks[j])
				imageSparksNodes.append(imageSparksUpNode)
				self.addChild(imageSparksUpNode)
				
				let imageSparksDownNode = SKEmitterNode(fileNamed: "SparksDownImage")!
				imageSparksDownNode.position = CGPoint(x: (i * 190) + 105, y: 425)
				imageSparksDownNode.zPosition = 1
				imageSparksDownNode.particleTexture = SKTexture(imageNamed: christmasSparks[j])
				imageSparksNodes.append(imageSparksDownNode)
				self.addChild(imageSparksDownNode)
			}
			
			imageSparks.append(imageSparksNodes)
		}
	}
	
	func reset() {
		leds?.stringOff()
		leds?.buzzersOff()
		for (_, team) in numbers.enumerate() {
			team.fontColor = NSColor.whiteColor()
			leds?.stringOff()
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
	}
	
	func buzzerPressed(team: Int) {
		numbers[team].fontColor = NSColor(calibratedHue: CGFloat(team) / 10.0, saturation: 1.0, brightness: 1.0, alpha: 1.0)
		leds?.buzzerOn(team)
		sparksUp[team].particleBirthRate = 600
		sparksDown[team].particleBirthRate = 600
		
		for node in imageSparks[team] {
			node.particleBirthRate = 3
		}
		
		if team == 7 {
			self.runAction(eightSound)
		}
	}
	
	func buzzerReleased(team: Int) {
		numbers[team].fontColor = NSColor.whiteColor()
		leds?.buzzerOff(team)
		sparksUp[team].particleBirthRate = 0
		sparksDown[team].particleBirthRate = 0
		
		for node in imageSparks[team] {
			node.particleBirthRate = 0
		}
	}
	
	func setTeamType(team: Int, type: TeamType) {
		var images: [String]
		
		switch type {
		case .Christmas:
			images = christmasSparks
		case .Academic:
			images = academicSparks
		case .Ibm:
			images = ibmSparks
		}
		
		for (i, node) in imageSparks[team].enumerate() {
			node.particleTexture = SKTexture(imageNamed: images[i / 2])
		}
	}
}
