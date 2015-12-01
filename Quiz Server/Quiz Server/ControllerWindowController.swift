//
//  ControllerWindowController.swift
//  Quiz Server
//
//  Created by Russell Joyce on 18/11/2014.
//  Copyright (c) 2014 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import DDHidLib

class ControllerWindowController: NSWindowController, NSWindowDelegate, NSTabViewDelegate {
    
    @IBOutlet weak var buzzerButton1: NSButton!
    @IBOutlet weak var buzzerButton2: NSButton!
    @IBOutlet weak var buzzerButton3: NSButton!
    @IBOutlet weak var buzzerButton4: NSButton!
    @IBOutlet weak var buzzerButton5: NSButton!
    @IBOutlet weak var buzzerButton6: NSButton!
    @IBOutlet weak var buzzerButton7: NSButton!
    @IBOutlet weak var buzzerButton8: NSButton!
	@IBOutlet weak var buzzerButton9: NSButton!
	@IBOutlet weak var buzzerButton10: NSButton!
    @IBOutlet weak var pointlessScore: NSTextField!
    
    var quizScreen: NSScreen?
    var quizBuzzers: DDHidJoystick?
    var quizLeds: QuizLeds?
    var testMode: Bool = true
    var buzzersEnabled = [Bool](count: 10, repeatedValue: true)
    var buzzersDisabled = false
    var buzzerButtons = [NSButton]()
    
    let quizView = QuizViewController(nibName: "QuizView", bundle: nil) as QuizViewController!
    var quizWindow: NSWindow?
    
    
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
        
        buzzerButtons += [buzzerButton1, buzzerButton2, buzzerButton3, buzzerButton4, buzzerButton5, buzzerButton6, buzzerButton7, buzzerButton8, buzzerButton9, buzzerButton10]
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
        // If buzzers are not connected, buttons will act as virtual buzzers,
        //  otherwise, buttons will disable buzzers
        if quizBuzzers == nil {
            if (sender.state == NSOnState) {
                quizView.buzzerPressed(sender.tag)
            }
            else {
                quizView.buzzerReleased(sender.tag)
            }
        }
        else {
            if (sender.state == NSOnState) {
                buzzersEnabled[sender.tag] = false
                quizView.buzzerReleased(sender.tag)
            }
            else {
                buzzersEnabled[sender.tag] = true
            }
        }
    }
    
    @IBAction func disableAllBuzzers(sender: NSButton) {
        if (sender.state == NSOnState) {
            buzzersDisabled = true
            for i in 0...9 {
                quizView.buzzerReleased(i)
                buzzerButtons[i].enabled = false
            }
        }
        else {
            buzzersDisabled = false
            for button in buzzerButtons {
                button.enabled = true
            }
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
		case 5:
			quizView.setRound(RoundType.Timer)
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
        else if let score = Int(pointlessScore.stringValue) {
            quizView.setPointlessScore(score, animated: true)
        }
    }
	
	@IBAction func setPointlessScoreValueImmediate(sender: AnyObject) {
		if pointlessScore.stringValue.lowercaseString == "w" {
			quizView.setPointlessWrong()
		}
		else if let score = Int(pointlessScore.stringValue) {
			quizView.setPointlessScore(score, animated: false)
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
	
    @IBAction func buzzersNextTeam(sender: AnyObject) {
        quizView.buzzersNextTeam()
    }
    
	@IBAction func startTimer(sender: AnyObject) {
		quizView.startTimer()
	}
	
	@IBAction func stopTimer(sender: AnyObject) {
		quizView.stopTimer()
	}
	
	@IBAction func timerIncrement(sender: AnyObject) {
		quizView.timerIncrement()
	}
	
	@IBAction func timerDecrement(sender: AnyObject) {
		quizView.timerDecrement()
	}
	
	@IBAction func setTeamType(sender: NSPopUpButton) {
		switch sender.indexOfSelectedItem {
		case 0:
			quizView.setTeamType(sender.tag, type: .Christmas)
		case 1:
			quizView.setTeamType(sender.tag, type: .Academic)
		case 2:
			quizView.setTeamType(sender.tag, type: .Ibm)
		default:
			quizView.setTeamType(sender.tag, type: .Christmas)
		}
	}
	
    override func ddhidJoystick(joystick: DDHidJoystick!, buttonDown buttonNumber: UInt32) {
        let button = Int(buttonNumber)
        if (!buzzersDisabled && buzzersEnabled[button]) {
            quizView.buzzerPressed(button)
        }
    }
    
    override func ddhidJoystick(joystick: DDHidJoystick!, buttonUp buttonNumber: UInt32) {
        let button = Int(buttonNumber)
        if (!buzzersDisabled && buzzersEnabled[button]) {
            quizView.buzzerReleased(button)
        }
    }

}
