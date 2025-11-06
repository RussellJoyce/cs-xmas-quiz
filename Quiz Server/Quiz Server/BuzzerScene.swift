//
//  BuzzerScene.swift
//  Quiz Server
//
//  Created by Russell Joyce on 17/11/2015.
//  Copyright © 2015 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import SpriteKit
import Starscream

class BuzzerScene: SKScene {
	fileprivate var setUp = false
	var webSocket: WebSocket?
	
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
	fileprivate let filternode = SKEffectNode()
	fileprivate var ledcount : Float = 0;


	func setUpScene(size: CGSize, webSocket: WebSocket?) {
		if setUp {
			return
		}
		setUp = true
		
		self.size = size
		self.webSocket = webSocket;
		
		let bgImage = SKSpriteNode(imageNamed: "red2")
		bgImage.zPosition = 0
		bgImage.position = CGPoint(x:self.frame.midX, y:self.frame.midY)
		bgImage.size = self.size
		
		let exfilter = CIFilter(name: "CIExposureAdjust")
		exfilter?.setDefaults()
		exfilter?.setValue(0, forKey: "inputEV")
		filternode.filter = exfilter
		filternode.shouldRasterize = true
		filternode.addChild(bgImage)
		self.addChild(filternode)
		
		let pulseupaction = SKAction.customAction(withDuration: 0.05, actionBlock: {
			(node, time) -> Void in (node as! SKEffectNode).filter!.setValue((time*3), forKey: "inputEV")
			self.filternode.shouldRasterize = false
			self.filternode.shouldRasterize = true
		})
		
		let pulsednaction = SKAction.customAction(withDuration: 0.25, actionBlock: {(node, time) -> Void in
			(node as! SKEffectNode).filter!.setValue((0.25 - time)*3, forKey: "inputEV")
			self.filternode.shouldRasterize = false
			self.filternode.shouldRasterize = true
		})
		
		let makeNotRaster = SKAction.run({() -> Void in self.filternode.shouldRasterize = false})
		let makeRaster = SKAction.run({() -> Void in self.filternode.shouldRasterize = true})
		
		pulseupaction.timingMode = .easeOut
		pulsednaction.timingMode = .easeOut
		
		pulseAction = SKAction.sequence([
			makeNotRaster,
			pulseupaction,
			tickSound,
			SKAction.run({ () -> Void in
				self.ledcount = self.ledcount + (100/Float(self.starttime))
				self.ledcount -= floor(self.ledcount)
				self.time -= 1
				if(self.time == 0) {
					self.timer?.invalidate()
					self.run(self.hornSound)
					let p = SKEmitterNode(fileNamed: "SparksUp2")!
					p.position = CGPoint(x: self.centrePoint.x, y: 0)
					p.zPosition = 2
					p.removeWhenDone()
					self.addChild(p)
				}
			}),
			pulsednaction,
			makeRaster
		])
		
		//Pulse for when a team buzzes
		buzzPulseAction = SKAction.sequence([makeNotRaster, pulseupaction, pulsednaction, makeRaster])
		
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
	
	override func didMove(to view: SKView) {
		super.didMove(to: view)
		if let sn = snow1 {
			sn.removeFromParent()
		}
		let snow1 = SKEmitterNode(fileNamed: "SnowBackground")!
		snow1.position = CGPoint(x: self.size.width / 2 - 300, y: self.size.height + 16)
		snow1.zPosition = 1
		snow1.particlePositionRange.dx = 2500
		snow1.advanceSimulationTime(8) //Calculate to immediately fill screen
		self.addChild(snow1)
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
	
	func reset() {
		if !(timer != nil && timer!.isValid) {
			webSocket?.ledsOff();
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
							webSocket?.buzz(team: team)
						}
					} else {
						webSocket?.buzz(team: team)
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
				filternode.run(buzzPulseAction!)
			}
		}
	}
	
	func nextTeam() {
		if nextTeamNumber < buzzes.count {
			teamBoxes[nextTeamNumber-1].run(SKAction.fadeAlpha(to: 0.3, duration: 0.5))
			teamBoxes[nextTeamNumber-1].stopGlow()
			teamBoxes[nextTeamNumber].startGlow()
			let team = buzzes[nextTeamNumber]
			webSocket?.setTeamColour(team: team)
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
		webSocket?.ledsOff()
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
