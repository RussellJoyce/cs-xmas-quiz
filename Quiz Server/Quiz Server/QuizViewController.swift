//
//  QuizViewController.swift
//  Quiz Server
//
//  Created by Russell Joyce on 04/12/2014.
//  Copyright (c) 2014 Russell Joyce. All rights reserved.
//

import Cocoa

enum RoundType {
    case Idle
    case Test
    case Buzzers
    case TrueFalse
    case Pointless
}

class QuizViewController: NSViewController {

    @IBOutlet weak var roundView: NSView!
    
    var currentRound = RoundType.Idle
    
    let testView = TestViewController(nibName: "TestView", bundle: nil)!
    let pointlessGame = PointlessGameController(nibName: "PointlessGameController", bundle: nil)!
    
    var currentRoundView: NSView?
    
    var quizLeds: QuizLeds?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        testView.view.frame = roundView.bounds
        pointlessGame.view.frame = roundView.bounds
    }
    
    func resetRound() {
        quizLeds?.allOff()
        
        switch (currentRound) {
        case .Idle:
            break // Do nothing
        case .Test:
            testView.reset()
        case .Buzzers:
            break // Do nothing
        case .TrueFalse:
            break // Do nothing
        case .Pointless:
			break
            //pointlessGame.reset()
        }
    }
    
    func setRound(round: RoundType) {
        if currentRound != round {
        
            currentRound = round
            
            currentRoundView?.removeFromSuperview()
            
            resetRound()
            
            switch (currentRound) {
            case .Idle:
                currentRoundView = nil
            case .Test:
                currentRoundView = testView.view
            case .Buzzers:
                currentRoundView = nil
            case .TrueFalse:
                currentRoundView = nil
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
        case .Idle:
            break // Do nothing
        case .Test:
            quizLeds?.ledOn(team)
            testView.buzzerPressed(team)
        case .Buzzers:
            break // Do nothing
        case .TrueFalse:
            break // Do nothing
        case .Pointless:
            break // Do nothing
        }
    }
    
    /// Called when buzzer has been released
    ///
    /// :param: team Team number (0-7)
    func buzzerReleased(team: Int) {
        switch (currentRound) {
        case .Idle:
            break // Do nothing
        case .Test:
            quizLeds?.ledOff(team)
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
    
}
