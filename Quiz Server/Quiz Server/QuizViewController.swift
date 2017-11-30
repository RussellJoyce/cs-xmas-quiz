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
    case trueFalse
    case pointless
	case timer
	case boggle
	case geography
	case text
}

class QuizViewController: NSViewController {
    
    let spriteKitView = SpriteKitViewController(nibName: NSNib.Name(rawValue: "SpriteKitViewController"), bundle: nil)
    let pointlessGame = PointlessGameController(nibName: NSNib.Name(rawValue: "PointlessGameController"), bundle: nil)
	let trueFalseView = TrueFalseViewController(nibName: NSNib.Name(rawValue: "TrueFalseViewController"), bundle: nil)
	
	var currentRound = RoundType.none
    var currentRoundView: NSView?
    var quizLeds: QuizLeds?
	var webSocket: WebSocket?
	var numTeams = 10
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        spriteKitView.leds = quizLeds
        trueFalseView.leds = quizLeds
        pointlessGame.leds = quizLeds
		
		spriteKitView.numTeams = numTeams
		pointlessGame.numTeams = numTeams
		trueFalseView.numTeams = numTeams
		
		spriteKitView.boggleScene.webSocket = webSocket
        
        spriteKitView.view.frame = view.bounds
        pointlessGame.view.frame = view.bounds
		trueFalseView.view.frame = view.bounds
        
        setRound(round: RoundType.idle)
    }
    
    func resetRound() {
        // Turn off LEDs
        quizLeds?.stringOff()
        quizLeds?.buzzersOff()
        
        switch (currentRound) {
        case .none:
            break // Do nothing
        case .idle, .test, .buzzers, .timer, .boggle, .geography, .text:
            spriteKitView.reset()
        case .trueFalse:
            trueFalseView.reset()
		case .pointless:
            pointlessGame.reset()
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
            case .idle, .test, .buzzers, .timer, .boggle, .geography, .text:
                currentRoundView = spriteKitView.view
            case .trueFalse:
                currentRoundView = trueFalseView.view
            case .pointless:
                currentRoundView = pointlessGame.view
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
	func buzzerPressed(team: Int, type: BuzzerType) {
        switch (currentRound) {
        case .none:
            break // Do nothing
		case .idle, .test, .buzzers, .timer, .boggle, .geography, .text:
            spriteKitView.buzzerPressed(team: team, type: type)
        case .trueFalse:
			trueFalseView.buzzerPressed(team: team)
		case .pointless:
            break // Do nothing
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
		case .idle, .test, .buzzers, .timer, .boggle, .geography, .text:
            spriteKitView.buzzerReleased(team: team, type: type)
		case .trueFalse:
			break // Do nothing
        case .pointless:
			break // Do nothing
        }
    }
    
	func startTimer() {
		spriteKitView.startTimer();
	}
	
	func boggleDisplayGrid() {
		spriteKitView.boggleDisplayGrid();
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
	
	func setPointlessTeam(team: Int) {
		pointlessGame.setCurrentTeam(team: team)
	}
	
	func pointlessResetCurrentTeam() {
		pointlessGame.resetTeam()
	}
	
	func setPointlessScore(score: Int, animated: Bool) {
        if currentRound == RoundType.pointless && score >= 0 && score <= 100 {
            pointlessGame.setScore(score: score, animated: animated)
        }
    }
    
    func setPointlessWrong() {
        if currentRound == RoundType.pointless {
            pointlessGame.wrong()
        }
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
	
	func setBoggleScore(team: Int, score: Int) {
		spriteKitView.boggleScene.setTeamScore(team: team, score: score)
	}
	
	func setBoggleQuestion(questionNum: Int) {
		spriteKitView.boggleScene.setQuestion(questionNum: questionNum)
	}
	
	func textTeamGuess(teamid : Int, guess : String, roundid : Int, showroundno : Bool) {
		spriteKitView.textTeamGuess(teamid: teamid, guess: guess, roundid: roundid, showroundno: showroundno)
	}
	
	func textShowGuesses(showroundno : Bool) {
		spriteKitView.textShowGuesses(showroundno: showroundno)
	}
	
}
