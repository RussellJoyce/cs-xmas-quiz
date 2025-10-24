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
	var webSocket: WebSocket?
	
	var scores : [(Int, Int, Int)] = []
	var teamBoxes = [ScoreNode]()
	var displayIndex = 0
	
	var scoreSounds = [SKAction]()
	var lastScoreSound = 0
	let topScoreNoise = SKAction.playSoundFileNamed("topscore", waitForCompletion: false)
	let simpleScoreNoise = SKAction.playSoundFileNamed("score5", waitForCompletion: false)
	
	let snow1 = SKEmitterNode(fileNamed: "ScoresBackground")!
	
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
	
	func numberAsEmoji(_ n: Int) -> String {
		func conv(_ n: Int) -> String {
			switch n {
			case 0: return "0️⃣"
			case 1: return "1️⃣"
			case 2: return "2️⃣"
			case 3: return "3️⃣"
			case 4: return "4️⃣"
			case 5: return "5️⃣"
			case 6: return "6️⃣"
			case 7: return "7️⃣"
			case 8: return "8️⃣"
			case 9: return "9️⃣"
			default: return ""
			}
		}
		if n > 10 {
			return conv(n/10) + conv(n%10)
		} else {
			return conv(n)
		}
	}
	
	
	func next() {
		
		if displayIndex < scores.count {
			//Add a team box
			//BuzzerTeamNode expects team number to be zero based
			let s = scores[displayIndex]
			let box = ScoreNode(team: s.1 - 1, width: 1000, height: 150, fontSize: 80, addGlow: true, altText: "\(numberAsEmoji(s.0))  Team \(s.1): \(s.2) points")
			box.position = CGPoint(x: self.centrePoint.x, y: self.size.height - 200)
			box.zPosition = 1
			teamBoxes.append(box)
			self.addChild(box)
			box.runShimmerEffect(width: 1000, height: 150)
			
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
		mainNode.setScale(1.8)
		
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
	
	func runShimmerEffect(width: CGFloat, height: CGFloat) {
		// Parameters for the shimmer angle and size
		let shimmerWidth = CGFloat(200)
		let shimmerHeight = height * 1
		let texture = BuzzerTeamNode.makeAngledGradientTexture(width: shimmerWidth, height: shimmerHeight)
		let shimmer = SKSpriteNode(texture: texture, size: CGSize(width: shimmerWidth, height: shimmerHeight))
		shimmer.alpha = 0.65
		shimmer.zPosition = 20
		shimmer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
		shimmer.position = CGPoint(x: -width/2 + shimmerWidth/2, y: 0)
		shimmer.blendMode = .add
		self.addChild(shimmer)

		// Animate shimmer
		let move = SKAction.moveBy(x: width*0.80, y: 0, duration: 0.3)
		move.timingMode = .easeOut
		let fade = SKAction.fadeOut(withDuration: 0.7)
		let group = SKAction.group([move, fade])
		let sequence = SKAction.sequence([group, SKAction.removeFromParent()])
		shimmer.run(sequence)
	}

	static func makeAngledGradientTexture(width: CGFloat, height: CGFloat) -> SKTexture {
		let size = CGSize(width: width, height: height)
		let image = NSImage(size: size)
		image.lockFocus()
		let context = NSGraphicsContext.current!.cgContext
		let colorSpace = CGColorSpaceCreateDeviceRGB()
		let colors: [CGColor] = [
			NSColor.white.withAlphaComponent(0.0).cgColor,
			NSColor.white.withAlphaComponent(0.95).cgColor,
			NSColor.white.withAlphaComponent(0.95).cgColor,
			NSColor.white.withAlphaComponent(0.0).cgColor
		]
		let locations: [CGFloat] = [0.0, 0.2, 0.3, 1.0]
		let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations)!

		let start = CGPoint(x: 200, y: height/2-10)
		let end = CGPoint(x: 0, y: height/2)
		context.drawLinearGradient(gradient, start: start, end: end, options: [])
		image.unlockFocus()

		return SKTexture(image: image)
	}
	
}

