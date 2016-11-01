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
    var buzzersEnabled = [Bool](repeating: true, count: 10)
    var buzzersDisabled = false
    var buzzerButtons = [NSButton]()
    
    let quizView = QuizViewController(nibName: "QuizView", bundle: nil) as QuizViewController!
    var quizWindow: NSWindow?
    
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        // Open serial port
        quizLeds?.openSerial()
        quizView?.quizLeds = quizLeds
		
        // Open game controller
        quizBuzzers?.setDelegate(self)
        quizBuzzers?.startListening()
        
        if (testMode) {
            // Show quiz view in floating window
            quizWindow = NSWindow(contentViewController: quizView!)
            quizWindow?.title = "Quiz Test"
            quizWindow?.styleMask = NSTitledWindowMask
            quizWindow?.makeKeyAndOrderFront(self)
            self.window?.orderFront(self)
        }
        else {
            // Show quiz view on selected screen (resized to fit)
            quizView?.view.addConstraint(NSLayoutConstraint(item: quizView?.view,
                attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal,
                toItem: nil, attribute: NSLayoutAttribute.notAnAttribute,
                multiplier: 1, constant: quizScreen!.frame.width))
            quizView?.view.addConstraint(NSLayoutConstraint(item: quizView?.view,
                attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal,
                toItem: nil, attribute: NSLayoutAttribute.notAnAttribute,
                multiplier: 1, constant: quizScreen!.frame.height))
            quizView?.view.enterFullScreenMode(quizScreen!, withOptions: [NSFullScreenModeAllScreens: 0])
        }
        
        buzzerButtons += [buzzerButton1, buzzerButton2, buzzerButton3, buzzerButton4, buzzerButton5, buzzerButton6, buzzerButton7, buzzerButton8, buzzerButton9, buzzerButton10]
    }
    
    func windowWillClose(_ notification: Notification) {
        // Turn off all buzzer and animation LEDs
        quizLeds?.buzzersOff()
        quizLeds?.stringOff()
        
        // Cleanly close serial port and game controller
        quizLeds?.closeSerial()
        quizBuzzers?.stopListening()
    }
    
    @IBAction func pressedNumber(_ sender: NSButton) {
        // If buzzers are not connected, buttons will act as virtual buzzers,
        //  otherwise, buttons will disable buzzers
        if quizBuzzers == nil {
            if (sender.state == NSOnState) {
                quizView?.buzzerPressed(sender.tag)
            }
            else {
                quizView?.buzzerReleased(sender.tag)
            }
        }
        else {
            if (sender.state == NSOnState) {
                buzzersEnabled[sender.tag] = false
                quizView?.buzzerReleased(sender.tag)
            }
            else {
                buzzersEnabled[sender.tag] = true
            }
        }
    }
    
    @IBAction func disableAllBuzzers(_ sender: NSButton) {
        if (sender.state == NSOnState) {
            buzzersDisabled = true
            for i in 0...9 {
                quizView?.buzzerReleased(i)
                buzzerButtons[i].isEnabled = false
            }
        }
        else {
            buzzersDisabled = false
            for button in buzzerButtons {
                button.isEnabled = true
            }
        }
    }

    
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        let index = tabView.indexOfTabViewItem(tabViewItem!)
        
        switch index {
        case 0:
            quizView?.setRound(RoundType.idle)
        case 1:
            quizView?.setRound(RoundType.test)
        case 2:
            quizView?.setRound(RoundType.buzzers)
        case 3:
            quizView?.setRound(RoundType.trueFalse)
        case 4:
            quizView?.setRound(RoundType.pointless)
		case 5:
			quizView?.setRound(RoundType.timer)
        default:
            break
        }
    }
    

    @IBAction func resetRound(_ sender: AnyObject) {
        quizView?.resetRound()
    }
    
    @IBAction func setPointlessScoreValue(_ sender: AnyObject) {
        if pointlessScore.stringValue.lowercased() == "w" {
            quizView?.setPointlessWrong()
        }
        else if let score = Int(pointlessScore.stringValue) {
            quizView?.setPointlessScore(score, animated: true)
        }
    }
	
	@IBAction func setPointlessScoreValueImmediate(_ sender: AnyObject) {
		if pointlessScore.stringValue.lowercased() == "w" {
			quizView?.setPointlessWrong()
		}
		else if let score = Int(pointlessScore.stringValue) {
			quizView?.setPointlessScore(score, animated: false)
		}
	}
	
	@IBAction func pointlessTeamPress(_ sender: NSButton) {
		quizView?.setPointlessTeam(sender.tag)
	}
	
	@IBAction func pointlessResetTeam(_ sender: AnyObject) {
		quizView?.pointlessResetCurrentTeam()
	}

    @IBAction func pointlessWrong(_ sender: AnyObject) {
        quizView?.setPointlessWrong()
    }
    
	@IBAction func trueFalseStart(_ sender: NSButton) {
		quizView?.trueFalseStart()
	}
	
	@IBAction func trueFalseTrue(_ sender: NSButton) {
		quizView?.trueFalseAnswer(true)
	}
	
	@IBAction func trueFalseFalse(_ sender: NSButton) {
		quizView?.trueFalseAnswer(false)
	}
	
    @IBAction func buzzersNextTeam(_ sender: AnyObject) {
        quizView?.buzzersNextTeam()
    }
    
	@IBAction func startTimer(_ sender: AnyObject) {
		quizView?.startTimer()
	}
	
	@IBAction func stopTimer(_ sender: AnyObject) {
		quizView?.stopTimer()
	}
	
	@IBAction func timerIncrement(_ sender: AnyObject) {
		quizView?.timerIncrement()
	}
	
	@IBAction func timerDecrement(_ sender: AnyObject) {
		quizView?.timerDecrement()
	}
	
	@IBAction func setTeamType(_ sender: NSPopUpButton) {
		switch sender.indexOfSelectedItem {
		case 0:
			quizView?.setTeamType(sender.tag, type: .christmas)
		case 1:
			quizView?.setTeamType(sender.tag, type: .academic)
		case 2:
			quizView?.setTeamType(sender.tag, type: .ibm)
		default:
			quizView?.setTeamType(sender.tag, type: .christmas)
		}
	}
	
    override func ddhidJoystick(_ joystick: DDHidJoystick!, buttonDown buttonNumber: UInt32) {
        let button = Int(buttonNumber)
        if (!buzzersDisabled && buzzersEnabled[button]) {
            quizView?.buzzerPressed(button)
        }
    }
    
    override func ddhidJoystick(_ joystick: DDHidJoystick!, buttonUp buttonNumber: UInt32) {
        let button = Int(buttonNumber)
        if (!buzzersDisabled && buzzersEnabled[button]) {
            quizView?.buzzerReleased(button)
        }
    }

}
