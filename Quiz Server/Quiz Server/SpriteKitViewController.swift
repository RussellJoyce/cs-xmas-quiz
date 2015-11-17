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
	var leds: QuizLeds?
	var currentRound = RoundType.None

	override func viewDidLoad() {
		super.viewDidLoad()
		
		skView.ignoresSiblingOrder = true
//		skView.showsFPS = true
//		skView.showsNodeCount = true
		
		idleScene.setUpScene(skView.bounds.size, leds: leds)
		testScene.setUpScene(skView.bounds.size, leds: leds)
		buzzerScene.setUpScene(skView.bounds.size, leds: leds)
	}
	
	func setRound(round: RoundType) {
		currentRound = round

		switch (currentRound) {
		case .None:
			skView.presentScene(nil)
		case .Idle:
			skView.presentScene(idleScene)
		case .Test:
			skView.presentScene(testScene)
		case .Buzzers:
			skView.presentScene(buzzerScene)
		case .TrueFalse:
			skView.presentScene(nil)
		case .Pointless:
			skView.presentScene(nil)
		}
	}
	
	func reset() {
		switch (currentRound) {
		case .None:
			break
		case .Idle:
			idleScene.reset()
		case .Test:
			testScene.reset()
		case .Buzzers:
			buzzerScene.reset()
		case .TrueFalse:
			break
		case .Pointless:
			break
		}
	}
	
	func buzzerPressed(team: Int) {
		switch (currentRound) {
		case .None:
			break
		case .Idle:
			idleScene.buzzerPressed(team)
		case .Test:
			testScene.buzzerPressed(team)
		case .Buzzers:
			buzzerScene.buzzerPressed(team)
		case .TrueFalse:
			break
		case .Pointless:
			break
		}
	}
	
	func buzzerReleased(team: Int) {
		switch (currentRound) {
		case .None:
			break
		case .Idle:
			idleScene.buzzerReleased(team)
		case .Test:
			testScene.buzzerReleased(team)
		case .Buzzers:
			break
		case .TrueFalse:
			break
		case .Pointless:
			break
		}
	}
	
	func nextBuzzerTeam() {
		buzzerScene.nextTeam()
	}
	
}
