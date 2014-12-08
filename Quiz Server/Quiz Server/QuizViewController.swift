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
            break // Do nothing
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
            
            for view in roundView.subviews as [NSView] {
                view.removeFromSuperview()
            }
            
            resetRound()
            
            switch (currentRound) {
            case .Idle:
                break // Do nothing
            case .Test:
                roundView.addSubview(testView.view)
            case .Buzzers:
                break // Do nothing
            case .TrueFalse:
                break // Do nothing
            case .Pointless:
                roundView.addSubview(pointlessGame.view)
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
        case .Buzzers:
            break // Do nothing
        case .TrueFalse:
            break // Do nothing
        case .Pointless:
            break // Do nothing
        }
    }
    
    
    func setPointlessScore(score: Int) -> Bool {
        if currentRound != RoundType.Pointless || score < 0 || score > 100 {
            return false
        }
        
        //pointlessView.setScore(score)
        return true
    }
    
    func setPointlessWrong() -> Bool {
        if currentRound != RoundType.Pointless {
            return false
        }
        
        //pointlessView.reset()
        //pointlessView.wrong()
        return true
    }
    
}
