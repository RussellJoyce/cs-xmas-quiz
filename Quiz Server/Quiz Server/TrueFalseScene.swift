//
//  TrueFalseScene.swift
//  Quiz Server
//
//  Created by Ian Gray on 11/12/2023.
//  Copyright © 2023 Russell Joyce & Ian Gray. All rights reserved.
//

import Foundation
import Cocoa
import SpriteKit
import Starscream
import AVFoundation

class TrueFalseScene: SKScene, QuizRound {
	
	static let TIMEOUT = 5
	
	var counting = false
	var teamEnabled = [Bool]()
	var teamGuesses = [Bool?]()
	var fireEmitter = SKEmitterNode(fileNamed: "SparksUp2")!
	var webSocket: WebSocket?
	fileprivate var setUp = false
	fileprivate var time: Int = TIMEOUT
	fileprivate var timer: Timer?
	fileprivate var mode: Bool = true
	fileprivate var tickSounds : Bool = true
	var teamBoxes = [TrueFalseTeamNode]()
	
	let tickSound = SKAction.playSoundFileNamed("timer.wav", waitForCompletion: false)
	let tickEnd = SKAction.playSoundFileNamed("timerend.wav", waitForCompletion: false)
	let tensionend = SKAction.playSoundFileNamed("counter_score100.wav", waitForCompletion: false)
	var music: AVAudioPlayer?
	
	var timeLabel: OutlinedLabelNode!
		
	func setUpScene(size: CGSize, webSocket : WebSocket?) {
		if setUp {
			return
		}
		setUp = true
		
		self.size = size
		self.webSocket = webSocket
		
		let bgImage = SKSpriteNode(imageNamed: "blackflakes")
		bgImage.zPosition = 0
		bgImage.position = CGPoint(x:self.frame.midX, y:self.frame.midY)
		bgImage.size = self.size
		self.addChild(bgImage)
		
		
		timeLabel = OutlinedLabelNode(
			text: "5",
			fontNamed: ".AppleSystemUIFontBold",
			fontSize: 120,
			fontColor: NSColor.white,
			outlineColor: NSColor.black,
			outlineWidth: 6.0
		)
		timeLabel.positionInParent = CGPoint(x: self.centrePoint.x, y: self.frame.height - 200)
		timeLabel.zPosition = 6
		self.addChild(timeLabel)
		
		let halfway = Int((Double(Settings.shared.numTeams) / 2).rounded(.up))
		var boxheight : Int = 150
		if(Settings.shared.numTeams > 10) {
			boxheight = 100
		}
		
		for team in 0..<Settings.shared.numTeams {
			var yOffset : Int
			if team >= halfway {
				yOffset = ((halfway-1) - (team - halfway)) * Int(Double(boxheight)*1.3)
			} else {
				yOffset = ((halfway-1) - team) * Int(Double(boxheight)*1.3)
			}
			let position = CGPoint(
				x: (team < halfway) ? self.centrePoint.x - 500 : self.centrePoint.x + 500,
				y: CGFloat(boxheight + 10 + yOffset)
			)
			let box = TrueFalseTeamNode(team: team, width: 600, height: boxheight, position: position, fontsize: Settings.shared.numTeams >= 10 ? 60 : 40)
			
			box.zPosition = 1
			teamBoxes.append(box)
			self.addChild(box)
		}
		
		//Fire emitter
		fireEmitter.position = CGPoint(x: self.centrePoint.x, y: -50)
		fireEmitter.zPosition = 2
		fireEmitter.numParticlesToEmit = 0
		fireEmitter.particleSpeed = 700
		fireEmitter.particleBirthRate = 0
		self.addChild(fireEmitter)
		
		reset()
	}
	
	func setMode(_ tfmode : Bool) {
		//If true then set to True/False mode, else Higher/Lower mode
		mode = tfmode
	}
	
	func reset() {
		self.timer?.invalidate()
		self.timeLabel.text = ""
		
		teamGuesses = [Bool?](repeating: nil, count: Settings.shared.numTeams)
		teamEnabled = [Bool](repeating: true, count: Settings.shared.numTeams)
		
		for i in 0..<Settings.shared.numTeams {
			teamBoxes[i].guessLabel.text = "Team \(i + 1)"
			teamBoxes[i].setEnabled(true)
		}
		self.time = TrueFalseScene.TIMEOUT
		self.counting = false
		self.stopFire();
		self.webSocket?.sendIfConnected(mode ? "h2" : "h1")
	}
	
	func addParticles() {
		let timeParticles = SKEmitterNode(fileNamed: "BuzzGlow")!
		timeParticles.particleColorSequence = nil
		timeParticles.particleColor = NSColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
		timeParticles.position = timeLabel.position
		timeParticles.zPosition = 2
		timeParticles.particlePositionRange.dx = 200
		timeParticles.particlePositionRange.dy = 200
		timeParticles.numParticlesToEmit = 120
		timeParticles.removeWhenDone()
		self.addChild(timeParticles)
	}
	
	func start(sounds: Bool) {
		self.time = TrueFalseScene.TIMEOUT
		teamGuesses = [Bool?](repeating: nil, count: Settings.shared.numTeams)
		
		timer?.invalidate()
		tickSounds = sounds
		timer = Timer(timeInterval: 1.0, target: self, selector: #selector(TrueFalseScene.tick), userInfo: nil, repeats: true)
		RunLoop.main.add(timer!, forMode: RunLoop.Mode.common)
		self.timeLabel.text = String(TrueFalseScene.TIMEOUT)
		addParticles()
		counting = true;
		self.webSocket?.setCounterValue(val: 200)
		
		if sounds {
			self.run(self.tickSound)
		}
	}
	
	func startNoTimer(sounds: Bool) {
		if self.counting == false {
			//Starting
			self.counting = true
			teamGuesses = [Bool?](repeating: nil, count: Settings.shared.numTeams)
			webSocket?.sendIfConnected("ha") //Also clear emphasis just in case
			self.timeLabel.text = "GO!"
			self.addParticles()
			self.createFire()

			music = nil
			if sounds {
				if let musicUrl = Bundle.main.url(forResource: "counter_soft_end", withExtension: "wav") {
					do {
						try music = AVAudioPlayer(contentsOf: musicUrl)
					} catch let error {
						print(error.localizedDescription)
					}
					music?.play()
				}
			}
			
		} else {
			//Stopping
			self.counting = false
			self.webSocket?.pulseWhite()
			self.timeLabel.text = ""
			self.revealTeamGuesses()
			self.stopFire()
			
			if sounds {
				music?.pause()
				self.run(self.tensionend)
			}
		}
	}
	
	func createFire() {
		fireEmitter.particleBirthRate = 3000
	}
	
	func stopFire() {
		fireEmitter.particleBirthRate = 0
	}
	
	@objc func tick() {
		self.run(SKAction.run({ () -> Void in
			self.time -= 1
			let lednum = Int(200.0 * Float(self.time) / Float(TrueFalseScene.TIMEOUT))
			self.webSocket?.setCounterValue(val: lednum)
			if(self.time > 0) {
				self.timeLabel.text = String(self.time)
				self.addParticles()
				if self.tickSounds {
					self.run(self.tickSound)
				}
			} else {
				self.counting = false
				self.timer?.invalidate()
				if self.tickSounds {
					self.run(self.tickEnd)
				}
				self.webSocket?.pulseWhite()
				self.timeLabel.text = ""
				self.revealTeamGuesses()
			}
		})
		)
	}
	
	func revealTeamGuesses() {
		for team in 0..<Settings.shared.numTeams {
			if teamEnabled[team] {
				teamBoxes[team].setEnabled(true)
				if teamGuesses[team] != nil {
					if mode {
						teamBoxes[team].guessLabel.text = teamGuesses[team]! ? "Team \(team + 1): TRUE" : "Team \(team + 1): FALSE"
					} else {
						teamBoxes[team].guessLabel.text = teamGuesses[team]! ? "Team \(team + 1): HIGHER" : "Team \(team + 1): LOWER"
					}
					teamBoxes[team].setGuessColour(teamGuesses[team]!)
				} else {
					teamBoxes[team].guessLabel.text = "Team \(team + 1) no guess"
				}
			} else {
				teamBoxes[team].setEnabled(false)
				teamBoxes[team].guessLabel.text = "Team \(team + 1) OUT"
			}
		}
	}
	
	func showAnswer(ans: Bool) {
		for team in 0..<Settings.shared.numTeams {
			if teamGuesses[team] == nil {
				teamEnabled[team] = false
			} else {
				let tg = teamGuesses[team]!
				teamEnabled[team] = tg && ans || !tg && !ans
			}
			
			teamBoxes[team].guessLabel.text = "Team \(team + 1)"
			teamBoxes[team].setEnabled(teamEnabled[team])
		}
	}
	
	func teamGuess(teamid : Int, guess : Bool) {
		if counting && teamEnabled[teamid] {
			teamGuesses[teamid] = guess
			teamBoxes[teamid].setIfGuessed(true)
			teamBoxes[teamid].pulseBox()
		}
	}
}

class TrueFalseTeamNode: SKNode {
	
	var width : Int = 0
	var height : Int = 0
	var teamNo : Int
	var fontsize : CGFloat
	var bgBox : SKShapeNode
	
	static let bgColour = NSColor(calibratedHue: 0, saturation: 0.0, brightness: 0.9, alpha: 0.9)
	static let bgColourTrue = NSColor(calibratedHue: 0.3, saturation: 0.4, brightness: 0.9, alpha: 0.9)
	static let bgColourFalse = NSColor(calibratedHue: 0, saturation: 0.4, brightness: 0.9, alpha: 0.9)
	static let bgColourDisabled = NSColor(calibratedHue: 0, saturation: 0.0, brightness: 0.4, alpha: 0.9)
	static let bgColourGuessed = NSColor(calibratedHue: 0.5, saturation: 0.5, brightness: 0.9, alpha: 0.9)
	static let textColStd = NSColor.black
	static let textColOut = NSColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1)
	
	var guessLabel = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	
	func setEnabled(_ e : Bool) {
		if e {
			bgBox.fillColor = TrueFalseTeamNode.bgColour
			guessLabel.fontColor = TrueFalseTeamNode.textColStd
		} else {
			bgBox.fillColor = TrueFalseTeamNode.bgColourDisabled
			guessLabel.fontColor = TrueFalseTeamNode.textColOut
		}
	}
	
	func setGuessColour(_ g : Bool) {
		bgBox.fillColor = g ? TrueFalseTeamNode.bgColourTrue : TrueFalseTeamNode.bgColourFalse
	}
	
	func setIfGuessed(_ g : Bool) {
		bgBox.fillColor = g ? TrueFalseTeamNode.bgColourGuessed : TrueFalseTeamNode.bgColour
	}
	
	init(team: Int, width: Int, height: Int, position : CGPoint, fontsize : CGFloat) {
		bgBox = SKShapeNode(rectOf: CGSize(width: width, height: height))
		bgBox.zPosition = 5
		bgBox.position = CGPoint.zero
		bgBox.fillColor = TrueFalseTeamNode.bgColour
		bgBox.lineWidth = 2.0
		
		guessLabel.text = "aaa"
		guessLabel.fontSize = fontsize
		guessLabel.fontColor = NSColor.black
		guessLabel.horizontalAlignmentMode = .center
		guessLabel.verticalAlignmentMode = .center
		guessLabel.zPosition = 6
		guessLabel.position = CGPoint(x: 0, y: 0)
		
		self.width = width
		self.height = height
		self.teamNo = team
		self.fontsize = fontsize
		
		super.init()
		
		self.position = position
		self.addChild(bgBox)
		self.addChild(guessLabel)
	}
	
	func pulseBox() {
		let pulseSequence = SKAction.sequence([SKAction.scale(to: 1.1, duration: 0.1), SKAction.scale(to: 1.0, duration: 0.5)])
		pulseSequence.timingMode = .easeInEaseOut
		self.run(pulseSequence)
	}
	
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

