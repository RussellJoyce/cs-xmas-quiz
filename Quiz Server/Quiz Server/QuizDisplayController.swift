//
//  QuizDisplayController.swift
//  Quiz Server
//
//  Created by Russell Joyce on 17/11/2015.
//  Copyright © 2015 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import SpriteKit

class QuizDisplayController: NSViewController {

	var skView: SKView { view as! SKView }

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
	let wavelengthScene = WavelengthScene()
	let multiChoiceScene = MultiChoiceScene()

	var rounds : [RoundType : QuizScene] = [:]
	var currentRound = RoundType.none
	
	private let transitionDuration = 1.0
	private var transitions = [SKTransition]()


	/// The window the display lives in
	private var displayWindow: NSWindow?

	override func loadView() {
		view = SKView(frame: NSRect(x: 0, y: 0, width: 1920, height: 1080))
	}


	/// Puts the main display on screen, either in a window or filling the chosen screen,
	/// according to `Settings.shared`.
	func present() {
		if displayWindow == nil {
			let window = NSWindow(contentViewController: self)
			window.title = "Quiz Main Display"
			window.styleMask = [.titled, .resizable, .closable]
			window.makeKeyAndOrderFront(self)
			displayWindow = window
		}

		if !Settings.shared.windowedMode, let quizScreen = Settings.shared.quizScreen {
			//Old exclusive fullscreen method
			view.addConstraint(NSLayoutConstraint(item: view, attribute: .width,
								   relatedBy: .equal, toItem: nil,
								   attribute: .notAnAttribute,
								   multiplier: 1, constant: quizScreen.frame.width))
			view.addConstraint(NSLayoutConstraint(item: view, attribute: .height,
								   relatedBy: .equal, toItem: nil,
								   attribute: .notAnAttribute,
								   multiplier: 1, constant: quizScreen.frame.height))
			view.enterFullScreenMode(quizScreen, withOptions: [NSView.FullScreenModeOptionKey.fullScreenModeAllScreens: 0])
		}
	}


	override func viewDidLoad() {
		super.viewDidLoad()

		skView.ignoresSiblingOrder = true

		rounds = [.idle : idleScene, .test : testScene, .buzzers : buzzerScene,
			.music : musicScene, .timer : timerScene, .trueFalse : truefalseScene,
			.geography : geographyScene, .text : textScene, .numbers : numbersScene,
			.scores : scoresScene, .pointless : pointlessScene,
			.wavelength : wavelengthScene, .multichoice : multiChoiceScene]

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
	
	func buzzerPressed(team: Int, type: BuzzerType, options: BuzzerOptions) {
		rounds[currentRound]?.buzzerPressed(team: team, type: type, options: options)
	}

	func setParticipating(_ teams: [Bool]) {
		rounds[currentRound]?.setParticipating(teams)
	}
	
}
