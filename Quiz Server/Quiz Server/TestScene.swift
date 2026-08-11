//
//  TestScene.swift
//  Quiz Server
//
//  Created by Russell Joyce on 17/11/2015.
//  Copyright © 2015 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import SpriteKit

class TestScene: QuizScene {
	
	var buzzerPresses = [Int]()
	let eightSound = SKAction.playSoundFileNamed("eight", waitForCompletion: false)
	
	var numbers = [SKLabelNode]()
	var sparksUp = [SKEmitterNode]()
	var sparksDown = [SKEmitterNode]()
	var imageSparks = [[SKEmitterNode]]()
	let christmasSparks = ["snowflake", "floppydisk", "star"]
	
	override func buildScene() {
		self.backgroundColor = NSColor.black
		
		for i in 0..<Settings.shared.numTeams {
			
			let brkpoint = (Settings.shared.numTeams / 2) + 1
			
			let xPos = i < ((Settings.shared.numTeams / 2) + 1) ?
				Double(i + 1) * (Double(size.width) / (Double(brkpoint) + 1.5)) :
				Double((i + 1) - brkpoint) * (Double(size.width) / (Double(brkpoint-1) + 1.5))
			let yPos = i < brkpoint ?
				540 + 250 :
				540 - 250
			
			let numberNode = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
			numberNode.fontSize = 130.0
			numberNode.horizontalAlignmentMode = .center
			numberNode.verticalAlignmentMode = .center
			numberNode.text = String(i + 1)
			numberNode.position = CGPoint(x: xPos, y: Double(yPos))
			numberNode.zPosition = 3
			numbers.append(numberNode)
			self.addChild(numberNode)
		
			let upPoint = CGPoint(x: xPos, y: Double(yPos+100))
			let downPoint = CGPoint(x: xPos, y: Double(yPos-100))

			sparksUp.append(addEmitter(named: "SparksUp", at: upPoint, zPosition: 2, autoRemove: false))
			sparksDown.append(addEmitter(named: "SparksDown", at: downPoint, zPosition: 2, autoRemove: false))

			var imageSparksNodes = [SKEmitterNode]()

			for j in 0...2 {
				let texture = SKTexture(imageNamed: christmasSparks[j])
				imageSparksNodes.append(addEmitter(named: "SparksUpImage", at: upPoint, zPosition: 1, autoRemove: false) {
					$0.particleTexture = texture
				})
				imageSparksNodes.append(addEmitter(named: "SparksDownImage", at: downPoint, zPosition: 1, autoRemove: false) {
					$0.particleTexture = texture
				})
			}
			
			imageSparks.append(imageSparksNodes)
			
			buzzerPresses.append(0)
		}
	}
	
	override func reset() {
		QuizWebSocket.shared?.ledsOff()
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
		
		buzzerPresses = [Int](repeating: 0, count: Settings.shared.numTeams)
	}
	
	override func buzzerPressed(team: Int, type: BuzzerType, options: BuzzerOptions) {

		//TODO: This needs some tidying up if we ever use this scene again
		// Specifically the "released" logic
		
		print("buzzerPressed in TestScene for team:" + String(team))
		numbers[team].fontColor = Utils.teamColour(team)
		sparksUp[team].particleBirthRate = 600
		sparksDown[team].particleBirthRate = 600
		QuizWebSocket.shared?.pulseTeamColour(team)
		
		for node in imageSparks[team] {
			node.particleBirthRate = 3
		}
		
		if team == 7 {
			self.run(eightSound)
		}
		
		if type == .websocket {
			buzzerPresses[team] += 1
		}
		
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
			self.buzzerReleased(team: team, type: type)
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
			for node in self.imageSparks[team] {
				node.particleBirthRate = 0
			}
		}
	}
}
