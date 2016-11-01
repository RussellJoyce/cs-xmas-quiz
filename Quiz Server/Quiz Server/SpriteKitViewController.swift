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
		
		idleScene.setUpScene(skView.bounds.size, leds: leds)
		testScene.setUpScene(skView.bounds.size, leds: leds)
		buzzerScene.setUpScene(skView.bounds.size, leds: leds)
		timerScene.setUpScene(skView.bounds.size, leds: leds)
	}
	
	func setRound(_ round: RoundType) {
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
	
	func buzzerPressed(_ team: Int) {
		switch (currentRound) {
		case .none:
			break
		case .idle:
			idleScene.buzzerPressed(team)
		case .test:
			testScene.buzzerPressed(team)
		case .buzzers:
			buzzerScene.buzzerPressed(team)
		case .timer:
			break
		case .trueFalse:
			break
		case .pointless:
			break
		}
	}
	
	func buzzerReleased(_ team: Int) {
		switch (currentRound) {
		case .none:
			break
		case .idle:
			idleScene.buzzerReleased(team)
		case .test:
			testScene.buzzerReleased(team)
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
	
	func setTeamType(_ team: Int, type: TeamType) {
		testScene.setTeamType(team, type: type)
	}
}
