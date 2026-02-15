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
	
	let idleScene = Idle2Scene()
	let testScene = TestScene()
	let buzzerScene = BuzzerScene()
	let musicScene = MusicScene()
	let timerScene = TimerScene()
	let geographyScene = GeographyScene()
	let textScene = TextScene()
	let numbersScene = NumbersScene()
	let truefalseScene = TrueFalseScene()
	let scoresScene = ScoresScene()
	let pointlessScene = PointlessScene()

	var rounds : [RoundType : QuizRound] = [:]
	var currentRound = RoundType.none
	
	private let transitionDuration = 1.0
	private var transitions = [SKTransition]()


	override func viewDidLoad() {
		super.viewDidLoad()

		skView.ignoresSiblingOrder = true

		rounds = [.idle : idleScene, .test : testScene, .buzzers : buzzerScene,
			.music : musicScene, .timer : timerScene, .trueFalse : truefalseScene,
			.geography : geographyScene, .text : textScene, .numbers : numbersScene,
			.scores : scoresScene, .pointless : pointlessScene]

		rounds.forEach { $1.setUpScene(size: skView.bounds.size) }

		transitions.append(SKTransition.doorsCloseVertical(withDuration: transitionDuration))
		transitions.append(SKTransition.doorsOpenVertical(withDuration: transitionDuration))
		transitions.append(SKTransition.doorway(withDuration: transitionDuration))
		transitions.append(SKTransition.flipHorizontal(withDuration: transitionDuration))
		transitions.append(SKTransition.flipVertical(withDuration: transitionDuration))
		transitions.append(SKTransition.moveIn(with: .down, duration: transitionDuration))
		transitions.append(SKTransition.moveIn(with: .up, duration: transitionDuration))
		transitions.append(SKTransition.push(with: .down, duration: transitionDuration))
		transitions.append(SKTransition.push(with: .up, duration: transitionDuration))
		transitions.append(SKTransition.reveal(with: .down, duration: transitionDuration))
		transitions.append(SKTransition.reveal(with: .up, duration: transitionDuration))
		for t in transitions {
			t.pausesIncomingScene = false
			t.pausesOutgoingScene = false
		}
	}
	
	func setRound(round: RoundType) {
		currentRound = round
		
		let scene : SKScene = rounds[round] ?? rounds[.idle]!
		if transitions.count > 0 {
			let randomIndex = Int(arc4random_uniform(UInt32(transitions.count)))
			let transition = transitions[randomIndex]
			skView.presentScene(scene, transition: transition)
		}
		else {
			skView.presentScene(scene)
		}
		
		reset()
	}
	
	func reset() {
		rounds[currentRound]?.reset()
	}
	
	func buzzerPressed(team: Int, type: BuzzerType, buzzcocksMode: Bool, buzzerQueueMode: Bool, quietMode : Bool, buzzerSounds : Bool, blankVideo: Bool) {
		switch (currentRound) {
		case .idle:
			idleScene.buzzerPressed(team: team, type: type)
		case .test:
			testScene.buzzerPressed(team: team, type: type)
		case .buzzers:
			buzzerScene.buzzerPressed(team: team, type: type, buzzerQueueMode: buzzerQueueMode, quietMode: quietMode, buzzerSounds: buzzerSounds)
        case .music:
			musicScene.buzzerPressed(team: team, type: type, buzzcocksMode: buzzcocksMode, blankVideo: blankVideo)
		default:
			break
		}
	}
	
}
