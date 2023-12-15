//
//  SpriteKitViewController.swift
//  Quiz Server
//
//  Created by Russell Joyce on 17/11/2015.
//  Copyright © 2015 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import SpriteKit
import Starscream

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
	let truefalseScene = TrueFalseScene()
	var currentRound = RoundType.none
	var numTeams = 10
	
	let transitionDuration = 1.0
	var transitions = [SKTransition]()
	
	var webSocket: WebSocket?
	
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		skView.ignoresSiblingOrder = true
		
		idleScene.setUpScene(size: skView.bounds.size, websocket: webSocket)
		testScene.setUpScene(size: skView.bounds.size, numTeams: numTeams, webSocket: webSocket)
		buzzerScene.setUpScene(size: skView.bounds.size, numTeams: numTeams, webSocket: webSocket)
        musicScene.setUpScene(size: skView.bounds.size, numTeams: numTeams, webSocket: webSocket)
		timerScene.setUpScene(size: skView.bounds.size, webSocket: webSocket)
		truefalseScene.setUpScene(size: skView.bounds.size, numTeams: numTeams, webSocket: webSocket)
		geographyScene.setUpScene(size: skView.bounds.size, numTeams: numTeams)
		textScene.setUpScene(size: skView.bounds.size, numTeams: numTeams, webSocket: webSocket)
		numbersScene.setUpScene(size: skView.bounds.size, numTeams: numTeams, webSocket: webSocket)
		
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
		case .trueFalse:
			scene = truefalseScene
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
		
		reset()
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
		case .trueFalse:
			truefalseScene.reset()
		default:
			break
		}
	}
	
	func buzzerPressed(team: Int, type: BuzzerType, buzzcocksMode: Bool, buzzerQueueMode: Bool, quietMode : Bool) {
		switch (currentRound) {
		case .idle:
			idleScene.buzzerPressed(team: team, type: type)
		case .test:
			testScene.buzzerPressed(team: team, type: type)
		case .buzzers:
			buzzerScene.buzzerPressed(team: team, type: type, buzzerQueueMode: buzzerQueueMode, quietMode: quietMode)
        case .music:
			musicScene.buzzerPressed(team: team, type: type, buzzcocksMode: buzzcocksMode)
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
		default:
			break
		}
	}
	
	func timerShowCounter(_ state : Bool) {
		timerScene.showCounter(state)
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
	
	func uniqueSetFile(file: String) {
		textScene.initUnique(file: file)
	}
	
	func startBuzzerTimer(_ secs : Int) {
		buzzerScene.startTimer(secs)
	}
	
	func stopBuzzerTimer() {
		buzzerScene.stopTimer()
	}
	
	func startTimer(music: Bool) {
		timerScene.startTimer(music: music)
	}
	
	func stopTimer() {
		timerScene.stopTimer()
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
	
	func textScoreUnique() {
		textScene.scoreUnique()
	}
	
	func trueFalseStart() {
		truefalseScene.start()
	}
	
	func trueFalseShowAnswer(ans : Bool) {
		truefalseScene.showAnswer(ans: ans)
	}
	
	func trueFalseTeamGuess(teamid : Int, guess : Bool) {
		truefalseScene.teamGuess(teamid: teamid, guess: guess)
	}
}
