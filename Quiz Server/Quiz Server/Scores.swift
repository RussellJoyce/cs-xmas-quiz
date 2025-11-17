//
//  Scores.swift
//  Quiz Server
//
//  Created by Ian Gray on 03/11/2024.
//  Copyright © 2024 Russell Joyce & Ian Gray. All rights reserved.
//


import Cocoa
import SpriteKit
import Starscream

class ScoresScene: SKScene, QuizRound {
	fileprivate var setUp = false
	var webSocket: WebSocket?
	
	var scores : [(Int, Int, Int)] = []
	var teamBoxes = [BuzzerTeamNode]()
	var displayIndex = 0
	
	var scoreSounds = [SKAction]()
	var lastScoreSound = 0
	let topScoreNoise = SKAction.playSoundFileNamed("topscore", waitForCompletion: false)
	let simpleScoreNoise = SKAction.playSoundFileNamed("score5", waitForCompletion: false)
	
	var snow1 : SKEmitterNode?
	
	var output : NSTextField!
	
	func setUpScene(size: CGSize, webSocket: WebSocket?) {
		if setUp {
			return
		}
		setUp = true
		
		self.size = size
		self.webSocket = webSocket
		
		let bgImage = SKSpriteNode(imageNamed: "abstract-dark")
		bgImage.zPosition = 0
		bgImage.position = CGPoint(x:self.frame.midX, y:self.frame.midY)
		bgImage.size = self.size
		
		self.addChild(bgImage)
		
		//Load team sounds
		for i in 1...14 {
			scoreSounds.append(SKAction.playSoundFileNamed("orch\(i)", waitForCompletion: false))
		}
	}

	override func didMove(to view: SKView) {
		super.didMove(to: view)
		// Remove existing snow emitter if present
		if let sn = snow1 {
			sn.removeFromParent()
		}
		
		// Create a new snow emitter
		let newSnow = SKEmitterNode(fileNamed: "ScoresBackground")!
		newSnow.position = CGPoint(x: self.size.width / 2 - 300, y: self.size.height + 16)
		newSnow.zPosition = 1
		newSnow.particlePositionRange.dx = 2500
		newSnow.advanceSimulationTime(8)
		snow1 = newSnow
		self.addChild(snow1!)
	}
	
	func reset() {
		webSocket?.ledsOff();
		scores = []
		for teamBox in teamBoxes {
			teamBox.removeFromParent()
		}
		teamBoxes.removeAll()
		displayIndex = 0
		
		lastScoreSound = 0
		output.stringValue = "Ready"
	}
	
	
	enum ParseError: Error {
		case invalidFormat
		case nonIntegerValue
	}
	
	func parseStringToPairs(_ input: String) -> [(Int, Int)]? {
		var pairs = [(Int, Int)]()
		let lines = input.replacingOccurrences(of: "\r", with: "").split(separator: "\n")
		for line in lines {
			do {
				//Split on either tab or comma
				var components : [Substring.SubSequence]
				if line.split(separator: ",").count != 2 {
					components = line.split(separator: "\t")
				} else {
					components = line.split(separator: ",")
				}
				
				if components.count == 2 {
					guard let x = Int(components[0].trimmingCharacters(in: .whitespaces)),
						  let y = Int(components[1].trimmingCharacters(in: .whitespaces)) else {
						throw ParseError.nonIntegerValue
					}
					pairs.append((x, y))
				}
			} catch {
				print("Error parsing line '\(line)': \(error)")
				output.stringValue = "Error parsing line '\(line)': \(error)"
				return nil
			}
		}
		
		print("Number of teams with valid scores: \(pairs.count)")
		output.stringValue = "Number of teams with valid scores: \(pairs.count)"
		return pairs
	}

	func parseAndReset(scoreText : String) {
		if let res = parseStringToPairs(scoreText) {
			
			//Determine ranks
			var rankedScores : [(Int, Int, Int)] = []
			var lastScore = -1
			var currentRank = 0
			var skipped = 1
			for i in res.sorted(by: { $0.1 > $1.1 }) {
				if i.1 != lastScore {
					lastScore = i.1
					currentRank += skipped
					skipped = 1
				} else {
					skipped += 1
				}
				rankedScores.append((currentRank, i.0, i.1))
			}
			
			scores = rankedScores.sorted { $0.0 > $1.0 }
			output.stringValue = scores.map({"\($0): Team \($1) (\($2))"}).joined(separator: "\n")
			
		} else {
			print("Failed to parse input.")
		}
		displayIndex = 0
	}
	
	
	func next() {
		
		if displayIndex < scores.count {
			//Add a team box
			//BuzzerTeamNode expects team number to be zero based
			let s = scores[displayIndex]
			let box = BuzzerTeamNode(team: s.1 - 1, width: 1000, height: 150, fontSize: 80, addGlow: true, glowType: "StarGlow", entranceShimmer: true, altText: "\(Utils.numberAsEmoji(s.0))  Team \(s.1): \(s.2) points")
			box.position = CGPoint(x: self.centrePoint.x, y: self.size.height - 200)
			box.zPosition = 1
			teamBoxes.append(box)
			self.addChild(box)
			
			//Play a sound, cycle through the sounds, shuffle the list when we've played them all once
			if displayIndex == scores.count - 1 {
				self.run(topScoreNoise)
			} else {
				if displayIndex < scoreSounds.count {
					self.run(scoreSounds[displayIndex])
				}
			}
			
			//LEDs expect zero based team ids
			webSocket?.buzz(team: scores[displayIndex].1 - 1)
			
			//Shuffle down any existing boxes
			if displayIndex > 0 {
				for i in (0 ... displayIndex - 1) {
					
					if i == displayIndex - 1 {
						teamBoxes[i].run(SKAction.fadeAlpha(to: 0.6, duration: 1))
					}
					let nextBoxAction = SKAction.move(by: CGVector(dx: 0, dy: -200), duration: 0.2)
					nextBoxAction.timingMode = .easeOut
					teamBoxes[i].run(nextBoxAction)
					teamBoxes[i].stopGlow()
				}
			}
			
			displayIndex += 1
		}
	}
	
}
