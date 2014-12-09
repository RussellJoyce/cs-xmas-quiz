//
//  ControllerWindowController.swift
//  Quiz Server
//
//  Created by Russell Joyce on 18/11/2014.
//  Copyright (c) 2014 Russell Joyce. All rights reserved.
//

import Cocoa
import DDHidLib

class ControllerWindowController: NSWindowController, NSWindowDelegate, NSTabViewDelegate {
    
    @IBOutlet weak var pointlessScore: NSTextField!
    
    var quizScreen: NSScreen?
    var quizBuzzers: DDHidJoystick?
    var quizLeds: QuizLeds?
    var testMode: Bool = true
    
    let quizView = QuizViewController(nibName: "QuizView", bundle: nil) as QuizViewController!
    var quizWindow: NSWindow?
    
    var led1 = false
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        // Open serial port
        quizLeds?.openSerial()
        quizView.quizLeds = quizLeds
        
        // Open game controller
        quizBuzzers?.setDelegate(self)
        quizBuzzers?.startListening()
        
        if (testMode) {
            // Show quiz view in floating window
            quizWindow = NSWindow(contentViewController: quizView)
            quizWindow?.title = "Quiz Test"
            quizWindow?.styleMask = NSTitledWindowMask
            quizWindow?.makeKeyAndOrderFront(self)
            self.window?.orderFront(self)
        }
        else {
            // Show quiz view on selected screen (resized to fit)
            quizView.view.addConstraint(NSLayoutConstraint(item: quizView.view,
                attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal,
                toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute,
                multiplier: 1, constant: quizScreen!.frame.width))
            quizView.view.addConstraint(NSLayoutConstraint(item: quizView.view,
                attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal,
                toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute,
                multiplier: 1, constant: quizScreen!.frame.height))
            quizView.view.enterFullScreenMode(quizScreen!, withOptions: [NSFullScreenModeAllScreens: 0])
        }
    }
    
    func windowWillClose(notification: NSNotification) {
        // Turn off all buzzer and animation LEDs
        quizLeds?.buzzersOff()
        quizLeds?.stringOff()
        
        // Cleanly close serial port and game controller
        quizLeds?.closeSerial()
        quizBuzzers?.stopListening()
    }
    
    @IBAction func pressedNumber(sender: NSButton) {
        if (sender.state == NSOnState) {
            quizLeds?.buzzerOn(sender.tag - 1)
        }
        else {
            quizLeds?.buzzerOff(sender.tag - 1)
        }
    }
    
	@IBAction func pointlessTeam1(sender: AnyObject) {
	}
	
	
	
    @IBAction func pressedButton(sender: NSButton) {
        if led1 {
            quizLeds?.buzzerOff(0)
            usleep(100000)
            quizLeds?.buzzerOff(1)
            usleep(100000)
            quizLeds?.buzzerOff(2)
            usleep(100000)
            quizLeds?.buzzerOff(3)
            usleep(100000)
            quizLeds?.buzzerOff(4)
            usleep(100000)
            quizLeds?.buzzerOff(5)
            usleep(100000)
            quizLeds?.buzzerOff(6)
            usleep(100000)
            quizLeds?.buzzerOff(7)
            led1 = false
        }
        else {
            quizLeds?.buzzerOn(0)
            usleep(100000)
            quizLeds?.buzzerOn(1)
            usleep(100000)
            quizLeds?.buzzerOn(2)
            usleep(100000)
            quizLeds?.buzzerOn(3)
            usleep(100000)
            quizLeds?.buzzerOn(4)
            usleep(100000)
            quizLeds?.buzzerOn(5)
            usleep(100000)
            quizLeds?.buzzerOn(6)
            usleep(100000)
            quizLeds?.buzzerOn(7)
            led1 = true
        }
    }
    
    func tabView(tabView: NSTabView, didSelectTabViewItem tabViewItem: NSTabViewItem?) {
        let index = tabView.indexOfTabViewItem(tabViewItem!)
        
        switch index {
        case 0:
            quizView.setRound(RoundType.Idle)
        case 1:
            quizView.setRound(RoundType.Test)
        case 2:
            quizView.setRound(RoundType.Buzzers)
        case 3:
            quizView.setRound(RoundType.TrueFalse)
        case 4:
            quizView.setRound(RoundType.Pointless)
        default:
            break
        }
    }
    

    @IBAction func resetRound(sender: AnyObject) {
        quizView.resetRound()
    }
    
    @IBAction func setPointlessScoreValue(sender: AnyObject) {
        if pointlessScore.stringValue.lowercaseString == "w" {
            quizView.setPointlessWrong()
        }
        else if let score = pointlessScore.stringValue.toInt() {
            quizView.setPointlessScore(score)
        }
    }
    
	@IBAction func pointlessTeamPress(sender: NSButton) {
		quizView.setPointlessTeam(sender.tag)
	}
	
	@IBAction func pointlessResetTeam(sender: AnyObject) {
		quizView.pointlessResetCurrentTeam()
	}

    @IBAction func pointlessWrong(sender: AnyObject) {
        quizView.setPointlessWrong()
    }
    
	@IBAction func trueFalseStart(sender: NSButton) {
		quizView.trueFalseStart()
	}
	
	@IBAction func trueFalseTrue(sender: NSButton) {
		quizView.trueFalseAnswer(true)
	}
	
	@IBAction func trueFalseFalse(sender: NSButton) {
		quizView.trueFalseAnswer(false)
	}
	
    override func ddhidJoystick(joystick: DDHidJoystick!, buttonDown buttonNumber: UInt32) {
        quizView.buzzerPressed(Int(buttonNumber))
    }
    
    override func ddhidJoystick(joystick: DDHidJoystick!, buttonUp buttonNumber: UInt32) {
        quizView.buzzerReleased(Int(buttonNumber))
    }

    
}
