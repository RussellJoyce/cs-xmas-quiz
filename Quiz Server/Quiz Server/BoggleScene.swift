//
//  TimedScoresScene.swift
//  Quiz Server
//
//  Created by Russell Joyce on 28/11/2016.
//  Copyright © 2016 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import SpriteKit

class BoggleScene: SKScene {
	
	var leds: QuizLeds?
	fileprivate var setUp = false
	var numTeams = 10
	
	private var teamScores = [Int]()
	private var time: Int = 120
	private var timer: Timer?
	
	let timerText = SKLabelNode(fontNamed: "Menlo")
	let timerShadowText = SKLabelNode(fontNamed: "Menlo")
	let timerTextNode = SKNode()
	
	let tickSound = SKAction.playSoundFileNamed("tick", waitForCompletion: false)
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
		
		teamScores = [Int](repeating: 0, count: numTeams)
		
		self.backgroundColor = NSColor.black
		
		let bgImage = SKSpriteNode(imageNamed: "background2")
		bgImage.zPosition = 0
		bgImage.position = CGPoint(x:self.frame.midX, y:self.frame.midY)
		bgImage.size = self.size
		self.addChild(bgImage)
		
		timerTextNode.position = CGPoint(x: self.size.width / 2, y: self.size.height - 360)
		timerText.fontSize = 300
		timerText.fontColor = NSColor.white
		timerText.horizontalAlignmentMode = .center
		timerText.verticalAlignmentMode = .baseline
		timerText.zPosition = 6
		timerText.position = CGPoint.zero
		timerShadowText.fontSize = 300
		timerShadowText.fontColor = NSColor(white: 0.1, alpha: 0.8)
		timerShadowText.horizontalAlignmentMode = .center
		timerShadowText.verticalAlignmentMode = .baseline
		timerShadowText.zPosition = 5
		timerShadowText.position = CGPoint.zero
		let textShadow = SKEffectNode()
		textShadow.shouldEnableEffects = true
		textShadow.shouldRasterize = true
		textShadow.zPosition = 5
		let filter = CIFilter(name: "CIGaussianBlur")
		filter?.setDefaults()
		filter?.setValue(350 / 5.8, forKey: "inputRadius")
		textShadow.filter = filter;
		textShadow.addChild(timerShadowText)
		timerTextNode.addChild(timerText)
		timerTextNode.addChild(textShadow)
		self.addChild(timerTextNode)
	}
	
	func reset() {
		teamScores = [Int](repeating: 0, count: numTeams)
		updateTime(seconds: 120)
		timer?.invalidate()
		//leds?.stringPointlessReset()
	}
	
	func updateTime(seconds : Int) {
		time = seconds;
		
		let secs = time % 60
		let mins = time / 60
		
		let timeString = String(format: "%02d:%02d", mins, secs)
		
		timerText.text = timeString
		timerShadowText.text = timeString
	}
	
	func startTimer() {
		if (time == 0) {
			reset()
		}
		
		timer?.invalidate()
		timer = Timer(timeInterval: 1.0, target: self, selector: #selector(timerTick), userInfo: nil, repeats: true)
		RunLoop.main.add(timer!, forMode: .commonModes)
	}
	
	func stopTimer() {
		timer?.invalidate()
	}
	
	func timerTick() {
		updateTime(seconds: time - 1);
	}
}
