//
//  PointlessScene.swift
//  Quiz Server
//
//  Created by Ian Gray on 2025-11-12.
//  Copyright © 2025 Russell Joyce & Ian Gray. All rights reserved.
//


import Foundation
import Cocoa
import SpriteKit
import Starscream
import AVFoundation

class PointlessScene : SKScene {
	
	private var webSocket : WebSocket?
	private var setUp = false
	private var teamBoxes = [BuzzerTeamNode]()
	private var teamGuesses = [String?]()
	private var questionTitle : String?
	private var answers = [(String, Int)]()
	var textQuestion: NSTextField!
	var textAnswers: NSTextField!
	private var counter : OutlinedLabelNode?
	private var scoreBars = [SKShapeNode?]()
	private var barEmitters = [SKEmitterNode?]()
	private var scoreLabels = [SKLabelNode]()
	private var winEmitters = [SKEmitterNode]()
	private var scoringTimer: Timer?
	private var lowestScoreThisRound : Int?
	
	enum PointlessGameState {case waitForAnswers, answersRevealed, incorrectShown, runPointless, done}
	private var gameState : PointlessGameState = .waitForAnswers
	
	let blopSound = SKAction.playSoundFileNamed("blop", waitForCompletion: false)
	let scoreSound = SKAction.playSoundFileNamed("counter_score", waitForCompletion: false)
	let scorePointlessSound = SKAction.playSoundFileNamed("counter_score2", waitForCompletion: false)
	let showAnswersSound = SKAction.playSoundFileNamed("display_sweep", waitForCompletion: false)
	let teamDoneSound = SKAction.playSoundFileNamed("circle_illuminates", waitForCompletion: false)
	let wrongSound = SKAction.playSoundFileNamed("counter_wrong", waitForCompletion: false)
	private var counterPlayer: AVAudioPlayer? = nil
	
	static let teamBoxHeight = 60
	static let barHeight = CGFloat(teamBoxHeight - 6)
	static let teamBoxWidth = 450
	static let barBaseWidth = CGFloat(20)
	static let teamBoxMargin = 300
	static let tickTime = TimeInterval(0.1)
	static let barColour = NSColor(red: 1.0, green: 1.0, blue: 0.0, alpha: 1.0)
	static let barAnimColour = NSColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 1.0)
	static let barDisabledColour = NSColor(red: 0.8, green: 0.8, blue: 0.0, alpha: 0.8)
	
	func setUpScene(size: CGSize, webSocket : WebSocket?) {
		if setUp {
			return
		}
		setUp = true
		gameState = .waitForAnswers
		self.size = size
		self.webSocket = webSocket
		teamGuesses = [String?]()
		
		let bgImage = SKSpriteNode(imageNamed: "background2")
		bgImage.zPosition = 0
		bgImage.position = CGPoint(x:self.frame.midX, y:self.frame.midY)
		bgImage.size = self.size
		self.addChild(bgImage)
	
		//Add 16 team nodes down the left side of the screen
		for i in 0..<Settings.shared.numTeams {
			let teamBox = BuzzerTeamNode(team: i, width: PointlessScene.teamBoxWidth, height: PointlessScene.teamBoxHeight, fontSize: 40)
			teamBox.position = CGPoint(x: self.frame.minX + CGFloat(PointlessScene.teamBoxMargin), y: (self.size.height - 100) - CGFloat(i * 70))
			teamBox.zPosition = 15
			teamBoxes.append(teamBox)
			self.addChild(teamBox)
			teamGuesses.append(nil)
			
			let numlabel = createTeamNumber(teamno: i+1)
			numlabel.position = CGPoint(x: self.frame.minX + CGFloat(PointlessScene.teamBoxMargin) - CGFloat(PointlessScene.teamBoxWidth)/2 + 28, y: (self.size.height - 100) - CGFloat(i * 70))
			self.addChild(numlabel)
		}
		scoreBars = Array(repeating: nil, count: Settings.shared.numTeams)
		barEmitters = Array(repeating: nil, count: Settings.shared.numTeams)
		
		if let url = Bundle.main.url(forResource: "counter_nosting", withExtension: "wav") {
			do {
				try counterPlayer = AVAudioPlayer(contentsOf: url)
			} catch let error {
				print(error.localizedDescription)
			}
		}
		counterPlayer?.prepareToPlay()
	}

	func reset() {
		webSocket?.ledsOff()
		for team in 0..<Settings.shared.numTeams {
			teamGuesses[team] = nil
			teamBoxes[team].updateText("Team \(team + 1)")
			teamBoxes[team].resetTeamColour()
		}
		textAnswers.stringValue = ""
		gameState = .waitForAnswers
		
		counter?.removeFromParent()
		counter = nil
		
		scoreBars.forEach {$0?.removeFromParent()}
		barEmitters.forEach {$0?.removeFromParent()}
		scoreLabels.forEach {$0.removeFromParent()}
		scoreLabels.removeAll()
		winEmitters.forEach {$0.removeFromParent()}
		winEmitters.removeAll()
		
		scoringTimer?.invalidate()
		scoringTimer = nil
		
		counterPlayer?.stop()
	}
	
	func changeToQuestion(path : String) {
		do {
			let data = try String(contentsOfFile: path, encoding: .ascii)
			let lines = data.components(separatedBy: .newlines).filter { !$0.isEmpty }
			guard !lines.isEmpty else { return }
			
			questionTitle = lines[0]
			answers = [(String, Int)]()
			
			for line in lines.dropFirst() {
				let parts = line.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
				if parts.count == 2,
				   let intValue = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
					let strValue = String(parts[0]).trimmingCharacters(in: .whitespaces)
					answers.append((strValue, intValue))
				}
			}
			
			textQuestion.stringValue = questionTitle! + "\n" + answers.map({"\($0): \($1)"}).joined(separator: "\n")
		} catch let err as NSError {
			print(err)
		}
	}
	
	func teamGuess(team : Int, guess : String) {
		if team < teamGuesses.count {
			if gameState == .waitForAnswers {
				self.run(blopSound)
				webSocket?.pulseTeamColour(team: team)
				teamGuesses[team] = guess
				teamBoxes[team].updateText("••••••••")
				teamBoxes[team].runEntranceFlash()
				teamBoxes[team].runPop()
				
				textAnswers.stringValue = teamGuesses.enumerated().map { (index, answer) in
					"\(index + 1): \(answer ?? "")"
				}.joined(separator: "\n")
			}
		} else {
			print("teamGuess: Out of bounds team guess")
		}
	}
	
	func showAnswers() {
		for i in 0..<Settings.shared.numTeams {
			teamBoxes[i].updateText((teamGuesses[i] ?? ""))
			teamBoxes[i].runShimmerEffect()
		}
		gameState = .answersRevealed
		
		run(showAnswersSound)
	}
	
	func runScoring() {
		switch gameState {
		case .waitForAnswers:
			return
			
		case .answersRevealed:
			var atLeastOneWrong = false
			
			//Fade to red any teams that are wrong
			for i in 0..<Settings.shared.numTeams {
				if !(teamGuesses[i]?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) != nil && answers.contains(where: { $0.0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == teamGuesses[i]!.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })) {
					teamBoxes[i].fadeBackgroundColor(to: NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.7), duration: 1.0)
					teamBoxes[i].fadeTextColor(to: .red, duration: 0.7)
					atLeastOneWrong = true
				}
			}
			if atLeastOneWrong { run(wrongSound) }
			
			let correctScores = (0..<Settings.shared.numTeams).compactMap { teamIndex -> Int? in
				guard let guess = teamGuesses[teamIndex]?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
				return answers.first(where: { $0.0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == guess })?.1
			}
			lowestScoreThisRound = correctScores.min()
			
			gameState = .incorrectShown
			
		case .incorrectShown:
			//Start the scoring process
			gameState = .runPointless

			counterPlayer?.play()
			
			// Prepare bars and emitters for correct teams
			for i in 0..<Settings.shared.numTeams {
				// Find team's guess and associated score
				if let guess = teamGuesses[i]?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
				   let _ = answers.first(where: { $0.0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == guess }) {
					let barNode = SKShapeNode()
					barNode.fillColor = PointlessScene.barColour
					barNode.strokeColor = .clear
					barNode.position = CGPoint(x: teamBoxes[i].position.x + (CGFloat(PointlessScene.teamBoxWidth) / 2) + 20, y: teamBoxes[i].position.y)
					barNode.zPosition = 15
					barNode.path = CGPath(rect: CGRect(x: 0, y: -PointlessScene.barHeight/2, width: PointlessScene.barBaseWidth, height: PointlessScene.barHeight), transform: nil)
					scoreBars[i]?.removeFromParent()
					scoreBars[i] = barNode
					addChild(barNode)

					// Start oscillating bar color with random durations
					self.startOscillatingBarColor(barNode)
					
					let emitter = SKEmitterNode(fileNamed: "SparksPointless")!
					emitter.position = CGPoint(x: barNode.position.x + 5, y: barNode.position.y)
					emitter.zPosition = 16
					barEmitters[i]?.removeFromParent()
					barEmitters[i] = emitter
					addChild(emitter)
				}
			}
			// Start scoring animation timer
			scoringTimer?.invalidate()
			scoringTimer = Timer.scheduledTimer(withTimeInterval: PointlessScene.tickTime, repeats: true) { _ in self.updateScoreBars() }
			
			addCounter()
			
		case .runPointless:
			break
		case .done:
			break
		}
	}
	
	private func updateScoreBars() {
		guard let counter = self.counter, var counterValue = Int(counter.text ?? "0") else { return }
		
		counterValue = counterValue - 1
		counter.text = "\(counterValue)"
		
		var anyActive = false
		for i in 0..<Settings.shared.numTeams {
			guard let bar = scoreBars.indices.contains(i) ? scoreBars[i] : nil,
				  let emitter = barEmitters.indices.contains(i) ? barEmitters[i] : nil,
				  let guess = teamGuesses.indices.contains(i) ? teamGuesses[i] : nil,
				  let answer = answers.first(where: { $0.0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == guess.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) })
			else { continue }
			let score = answer.1
			
			let newWidth = CGFloat((100 - counterValue) * 12) + PointlessScene.barBaseWidth
			
			if counterValue > score {
				let scale = newWidth / PointlessScene.barBaseWidth
				let action = SKAction.scaleX(to: scale, duration: PointlessScene.tickTime * 0.99)
				action.timingMode = .linear
				bar.run(action)

				let newPoint = CGPoint(x: bar.position.x + newWidth, y: bar.position.y)
				emitter.run(SKAction.move(to: newPoint, duration: PointlessScene.tickTime * 0.99))
				anyActive = true
			} else {
				
				// Bar reached score, remove emitter and add score label
				emitter.particleBirthRate = 0
				emitter.removeWhenDone()
				barEmitters[i] = nil
				
				//Was this a winning bar?
				if let lowScore = lowestScoreThisRound, score <= lowScore {
					// This is a winning bar (no-op or handle winner here)
					counterPlayer?.stop()
					self.run(score == 0 ? scorePointlessSound : scoreSound)
					
					//Star spray for winning bar(s)
					let em = SKEmitterNode(fileNamed: "StarGlow")!
					em.position = bar.position
					em.position.x = em.position.x + newWidth / 2
					em.zPosition = bar.zPosition - 1
					em.particleBirthRate = 300
					em.particleScaleSpeed = 0.5
					em.particlePositionRange = CGVector(dx: newWidth, dy: PointlessScene.barHeight)
					self.addChild(em)
					winEmitters.append(em)
					
				} else {
					run(teamDoneSound)
					// Stop color oscillation before running white flash
					bar.removeAction(forKey: "colorOscillation")
					let flash = SKAction.sequence([
						SKAction.run { bar.fillColor = .white },
						SKAction.wait(forDuration: 0.07),
						SKAction.customAction(withDuration: 0.5) { node, elapsedTime in
							guard let shape = node as? SKShapeNode else { return }
							let t = CGFloat(elapsedTime) / 0.5
							shape.fillColor = .white.blended(withFraction: t, of: PointlessScene.barDisabledColour) ?? PointlessScene.barDisabledColour
						}
					])
					bar.run(flash)
				}
				
				//Add the team's final score
				let label = SKLabelNode(text: "\(score)")
				self.scoreLabels.append(label)
				label.fontSize = 50
				label.fontName = "PT Sans Caption Bold"
				label.zPosition = 100
				label.fontColor = NSColor(red: 0.2, green: 0.0, blue: 0.05, alpha: 1.0)
				label.horizontalAlignmentMode = .left
				label.position = CGPoint(x: bar.position.x + 30, y: bar.position.y - 20)
				addChild(label)
				//Pulse it in
				label.setScale(3.0)
				let scalein = SKAction.scale(to: 1.0, duration: 0.3)
				scalein.timingMode = .easeOut
				label.run(scalein)
			}
		}
		if !anyActive {
			scoringTimer?.invalidate()
			scoringTimer = nil
			gameState = .done
		}
	}
	
	
	// Repeatedly animates the bar's color back and forth with a new random duration for each half-cycle.
	private func startOscillatingBarColor(_ barNode: SKShapeNode, toAnimColor: Bool = true) {
		let duration = Double.random(in: 0.2...0.5)
		let fromColor = toAnimColor ? PointlessScene.barColour : PointlessScene.barAnimColour
		let toColor = toAnimColor ? PointlessScene.barAnimColour : PointlessScene.barColour
		let action = SKAction.customAction(withDuration: duration) { node, elapsedTime in
			guard let shape = node as? SKShapeNode else { return }
			let t = CGFloat(elapsedTime) / CGFloat(duration)
			shape.fillColor = fromColor.blended(withFraction: t, of: toColor) ?? toColor
		}
		let next = SKAction.run { [weak self, weak barNode] in
			guard let self = self, let barNode = barNode else { return }
			if barNode.action(forKey: "colorOscillation") != nil {
				self.startOscillatingBarColor(barNode, toAnimColor: !toAnimColor)
			}
		}
		let sequence = SKAction.sequence([action, next])
		barNode.run(sequence, withKey: "colorOscillation")
	}
	
	func addCounter() {
		counter?.removeFromParent()
		counter = OutlinedLabelNode(text: "100", fontNamed: "Electronic Highway Sign", fontSize: 110, fontColor: .white, outlineColor: .black, outlineWidth: 5.0)
		counter?.position = CGPoint(x: size.width - 150, y: size.height / 2)
		addChild(counter!)
	}
	
	
	
	func createTeamNumber(teamno : Int) -> SKNode {
		let text = SKLabelNode(fontNamed: "PT Sans Caption Bold")
		text.fontSize = 40
		text.fontColor = NSColor.white
		text.horizontalAlignmentMode = .center
		text.verticalAlignmentMode = .center
		text.zPosition = 28
		text.position = CGPoint.zero
		text.text = "\(teamno)"
		
		let shadowText = SKLabelNode(fontNamed: "PT Sans Caption Bold")
		shadowText.text = text.text
		shadowText.fontSize = 40
		shadowText.fontColor = NSColor(white: 0, alpha: 1.0)
		shadowText.horizontalAlignmentMode = .center
		shadowText.verticalAlignmentMode = .center
		shadowText.zPosition = 27
		shadowText.position = CGPoint.zero
		shadowText.text = "\(teamno)"
		
		let textShadow = SKEffectNode()
		textShadow.shouldEnableEffects = true
		textShadow.shouldRasterize = true
		textShadow.zPosition = 27
		let filter = CIFilter(name: "CIGaussianBlur")
		filter?.setDefaults()
		filter?.setValue(40 / 5.8, forKey: "inputRadius")
		textShadow.filter = filter;
		textShadow.addChild(shadowText)
		
		let container = SKNode()
		container.addChild(text)
		container.addChild(textShadow)
		
		return container
	}
	
	
	func debugTest() {
		teamGuess(team: 0, guess: "anne")
		teamGuess(team: 1, guess: "brian")
		teamGuess(team: 2, guess: "charlotte")
		teamGuess(team: 3, guess: "elizabeth")
		teamGuess(team: 4, guess: "elizabeth")
		teamGuess(team: 5, guess: "gary")
		teamGuess(team: 6, guess: "maria")
		teamGuess(team: 7, guess: "luigi")
		
		teamGuess(team: 10, guess: "elizabeth")
		
		teamGuess(team: 12, guess: "anne")
		teamGuess(team: 13, guess: "brian")
		teamGuess(team: 14, guess: "charlotte")
	}

}

