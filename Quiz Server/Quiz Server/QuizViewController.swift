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
    case test
    case buzzers
    case pointless
}

class QuizViewController: NSViewController {

    @IBOutlet weak var roundView: NSView!
    
    var currentRound = RoundType.none
    
    let testView = TestViewController(nibName: "TestView", bundle: nil)!
    let buzzerView = BuzzerViewController(nibName: "BuzzerView", bundle: nil)!
    let pointlessGame = PointlessGameController(nibName: "PointlessGameController", bundle: nil)!
	
    var currentRoundView: NSView?
    
    var quizLeds: QuizLeds?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        testView.leds = quizLeds
        buzzerView.leds = quizLeds
        pointlessGame.leds = quizLeds
        
        testView.view.frame = roundView.bounds
        buzzerView.view.frame = roundView.bounds
        pointlessGame.view.frame = roundView.bounds
		
        setRound(RoundType.test)
    }
    
    func resetRound() {
        // Turn off LEDs
        quizLeds?.stringOff()
        quizLeds?.buzzersOff()
        
        switch (currentRound) {
        case .none:
            break // Do nothing
        case .test:
            testView.reset()
        case .buzzers:
            buzzerView.reset()
		case .pointless:
            pointlessGame.reset()
        }
    }
    
    func setRound(_ round: RoundType) {
        if currentRound != round {
            let lastRoundView = currentRoundView
            resetRound()
            currentRound = round
            resetRound()
            
            switch (currentRound) {
            case .none:
                currentRoundView = nil
            case .test:
                currentRoundView = testView.view
            case .buzzers:
                currentRoundView = buzzerView.view
            case .pointless:
                currentRoundView = pointlessGame.view
            }
            
            if let currentRoundViewOpt = currentRoundView {
                if let lastRoundViewOpt = lastRoundView {
                    // Animated transitions (doesn't quite work)
//                    let transition = CATransition()
//                    transition.type = kCATransitionReveal
//                    transition.subtype = kCATransitionFromTop
//                    roundView.setAnimations(["subviews": transition])
//                    NSAnimationContext.beginGrouping()
//                    NSAnimationContext.currentContext().timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn)
//                    NSAnimationContext.currentContext().duration = 3.0
//                    roundView.animator().replaceSubview(lastRoundViewOpt, with: currentRoundViewOpt)
//                    NSAnimationContext.endGrouping()
                    
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
    
    
    /// Called when buzzer has been pressed down
    ///
    /// :param: team Team number (0-7)
    func buzzerPressed(_ team: Int) {
        switch (currentRound) {
        case .none:
            break // Do nothing
        case .test:
            testView.buzzerPressed(team)
        case .buzzers:
            buzzerView.buzzerPressed(team)
        case .pointless:
            break // Do nothing
        }
    }
    
    /// Called when buzzer has been released
    ///
    /// :param: team Team number (0-7)
    func buzzerReleased(_ team: Int) {
        switch (currentRound) {
        case .none:
            break // Do nothing
        case .test:
            testView.buzzerReleased(team)
        case .buzzers:
            break // Do nothing
        case .pointless:
            break // Do nothing
        }
    }
    
	
	func setPointlessTeam(_ team: Int) {
		pointlessGame.setCurrentTeam(team)
	}
	
	func pointlessResetCurrentTeam() {
		pointlessGame.resetTeam()
	}
	
    func setPointlessScore(_ score: Int) -> Bool {
        if currentRound != RoundType.pointless || score < 0 || score > 100 {
            return false
        }
		pointlessGame.setScore(score)
		return true
    }
    
    func setPointlessWrong() -> Bool {
        if currentRound != RoundType.pointless {
            return false
        }
		pointlessGame.wrong()
		return true
    }
	
    func buzzersNextTeam() {
        buzzerView.nextTeam()
    }
    
}
