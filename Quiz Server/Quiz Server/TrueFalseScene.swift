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

class TrueFalseScene: SKScene {
	
	static let TIMEOUT = 5
	
	var counting = false
	var teamEnabled = [Bool]()
	var teamGuesses = [Bool?]()
	var leds: QuizLeds?
	var webSocket: WebSocket?
	fileprivate var setUp = false
	fileprivate var time: Int = TIMEOUT
	fileprivate var timer: Timer?
	var numTeams = 10
	var teamBoxes = [TrueFalseTeamNode]()
	
	var tickSound = SKAction.playSoundFileNamed("timer", waitForCompletion: false)
	var tickEnd = SKAction.playSoundFileNamed("timerend", waitForCompletion: false)
	
	var timeLabel = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		
	func setUpScene(size: CGSize, leds: QuizLeds?, numTeams: Int, webSocket : WebSocket?) {
		if setUp {
			return
		}
		setUp = true
		
		self.size = size
		self.leds = leds
		self.webSocket = webSocket
		self.numTeams = numTeams
		
		let bgImage = SKSpriteNode(imageNamed: "background2")
		bgImage.zPosition = 0
		bgImage.position = CGPoint(x:self.frame.midX, y:self.frame.midY)
		bgImage.size = self.size
		self.addChild(bgImage)
		
		
		timeLabel.text = "5"
		timeLabel.fontSize = 120
		timeLabel.fontColor = NSColor.black
		timeLabel.horizontalAlignmentMode = .center
		timeLabel.verticalAlignmentMode = .center
		timeLabel.zPosition = 6
		timeLabel.position = CGPoint(x: self.centrePoint.x, y: self.frame.height - 200)
		self.addChild(timeLabel)
		
		let halfway = Int((Double(numTeams) / 2).rounded(.up))
		var boxheight : Int = 150
		if(numTeams > 10) {
			boxheight = 100
		}
		
		for team in 0..<numTeams {
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
			let box = TrueFalseTeamNode(team: team, width: 600, height: boxheight, position: position, fontsize: numTeams >= 10 ? 60 : 40)
			
			box.zPosition = 1
			teamBoxes.append(box)
			self.addChild(box)
		}
		
		reset()
	}
	
	func reset() {
		self.timer?.invalidate()
		self.timeLabel.text = ""
		
		teamGuesses = [Bool?](repeating: nil, count: numTeams)
		teamEnabled = [Bool](repeating: true, count: numTeams)
		
		for i in 0..<numTeams {
			teamBoxes[i].guessLabel.text = "Team \(i + 1)"
			teamBoxes[i].setEnabled(true)
		}
		self.time = TrueFalseScene.TIMEOUT
	}
	
	func addParticles() {
		let timeParticles = SKEmitterNode(fileNamed: "BuzzGlow")!
		timeParticles.position = timeLabel.position
		timeParticles.zPosition = 2
		timeParticles.particlePositionRange.dx = 200
		timeParticles.particlePositionRange.dy = 200
		timeParticles.numParticlesToEmit = 120
		timeParticles.removeWhenDone()
		self.addChild(timeParticles)
	}
	
	func start() {
		self.time = TrueFalseScene.TIMEOUT
		teamGuesses = [Bool?](repeating: nil, count: numTeams)
		
		timer?.invalidate()
		timer = Timer(timeInterval: 1.0, target: self, selector: #selector(TrueFalseScene.tick), userInfo: nil, repeats: true)
		RunLoop.main.add(timer!, forMode: RunLoop.Mode.common)
		self.timeLabel.text = String(TrueFalseScene.TIMEOUT)
		addParticles()
		counting = true;
		self.webSocket?.setCounterValue(val: 200)
		self.run(self.tickSound)
	}
	
	@objc func tick() {
		self.run(SKAction.run({ () -> Void in
			self.time -= 1
			let lednum = Int(200.0 * Float(self.time) / Float(TrueFalseScene.TIMEOUT))
			self.webSocket?.setCounterValue(val: lednum)
			if(self.time > 0) {
				self.timeLabel.text = String(self.time)
				self.addParticles()
				self.run(self.tickSound)
			} else {
				self.counting = false
				self.timer?.invalidate()
				self.run(self.tickEnd)
				self.webSocket?.pulseWhite()
				self.timeLabel.text = ""
				self.revealTeamGuesses()
			}
		})
		)
	}
	
	func revealTeamGuesses() {
		for team in 0..<numTeams {
			if teamEnabled[team] {
				teamBoxes[team].setEnabled(true)
				if teamGuesses[team] != nil {
					teamBoxes[team].guessLabel.text = teamGuesses[team]! ? "Team \(team + 1): TRUE" : "Team \(team + 1): FALSE"
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
		for team in 0..<numTeams {
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
		if counting {
			teamGuesses[teamid] = guess
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
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}

