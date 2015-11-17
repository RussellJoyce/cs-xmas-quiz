//
//  QuizViewController.swift
//  Quiz Server
//
//  Created by Russell Joyce on 04/12/2014.
//  Copyright (c) 2014 Russell Joyce & Ian Gray. All rights reserved.
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
    
    let spriteKitView = SpriteKitViewController(nibName: "SpriteKitViewController", bundle: nil)!
    let pointlessGame = PointlessGameController(nibName: "PointlessGameController", bundle: nil)!
	let trueFalseView = TrueFalseViewController(nibName: "TrueFalseViewController", bundle: nil)!
    
    var currentRoundView: NSView?
    
    var quizLeds: QuizLeds?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        spriteKitView.leds = quizLeds
        trueFalseView.leds = quizLeds
        pointlessGame.leds = quizLeds
        
        spriteKitView.view.frame = roundView.bounds
        pointlessGame.view.frame = roundView.bounds
		trueFalseView.view.frame = roundView.bounds
        
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
            spriteKitView.reset()
        case .Test:
            spriteKitView.reset()
        case .Buzzers:
            spriteKitView.reset()
        case .TrueFalse:
            trueFalseView.reset()
		case .Pointless:
            pointlessGame.reset()
        }
    }
    
    func setRound(round: RoundType) {
        if currentRound != round {
            let lastRoundView = currentRoundView
            resetRound()
            currentRound = round
			spriteKitView.setRound(round)
            resetRound()
            
            switch (currentRound) {
            case .None:
                currentRoundView = nil
            case .Idle:
                currentRoundView = spriteKitView.view
            case .Test:
				currentRoundView = spriteKitView.view
            case .Buzzers:
				currentRoundView = spriteKitView.view
            case .TrueFalse:
                currentRoundView = trueFalseView.view
            case .Pointless:
                currentRoundView = pointlessGame.view
            }
			
			if currentRoundView != lastRoundView {
				if let currentRoundViewOpt = currentRoundView {
					if let lastRoundViewOpt = lastRoundView {
						roundView.replaceSubview(lastRoundViewOpt, with: currentRoundViewOpt)
					}
					else {
						roundView.addSubview(currentRoundViewOpt)
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
        case .None:
            break // Do nothing
        case .Idle:
            spriteKitView.buzzerPressed(team)
        case .Test:
            spriteKitView.buzzerPressed(team)
        case .Buzzers:
            spriteKitView.buzzerPressed(team)
        case .TrueFalse:
			trueFalseView.buzzerPressed(team)
        case .Pointless:
            break // Do nothing
        }
    }
    
    /// Called when buzzer has been released
    ///
    /// - parameter team: Team number (0-7)
    func buzzerReleased(team: Int) {
        switch (currentRound) {
        case .None:
            break // Do nothing
        case .Idle:
            spriteKitView.buzzerReleased(team)
        case .Test:
            spriteKitView.buzzerReleased(team)
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
	
	func trueFalseStart() {
		trueFalseView.start()
	}
	
	func trueFalseAnswer(ans : Bool) {
		trueFalseView.answer(ans)
	}
    
    func buzzersNextTeam() {
        spriteKitView.nextBuzzerTeam()
    }
    
}
