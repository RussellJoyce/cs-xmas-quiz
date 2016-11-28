//
//  QuizViewController.swift
//  Quiz Server
//
//  Created by Russell Joyce on 04/12/2014.
//  Copyright (c) 2014 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa

enum RoundType {
    case none
    case idle
    case test
    case buzzers
    case trueFalse
    case pointless
	case timer
}

class QuizViewController: NSViewController {
    
    let spriteKitView = SpriteKitViewController(nibName: "SpriteKitViewController", bundle: nil)!
    let pointlessGame = PointlessGameController(nibName: "PointlessGameController", bundle: nil)!
	let trueFalseView = TrueFalseViewController(nibName: "TrueFalseViewController", bundle: nil)!
	
	var currentRound = RoundType.none
    var currentRoundView: NSView?
    var quizLeds: QuizLeds?
	var numTeams = 10
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        spriteKitView.leds = quizLeds
        trueFalseView.leds = quizLeds
        pointlessGame.leds = quizLeds
		
		spriteKitView.numTeams = numTeams
		pointlessGame.numTeams = numTeams
		trueFalseView.numTeams = numTeams
        
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
        case .idle, .test, .buzzers, .timer:
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
            case .idle, .test, .buzzers, .timer:
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
    /// - parameter team: Team number (0-7)
    func buzzerPressed(team: Int) {
        switch (currentRound) {
        case .none:
            break // Do nothing
        case .idle, .test, .buzzers, .timer:
            spriteKitView.buzzerPressed(team: team)
        case .trueFalse:
			trueFalseView.buzzerPressed(team: team)
        case .pointless:
            break // Do nothing
        }
    }
    
    /// Called when buzzer has been released
    ///
    /// - parameter team: Team number (0-7)
    func buzzerReleased(team: Int) {
        switch (currentRound) {
        case .none:
            break // Do nothing
        case .idle:
            spriteKitView.buzzerReleased(team: team)
        case .test:
            spriteKitView.buzzerReleased(team: team)
		case .timer:
			break
        case .buzzers:
            break // Do nothing
        case .trueFalse:
            break // Do nothing
        case .pointless:
            break // Do nothing
        }
    }
    
	func startTimer() {
		spriteKitView.startTimer();
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
	
	func setTeamType(team: Int, type: TeamType) {
		spriteKitView.setTeamType(team: team, type: type)
	}
}
