//
//  ControllerWindowController.swift
//  Quiz Server
//
//  Created by Russell Joyce on 18/11/2014.
//  Copyright (c) 2014 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import DDHidLib
import Starscream

enum BuzzerType {
	case test
	case button
	case websocket
	case disabled
}

class ControllerWindowController: NSWindowController, NSWindowDelegate, NSTabViewDelegate, WebSocketDelegate {
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
    var testMode = true
	var numTeams = 10
    var buzzersEnabled = [Bool]()
    var buzzersDisabled = false
    var buzzerButtons = [NSButton]()
    
    let quizView = QuizViewController(nibName: "QuizView", bundle: nil)!
    var quizWindow: NSWindow?
	
	let socket = WebSocket(url: URL(string: "ws://localhost:8091/")!)
	
    override func windowDidLoad() {
        super.windowDidLoad()
        
        // Open serial port
        quizLeds?.openSerial()
        quizView.quizLeds = quizLeds
		
        // Open game controller
        quizBuzzers?.setDelegate(self)
        quizBuzzers?.startListening()
		
		//Connect to Node server
		socket.delegate = self
		socket.connect()
		
		// Trim number of buttons down to match number of teams
		let allBuzzerButtons : [NSButton] = [buzzerButton1, buzzerButton2, buzzerButton3, buzzerButton4, buzzerButton5, buzzerButton6, buzzerButton7, buzzerButton8, buzzerButton9, buzzerButton10]
		for i in 0..<numTeams {
			buzzerButtons.append(allBuzzerButtons[i])
			buzzerButtons[i].isEnabled = true
			buzzersEnabled.append(true)
		}
		
		quizView.numTeams = numTeams
		
        if (testMode) {
            // Show quiz view in floating window
            quizWindow = NSWindow(contentViewController: quizView)
            quizWindow?.title = "Quiz Test"
            quizWindow?.styleMask = NSWindowStyleMask.titled
            quizWindow?.makeKeyAndOrderFront(self)
            self.window?.orderFront(self)
        }
        else {
            // Show quiz view on selected screen (resized to fit)
            quizView.view.addConstraint(NSLayoutConstraint(item: quizView.view,
                attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal,
                toItem: nil, attribute: NSLayoutAttribute.notAnAttribute,
                multiplier: 1, constant: quizScreen!.frame.width))
            quizView.view.addConstraint(NSLayoutConstraint(item: quizView.view,
                attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.equal,
                toItem: nil, attribute: NSLayoutAttribute.notAnAttribute,
                multiplier: 1, constant: quizScreen!.frame.height))
            quizView.view.enterFullScreenMode(quizScreen!, withOptions: [NSFullScreenModeAllScreens: 0])
        }
		
		
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
                quizView.buzzerPressed(team: sender.tag, type: .test)
            }
            else {
                quizView.buzzerReleased(team: sender.tag, type: .test)
            }
        }
        else {
            if (sender.state == NSOnState) {
                buzzersEnabled[sender.tag] = false
				if(socket.isConnected) {
					socket.write(string: "of" + String(sender.tag + 1))
				}
                quizView.buzzerReleased(team: sender.tag, type: .disabled)
            }
            else {
                buzzersEnabled[sender.tag] = true
				if(socket.isConnected) {
					socket.write(string: "on" + String(sender.tag + 1))
				}
            }
        }
    }
    
    @IBAction func disableAllBuzzers(_ sender: NSButton) {
        if (sender.state == NSOnState) {
            buzzersDisabled = true
            for i in 0..<numTeams {
                quizView.buzzerReleased(team: i, type: .disabled)
                buzzerButtons[i].isEnabled = false
				if(socket.isConnected) {
					socket.write(string: "of" + String(i + 1))
				}
            }
        }
        else {
            buzzersDisabled = false
			for i in 0..<numTeams {
                buzzerButtons[i].isEnabled = true
				if(socket.isConnected) {
					socket.write(string: "on" + String(i + 1))
				}
            }
        }
    }

    
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        let index = tabView.indexOfTabViewItem(tabViewItem!)
        
        switch index {
        case 0:
            quizView.setRound(round: RoundType.idle)
        case 1:
            quizView.setRound(round: RoundType.test)
        case 2:
            quizView.setRound(round: RoundType.buzzers)
        case 3:
            quizView.setRound(round: RoundType.trueFalse)
        case 4:
            quizView.setRound(round: RoundType.pointless)
		case 5:
			quizView.setRound(round: RoundType.timer)
        default:
            break
        }
    }
    

    @IBAction func resetRound(_ sender: AnyObject) {
        quizView.resetRound()
    }
    
    @IBAction func setPointlessScoreValue(_ sender: AnyObject) {
        if pointlessScore.stringValue.lowercased() == "w" {
            quizView.setPointlessWrong()
        }
        else if let score = Int(pointlessScore.stringValue) {
            quizView.setPointlessScore(score: score, animated: true)
        }
    }
	
	@IBAction func setPointlessScoreValueImmediate(_ sender: AnyObject) {
		if pointlessScore.stringValue.lowercased() == "w" {
			quizView.setPointlessWrong()
		}
		else if let score = Int(pointlessScore.stringValue) {
			quizView.setPointlessScore(score: score, animated: false)
		}
	}
	
	@IBAction func pointlessTeamPress(_ sender: NSButton) {
		let team = sender.tag
		if (team < numTeams) {
			quizView.setPointlessTeam(team: team)
		}
	}
	
	@IBAction func pointlessResetTeam(_ sender: AnyObject) {
		quizView.pointlessResetCurrentTeam()
	}

    @IBAction func pointlessWrong(_ sender: AnyObject) {
        quizView.setPointlessWrong()
    }
    
	@IBAction func trueFalseStart(_ sender: NSButton) {
		quizView.trueFalseStart()
	}
	
	@IBAction func trueFalseTrue(_ sender: NSButton) {
		quizView.trueFalseAnswer(ans: true)
	}
	
	@IBAction func trueFalseFalse(_ sender: NSButton) {
		quizView.trueFalseAnswer(ans: false)
	}
	
    @IBAction func buzzersNextTeam(_ sender: AnyObject) {
        quizView.buzzersNextTeam()
    }
    
	@IBAction func startTimer(_ sender: AnyObject) {
		quizView.startTimer()
	}
	
	@IBAction func stopTimer(_ sender: AnyObject) {
		quizView.stopTimer()
	}
	
	@IBAction func timerIncrement(_ sender: AnyObject) {
		quizView.timerIncrement()
	}
	
	@IBAction func timerDecrement(_ sender: AnyObject) {
		quizView.timerDecrement()
	}
	
	@IBAction func setTeamType(_ sender: NSPopUpButton) {
		let team = sender.tag
		if (team < numTeams) {
			switch sender.indexOfSelectedItem {
			case 0:
				quizView.setTeamType(team: team, type: .christmas)
			case 1:
				quizView.setTeamType(team: team, type: .academic)
			case 2:
				quizView.setTeamType(team: team, type: .ibm)
			default:
				quizView.setTeamType(team: team, type: .christmas)
			}
		}
	}
	
    override func ddhidJoystick(_ joystick: DDHidJoystick!, buttonDown buttonNumber: UInt32) {
        let button = Int(buttonNumber)
        if (!buzzersDisabled && button < numTeams && buzzersEnabled[button]) {
            quizView.buzzerPressed(team: button, type: .button)
        }
    }
    
    override func ddhidJoystick(_ joystick: DDHidJoystick!, buttonUp buttonNumber: UInt32) {
        let button = Int(buttonNumber)
        if (!buzzersDisabled && button < numTeams && buzzersEnabled[button]) {
            quizView.buzzerReleased(team: button, type: .button)
        }
    }
	
	
	public func websocketDidConnect(socket: WebSocket) {
		print("Websocket connected.")
	}
	
	public func websocketDidReceiveData(socket: WebSocket, data: Data) {
		//print("Got data: " . data)
	}
	
	public func websocketDidDisconnect(socket: WebSocket, error: NSError?) {
		print("Websocket disconnected.")
		
		DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
			socket.connect()
		}
	}
	
	public func websocketDidReceiveMessage(socket: WebSocket, text: String) {
		if(text.characters.count >= 3) {
			switch(String(text.characters.prefix(2))) {
				case "co":
					break;
				case "zz":
					if let idx = Int(String(text[text.index(text.startIndex, offsetBy:2)])) {
						let team = idx - 1 // Make zero-indexed
						if (!buzzersDisabled && team < numTeams && buzzersEnabled[team]) {
							quizView.buzzerPressed(team: team, type: .websocket)
							DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
								self.quizView.buzzerReleased(team: team, type: .websocket)
							}
						}
					}
					break;
				default:
					print("Unknown message: " + text)
					break;
			}
		}
	}

}
