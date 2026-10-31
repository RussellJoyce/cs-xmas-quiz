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
	
	private var snow1 : SKEmitterNode?
	private var bokeh : SKEmitterNode?
	private var flare1 : SKEmitterNode?
	private var flare2 : SKEmitterNode?

	fileprivate var time: Int = 30
	fileprivate var starttime: Int = 30
	fileprivate var timer: Timer?
	let tickSound = SKAction.playSoundFileNamed("tick", waitForCompletion: false)
	let hornSound = SKAction.playSoundFileNamed("airhorn", waitForCompletion: false)
	fileprivate var pulseAction: SKAction?
	fileprivate var buzzPulseAction: SKAction?

	override func buildScene() {
		let filternode = addPulsableBackground(texture: SKTexture(image: backgroundGradientImage(size: self.size)))

		//Kept out of the pulsable background, as the pulse leaves that rasterised and would freeze them.
		//Just under the team boxes, which also sit at 1, as sibling order is not respected.
		bokeh = addBokehBackground(replacing: bokeh, textureName: "spark", zPosition: 0.5) {
			$0.particleBirthRate = 12
			$0.particleColor = NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.35, alpha: 1)
			$0.particleColorBlendFactor = 1
			$0.particleBlendMode = .add
		}
		flare1 = addBokehBackground(replacing: flare1, textureName: "flare1", zPosition: 0.5) {
			BuzzerScene.configureFlare($0)
		}
		flare2 = addBokehBackground(replacing: flare2, textureName: "flare2", zPosition: 0.5) {
			BuzzerScene.configureFlare($0)
		}

		let mainAction = SKAction.run({ () -> Void in
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
	
	private func backgroundGradientImage(size: CGSize) -> NSImage {
		let colours = [
			NSColor(calibratedRed: 0.96, green: 0.50, blue: 0.32, alpha: 1),
			NSColor(calibratedRed: 0.78, green: 0.16, blue: 0.18, alpha: 1),
			NSColor(calibratedRed: 0.32, green: 0.02, blue: 0.08, alpha: 1)
		]
		return radialGradientImage(size: size, colors: colours, locations: [0.0, 0.45, 1.0],
								   centre: CGPoint(x: size.width * 0.55, y: size.height * 0.6),
								   radius: hypot(size.width, size.height) * 0.6)
	}

	private static func configureFlare(_ flare: SKEmitterNode) {
		flare.particleBirthRate = 0.75
		flare.particleLifetime = 8
		flare.particleLifetimeRange = 2
		flare.particleScale = 0.5
		flare.particleScaleRange = 0.5
		flare.particleScaleSpeed = 0
		flare.particleRotationSpeed = 0.05
		flare.particleColor = NSColor(calibratedRed: 1.0, green: 0.85, blue: 0.75, alpha: 1)
		flare.particleColorBlendFactor = 1
		flare.particleBlendMode = .add

		let twinkle = SKKeyframeSequence(keyframeValues: [0.0, 0.6, 0.0], times: [0.0, 0.5, 1.0])
		twinkle.interpolationMode = .spline
		flare.particleAlphaSequence = twinkle
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
	
	override func buzzerPressed(team: Int, type: BuzzerType, options: BuzzerOptions) {
		if buzzes.count == 0 || (buzzes.count > 0 && options.buzzerQueueMode) {
			if teamEnabled[team] && buzzes.count < 5 {
				teamEnabled[team] = false
				
				buzzes.append(team)
				
				if buzzNumber == 0 {
					firstBuzzTime = Date()
					if options.buzzerSounds {
						buzzSound(options.quietMode)
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


// MARK: - Controller window

class BuzzerPanel: NSObject, RoundPanel {

	let round = RoundType.buzzers
	weak var host: ControllerWindowController!

	@IBOutlet weak var timerSeconds: NSTextField!

	private var scene: BuzzerScene { host.quizDisplay.buzzerScene }

	@IBAction func nextTeam(_ sender: AnyObject) {
		scene.nextTeam()
	}

	@IBAction func startTimer(_ sender: Any) {
		if let secs = Int(timerSeconds.stringValue) {
			scene.startTimer(secs)
		}
	}

	@IBAction func stopTimer(_ sender: Any) {
		scene.stopTimer()
	}
}
