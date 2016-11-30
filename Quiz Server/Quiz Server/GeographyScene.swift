//
//  GeographyScene.swift
//  Quiz Server
//
//  Created by Russell Joyce on 28/11/2016.
//  Copyright © 2016 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import SpriteKit

class GeographyScene: SKScene {
	
	var leds: QuizLeds?
	fileprivate var setUp = false
	var numTeams = 10
	
	let text = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	
	func setUpScene(size: CGSize, leds: QuizLeds?, numTeams: Int) {
		if setUp {
			return
		}
		setUp = true
		
		self.size = size
		self.leds = leds
		self.numTeams = numTeams
		
		let bgImage = SKSpriteNode(imageNamed: "purple-texture-blurred")
		bgImage.zPosition = 0.0
		bgImage.position = CGPoint(x:self.frame.midX, y:self.frame.midY)
		bgImage.size = self.size
		
		self.addChild(bgImage)
		
		let mainImage = SKSpriteNode(imageNamed: "2")
		mainImage.position = CGPoint(x: 0, y: 50.0)
		mainImage.size.width = 1300.0
		mainImage.size.height = 867.0
		mainImage.zPosition = 1.0
		bgImage.addChild(mainImage)
		
		
		text.fontSize = 70
		text.fontColor = NSColor.white
		text.horizontalAlignmentMode = .left
		text.verticalAlignmentMode = .baseline
		text.zPosition = 6.0
		text.position = CGPoint(x: 50, y: 50)
		text.text = "Teams Remaining: 1 2 3 4 5 6 7 8"
		
		self.addChild(text)

	}
	
	func setQuestion(question: Int) {
		print("Question " + String(question))
	}
	
	func showWinner(answerx: Int, answery: Int) {
		print("Show Winner " + String(answerx) + " " + String(answery))
	}
	
	func teamAnswered(team: Int, x: Int, y: Int) {
		print("Team: " + String(team) + " X: " + String(x) + " Y: " + String(y))
	}
	
	func reset() {
		print("Geo reset")
	}
}
