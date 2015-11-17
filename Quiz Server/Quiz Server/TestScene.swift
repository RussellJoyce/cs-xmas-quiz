//
//  TestScene.swift
//  Quiz Server
//
//  Created by Russell Joyce on 17/11/2015.
//  Copyright © 2015 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import SpriteKit

class TestScene: SKScene {
	
	var leds: QuizLeds?
	private var setUp = false
	
	let eightSound = SKAction.playSoundFileNamed("eight", waitForCompletion: false)
	
	let numbers = [SKLabelNode(fontNamed: ".AppleSystemUIFontBold"),
		SKLabelNode(fontNamed: ".AppleSystemUIFontBold"),
		SKLabelNode(fontNamed: ".AppleSystemUIFontBold"),
		SKLabelNode(fontNamed: ".AppleSystemUIFontBold"),
		SKLabelNode(fontNamed: ".AppleSystemUIFontBold"),
		SKLabelNode(fontNamed: ".AppleSystemUIFontBold"),
		SKLabelNode(fontNamed: ".AppleSystemUIFontBold"),
		SKLabelNode(fontNamed: ".AppleSystemUIFontBold"),
		SKLabelNode(fontNamed: ".AppleSystemUIFontBold"),
		SKLabelNode(fontNamed: ".AppleSystemUIFontBold")]
	let sparksUp = [SKEmitterNode(fileNamed: "SparksUp")!,
		SKEmitterNode(fileNamed: "SparksUp")!,
		SKEmitterNode(fileNamed: "SparksUp")!,
		SKEmitterNode(fileNamed: "SparksUp")!,
		SKEmitterNode(fileNamed: "SparksUp")!,
		SKEmitterNode(fileNamed: "SparksUp")!,
		SKEmitterNode(fileNamed: "SparksUp")!,
		SKEmitterNode(fileNamed: "SparksUp")!,
		SKEmitterNode(fileNamed: "SparksUp")!,
		SKEmitterNode(fileNamed: "SparksUp")!]
	let sparksDown = [SKEmitterNode(fileNamed: "SparksDown")!,
		SKEmitterNode(fileNamed: "SparksDown")!,
		SKEmitterNode(fileNamed: "SparksDown")!,
		SKEmitterNode(fileNamed: "SparksDown")!,
		SKEmitterNode(fileNamed: "SparksDown")!,
		SKEmitterNode(fileNamed: "SparksDown")!,
		SKEmitterNode(fileNamed: "SparksDown")!,
		SKEmitterNode(fileNamed: "SparksDown")!,
		SKEmitterNode(fileNamed: "SparksDown")!,
		SKEmitterNode(fileNamed: "SparksDown")!]
	
	func setUpScene(size: CGSize, leds: QuizLeds?) {
		if setUp {
			return
		}
		setUp = true
		
		self.size = size
		self.leds = leds
		
		self.backgroundColor = NSColor.blackColor()
		for (index, node) in numbers.enumerate() {
			node.fontColor = NSColor.blueColor()
			node.fontSize = 170.0
			node.horizontalAlignmentMode = .Center
			node.verticalAlignmentMode = .Center
			node.text = String(index + 1)
			node.position = CGPoint(x: (index * 190) + 105, y: 540)
			node.zPosition = 2
			self.addChild(node)
		}
		for (index, node) in sparksUp.enumerate() {
			node.position = CGPoint(x: (index * 190) + 105, y: 655)
			node.zPosition = 1
			self.addChild(node)
		}
		for (index, node) in sparksDown.enumerate() {
			node.position = CGPoint(x: (index * 190) + 105, y: 425)
			node.zPosition = 1
			self.addChild(node)
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
	}
	
	func buzzerPressed(team: Int) {
		numbers[team].fontColor = NSColor(calibratedHue: CGFloat(team) / 10.0, saturation: 1.0, brightness: 1.0, alpha: 1.0)
		leds?.buzzerOn(team)
		sparksUp[team].particleBirthRate = 600
		sparksDown[team].particleBirthRate = 600
		
		if team == 7 {
			self.runAction(eightSound)
		}
	}
	
	func buzzerReleased(team: Int) {
		numbers[team].fontColor = NSColor.whiteColor()
		leds?.buzzerOff(team)
		sparksUp[team].particleBirthRate = 0
		sparksDown[team].particleBirthRate = 0
	}
}
