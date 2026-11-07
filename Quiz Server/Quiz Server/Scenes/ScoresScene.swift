//
//  Scores.swift
//  Quiz Server
//
//  Created by Ian Gray on 03/11/2024.
//  Copyright © 2024 Russell Joyce & Ian Gray. All rights reserved.
//


import Cocoa
import SpriteKit

class ScoresScene: QuizScene {

	var scores : [(Int, Int, Int)] = []
	var teamBoxes = [BuzzerTeamNode]()
	var displayIndex = 0
	
	var scoreSounds = [SKAction]()
	var lastScoreSound = 0
	let topScoreNoise = Sound.effect("topscore")
	let simpleScoreNoise = Sound.effect("score5")
	
	var snow1 : SKEmitterNode?
	
	var output : NSTextField?
	
	override func buildScene() {
		addBackground(imageNamed: "abstract-dark")

		//Load team sounds
		for i in 1...14 {
			scoreSounds.append(Sound.effect("orch\(i)"))
		}
	}

	override func didMove(to view: SKView) {
		super.didMove(to: view)
		snow1 = addSnow(replacing: snow1, emitterNamed: "ScoresBackground", zPosition: 1, xOffset: -300) {
			$0.particlePositionRange.dx = 2500
		}
	}
	
	override func reset() {
		QuizWebSocket.shared?.ledsOff();
		scores = []
		for teamBox in teamBoxes {
			teamBox.removeFromParent()
		}
		teamBoxes.removeAll()
		displayIndex = 0
		
		lastScoreSound = 0
		output?.stringValue = "Ready"
	}
	
	
	enum ParseError: Error {
		case invalidFormat
		case nonIntegerValue
		case teamOutOfRange
		case duplicateTeam
	}
	
	func parseStringToPairs(_ input: String) -> [(Int, Int)]? {
		var pairs = [(Int, Int)]()
		var seenTeams = Set<Int>()
		let lines = input.replacingOccurrences(of: "\r", with: "").split(separator: "\n")
		for line in lines {
			do {
				//Each line is a team and its score, separated by one comma or by spaces or tabs.
				//A score of x means the team has no score and is left out, as is a team with no
				//line at all. Blank lines are ignored, and anything else is an error.
				let trimmed = line.trimmingCharacters(in: .whitespaces)
				if trimmed.isEmpty {
					continue
				}
				//Empty fields are kept when splitting on commas, so that 1,,10 is an error
				let components = trimmed.contains(",")
					? trimmed.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
					: trimmed.split(whereSeparator: { $0.isWhitespace }).map(String.init)
				guard components.count == 2 else {
					throw ParseError.invalidFormat
				}
				guard let team = Int(components[0]) else {
					throw ParseError.nonIntegerValue
				}
				guard (1...Settings.shared.numTeams).contains(team) else {
					throw ParseError.teamOutOfRange
				}
				guard seenTeams.insert(team).inserted else {
					throw ParseError.duplicateTeam
				}
				if components[1].lowercased() == "x" {
					continue
				}
				guard let score = Int(components[1]) else {
					throw ParseError.nonIntegerValue
				}
				pairs.append((team, score))
			} catch {
				print("Error parsing line '\(line)': \(error)")
				output?.stringValue = "Error parsing line '\(line)': \(error)"
				return nil
			}
		}
		
		print("Number of teams with valid scores: \(pairs.count)")
		output?.stringValue = "Number of teams with valid scores: \(pairs.count)"
		return pairs
	}

	func parseAndReset(scoreText : String) {
		if let res = parseStringToPairs(scoreText) {
			
			//Determine ranks
			var rankedScores : [(Int, Int, Int)] = []
			var lastScore: Int? = nil
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
			output?.stringValue = scores.map({"\($0): Team \($1) (\($2))"}).joined(separator: "\n")
			
		} else {
			print("Failed to parse input.")
			scores = []
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
			QuizWebSocket.shared?.buzz(team: scores[displayIndex].1 - 1)
			
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


// MARK: - Controller window

class ScoresPanel: NSObject, RoundPanel {

	let round = RoundType.scores
	weak var host: ControllerWindowController!

	@IBOutlet weak var output: NSTextField!
	@IBOutlet weak var scoreText: NSTextView!

	private var scene: ScoresScene { host.quizDisplay.scoresScene }

	func connectControls() {
		scene.output = output
	}

	/// Lays out one blank line per team, ready for the host to type the scores in
	@IBAction func initText(_ sender: Any) {
		scoreText.string = (1...Settings.shared.numTeams).map { "\($0),x\n" }.joined()
	}

	@IBAction func parseAndReset(_ sender: Any) {
		scene.parseAndReset(scoreText: scoreText.string)
	}

	@IBAction func showNext(_ sender: Any) {
		scene.next()
	}
}
