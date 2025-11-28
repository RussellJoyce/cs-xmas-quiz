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

class PointlessScene : SKScene, QuizRound, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {

	//Connections from the UI and rest of the app
	var textQuestion: NSTextField!
	var answerTable : NSTableView!
	private var webSocket : WebSocket?
	var descending : NSButton!
	
	//Internal vars
	private var setUp = false
	private var teamBoxes = [BuzzerTeamNode]()
	private var teamGuesses = [String?]()
	private var questionTitle : String?
	private var answers = [(String, Int)]()
	private var counter : OutlinedLabelNode?
	private var scoreBars = [SKShapeNode?]()
	private var barEmitters = [SKEmitterNode?]()
	private var scoreLabels = [SKLabelNode]()
	private var winEmitters = [SKEmitterNode]()
	private var scoringTimer: Timer?
	private var lowestScoreThisRound : Int?
	private var teamScores = [Int?]() // nil means either no answer, or an incorrect answer. Scores are 100 down to 0
	private let filternode = SKEffectNode()
	private var pulseAction, pulseActionSmall : SKAction!
	
	enum PointlessGameState {case waitForAnswers, answersRevealed, incorrectShown, runPointless, done}
	private var gameState : PointlessGameState = .waitForAnswers
	
	//Media
	let blopSound = SKAction.playSoundFileNamed("blop", waitForCompletion: false)
	let scoreSound = SKAction.playSoundFileNamed("counter_score", waitForCompletion: false)
	let scorePointlessSound = SKAction.playSoundFileNamed("counter_score2", waitForCompletion: false)
	let showAnswersSound = SKAction.playSoundFileNamed("display_sweep", waitForCompletion: false)
	let teamDoneSound = SKAction.playSoundFileNamed("circle_illuminates", waitForCompletion: false)
	let wrongSound = SKAction.playSoundFileNamed("counter_wrong", waitForCompletion: false)
	let manualEditSound = SKAction.playSoundFileNamed("quietbuzz2", waitForCompletion: false)
	private var counterPlayer: AVAudioPlayer? = nil
	
	//Layout constants
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
		teamScores = [Int?](repeating: nil, count: Settings.shared.numTeams)
		
		let bgImage = SKSpriteNode(imageNamed: "purple-texture-blurred")
		bgImage.zPosition = 0
		bgImage.position = CGPoint(x:self.frame.midX, y:self.frame.midY)
		bgImage.size = self.size
	
		//Add exposure filter to background image node
		let exfilter = CIFilter(name: "CIExposureAdjust")
		exfilter?.setDefaults()
		exfilter?.setValue(0, forKey: "inputEV")
		filternode.filter = exfilter
		filternode.addChild(bgImage)
		self.addChild(filternode)
		pulseAction = Utils.createFilterPulse(upTime: 0.15, downTime: 1.0, filterNode: filternode)
		pulseActionSmall = Utils.createFilterPulse(upTime: 0.10, downTime: 0.25, filterNode: filternode)
		
		//Add team nodes down the left side of the screen
		for i in 0..<Settings.shared.numTeams {
			let teamBox = BuzzerTeamNode(team: i, width: PointlessScene.teamBoxWidth, height: PointlessScene.teamBoxHeight, fontSize: 40)
			teamBox.position = CGPoint(x: self.frame.minX + CGFloat(PointlessScene.teamBoxMargin), y: (self.size.height - 100) - CGFloat(i * 70))
			teamBox.zPosition = 15
			teamBoxes.append(teamBox)
			self.addChild(teamBox)
			teamGuesses.append(nil)
			
			let numlabel = ShadowedLabelNode(text: "\(i+1)", fontNamed: "PT Sans Caption Bold", fontSize: 25, fontColor: .white, zPosition: 100)
			let xpos : CGFloat = CGFloat(PointlessScene.teamBoxMargin - PointlessScene.teamBoxWidth/2) + 20
			numlabel.position = CGPoint(x: self.frame.minX + xpos, y: (self.size.height - 100) - CGFloat(i * 70))
			self.addChild(numlabel)
		}
		scoreBars = Array(repeating: nil, count: Settings.shared.numTeams)
		barEmitters = Array(repeating: nil, count: Settings.shared.numTeams)
		
		// Setup the answerTable with 3 columns: Team, Guess, Score
		if answerTable != nil {
			// Remove all existing columns
			for column in answerTable.tableColumns {
				answerTable.removeTableColumn(column)
			}
			
			// Team Number column
			let teamColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("TeamColumn"))
			teamColumn.title = "Team"
			teamColumn.width = 40
			answerTable.addTableColumn(teamColumn)
			
			// Guess column
			let guessColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("GuessColumn"))
			guessColumn.title = "Guess"
			guessColumn.width = 150
			answerTable.addTableColumn(guessColumn)
			
			// Score column (editable)
			let scoreColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ScoreColumn"))
			scoreColumn.title = "Score"
			scoreColumn.width = 50
			answerTable.addTableColumn(scoreColumn)
			
			answerTable.delegate = self
			answerTable.dataSource = self
			answerTable.reloadData()
		}
		
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
		counterPlayer?.currentTime = 0
		
		teamScores = [Int?](repeating: nil, count: Settings.shared.numTeams)
		answerTable?.safeReloadData()
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
					let strValue = String(parts[0]).lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
					answers.append((strValue, intValue))
				}
			}
			
			teamScores = [Int?](repeating: nil, count: Settings.shared.numTeams)
			textQuestion.stringValue = questionTitle! + "\n" + answers.map({"\($0): \($1)"}).joined(separator: "\n")
			answerTable?.safeReloadData()
		} catch let err as NSError {
			print(err)
		}
	}
	
	func teamGuess(team : Int, guess : String) {
		if team < teamGuesses.count {
			if gameState == .waitForAnswers {
				self.run(blopSound)
				webSocket?.pulseTeamColour(team)
				teamGuesses[team] = guess
				teamBoxes[team].updateText("••••••••")
				teamBoxes[team].runEntranceFlash()
				teamBoxes[team].runPop()

				//Recalculate team score
				let guessSane = guess.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
				let cas = answers.filter({ $0.0 == guessSane })
				if !cas.isEmpty {
					teamScores[team] = cas.first?.1
				} else {
					teamScores[team] = nil
				}
				
				answerTable?.safeReloadData()
			}
		} else {
			print("teamGuess: Out of bounds team guess")
		}
	}
	
	func showAnswers() {
		for i in 0..<Settings.shared.numTeams {
			teamBoxes[i].updateText((teamGuesses[i] ?? ""))
			teamBoxes[i].runShimmerEffect(shimmerWidth: 300, duration: 0.5)
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
				if teamScores[i] == nil {
					teamBoxes[i].fadeBackgroundColor(to: NSColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.7), duration: 1.0)
					teamBoxes[i].fadeTextColor(to: .red, duration: 0.7)
					atLeastOneWrong = true
				}
			}
			if atLeastOneWrong { run(wrongSound) }
			
			lowestScoreThisRound = teamScores.compactMap({$0}).min()
			gameState = .incorrectShown
			
		case .incorrectShown:
			//Start the scoring process
			gameState = .runPointless
			counterPlayer?.play()
			
			// Prepare bars and emitters for correct teams
			for i in 0..<Settings.shared.numTeams {
				if let _ = teamScores[i] { //If has correct answer
					let barNode = SKShapeNode()
					barNode.fillColor = PointlessScene.barColour
					barNode.strokeColor = .clear
					barNode.position = CGPoint(x: teamBoxes[i].position.x + (CGFloat(PointlessScene.teamBoxWidth) / 2) + 20, y: teamBoxes[i].position.y)
					barNode.zPosition = 15
					barNode.path = CGPath(rect: CGRect(x: 0, y: -PointlessScene.barHeight/2, width: (descending.state == .off ? 0 : 100*11) + PointlessScene.barBaseWidth, height: PointlessScene.barHeight), transform: nil)
					
					scoreBars[i]?.removeFromParent()
					scoreBars[i] = barNode
					addChild(barNode)

					// Start oscillating bar color with random durations
					self.startOscillatingBarColor(barNode)
					
					let emitter = SKEmitterNode(fileNamed: "SparksPointless")!
					emitter.position = CGPoint(x: barNode.position.x + 5 + (descending.state == .off ? 0 : 100*11), y: barNode.position.y)
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
				  let score = teamScores[i]
			else { continue }
			
			let newWidth = CGFloat(
					(descending.state == .off ? (100 - counterValue) : counterValue)
				* 11) + PointlessScene.barBaseWidth

			if counterValue > score {
				let scale = newWidth / (descending.state == .off ? PointlessScene.barBaseWidth : 100*11 + PointlessScene.barBaseWidth)
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
					
					filternode.run(pulseAction)
					
					//Star spray for winning bar(s)
					let em = SKEmitterNode(fileNamed: "StarGlow")!
					em.position = bar.position
					em.position.x = em.position.x + (100*11 + PointlessScene.barBaseWidth) / 2
					em.zPosition = bar.zPosition - 1
					em.particleBirthRate = 300
					em.particleScaleSpeed = 0.5
					em.particlePositionRange = CGVector(dx: 100*11, dy: PointlessScene.barHeight)
					self.addChild(em)
					winEmitters.append(em)
					
					counter.removeFromParent()
					webSocket?.pulseWhite()
					
				} else {
					run(teamDoneSound)
					filternode.run(pulseActionSmall)
					
					webSocket?.pulseTeamColourQuick(i)
					
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
	
	
	
	func debugTest() {
		teamGuess(team: 0, guess: "anne")
		teamGuess(team: 1, guess: "brian")
		teamGuess(team: 2, guess: "charlotte")
		teamGuess(team: 3, guess: "elizabeth")
		teamGuess(team: 4, guess: "elizabeth")
		teamGuess(team: 5, guess: "gary")
		teamGuess(team: 6, guess: "maria")
		teamGuess(team: 7, guess: "luigi")
		
		teamGuess(team: 10, guess: "plimplington")
		
		teamGuess(team: 12, guess: "anne")
		teamGuess(team: 13, guess: "brian")
	}

	// MARK: - NSTableViewDataSource
	
	func numberOfRows(in tableView: NSTableView) -> Int {
		return Settings.shared.numTeams
	}
	
	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
		guard row < Settings.shared.numTeams else { return nil }
		guard let identifier = tableColumn?.identifier.rawValue else { return nil }
		
		switch identifier {
		case "TeamColumn":
			return "\(row + 1)"
		case "GuessColumn":
			return teamGuesses.indices.contains(row) ? (teamGuesses[row] ?? "") : ""
		case "ScoreColumn":
			if let score = teamScores.indices.contains(row) ? teamScores[row] : nil {
				return "\(score)"
			} else {
				return ""
			}
		default:
			return nil
		}
	}

	
	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		guard row < Settings.shared.numTeams else { return nil }
		guard let identifier = tableColumn?.identifier.rawValue else { return nil }
		
		let text: String
		switch identifier {
		case "TeamColumn":
			text = "\(row + 1)"
		case "GuessColumn":
			text = teamGuesses.indices.contains(row) ? (teamGuesses[row] ?? "") : ""
		case "ScoreColumn":
			if let score = teamScores.indices.contains(row) ? teamScores[row] : nil {
				text = "\(score)"
			} else {
				text = ""
			}
		default:
			text = ""
		}
		
		let cellIdentifier = NSUserInterfaceItemIdentifier("Cell_\(identifier)")
		var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView
		
		if cellView == nil {
			cellView = NSTableCellView()
			cellView!.identifier = cellIdentifier
			
			let textField = NSTextField()
			textField.translatesAutoresizingMaskIntoConstraints = false
			cellView!.addSubview(textField)
			
			NSLayoutConstraint.activate([
				textField.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 2),
				textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -2),
				textField.topAnchor.constraint(equalTo: cellView!.topAnchor),
				textField.bottomAnchor.constraint(equalTo: cellView!.bottomAnchor)
			])
			
			// Configure textField properties, editable only for Score column
			textField.isBordered = false
			textField.backgroundColor = .clear
			textField.isEditable = (identifier == "ScoreColumn")
			textField.font = NSFont.systemFont(ofSize: 13)
			textField.delegate = self
			
			if identifier == "ScoreColumn" {
				// Set tag and action/target for editable Score column cells
				textField.tag = row
				textField.action = #selector(scoreTextFieldDidEndEditing(_:))
				textField.target = self
			} else {
				textField.tag = 0
				textField.action = nil
				textField.target = nil
			}
			
			cellView!.textField = textField
		} else {
			// Update tag and action/target for existing Score column cells (to handle cell reuse)
			if let textField = cellView?.textField {
				textField.isEditable = (identifier == "ScoreColumn")
				if identifier == "ScoreColumn" {
					textField.tag = row
					textField.action = #selector(scoreTextFieldDidEndEditing(_:))
					textField.target = self
				} else {
					textField.tag = 0
					textField.action = nil
					textField.target = nil
				}
			}
		}
		
		cellView!.textField?.stringValue = text
		
		return cellView
	}
	
	@objc private func scoreTextFieldDidEndEditing(_ sender: NSTextField) {
		let row = sender.tag
		guard row < Settings.shared.numTeams else { return }
		
		let strValue = sender.stringValue
		if let intVal = Int(strValue.trimmingCharacters(in: .whitespaces)), intVal >= 0 {
			teamScores[row] = intVal
		} else if strValue.isEmpty {
			teamScores[row] = nil
		}
		run(manualEditSound)
		
		answerTable?.safeReloadData()
	}

	

	//Note: Appears unneccesary if we use scoreTextFieldDidEndEditing above
	/*func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
		guard row < Settings.shared.numTeams else { return }
		guard let identifier = tableColumn?.identifier.rawValue else { return }
		
		print("We are in tableView:setObjectValue:for:row:")
		
		if identifier == "ScoreColumn" {
			if let strValue = object as? String,
			   let intVal = Int(strValue.trimmingCharacters(in: .whitespaces)),
			   intVal >= 0 {
				// Update teamScores override
				if teamScores.indices.contains(row) {
					teamScores[row] = intVal
					// Reload the table to update display
					tableView.safeReloadData()
				}
			} else if object == nil || (object as? String)?.isEmpty == true {
				// Clear override if empty string
				if teamScores.indices.contains(row) {
					teamScores[row] = nil
					tableView.safeReloadData()
				}
			}
		}
	}*/
	
}



