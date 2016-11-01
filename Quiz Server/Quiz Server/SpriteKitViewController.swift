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
	var leds: QuizLeds?
	var currentRound = RoundType.none

	override func viewDidLoad() {
		super.viewDidLoad()
		
		skView.ignoresSiblingOrder = true
		//skView.showsFPS = true
		//skView.showsNodeCount = true
		
		idleScene.setUpScene(size: skView.bounds.size, leds: leds)
		testScene.setUpScene(size: skView.bounds.size, leds: leds)
		buzzerScene.setUpScene(size: skView.bounds.size, leds: leds)
		timerScene.setUpScene(size: skView.bounds.size, leds: leds)
	}
	
	func setRound(round: RoundType) {
		currentRound = round

		switch (currentRound) {
		case .none:
			skView.presentScene(nil)
		case .idle:
			skView.presentScene(idleScene)
		case .test:
			skView.presentScene(testScene)
		case .buzzers:
			skView.presentScene(buzzerScene)
		case .timer:
			skView.presentScene(timerScene)
		case .trueFalse:
			skView.presentScene(nil)
		case .pointless:
			skView.presentScene(nil)
		}
	}
	
	func reset() {
		switch (currentRound) {
		case .none:
			break
		case .idle:
			idleScene.reset()
		case .test:
			testScene.reset()
		case .buzzers:
			buzzerScene.reset()
		case .timer:
			timerScene.reset()
		case .trueFalse:
			break
		case .pointless:
			break
		}
	}
	
	func buzzerPressed(team: Int) {
		switch (currentRound) {
		case .none:
			break
		case .idle:
			idleScene.buzzerPressed(team: team)
		case .test:
			testScene.buzzerPressed(team: team)
		case .buzzers:
			buzzerScene.buzzerPressed(team: team)
		case .timer:
			break
		case .trueFalse:
			break
		case .pointless:
			break
		}
	}
	
	func buzzerReleased(team: Int) {
		switch (currentRound) {
		case .none:
			break
		case .idle:
			idleScene.buzzerReleased(team: team)
		case .test:
			testScene.buzzerReleased(team: team)
		case .timer:
			break
		case .buzzers:
			break
		case .trueFalse:
			break
		case .pointless:
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
