//
//  BuzzerScene.swift
//  Quiz Server
//
//  Created by Russell Joyce on 17/11/2015.
//  Copyright © 2015 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import SpriteKit

class BuzzerScene: QuizScene {

	let useAlternateBuzzers = false
	
	var buzzNumber = 0
	var firstBuzzTime: Date?
	var teamEnabled = [Bool](repeating: true, count: 15) //Will be rebuilt every call of reset()
	var buzzes = [Int]()
	var nextTeamNumber = 0
	let buzzNoise = SKAction.playSoundFileNamed("buzzer", waitForCompletion: false)
	let buzzNoiseQuack = SKAction.playSoundFileNamed("altBuzz1", waitForCompletion: false)
	let buzzNoiseQuiet = SKAction.playSoundFileNamed("quietbuzz1", waitForCompletion: false)
	var teamBoxes = [BuzzerTeamNode]()
	
	var altBuzzNoise = [SKAction]()
	var lastAltBuzzIndex = 0
	
	var snow1 : SKEmitterNode?
	
	fileprivate var time: Int = 30
	fileprivate var starttime: Int = 30
	fileprivate var timer: Timer?
	let tickSound = SKAction.playSoundFileNamed("tick", waitForCompletion: false)
	let hornSound = SKAction.playSoundFileNamed("airhorn", waitForCompletion: false)
	fileprivate var pulseAction: SKAction?
	fileprivate var buzzPulseAction: SKAction?
	fileprivate var ledcount : Float = 0;


	override func buildScene() {
		let filternode = addPulsableBackground(imageNamed: "red2")

		let mainAction = SKAction.run({ () -> Void in
			self.ledcount = self.ledcount + (100/Float(self.starttime))
			self.ledcount -= floor(self.ledcount)
			self.time -= 1
			if(self.time == 0) {
				self.timer?.invalidate()
				self.run(self.hornSound)
				self.addEmitter(named: "SparksUp2", at: CGPoint(x: self.centrePoint.x, y: 0), zPosition: 2)
			}
		})
	
		pulseAction = Utils.createFilterPulse(upTime: 0.05, downTime: 0.25, filterNode: filternode, extraAction: SKAction.sequence([tickSound, mainAction]))
		buzzPulseAction = Utils.createFilterPulse(upTime: 0.05, downTime: 0.25, filterNode: filternode)
		
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
		
	}
	
	override func didMove(to view: SKView) {
		super.didMove(to: view)
		snow1 = addSnow(replacing: snow1, emitterNamed: "SnowBackground", zPosition: 1, xOffset: -300) {
			$0.particlePositionRange.dx = 2500
		}
	}
	
	
	func buzzSound(_ quietMode: Bool) {
		if timer != nil && timer!.isValid {
			self.run(buzzNoiseQuack)
		} else {
			if(quietMode) {
				//Play the quiet buzzer sound
				self.run(buzzNoiseQuiet)
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
	}
	
	override func reset() {
		if !(timer != nil && timer!.isValid) {
			QuizWebSocket.shared?.ledsOff();
		}
		teamEnabled = [Bool](repeating: true, count: Settings.shared.numTeams)
		buzzNumber = 0
		buzzes.removeAll()
		nextTeamNumber = 0
		
		for teamBox in teamBoxes {
			teamBox.removeFromParent()
		}
		teamBoxes.removeAll()
	}
	
	func buzzerPressed(team: Int, type: BuzzerType, buzzerQueueMode: Bool, quietMode: Bool, buzzerSounds : Bool) {
		if buzzes.count == 0 || (buzzes.count > 0 && buzzerQueueMode) {
			if teamEnabled[team] && buzzes.count < 5 {
				teamEnabled[team] = false
				
				buzzes.append(team)
				
				if buzzNumber == 0 {
					firstBuzzTime = Date()
					if buzzerSounds {
						buzzSound(quietMode)
					}
					if let t = timer {
						if !t.isValid {
							QuizWebSocket.shared?.buzz(team: team)
						}
					} else {
						QuizWebSocket.shared?.buzz(team: team)
					}
					nextTeamNumber = 1
					
					let box = BuzzerTeamNode(team: team, width: 1000, height: 200, fontSize: 150, addGlow: true, entranceParticles: true, entranceShimmer: true)
					box.position = CGPoint(x: self.centrePoint.x, y: self.size.height - 160)
					box.zPosition = 1
					teamBoxes.append(box)
					self.addChild(box)
				} else {
					let box = BuzzerTeamNode(team: team, width: 800, height: 130, fontSize: 100, addGlow: false, entranceParticles: true, entranceShimmer: true)
					box.position = CGPoint(x: self.centrePoint.x, y: (self.size.height - 230) - CGFloat(buzzNumber * 175))
					box.zPosition = 1
					teamBoxes.append(box)
					self.addChild(box)
				}
				
				buzzNumber += 1
				backgroundEffect?.run(buzzPulseAction!)
			}
		}
	}
	
	func nextTeam() {
		if nextTeamNumber < buzzes.count {
			teamBoxes[nextTeamNumber-1].run(SKAction.fadeAlpha(to: 0.3, duration: 0.5))
			teamBoxes[nextTeamNumber-1].stopGlow()
			teamBoxes[nextTeamNumber].startGlow()
			let team = buzzes[nextTeamNumber]
			QuizWebSocket.shared?.setTeamColour(team)
			nextTeamNumber += 1
		}
	}
	
	func startTimer(_ secs : Int) {
		time = secs
		starttime = secs
		timer?.invalidate()
		timer = Timer(timeInterval: 1.0, target: self, selector: #selector(BuzzerScene.tick), userInfo: nil, repeats: true)
		RunLoop.main.add(timer!, forMode: RunLoop.Mode.common)
	}
	
	func stopTimer() {
		QuizWebSocket.shared?.ledsOff()
		timer?.invalidate()
	}
	
	@objc func tick() {
		backgroundEffect?.run(pulseAction!)
	}

	override func teardown() {
		//The countdown is not cleared by reset(), so it must be stopped on the way out
		timer?.invalidate()
	}
	
}
