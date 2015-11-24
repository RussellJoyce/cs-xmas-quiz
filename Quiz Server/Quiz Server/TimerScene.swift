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
	private var running: Bool = false
	private var starttime: NSDate = NSDate()
	private var tickcount: Int = 0
	
	let text = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	let shadowText = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	
	let counttext = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	let countshadowText = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	let mainNode = SKNode()
	let countmainNode = SKNode()
	
	let tickSound = try! AVAudioPlayer(
		contentsOfURL: NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource("tick", ofType: "mp3")!))
	let blopSound = try! AVAudioPlayer(
		contentsOfURL: NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource("blop", ofType: "mp3")!))
	let hornSound = try! AVAudioPlayer(
		contentsOfURL: NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource("airhorn", ofType: "mp3")!))
	
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
		self.addChild(bgImage)
		
		mainNode.position = CGPoint(x: self.centrePoint.x, y: self.size.height - 360)
		countmainNode.position = CGPoint(x: self.centrePoint.x, y: self.size.height - 700)
		
		text.text = "60"
		text.fontSize = 300
		text.fontColor = NSColor.whiteColor()
		text.horizontalAlignmentMode = .Center
		text.verticalAlignmentMode = .Baseline
		text.zPosition = 6
		text.position = CGPointZero
		shadowText.text = "60"
		shadowText.fontSize = 300
		shadowText.fontColor = NSColor(white: 0.1, alpha: 0.8)
		shadowText.horizontalAlignmentMode = .Center
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
		
		counttext.text = "Answers: 0"
		counttext.fontSize = 200
		counttext.fontColor = NSColor.whiteColor()
		counttext.horizontalAlignmentMode = .Center
		counttext.verticalAlignmentMode = .Baseline
		counttext.zPosition = 6
		counttext.position = CGPointZero
		countshadowText.text = "Answers: 0"
		countshadowText.fontSize = 200
		countshadowText.fontColor = NSColor(white: 0.1, alpha: 0.8)
		countshadowText.horizontalAlignmentMode = .Center
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
		time = 60
		running = false
		updateAnswers()
		updateTime()
	}
	
	func startTimer() {
		tickcount = 1
		running = true
		starttime = NSDate()
		dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), {
			NSThread.sleepUntilDate(self.starttime.dateByAddingTimeInterval(NSTimeInterval(self.tickcount)))
			dispatch_async(dispatch_get_main_queue(), {
				self.tick();
			})
		})
	}
	
	func tick() {
		if(running) {
			time--
			tickcount++
			updateTime()
			if(time == 0) {
				running = false
				hornSound.currentTime = 0
				hornSound.play()
				
				let p = SKEmitterNode(fileNamed: "SparksUp2")!
				p.position = CGPoint(x: self.centrePoint.x, y: 0)
				p.zPosition = 2
				p.removeWhenDone()
				self.addChild(p)
			} else {
				tickSound.currentTime = 0
				tickSound.play()
				dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), {
					NSThread.sleepUntilDate(self.starttime.dateByAddingTimeInterval(NSTimeInterval(self.tickcount)))
					dispatch_async(dispatch_get_main_queue(), {
						self.tick();
					})
				})
			}
		}
	}
	
	func stopTimer() {
		running = false
	}
	
	func timerIncrement() {
		correct++
		blopSound.currentTime = 0
		blopSound.play()
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
		counttext.text = "Answers: " + String(correct)
		countshadowText.text = "Answers: " + String(correct)
	}
	
}
