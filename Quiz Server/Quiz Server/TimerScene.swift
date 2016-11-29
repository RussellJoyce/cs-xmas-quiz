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
import Darwin

class TimerScene: SKScene {

	var leds: QuizLeds?
	fileprivate var setUp = false
	fileprivate var correct: Int = 0
	fileprivate var time: Int = 60
	fileprivate var timer: Timer?
	fileprivate var pulseAction: SKAction?
	fileprivate let filternode = SKEffectNode()
	fileprivate var ledcount : Float = 0;
	
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
		bgImage.position = CGPoint(x:self.frame.midX, y:self.frame.midY)
		bgImage.size = self.size
		
		let exfilter = CIFilter(name: "CIExposureAdjust")
		exfilter?.setDefaults()
		exfilter?.setValue(1, forKey: "inputEV")
		filternode.filter = exfilter
		filternode.shouldRasterize = true
		filternode.addChild(bgImage)
		self.addChild(filternode)
		
		
		
		let pulseupaction = SKAction.customAction(withDuration: 0.15, actionBlock: {(node, time) -> Void in
			(node as! SKEffectNode).filter!.setValue(1 + (time*3), forKey: "inputEV")
		})
		
		let pulsednaction = SKAction.customAction(withDuration: 0.25, actionBlock: {(node, time) -> Void in
			(node as! SKEffectNode).filter!.setValue(1 + (0.25 - time)*3, forKey: "inputEV")
		})
		
		pulseupaction.timingMode = .easeInEaseOut
		pulsednaction.timingMode = .easeInEaseOut
		
		pulseAction = SKAction.sequence([
			SKAction.run({ () -> Void in
				self.filternode.shouldRasterize = false
			}),
			pulseupaction,
			tickSound,
			SKAction.run({ () -> Void in
				self.ledcount = self.ledcount + (5/3)
				let ledstodec = Int(floor(self.ledcount))
				for _ in 0..<ledstodec {
					self.leds?.stringPointlessDec()
				}
				self.ledcount -= floor(self.ledcount)
				
				self.time -= 1
				self.updateTime()
				if(self.time == 0) {
					self.timer?.invalidate()
					self.run(self.hornSound)
					leds?.stringPointlessCorrect()
					let p = SKEmitterNode(fileNamed: "SparksUp2")!
					p.position = CGPoint(x: self.centrePoint.x, y: 0)
					p.zPosition = 2
					p.removeWhenDone()
					self.addChild(p)
				}
			}),
			pulsednaction,
			SKAction.run({ () -> Void in
				self.filternode.shouldRasterize = true
			})
		])

		mainNode.position = CGPoint(x: 750, y: self.size.height - 360)
		countmainNode.position = CGPoint(x: 460, y: self.size.height - 700)
		
		text.fontSize = 300
		text.fontColor = NSColor.white
		text.horizontalAlignmentMode = .left
		text.verticalAlignmentMode = .baseline
		text.zPosition = 6
		text.position = CGPoint.zero
		shadowText.fontSize = 300
		shadowText.fontColor = NSColor(white: 0.1, alpha: 0.8)
		shadowText.horizontalAlignmentMode = .left
		shadowText.verticalAlignmentMode = .baseline
		shadowText.zPosition = 5
		shadowText.position = CGPoint.zero
		let textShadow = SKEffectNode()
		textShadow.shouldEnableEffects = true
		textShadow.shouldRasterize = true
		textShadow.zPosition = 5
		let filter = CIFilter(name: "CIGaussianBlur")
		filter?.setDefaults()
		filter?.setValue(350 / 5.8, forKey: "inputRadius")
		textShadow.filter = filter;
		textShadow.addChild(shadowText)
		
		counttext.fontSize = 200
		counttext.fontColor = NSColor.white
		counttext.horizontalAlignmentMode = .left
		counttext.verticalAlignmentMode = .baseline
		counttext.zPosition = 6
		counttext.position = CGPoint.zero
		countshadowText.fontSize = 200
		countshadowText.fontColor = NSColor(white: 0.1, alpha: 0.8)
		countshadowText.horizontalAlignmentMode = .left
		countshadowText.verticalAlignmentMode = .baseline
		countshadowText.zPosition = 5
		countshadowText.position = CGPoint.zero
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
		timer?.invalidate()
		updateAnswers()
		updateTime()
		leds?.stringPointlessReset()
	}
	
	func startTimer() {
		if(time == 0) {
			reset()
		}
		
		timer?.invalidate()
		timer = Timer(timeInterval: 1.0, target: self, selector: #selector(TimerScene.tick), userInfo: nil, repeats: true)
		RunLoop.main.add(timer!, forMode: .commonModes)
	}
	
	func tick() {
		filternode.run(pulseAction!)
	}
	
	func stopTimer() {
		timer?.invalidate()
	}
	
	func timerIncrement() {
		correct += 1
		self.run(blopSound)
		
		/*let sprayEmitter = SKEmitterNode(fileNamed: "TimerSpray")!
		sprayEmitter.position = CGPoint(x: 1430, y: self.size.height - 650)
		sprayEmitter.zPosition = 2
		self.addChild(sprayEmitter)
		var rnd: CGFloat?
		let sprayAction = SKAction.sequence([
			SKAction.runBlock({ () -> Void in
				rnd = CGFloat(arc4random_uniform(1000)) / CGFloat(1000)
			}),
			SKAction.customActionWithDuration(0.4, actionBlock: {(node, time) -> Void in
				sprayEmitter.emissionAngle = ((time / 0.4) * 3 * CGFloat(M_PI)) + (rnd! * 2 * CGFloat(M_PI))
				if(time > 0.3) {
					sprayEmitter.particleBirthRate = (0.4 - time) * 4000
				}
			}),
			SKAction.runBlock({ () -> Void in
				sprayEmitter.particleBirthRate = 0
			}),
			SKAction.waitForDuration(2),
			SKAction.removeFromParent()
		])
		
		sprayEmitter.runAction(sprayAction)*/
		
		updateAnswers()
	}
	
	func timerDecrement() {
		correct -= 1
		updateAnswers()
	}
	
	func updateTime() {
		if(time > 9) {
			mainNode.position = CGPoint(x: 770, y: self.size.height - 360)
		} else {
			mainNode.position = CGPoint(x: 850, y: self.size.height - 360)
		}
		text.text = String(time)
		shadowText.text = String(time)
	}
	
	func updateAnswers() {
		counttext.text = "Correct: " + String(correct)
		countshadowText.text = "Correct: " + String(correct)
	}
	
}
