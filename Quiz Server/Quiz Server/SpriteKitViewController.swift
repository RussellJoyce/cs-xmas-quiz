//
//  SpriteKitViewController.swift
//  Quiz Server
//
//  Created by Russell Joyce on 17/11/2015.
//  Copyright © 2015 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import SpriteKit

class SpriteKitViewController: NSViewController {
	
	@IBOutlet weak var skView: SKView!
	
	let idleScene = IdleScene()
	let testScene = TestScene()
	let buzzerScene = BuzzerScene()
	let timerScene = TimerScene()
	let timedScoresScene = TimedScoresScene()
	let geographyScene = GeographyScene()
	var leds: QuizLeds?
	var currentRound = RoundType.none
	var numTeams = 10

	override func viewDidLoad() {
		super.viewDidLoad()
		
		skView.ignoresSiblingOrder = true
		//skView.showsFPS = true
		//skView.showsNodeCount = true
		
		idleScene.setUpScene(size: skView.bounds.size, leds: leds)
		testScene.setUpScene(size: skView.bounds.size, leds: leds, numTeams: numTeams)
		buzzerScene.setUpScene(size: skView.bounds.size, leds: leds)
		timerScene.setUpScene(size: skView.bounds.size, leds: leds)
		timedScoresScene.setUpScene(size: skView.bounds.size, leds: leds, numTeams: numTeams)
		geographyScene.setUpScene(size: skView.bounds.size, leds: leds, numTeams: numTeams)
	}
	
	func setRound(round: RoundType) {
		currentRound = round

		switch (currentRound) {
		case .idle:
			skView.presentScene(idleScene)
		case .test:
			skView.presentScene(testScene)
		case .buzzers:
			skView.presentScene(buzzerScene)
		case .timer:
			skView.presentScene(timerScene)
		case .timedScores:
			skView.presentScene(timedScoresScene)
		case .geography:
			skView.presentScene(geographyScene)
		default:
			skView.presentScene(nil)
		}
	}
	
	func reset() {
		switch (currentRound) {
		case .idle:
			idleScene.reset()
		case .test:
			testScene.reset()
		case .buzzers:
			buzzerScene.reset()
		case .timer:
			timerScene.reset()
		case .timedScores:
			timedScoresScene.reset()
		case .geography:
			geographyScene.reset()
		default:
			break
		}
	}
	
	func buzzerPressed(team: Int, type: BuzzerType) {
		switch (currentRound) {
		case .idle:
			idleScene.buzzerPressed(team: team, type: type)
		case .test:
			testScene.buzzerPressed(team: team, type: type)
		case .buzzers:
			buzzerScene.buzzerPressed(team: team, type: type)
		case .timer:
			break
		case .timedScores:
			break
		case .geography:
			break
		default:
			break
		}
	}
	
	func buzzerReleased(team: Int, type: BuzzerType) {
		switch (currentRound) {
		case .idle:
			idleScene.buzzerReleased(team: team, type: type)
		case .test:
			testScene.buzzerReleased(team: team, type: type)
		case .buzzers:
			break
		case .timer:
			break
		case .timedScores:
			break
		case .geography:
			break
		default:
			break
		}
	}
	
	func nextBuzzerTeam() {
		buzzerScene.nextTeam()
	}
	
	func startTimer() {
		timerScene.startTimer();
	}
	
	func stopTimer() {
		timerScene.stopTimer();
	}
	
	func timerIncrement() {
		timerScene.timerIncrement();
	}
	
	func timerDecrement() {
		timerScene.timerDecrement();
	}
	
	func setTeamType(team: Int, type: TeamType) {
		testScene.setTeamType(team: team, type: type)
	}
}
