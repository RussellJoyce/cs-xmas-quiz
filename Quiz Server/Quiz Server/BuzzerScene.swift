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
	fileprivate var setUp = false
	var numTeams = 10
	
	let useAlternateBuzzers = false
	
	var buzzNumber = 0
	var firstBuzzTime: Date?
	var teamEnabled = [Bool](repeating: true, count: 10)
	var buzzes = [Int]()
	var nextTeamNumber = 0
	let buzzNoise = SKAction.playSoundFileNamed("buzzer", waitForCompletion: false)
	let buzzNoiseQuack = SKAction.playSoundFileNamed("altBuzz1", waitForCompletion: false)
	var teamBoxes = [BuzzerTeamNode]()
	
	var altBuzzNoise = [SKAction]()
	var lastAltBuzzIndex = 0
	
	fileprivate var time: Int = 30
	fileprivate var starttime: Int = 30
	fileprivate var timer: Timer?
	let tickSound = SKAction.playSoundFileNamed("tick", waitForCompletion: false)
	let hornSound = SKAction.playSoundFileNamed("airhorn", waitForCompletion: false)
	fileprivate var pulseAction: SKAction?
	fileprivate let filternode = SKEffectNode()
	fileprivate var ledcount : Float = 0;
		
	func setUpScene(size: CGSize, leds: QuizLeds?, numTeams: Int) {
		if setUp {
			return
		}
		setUp = true
		
		self.size = size
		self.leds = leds
		self.numTeams = numTeams
		
		let bgImage = SKSpriteNode(imageNamed: "abstract-tree-and-stars")
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
		
		let pulseupaction = SKAction.customAction(withDuration: 0.15, actionBlock: {
			(node, time) -> Void in (node as! SKEffectNode).filter!.setValue(1 + (time*3), forKey: "inputEV")
			self.filternode.shouldRasterize = false
			self.filternode.shouldRasterize = true
		})
		
		let pulsednaction = SKAction.customAction(withDuration: 0.25, actionBlock: {(node, time) -> Void in
			(node as! SKEffectNode).filter!.setValue(1 + (0.25 - time)*3, forKey: "inputEV")
			self.filternode.shouldRasterize = false
			self.filternode.shouldRasterize = true
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
				self.ledcount = self.ledcount + (100/Float(self.starttime))
				let ledstodec = Int(floor(self.ledcount))
				for _ in 0..<ledstodec {
					self.leds?.stringPointlessDec()
				}
				self.ledcount -= floor(self.ledcount)
				
				self.time -= 1
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
		
		
		//Load any alternative Buzzer sounds
		do {
			let docsArray = try FileManager.default.contentsOfDirectory(atPath: Bundle.main.resourcePath!)
			for fileName in docsArray {
				if fileName.starts(with: "altBuzz") {
					altBuzzNoise.append(SKAction.playSoundFileNamed(fileName, waitForCompletion: false))
				}
			}
			altBuzzNoise.shuffle()
		} catch {
			print(error)
		}
		
		//self.addChild(bgImage)
	}
	
	func buzzSound() {
		if timer != nil && timer!.isValid {
			self.run(buzzNoiseQuack)
		} else {
			if useAlternateBuzzers && Int.random(in: 0...8) == 0 {
				//Play the next alternative buzzer sound
				if lastAltBuzzIndex >= altBuzzNoise.count {
					lastAltBuzzIndex = 0
				}
				self.run(altBuzzNoise[lastAltBuzzIndex])
				lastAltBuzzIndex = lastAltBuzzIndex + 1
			} else {
				//Play the default buzzer sound
				self.run(buzzNoise)
			}
		}
	}
	
	func reset() {
		if !(timer != nil && timer!.isValid) {
			leds?.stringOff()
		}
		teamEnabled = [Bool](repeating: true, count: 10)
		buzzNumber = 0
		buzzes.removeAll()
		nextTeamNumber = 0
		
		for teamBox in teamBoxes {
			teamBox.removeFromParent()
		}
		teamBoxes.removeAll()
	}
	
	func buzzerPressed(team: Int, type: BuzzerType, buzzerQueueMode: Bool) {
		if buzzes.count == 0 || (buzzes.count > 0 && buzzerQueueMode) {
			if teamEnabled[team] && buzzes.count < 5 {
				teamEnabled[team] = false
				
				buzzes.append(team)
				
				if buzzNumber == 0 {
					firstBuzzTime = Date()
					buzzSound()
					if let t = timer {
						if !t.isValid {
							leds?.stringTeamAnimate(team: team)
						}
					} else {
						leds?.stringTeamAnimate(team: team)
					}
					nextTeamNumber = 1
					
					let box = BuzzerTeamNode(team: team, width: 1000, height: 200, fontSize: 150, addGlow: true)
					box.position = CGPoint(x: self.centrePoint.x, y: self.size.height - 160)
					box.zPosition = 1
					teamBoxes.append(box)
					self.addChild(box)
					
				} else {
					let box = BuzzerTeamNode(team: team, width: 800, height: 130, fontSize: 100, addGlow: false)
					box.position = CGPoint(x: self.centrePoint.x, y: (self.size.height - 230) - CGFloat(buzzNumber * 175))
					box.zPosition = 1
					teamBoxes.append(box)
					self.addChild(box)
				}
				
				buzzNumber += 1
			}
		}
	}
	
	func nextTeam() {
		if nextTeamNumber < buzzes.count {
			teamBoxes[nextTeamNumber-1].run(SKAction.fadeAlpha(to: 0.3, duration: 0.5))
			teamBoxes[nextTeamNumber-1].stopGlow()
			teamBoxes[nextTeamNumber].startGlow()
			let team = buzzes[nextTeamNumber]
			leds?.stringTeamColour(team: team)
			nextTeamNumber += 1
		}
	}
	
	func startTimer(_ secs : Int) {
		time = secs
		starttime = secs
		timer?.invalidate()
		leds?.stringPointlessReset()
		timer = Timer(timeInterval: 1.0, target: self, selector: #selector(BuzzerScene.tick), userInfo: nil, repeats: true)
		RunLoop.main.add(timer!, forMode: RunLoop.Mode.common)
	}
	
	func stopTimer() {
		leds?.stringOff()
		timer?.invalidate()
	}
	
	@objc func tick() {
		filternode.run(pulseAction!)
	}
	
}


extension SKNode {
	var centrePoint: CGPoint {
		return CGPoint(x:self.frame.midX, y:self.frame.midY)
	}
}
