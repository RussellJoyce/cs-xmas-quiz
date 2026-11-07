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

	/// Floods the scene with the colour of the team that has the buzz
	private var teamWash: SKSpriteNode?
	private static let washAlpha: CGFloat = 0.85
	private static let washKey = "teamWash"
	/// The team whose colour the room is washed with, or nil when resting
	private var washTeam: Int?
	private static let bokehColour = NSColor(calibratedRed: 1.0, green: 0.62, blue: 0.35, alpha: 1)
	private static let flareColour = NSColor(calibratedRed: 1.0, green: 0.85, blue: 0.75, alpha: 1)

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
			$0.particleColor = BuzzerScene.bokehColour
			$0.particleColorBlendFactor = 1
			$0.particleBlendMode = .add
		}
		flare1 = addBokehBackground(replacing: flare1, textureName: "flare1", zPosition: 0.5) {
			BuzzerScene.configureFlare($0)
		}
		flare2 = addBokehBackground(replacing: flare2, textureName: "flare2", zPosition: 0.5) {
			BuzzerScene.configureFlare($0)
		}

		//Over the background but under the bokeh, and outside the pulsable background for the
		//same reason as the bokeh. A team-coloured vignette: lighter in the middle, deeper at the edges.
		let washImage = radialGradientImage(size: self.size,
											colors: [NSColor(white: 1.0, alpha: 0.7), NSColor(white: 0.35, alpha: 1.0)],
											locations: [0.0, 1.0],
											centre: CGPoint(x: self.size.width / 2, y: self.size.height * 0.6),
											radius: hypot(self.size.width, self.size.height) * 0.55)
		let wash = SKSpriteNode(texture: SKTexture(image: washImage))
		wash.position = self.centrePoint
		wash.size = self.size
		wash.zPosition = 0.25
		wash.colorBlendFactor = 1
		wash.alpha = 0
		self.addChild(wash)
		teamWash = wash

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
			NSColor(calibratedRed: 0.9, green: 0.7, blue: 0.9, alpha: 1),
			NSColor(calibratedRed: 0.5, green: 0.5, blue: 0.9, alpha: 1),
			NSColor(calibratedRed: 0.3, green: 0.3, blue: 0.7, alpha: 1)
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
		flare.particleColor = BuzzerScene.flareColour
		flare.particleColorBlendFactor = 1
		flare.particleBlendMode = .add

		let twinkle = SKKeyframeSequence(keyframeValues: [0.0, 0.6, 0.0], times: [0.0, 0.5, 1.0])
		twinkle.interpolationMode = .spline
		flare.particleAlphaSequence = twinkle
	}

	override func didMove(to view: SKView) {
		super.didMove(to: view)
		//snow1 = addSnow(replacing: snow1, emitterNamed: "SnowBackground", zPosition: 1, xOffset: -300) {
		//	$0.particlePositionRange.dx = 2500
		//	$0.particleBirthRate = 50
		//}
	}
	
	
	/// Turns the room the colour of `team`, or back to its resting colours if nil.
	/// The bokeh only colours new particles, so it drifts over to the new colour over a few seconds.
	private func washRoom(team: Int?) {
		guard let wash = teamWash else { return }
		wash.removeAction(forKey: BuzzerScene.washKey)
		washTeam = team

		if let team = team {
			let colour = Utils.teamColour(team)
			let tint = SKAction.colorize(with: colour, colorBlendFactor: 1, duration: 0.3)
			let show = SKAction.fadeAlpha(to: BuzzerScene.washAlpha, duration: 0.3)
			if wash.alpha == 0 {
				//Nothing showing, so there is no old colour to blend away from
				wash.color = colour
				show.timingMode = .easeOut
				wash.run(show, withKey: BuzzerScene.washKey)
			} else {
				wash.run(SKAction.group([tint, show]), withKey: BuzzerScene.washKey)
			}
			bokeh?.particleColor = BuzzerScene.bokehColour.blended(withFraction: 0.85, of: colour) ?? colour
			let flare = BuzzerScene.flareColour.blended(withFraction: 0.45, of: colour) ?? colour
			flare1?.particleColor = flare
			flare2?.particleColor = flare
		} else {
			wash.run(SKAction.fadeOut(withDuration: 0.5), withKey: BuzzerScene.washKey)
			bokeh?.particleColor = BuzzerScene.bokehColour
			flare1?.particleColor = BuzzerScene.flareColour
			flare2?.particleColor = BuzzerScene.flareColour
		}
	}

	private static func restingParticleColour() -> NSColor {
		if Bool.random() { return .white }
		return NSColor(calibratedHue: .random(in: 0..<1), saturation: 0.8, brightness: 1, alpha: 1)
	}

	override func update(_ currentTime: TimeInterval) {
		super.update(currentTime)
		guard washTeam == nil else { return }
		for emitter in [bokeh, flare1, flare2] {
			emitter?.particleColor = BuzzerScene.restingParticleColour()
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
		washRoom(team: nil)
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
					
					let box = BuzzerTeamNode(team: team, width: 1000, height: 200, fontSize: 150, addGlow: true, entranceParticles: true, entranceShimmer: true, style: .glossy)
					box.position = CGPoint(x: self.centrePoint.x, y: self.size.height - 160)
					box.zPosition = 1
					teamBoxes.append(box)
					self.addChild(box)
					washRoom(team: team)
				} else {
					let box = BuzzerTeamNode(team: team, width: 800, height: 130, fontSize: 100, addGlow: false, entranceParticles: true, entranceShimmer: true, style: .glossy)
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
			washRoom(team: team)
			QuizWebSocket.shared?.setTeamColour(team)
			nextTeamNumber += 1
		}
	}
	
	func startTimer(_ secs : Int) {
		//The countdown only stops on reaching exactly 0, so it must start at 1 or more
		let secs = max(1, secs)
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

	/// Document view of the entrance-effects scroll view. Holds one checkbox per effect,
	/// made here rather than in the xib so that a new effect gets one automatically.
	@IBOutlet weak var entranceEffectsList: NSView!

	private var scene: BuzzerScene { host.quizDisplay.buzzerScene }

	func setUp() {
		let rowHeight: CGFloat = 22
		let width = entranceEffectsList.frame.width
		entranceEffectsList.subviews.forEach { $0.removeFromSuperview() }

		for (row, effect) in BuzzerEffects.Entrance.allCases.enumerated() {
			let toggle = NSButton(checkboxWithTitle: effect.title, target: self, action: #selector(entranceToggled(_:)))
			toggle.tag = row
			toggle.state = BuzzerEffects.enabledEntrances.contains(effect) ? .on : .off
			toggle.frame = NSRect(x: 4, y: 2 + CGFloat(row) * rowHeight, width: width - 8, height: rowHeight - 4)
			toggle.autoresizingMask = [.width]
			entranceEffectsList.addSubview(toggle)
		}

		let rows = CGFloat(BuzzerEffects.Entrance.allCases.count)
		entranceEffectsList.setFrameSize(NSSize(width: width, height: rows * rowHeight + 4))
	}

	@objc private func entranceToggled(_ sender: NSButton) {
		let effect = BuzzerEffects.Entrance.allCases[sender.tag]
		if sender.state == .on {
			BuzzerEffects.enabledEntrances.insert(effect)
		} else {
			BuzzerEffects.enabledEntrances.remove(effect)
		}
	}

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

/// A view whose origin is at the top left, so that a list laid out in it reads top
/// down and a scroll view holding it starts scrolled to the top.
final class FlippedView: NSView {
	override var isFlipped: Bool { true }
}
