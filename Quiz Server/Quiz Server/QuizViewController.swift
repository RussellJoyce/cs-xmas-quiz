//
//  QuizViewController.swift
//  Quiz Server
//
//  Created by Russell Joyce on 04/12/2014.
//  Copyright (c) 2014 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import Starscream

enum RoundType {
    case none
    case idle
    case test
    case buzzers
    case music
    case trueFalse
	case timer
	case geography
	case text
	case numbers
}

class QuizViewController: NSViewController {
    
    let spriteKitView = SpriteKitViewController(nibName: "SpriteKitViewController", bundle: nil)
	let trueFalseView = TrueFalseViewController(nibName: "TrueFalseViewController", bundle: nil)
	
	var currentRound = RoundType.none
    var currentRoundView: NSView?
    var quizLeds: QuizLeds?
	var webSocket: WebSocket?
	var numTeams = 10
	var geographyImagesPath: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        spriteKitView.leds = quizLeds
        trueFalseView.leds = quizLeds
		
		spriteKitView.webSocket = webSocket

		spriteKitView.numTeams = numTeams
		trueFalseView.numTeams = numTeams
		
		spriteKitView.geographyScene.imagesPath = geographyImagesPath
        
        spriteKitView.view.frame = view.bounds
		trueFalseView.view.frame = view.bounds
        
        setRound(round: RoundType.idle)
    }
    
    func resetRound() {
		switch (currentRound) {
		case .none:
			break // Do nothing
		case .idle, .test, .buzzers, .music, .timer, .geography, .text, .numbers:
			spriteKitView.reset()
		case .trueFalse:
			trueFalseView.reset()
		}
    }
    
    func setRound(round: RoundType) {
        if currentRound != round {
            let lastRoundView = currentRoundView
            resetRound()
            currentRound = round
			spriteKitView.setRound(round: round)
            resetRound()
            
			switch (currentRound) {
			case .none:
				currentRoundView = nil
			case .idle, .test, .buzzers, .music, .timer, .geography, .text, .numbers:
				currentRoundView = spriteKitView.view
			case .trueFalse:
				currentRoundView = trueFalseView.view
			}
			
			if currentRoundView != lastRoundView {
				if let currentRoundView = currentRoundView {
					if let lastRoundView = lastRoundView {
						view.replaceSubview(lastRoundView, with: currentRoundView)
					}
					else {
						view.addSubview(currentRoundView)
					}
				}
				else {
					lastRoundView?.removeFromSuperview()
				}
			}
        }
    }
	
    /// Called when buzzer has been pressed down
    ///
    /// - parameter team: Team number (0-9)
	/// - parameter type: Type of buzzer that was pressed (test button, physical button, or websocket)
	func buzzerPressed(team: Int, type: BuzzerType, buzzcocksMode: Bool, buzzerQueueMode: Bool, quietMode: Bool) {
        switch (currentRound) {
        case .none:
            break // Do nothing
        case .idle, .test, .buzzers, .music, .timer, .geography, .text, .numbers:
			spriteKitView.buzzerPressed(team: team, type: type, buzzcocksMode: buzzcocksMode, buzzerQueueMode: buzzerQueueMode, quietMode: quietMode)
        case .trueFalse:
			trueFalseView.buzzerPressed(team: team)
        }
    }
    
    /// Called when buzzer has been released
    ///
	/// - parameter team: Team number (0-9)
	/// - parameter type: Type of buzzer that was pressed (test button, physical button, or websocket)
    func buzzerReleased(team: Int, type: BuzzerType) {
        switch (currentRound) {
        case .none:
            break // Do nothing
        case .idle, .test, .buzzers, .music, .timer, .geography, .text, .numbers:
            spriteKitView.buzzerReleased(team: team, type: type)
		case .trueFalse:
			break // Do nothing
        }
    }
    
	func timerShowCounter(_ state : Bool) {
		spriteKitView.timerShowCounter(state)
	}
	
	func startTimer(music : Bool) {
		spriteKitView.startTimer(music: music);
	}

	func stopTimer() {
		spriteKitView.stopTimer();
	}

	func timerIncrement() {
		spriteKitView.timerIncrement();
	}
	
	func timerDecrement() {
		spriteKitView.timerDecrement();
	}
	
	func startBuzzerTimer(_ seconds: Int) {
		spriteKitView.startBuzzerTimer(seconds)
	}
	
	func stopBuzzerTimer() {
		spriteKitView.stopBuzzerTimer()
	}
	
	func trueFalseStart() {
		trueFalseView.start()
	}
	
	func trueFalseAnswer(ans : Bool) {
		trueFalseView.answer(ans: ans)
	}
    
    func buzzersNextTeam() {
        spriteKitView.nextBuzzerTeam()
    }
    
    func musicNextTeam() {
        spriteKitView.nextMusicTeam()
    }
    
    func musicPlay() {
        spriteKitView.musicPlay()
    }
    
    func musicPause() {
        spriteKitView.musicPause()
    }
    
    func musicStop() {
        spriteKitView.musicStop()
    }
    
    func musicSetFile(file: String) {
        spriteKitView.musicSetFile(file: file)
    }
	
	func uniqueSetFile(file: String) {
		spriteKitView.uniqueSetFile(file: file)
	}

	func geoStartQuestion(question: Int) {
		spriteKitView.geographyScene.setQuestion(question: question)
	}
	
	func geoShowWinner(x: Int, y: Int) {
		spriteKitView.geographyScene.showWinner(answerx: x, answery: y)
	}
	
	func geoTeamAnswered(team: Int, x: Int, y: Int) {
		spriteKitView.geographyScene.teamAnswered(team: team, x: x, y: y)
	}
	
	func setTeamType(team: Int, type: TeamType) {
		spriteKitView.setTeamType(team: team, type: type)
	}

	func textTeamGuess(teamid : Int, guess : String, roundid : Int, showroundno : Bool) {
		spriteKitView.textTeamGuess(teamid: teamid, guess: guess, roundid: roundid, showroundno: showroundno)
	}
	
	func textScoreUnique() {
		spriteKitView.textScoreUnique()
	}
	
	func textShowGuesses(showroundno : Bool) {
		spriteKitView.textShowGuesses(showroundno: showroundno)
	}
	
	func numbersTeamGuess(teamid : Int, guess : Int) {
		spriteKitView.numbersTeamGuess(teamid: teamid, guess: guess)
	}
	
	func numbersShowGuesses(actualAnswer : Int) {
		spriteKitView.numbersShowGuesses(actualAnswer: actualAnswer)
	}
	
}
