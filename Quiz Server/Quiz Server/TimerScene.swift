//
//  TimerScene.swift
//  Quiz Server
//
//  Created by Ian Gray on 23/11/2015.
//  Copyright © 2015 Russell Joyce & Ian Gray. All rights reserved.
//

import Foundation
import Cocoa
import SpriteKit
import AVFoundation

class TimerScene: SKScene {

	var leds: QuizLeds?
	private var setUp = false
	private var correct: Int = 0
	private var time: Int = 60
	private var timer: NSTimer?
	private var pulseAction: SKAction?
	private let filternode = SKEffectNode()
	
	let text = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	let shadowText = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	
	let counttext = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	let countshadowText = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	let mainNode = SKNode()
	let countmainNode = SKNode()
	
	let tickSound = SKAction.playSoundFileNamed("tick", waitForCompletion: false)
	let blopSound = SKAction.playSoundFileNamed("blop", waitForCompletion: false)
	let hornSound = SKAction.playSoundFileNamed("airhorn", waitForCompletion: false)
	
	func setUpScene(size: CGSize, leds: QuizLeds?) {
		if setUp {
			return
		}
		setUp = true
		
		self.size = size
		self.leds = leds
		correct = 0
		time = 60
		
		let bgImage = SKSpriteNode(imageNamed: "3")
		bgImage.zPosition = 0
		bgImage.position = CGPoint(x:CGRectGetMidX(self.frame), y:CGRectGetMidY(self.frame))
		bgImage.size = self.size
		
		let exfilter = CIFilter(name: "CIExposureAdjust")
		exfilter?.setDefaults()
		exfilter?.setValue(1, forKey: "inputEV")
		filternode.filter = exfilter
		filternode.shouldRasterize = true
		filternode.addChild(bgImage)
		self.addChild(filternode)
		
		
		
		let pulseupaction = SKAction.customActionWithDuration(0.15, actionBlock: {(node, time) -> Void in
			(node as! SKEffectNode).filter!.setValue(1 + (time*3), forKey: "inputEV")
		})
		
		let pulsednaction = SKAction.customActionWithDuration(0.25, actionBlock: {(node, time) -> Void in
			(node as! SKEffectNode).filter!.setValue(1 + (0.25 - time)*3, forKey: "inputEV")
		})
		
		pulseupaction.timingMode = .EaseInEaseOut
		pulsednaction.timingMode = .EaseInEaseOut
		
		pulseAction = SKAction.sequence([
			SKAction.runBlock({ () -> Void in
				self.filternode.shouldRasterize = false
			}),
			pulseupaction,
			tickSound,
			SKAction.runBlock({ () -> Void in
				self.time--
				self.updateTime()
				if(self.time == 0) {
					self.timer?.invalidate()
					self.runAction(self.hornSound)
					let p = SKEmitterNode(fileNamed: "SparksUp2")!
					p.position = CGPoint(x: self.centrePoint.x, y: 0)
					p.zPosition = 2
					p.removeWhenDone()
					self.addChild(p)
				}
			}),
			pulsednaction,
			SKAction.runBlock({ () -> Void in
				self.filternode.shouldRasterize = true
			})
		])
		

		mainNode.position = CGPoint(x: 900, y: self.size.height - 360)
		countmainNode.position = CGPoint(x: 560, y: self.size.height - 700)
		
		text.fontSize = 300
		text.fontColor = NSColor.whiteColor()
		text.horizontalAlignmentMode = .Left
		text.verticalAlignmentMode = .Baseline
		text.zPosition = 6
		text.position = CGPointZero
		shadowText.fontSize = 300
		shadowText.fontColor = NSColor(white: 0.1, alpha: 0.8)
		shadowText.horizontalAlignmentMode = .Left
		shadowText.verticalAlignmentMode = .Baseline
		shadowText.zPosition = 5
		shadowText.position = CGPointZero
		let textShadow = SKEffectNode()
		textShadow.shouldEnableEffects = true
		textShadow.shouldRasterize = true
		textShadow.zPosition = 5
		let filter = CIFilter(name: "CIGaussianBlur")
		filter?.setDefaults()
		filter?.setValue(120 / 5.8, forKey: "inputRadius")
		textShadow.filter = filter;
		textShadow.addChild(shadowText)
		
		counttext.fontSize = 200
		counttext.fontColor = NSColor.whiteColor()
		counttext.horizontalAlignmentMode = .Left
		counttext.verticalAlignmentMode = .Baseline
		counttext.zPosition = 6
		counttext.position = CGPointZero
		countshadowText.fontSize = 200
		countshadowText.fontColor = NSColor(white: 0.1, alpha: 0.8)
		countshadowText.horizontalAlignmentMode = .Left
		countshadowText.verticalAlignmentMode = .Baseline
		countshadowText.zPosition = 5
		countshadowText.position = CGPointZero
		let counttextShadow = SKEffectNode()
		counttextShadow.shouldEnableEffects = true
		counttextShadow.shouldRasterize = true
		counttextShadow.zPosition = 5
		counttextShadow.filter = filter;
		counttextShadow.addChild(countshadowText)
		
		mainNode.addChild(text)
		mainNode.addChild(textShadow)
		countmainNode.addChild(counttext)
		countmainNode.addChild(counttextShadow)

		self.addChild(countmainNode)
		self.addChild(mainNode)
	}
	

	func reset() {
		correct = 0
		time = 5
		timer?.invalidate()
		updateAnswers()
		updateTime()
	}
	
	func startTimer() {
		if(time == 0) {
			reset()
		}
		
		timer?.invalidate()
		timer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: Selector("tick"), userInfo: nil, repeats: true)
	}
	
	func tick() {
		filternode.runAction(pulseAction!)
	}
	
	func stopTimer() {
		timer?.invalidate()
	}
	
	func timerIncrement() {
		correct++
		self.runAction(blopSound)
		updateAnswers()
	}
	
	func timerDecrement() {
		correct--
		updateAnswers()
	}
	
	func updateTime() {
		text.text = String(time)
		shadowText.text = String(time)
	}
	
	func updateAnswers() {
		counttext.text = "Correct: " + String(correct)
		countshadowText.text = "Correct: " + String(correct)
	}
	
}
