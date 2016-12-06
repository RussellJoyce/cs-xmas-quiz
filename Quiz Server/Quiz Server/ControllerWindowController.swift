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
	@IBOutlet weak var boggleQuestions: NSPopUpButton!
	@IBOutlet weak var bogglePreview: NSTextField!
    var quizScreen: NSScreen?
    var quizBuzzers: DDHidJoystick?
    var quizLeds: QuizLeds?
    var testMode = true
	var numTeams = 10
    var buzzersEnabled = [Bool]()
    var buzzersDisabled = false
    var buzzerButtons = [NSButton]()
	var boggleGrids = [String]()
    
	@IBOutlet var tabitemtruefalse: NSTabViewItem!
	@IBOutlet var tabitemPointless: NSTabViewItem!
	@IBOutlet var tabitemTimer: NSTabViewItem!
	@IBOutlet var tabView: NSTabView!
	
	@IBOutlet var tabitemIdle: NSTabViewItem!
	@IBOutlet var tabitemTest: NSTabViewItem!
	@IBOutlet var tabitemBuzzers: NSTabViewItem!
	@IBOutlet var tabitemBoggle: NSTabViewItem!
	@IBOutlet var tabitemGeography: NSTabViewItem!
	
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
		quizView.webSocket = socket
		
		// Load entries into Boggle questions list from plist
		let plist = Bundle.main.path(forResource: "Boggle", ofType:"plist")
		let grids = NSDictionary(contentsOfFile:plist!)
		let questionGrids = grids?.value(forKey: "questionGrids") as! [NSDictionary]
		for (i, gridItem) in questionGrids.enumerated() {
			let number = i + 1
			let score = gridItem.value(forKey: "score") as! Int
			let grid = gridItem.value(forKey: "grid") as! String
			let title = "Question \(number):  score \(score)  '\(grid)'"
			boggleQuestions.addItem(withTitle: title)
			boggleGrids.append(grid.replacingOccurrences(of: ",", with: "\n"))
		}
		setBoggleQuestion(boggleQuestions)
		
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
		
		if(socket.isConnected) {
			socket.write(string: "vibuzzer")
		}
		
		tabView.removeTabViewItem(tabitemPointless)
		tabView.removeTabViewItem(tabitemTimer)
		tabView.removeTabViewItem(tabitemtruefalse)
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
		switch(tabViewItem!) {
		case tabitemIdle:
			if(socket.isConnected) {
				socket.write(string: "vibuzzer")
			}
			quizView.setRound(round: RoundType.idle)
		case tabitemTest:
			if(socket.isConnected) {
				socket.write(string: "vibuzzer")
			}
			quizView.setRound(round: RoundType.test)
		case tabitemBuzzers:
			if(socket.isConnected) {
				socket.write(string: "vibuzzer")
			}
			quizView.setRound(round: RoundType.buzzers)
		case tabitemtruefalse:
			quizView.setRound(round: RoundType.trueFalse)
		case tabitemPointless:
			quizView.setRound(round: RoundType.pointless)
		case tabitemTimer:
			quizView.setRound(round: RoundType.timer)
		case tabitemBoggle:
			if(socket.isConnected) {
				socket.write(string: "viboggle")
			}
			quizView.setRound(round: RoundType.boggle)
		case tabitemGeography:
			if(socket.isConnected) {
				socket.write(string: "imstart.jpg")
				socket.write(string: "vigeo")
			}
			quizView.setRound(round: RoundType.geography)
		default:
			break
		}
    }
    

    @IBAction func resetRound(_ sender: AnyObject) {
        quizView.resetRound()

		if (tabView.selectedTabViewItem == tabitemGeography) {
			socket.write(string: "imgeo" + geoStepper.stringValue + ".jpg")
			quizView.geoStartQuestion(question: Int(geoStepper.intValue))
		}
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
	
	@IBOutlet var geoAnswerX: NSTextField!
	@IBOutlet var geoAnswerY: NSTextField!
	@IBOutlet var geoQuestionNumber: NSTextField!
	@IBOutlet var geoStepper: NSStepper!
	@IBAction func geoStepperChange(_ sender: Any) {
		geoQuestionNumber.stringValue = geoStepper.stringValue
	}
	
	@IBAction func geoStartQuestion(_ sender: Any) {
		quizView.resetRound()
		socket.write(string: "imgeo" + geoStepper.stringValue + ".jpg")
		quizView.geoStartQuestion(question: Int(geoStepper.intValue))
	}
	
	@IBAction func geoShowWinner(_ sender: Any) {
		quizView.geoShowWinner(x: Int(geoAnswerX.intValue), y: Int(geoAnswerY.intValue))
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
	
	@IBAction func setBoggleQuestion(_ sender: NSPopUpButton) {
		let index = sender.indexOfSelectedItem
		quizView.setBoggleQuestion(questionNum: index)
		bogglePreview.stringValue = boggleGrids[index]
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
			case "ii":
				var details = String(text)!
				details = details.substring(from: details.characters.index(details.startIndex, offsetBy: 2)) //bleh
				let vals = details.components(separatedBy: ",")
				if(vals.count >= 3) {
					if let team = Int(vals[0]), let x = Int(vals[1]), let y = Int(vals[2]) {
						quizView.geoTeamAnswered(team: team - 1, x: x, y: y) //make zero indexed
					}
				}
			case "bs":
				var details = String(text)!
				details = details.substring(from: details.characters.index(details.startIndex, offsetBy: 2))
				print("Boggle message: \(details)")
				if let dataFromString = details.data(using: .utf8, allowLossyConversion: false) {
					let json = JSON(data: dataFromString)
					for (key, subJson) : (String, JSON) in json {
						let team = Int(key)
						let score = subJson.int
						if let team = team, let score = score {
							quizView.setBoggleScore(team: team - 1, score: score)
						}
						else {
							print("Bad Boggle score data: key \(key), subJson \(subJson)")
						}
					}
				}
			default:
				print("Unknown message: " + text)
			}
		}
	}

}
