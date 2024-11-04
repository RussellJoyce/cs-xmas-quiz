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

class ScoresScene: SKScene {
	fileprivate var setUp = false
	var numTeams = 15
	var webSocket: WebSocket?
	
	var scores : [(Int, Int)] = []
	var teamBoxes = [ScoreNode]()
	var displayIndex = 0
	
	var scoreSounds = [SKAction]()
	var lastScoreSound = 0
	let topScoreNoise = SKAction.playSoundFileNamed("topscore", waitForCompletion: false)
	
	let snow1 = SKEmitterNode(fileNamed: "ScoresBackground")!
	
	func setUpScene(size: CGSize, numTeams: Int, webSocket: WebSocket?) {
		if setUp {
			return
		}
		setUp = true
		
		self.size = size
		self.numTeams = numTeams
		self.webSocket = webSocket;
		
		let bgImage = SKSpriteNode(imageNamed: "abstract-dark")
		bgImage.zPosition = 0
		bgImage.position = CGPoint(x:self.frame.midX, y:self.frame.midY)
		bgImage.size = self.size
		
		self.addChild(bgImage)
		
		//Load team sounds
		do {
			let docsArray = try FileManager.default.contentsOfDirectory(atPath: Bundle.main.resourcePath!)
			for fileName in docsArray {
				if fileName.starts(with: "score") {
					scoreSounds.append(SKAction.playSoundFileNamed(fileName, waitForCompletion: false))
				}
			}
			scoreSounds.shuffle()
		} catch {
			print(error)
		}
		
		
		
		snow1.position = CGPoint(x: self.size.width / 2 - 300, y: self.size.height + 16)
		snow1.zPosition = 1
		snow1.particlePositionRange.dx = 2500
		//snow1.particleColorBlendFactor = 1.0
		//snow1.particleColorSequence = nil
		self.addChild(snow1)
		
	}
	
	override func update(_ currentTime: TimeInterval) {
		//let colors = [SKColor.red, SKColor.green, SKColor.blue, SKColor.white, SKColor.cyan, SKColor.magenta, SKColor.yellow]
		//snow1.particleColor = colors[Int(arc4random_uniform(UInt32(colors.count)))]
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
		scoreSounds.shuffle()
	}
	
	
	enum ParseError: Error {
		case invalidFormat
		case nonIntegerValue
	}
	
	func parseStringToPairs(_ input: String) -> [(Int, Int)]? {
		var pairs = [(Int, Int)]()
		
		let lines = input.split(separator: "\n")
		
		for line in lines {
			do {
				let components = line.split(separator: ",")
				
				if components.count == 2 {
					guard let x = Int(components[0].trimmingCharacters(in: .whitespaces)),
						  let y = Int(components[1].trimmingCharacters(in: .whitespaces)) else {
						throw ParseError.nonIntegerValue
					}
					pairs.append((x, y))
				}
			} catch {
				print("Error parsing line '\(line)': \(error)")
				return nil
			}
		}
		
		print("Number of teams with valid scores: \(pairs.count)")
		return pairs
	}

	func parseAndReset(scoreText : String) {
		if let res = parseStringToPairs(scoreText) {
			scores = res.sorted { $0.1 < $1.1 }
			print(scores)
		} else {
			print("Failed to parse input.")
		}
		displayIndex = 0
	}
	
	func next() {
		
		if displayIndex < scores.count {
			//Add a team box
			//BuzzerTeamNode expects team number to be zero based
			let box = ScoreNode(team: scores[displayIndex].0 - 1, width: 1000, height: 150, fontSize: 80, addGlow: true, altText: "Team \(scores[displayIndex].0): \(scores[displayIndex].1) points")
			box.position = CGPoint(x: self.centrePoint.x, y: self.size.height - 200)
			box.zPosition = 1
			teamBoxes.append(box)
			self.addChild(box)
			
			//Play a sound, cycle through the sounds, shuffle the list when we've played them all once
			if displayIndex == scores.count - 1 {
				self.run(topScoreNoise)
			} else {
				if scoreSounds.count > 1 {
					if lastScoreSound > scoreSounds.count - 1 {
						lastScoreSound = 0
						scoreSounds.shuffle()
					}
					self.run(scoreSounds[lastScoreSound])
					lastScoreSound += 1
				}
			}
			
			//LEDs expect zero based team ids
			webSocket?.buzz(team: scores[displayIndex].0 - 1)
			
			//Shuffle down any existing boxes
			if displayIndex > 0 {
				for i in (0 ... displayIndex - 1) {
					
					if i == displayIndex - 1 {
						teamBoxes[i].run(SKAction.fadeAlpha(to: 0.6, duration: 1))
					}
					let nextBoxAction = SKAction.move(by: CGVector(dx: 0, dy: -200), duration: 0.4)
					nextBoxAction.timingMode = .easeInEaseOut
					teamBoxes[i].run(nextBoxAction)
					teamBoxes[i].stopGlow()
				}
			}
			
			displayIndex += 1
		}
	}
	
}



class ScoreNode: SKNode {
	
	let glow = SKEmitterNode(fileNamed: "StarGlow")!
	
	convenience init(team: Int, width: Int, height: Int, fontSize: CGFloat, addGlow: Bool, altText: String) {
		self.init()
		
		var teamHue = CGFloat(team) / 10.0
		if teamHue > 1.0 {
			teamHue -= 1.0
		}
		let bgColour = NSColor(calibratedHue: teamHue, saturation: 1.0, brightness: 0.8, alpha: 1.0)
		
		let scale = SKAction.scale(to: 1, duration: 0.2)
		scale.timingMode = .easeOut
		let fade = SKAction.fadeIn(withDuration: 0.2)
		fade.timingMode = .easeOut
		let entranceGroup = SKAction.group([fade, scale])
		
		let mainNode = SKNode()
		mainNode.position = CGPoint.zero
		
		let bgBox = SKShapeNode(rectOf: CGSize(width: width, height: height))
		bgBox.zPosition = 4
		bgBox.position = CGPoint.zero
		bgBox.fillColor = bgColour
		bgBox.lineWidth = 0.0
		
		let shadow = SKShapeNode(rectOf: CGSize(width: width + 20, height: height + 20))
		shadow.zPosition = 3
		shadow.position = CGPoint.zero
		shadow.fillColor = NSColor(white: 0.1, alpha: 0.5)
		shadow.lineWidth = 0.0
		
		let text = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		text.text = altText;
		text.fontSize = fontSize
		text.fontColor = NSColor.white
		text.horizontalAlignmentMode = .center
		text.verticalAlignmentMode = .center
		text.zPosition = 6
		text.position = CGPoint.zero
		
		let shadowText = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		shadowText.text = text.text
		shadowText.fontSize = fontSize
		shadowText.fontColor = NSColor(white: 0.1, alpha: 0.8)
		shadowText.horizontalAlignmentMode = .center
		shadowText.verticalAlignmentMode = .center
		shadowText.zPosition = 5
		shadowText.position = CGPoint.zero
		
		let textShadow = SKEffectNode()
		textShadow.shouldEnableEffects = true
		textShadow.shouldRasterize = true
		textShadow.zPosition = 5
		let filter = CIFilter(name: "CIGaussianBlur")
		filter?.setDefaults()
		filter?.setValue(fontSize / 5.8, forKey: "inputRadius")
		textShadow.filter = filter;
		textShadow.addChild(shadowText)
		
		glow.position = CGPoint.zero
		glow.particlePositionRange = CGVector(dx: Double(width) * 1.2, dy: Double(height) * 1.2)
		glow.zPosition = 1
		if addGlow {
			startGlow()
		}
		else {
			stopGlow()
		}
		
		mainNode.addChild(bgBox)
		mainNode.addChild(shadow)
		mainNode.addChild(text)
		mainNode.addChild(textShadow)
		mainNode.alpha = 0
		mainNode.setScale(1.3)
		
		self.addChild(mainNode)
		
		mainNode.run(entranceGroup)
		
		self.addChild(glow)
	}
	
	func startGlow() {
		glow.particleBirthRate = glow.particlePositionRange.dx / 10.0
	}
	
	func stopGlow() {
		glow.particleBirthRate = 0
	}
}

