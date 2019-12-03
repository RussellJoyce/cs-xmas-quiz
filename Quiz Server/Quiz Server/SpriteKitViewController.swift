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
    let musicScene = MusicScene()
	let timerScene = TimerScene()
	let geographyScene = GeographyScene()
	let textScene = TextScene()
	let numbersScene = NumbersScene()
	var leds: QuizLeds?
	var currentRound = RoundType.none
	var numTeams = 10
	var transitions = [SKTransition]()

	override func viewDidLoad() {
		super.viewDidLoad()
		
		skView.ignoresSiblingOrder = true
		//skView.showsFPS = true
		//skView.showsNodeCount = true
		
		idleScene.setUpScene(size: skView.bounds.size, leds: leds)
		testScene.setUpScene(size: skView.bounds.size, leds: leds, numTeams: numTeams)
		buzzerScene.setUpScene(size: skView.bounds.size, leds: leds, numTeams: numTeams)
        musicScene.setUpScene(size: skView.bounds.size, leds: leds, numTeams: numTeams)
		timerScene.setUpScene(size: skView.bounds.size, leds: leds)
		geographyScene.setUpScene(size: skView.bounds.size, leds: leds, numTeams: numTeams)
		textScene.setUpScene(size: skView.bounds.size, leds: leds, numTeams: numTeams)
		numbersScene.setUpScene(size: skView.bounds.size, leds: leds, numTeams: numTeams)
		
		let transitionDuration = 1.0
		
		var transition = SKTransition.doorsCloseVertical(withDuration: transitionDuration)
		transition.pausesIncomingScene = false
		transition.pausesOutgoingScene = false
		transitions.append(transition)
		
		transition = SKTransition.doorsOpenVertical(withDuration: transitionDuration)
		transition.pausesIncomingScene = false
		transition.pausesOutgoingScene = false
		transitions.append(transition)
		
		transition = SKTransition.doorway(withDuration: transitionDuration)
		transition.pausesIncomingScene = false
		transition.pausesOutgoingScene = false
		transitions.append(transition)
		
		transition = SKTransition.flipHorizontal(withDuration: transitionDuration)
		transition.pausesIncomingScene = false
		transition.pausesOutgoingScene = false
		transitions.append(transition)

		transition = SKTransition.flipVertical(withDuration: transitionDuration)
		transition.pausesIncomingScene = false
		transition.pausesOutgoingScene = false
		transitions.append(transition)
		
		transition = SKTransition.moveIn(with: .down, duration: transitionDuration)
		transition.pausesIncomingScene = false
		transition.pausesOutgoingScene = false
		transitions.append(transition)
		
		transition = SKTransition.moveIn(with: .up, duration: transitionDuration)
		transition.pausesIncomingScene = false
		transition.pausesOutgoingScene = false
		transitions.append(transition)
		
		transition = SKTransition.push(with: .down, duration: transitionDuration)
		transition.pausesIncomingScene = false
		transition.pausesOutgoingScene = false
		transitions.append(transition)
		
		transition = SKTransition.push(with: .up, duration: transitionDuration)
		transition.pausesIncomingScene = false
		transition.pausesOutgoingScene = false
		transitions.append(transition)
		
		transition = SKTransition.reveal(with: .down, duration: transitionDuration)
		transition.pausesIncomingScene = false
		transition.pausesOutgoingScene = false
		transitions.append(transition)
		
		transition = SKTransition.reveal(with: .up, duration: transitionDuration)
		transition.pausesIncomingScene = false
		transition.pausesOutgoingScene = false
		transitions.append(transition)
		
	}
	
	func setRound(round: RoundType) {
		currentRound = round
		
		var scene : SKScene?

		switch (currentRound) {
		case .idle:
			scene = idleScene
		case .test:
			scene = testScene
		case .buzzers:
			scene = buzzerScene
        case .music:
            scene = musicScene
		case .timer:
			scene = timerScene
		case .geography:
			scene = geographyScene
		case .text:
			scene = textScene
		case .numbers:
			scene = numbersScene
		default:
			scene = nil
		}
		
		if let scene = scene, transitions.count > 0 {
			let randomIndex = Int(arc4random_uniform(UInt32(transitions.count)))
			let transition = transitions[randomIndex]
			skView.presentScene(scene, transition: transition)
		}
		else {
			skView.presentScene(scene)
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
        case .music:
            musicScene.reset()
		case .timer:
			timerScene.reset()
		case .geography:
			geographyScene.reset()
		case .text:
			textScene.reset()
		case .numbers:
			numbersScene.reset()
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
        case .music:
            musicScene.buzzerPressed(team: team, type: type)
		case .timer:
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
        case .music:
            break
		case .timer:
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
    
    func nextMusicTeam() {
        musicScene.nextTeam()
    }
    
    func musicPlay() {
        musicScene.resumeMusic()
    }
    
    func musicPause() {
        musicScene.pauseMusic()
    }
    
    func musicStop() {
        musicScene.stopMusic()
    }
    
    func musicSetFile(file: String) {
        musicScene.initMusic(file: file)
    }
	
	func startTimer() {
		switch (currentRound) {
		case .timer:
			timerScene.startTimer()
		default:
			break
		}
	}
	
	func stopTimer() {
		switch (currentRound) {
		case .timer:
			timerScene.stopTimer()
		default:
			break
		}
	}
	
	func textTeamGuess(teamid : Int, guess : String, roundid : Int, showroundno : Bool) {
		textScene.teamGuess(teamid: teamid, guess: guess, roundid: roundid, showroundno: showroundno)
	}
	
	func numbersTeamGuess(teamid : Int, guess : Int) {
		numbersScene.teamGuess(teamid: teamid, guess: guess)
	}
	
	func textShowGuesses(showroundno : Bool) {
		textScene.showGuesses(showroundno: showroundno)
	}
	
	func numbersShowGuesses(actualAnswer : Int) {
		numbersScene.showGuesses(actualAnswer: actualAnswer)
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
