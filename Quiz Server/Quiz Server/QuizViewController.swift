//
//  QuizViewController.swift
//  Quiz Server
//
//  Created by Russell Joyce on 04/12/2014.
//  Copyright (c) 2014 Russell Joyce. All rights reserved.
//

import Cocoa

enum RoundType {
    case None
    case Idle
    case Test
    case Buzzers
    case TrueFalse
    case Pointless
}

class QuizViewController: NSViewController {

    @IBOutlet weak var roundView: NSView!
    
    var currentRound = RoundType.None
    
    let idleView = IdleViewController(nibName: "IdleView", bundle: nil)!
    let testView = TestViewController(nibName: "TestView", bundle: nil)!
    let buzzerView = BuzzerViewController(nibName: "BuzzerView", bundle: nil)!
    let pointlessGame = PointlessGameController(nibName: "PointlessGameController", bundle: nil)!
	let trueFalseView = TrueFalseViewController(nibName: "TrueFalseViewController", bundle: nil)!
    
    var currentRoundView: NSView?
    
    var quizLeds: QuizLeds?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        idleView.view.frame = roundView.bounds
        testView.view.frame = roundView.bounds
        pointlessGame.view.frame = roundView.bounds
		trueFalseView.view.frame = roundView.bounds
        
        idleView.leds = quizLeds
        testView.leds = quizLeds
        buzzerView.leds = quizLeds
        
        setRound(RoundType.Idle)
    }
    
    func resetRound() {
        // Turn off LEDs
        quizLeds?.stringOff()
        quizLeds?.buzzersOff()
        
        switch (currentRound) {
        case .None:
            break // Do nothing
        case .Idle:
            idleView.reset()
        case .Test:
            testView.reset()
        case .Buzzers:
            buzzerView.reset()
        case .TrueFalse:
            trueFalseView.reset()
		case .Pointless:
            pointlessGame.reset()
        }
    }
    
    func setRound(round: RoundType) {
        if currentRound != round {
            currentRound = round
            currentRoundView?.removeFromSuperview()
            resetRound()
            
            switch (currentRound) {
            case .None:
                break // Do nothing
            case .Idle:
                currentRoundView = idleView.view
            case .Test:
                currentRoundView = testView.view
            case .Buzzers:
                currentRoundView = buzzerView.view
            case .TrueFalse:
                currentRoundView = trueFalseView.view
            case .Pointless:
                currentRoundView = pointlessGame.view
            }
            
            if let currentRoundViewOpt = currentRoundView {
                roundView.addSubview(currentRoundViewOpt)
            }
        }
    }
    
    
    /// Called when buzzer has been pressed down
    ///
    /// :param: team Team number (0-7)
    func buzzerPressed(team: Int) {
        switch (currentRound) {
        case .None:
            break // Do nothing
        case .Idle:
            break // Do nothing
        case .Test:
            testView.buzzerPressed(team)
        case .Buzzers:
            buzzerView.buzzerPressed(team)
        case .TrueFalse:
			trueFalseView.buzzerPressed(team)
        case .Pointless:
            break // Do nothing
        }
    }
    
    /// Called when buzzer has been released
    ///
    /// :param: team Team number (0-7)
    func buzzerReleased(team: Int) {
        switch (currentRound) {
        case .None:
            break // Do nothing
        case .Idle:
            break // Do nothing
        case .Test:
            testView.buzzerReleased(team)
        case .Buzzers:
            break // Do nothing
        case .TrueFalse:
            break // Do nothing
        case .Pointless:
            break // Do nothing
        }
    }
    
	
	func setPointlessTeam(team: Int) {
		quizLeds?.buzzersOff()
		quizLeds?.buzzerOn(team)
		pointlessGame.setCurrentTeam(team)
	}
	
	func pointlessResetCurrentTeam() {
		pointlessGame.resetTeam()
	}
	
    func setPointlessScore(score: Int) -> Bool {
        if currentRound != RoundType.Pointless || score < 0 || score > 100 {
            return false
        }
		pointlessGame.setScore(score)
		return true
    }
    
    func setPointlessWrong() -> Bool {
        if currentRound != RoundType.Pointless {
            return false
        }
		pointlessGame.wrong()
		return true
    }
	
	func trueFalseStart() {
		trueFalseView.start()
	}
	
	func trueFalseAnswer(ans : Bool) {
		trueFalseView.answer(ans)
	}
    
}
