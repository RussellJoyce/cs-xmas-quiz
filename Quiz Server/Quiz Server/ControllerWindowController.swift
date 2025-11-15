//
//  ControllerWindowController.swift
//  Quiz Server
//
//  Created by Russell Joyce on 18/11/2014.
//  Copyright (c) 2014 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import Starscream

enum BuzzerType {
	case test
	case button
	case websocket
	case disabled
}

enum RoundType {
	case none
	case idle
	case test
	case buzzers
	case music
	case trueFalse
	case timer
	case geography
	case text
	case numbers
	case scores
	case pointless
}

class ControllerWindowController: NSWindowController, NSWindowDelegate, NSTabViewDelegate, WebSocketDelegate {
    
	@IBOutlet weak var virtualBuzzersBtn: NSButton!
	
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
	@IBOutlet weak var buzzerButton11: NSButton!
	@IBOutlet weak var buzzerButton12: NSButton!
	@IBOutlet weak var buzzerButton13: NSButton!
	@IBOutlet weak var buzzerButton14: NSButton!
	@IBOutlet weak var buzzerButton15: NSButton!
	
	@IBOutlet weak var st1: NSBox!
	@IBOutlet weak var st2: NSBox!
	@IBOutlet weak var st3: NSBox!
	@IBOutlet weak var st4: NSBox!
	@IBOutlet weak var st5: NSBox!
	@IBOutlet weak var st6: NSBox!
	@IBOutlet weak var st7: NSBox!
	@IBOutlet weak var st8: NSBox!
	@IBOutlet weak var st9: NSBox!
	@IBOutlet weak var st10: NSBox!
	@IBOutlet weak var st11: NSBox!
	@IBOutlet weak var st12: NSBox!
	@IBOutlet weak var st13: NSBox!
	@IBOutlet weak var st14: NSBox!
	@IBOutlet weak var st15: NSBox!
	
	@IBOutlet var tabView: NSTabView!
	@IBOutlet var tabitemtruefalse: NSTabViewItem!
	@IBOutlet var tabitemTimer: NSTabViewItem!
	@IBOutlet var tabitemIdle: NSTabViewItem!
	@IBOutlet var tabitemTest: NSTabViewItem!
	@IBOutlet var tabitemBuzzers: NSTabViewItem!
	@IBOutlet var tabitemMusic: NSTabViewItem!
	@IBOutlet var tabitemGeography: NSTabViewItem!
	@IBOutlet var tabitemText: NSTabViewItem!
	@IBOutlet var tabitemNumbers: NSTabViewItem!
	@IBOutlet var tabitemScores: NSTabViewItem!
	@IBOutlet var tabitemPointless: NSTabViewItem!
	
	//MARK: - General
	//--------------------------------------------------------------------------------------------------------------------------
	var quizScreen: NSScreen?
	var windowedMode = true
	var buzzersEnabled = [Bool]()
	var buzzersDisabled = false
	var buzzerButtons = [NSButton]()
	let quizView = SpriteKitViewController(nibName: "SpriteKitViewController", bundle: nil)
	var quizWindow: NSWindow?
	
	
    override func windowDidLoad() {
        super.windowDidLoad()
		
		//Connect any output UI elements
		quizView.scoresScene.output = scoresOutput
		quizView.pointlessScene.textQuestion = pointlessTextQuestion
		quizView.pointlessScene.answerTable = pointlessTable
		
		//Connect to Node server
		print("Connect to Node server...")
		socket.delegate = self
		socket.connect()
		
		// Trim number of buttons down to match number of teams
		// We only handle 15 test buzzers up here
		let allBuzzerButtons : [NSButton] = [buzzerButton1, buzzerButton2, buzzerButton3, buzzerButton4, buzzerButton5, buzzerButton6, buzzerButton7, buzzerButton8, buzzerButton9, buzzerButton10, buzzerButton11, buzzerButton12, buzzerButton13, buzzerButton14, buzzerButton15]
		for i in 0..<Settings.shared.numTeams {
			if i < allBuzzerButtons.count {
				buzzerButtons.append(allBuzzerButtons[i])
				buzzerButtons[i].isEnabled = true
				buzzersEnabled.append(true)
			}
		}
		
		let allSkipButtons : [NSButton] = [skip1, skip2, skip3, skip4, skip5, skip6, skip7, skip8, skip9, skip10, skip11, skip12, skip13, skip14, skip15, skip16]
		for i in 0..<Settings.shared.numTeams {
			if i < allSkipButtons.count {
				skipButtons.append(allSkipButtons[i])
			}
		}
		
		quizView.webSocket = socket

		if quizWindow == nil {
			quizWindow = NSWindow(contentViewController: quizView)
			quizWindow?.title = "Quiz Main Display"
			quizWindow?.styleMask = [.titled, .resizable, .closable]
			quizWindow?.makeKeyAndOrderFront(self)
		}
		
        if (!windowedMode) {
			//Old exclusive fullscreen method
			quizView.view.addConstraint(NSLayoutConstraint(item: quizView.view, attribute: NSLayoutConstraint.Attribute.width,
								   relatedBy: NSLayoutConstraint.Relation.equal,toItem: nil,
								   attribute: NSLayoutConstraint.Attribute.notAnAttribute,
								   multiplier: 1, constant: quizScreen!.frame.width))
			quizView.view.addConstraint(NSLayoutConstraint(item: quizView.view, attribute: NSLayoutConstraint.Attribute.height,
								   relatedBy: NSLayoutConstraint.Relation.equal, toItem: nil,
								   attribute: NSLayoutConstraint.Attribute.notAnAttribute,
								   multiplier: 1, constant: quizScreen!.frame.height))
			quizView.view.enterFullScreenMode(quizScreen!, withOptions: [NSView.FullScreenModeOptionKey.fullScreenModeAllScreens: 0])
        }
		
		socketWriteIfConnected("vibuzzer")
        
        if Settings.shared.musicPath != "" {
            do {
				let files = try FileManager.default.contentsOfDirectory(atPath: Settings.shared.musicPath)
                for file in files.sorted() {
					if !file.hasPrefix(".") {
						if file.hasSuffix(".mp3") || file.hasSuffix(".wav") {
							musicFile.addItem(withTitle: file)
						}
						if file.hasSuffix(".mov") || file.hasSuffix(".mp4") || file.hasSuffix(".mpeg") || file.hasSuffix(".avi") {
							videoFile.addItem(withTitle: file)
						}
					}
                }
                musicChooseFile(musicFile)
            } catch {
                print("Error while enumerating files \(Settings.shared.musicPath): \(error.localizedDescription)")
            }
        }
		
		if Settings.shared.uniquePath != "" {
			do {
				let files = try FileManager.default.contentsOfDirectory(atPath: Settings.shared.uniquePath)
				for file in files.sorted() {
					if (!file.hasPrefix(".")) {
						uniqueFile.addItem(withTitle: file)
					}
				}
				uniqueChooseFile(uniqueFile)
			} catch {
				print("Error while enumerating files \(Settings.shared.uniquePath): \(error.localizedDescription)")
			}
		}
		
		if Settings.shared.pointlessPath != "" {
			do {
				let files = try FileManager.default.contentsOfDirectory(atPath: Settings.shared.pointlessPath)
				for file in files.sorted() {
					if (!file.hasPrefix(".")) {
						pointlessQuestionSelector.addItem(withTitle: file)
					}
				}
				pointlessQuestionSelected(pointlessQuestionSelector!)
			} catch {
				print("Error while enumerating files \(Settings.shared.pointlessPath): \(error.localizedDescription)")
			}
		}
		
		
		//We don't currently need the Test view
		tabView.removeTabViewItem(tabitemTest)
		
		//Default to Idle on load regardless of what we left it on in Interface Builder
		quizView.setRound(round: RoundType.idle)

        // Start periodic task to ask the server what clients are connected
        clientListTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(clientListTask), userInfo: nil, repeats: true)
    }
	
	func windowWillClose(_ notification: Notification) {
		clientListTimer?.invalidate()
		socket.ledsOff()
	}
	
	private var clientListTimer: Timer!
	
    @objc private func clientListTask() {
		//Periodically check to see what clients are connected. The reply will be "lr" and the handler will parse this to set the indicators
		socketWriteIfConnected("ls")
    }
	

	
	@IBAction func vitualBuzzersPress(_ sender: NSButton) {
		if virtualBuzzersBtn.state == .on {
			virtualBuzzersBtn.title = "Virtual Buzzers"
		} else {
			virtualBuzzersBtn.title = "Disable Buzzers"
		}
	}
    
    @IBAction func pressedNumber(_ sender: NSButton) {
        // Can either trigger virtual buzzers, or be toggles to enable and disable certain buzzers, based on virtualBuzzersBtn
		if virtualBuzzersBtn.state == .on {
            if (sender.state == NSControl.StateValue.on) {
				quizView.buzzerPressed(team: sender.tag, type: .test, buzzcocksMode: buzzcocksMode.state == .on, buzzerQueueMode: buzzerQueueMode.state == .on, quietMode: quieterBuzzes.state == .on, buzzerSounds: buzzerSounds.state == .on, blankVideo: blankVideo.state == .on)
				quizView.buzzerReleased(team: sender.tag, type: .websocket)
				sender.state = NSControl.StateValue.off
            }
        }
        else {
            if (sender.state == NSControl.StateValue.on) {
                buzzersEnabled[sender.tag] = false
				socketWriteIfConnected("of" + String(sender.tag + 1))
                quizView.buzzerReleased(team: sender.tag, type: .disabled)
            }
            else {
                buzzersEnabled[sender.tag] = true
				socketWriteIfConnected("on" + String(sender.tag + 1))
            }
        }
    }
    
    @IBAction func disableAllBuzzers(_ sender: NSButton) {
        if (sender.state == NSControl.StateValue.on) {
            buzzersDisabled = true
            for i in 0..<Settings.shared.numTeams {
                quizView.buzzerReleased(team: i, type: .disabled)
                buzzerButtons[i].isEnabled = false
				buzzersEnabled[i] = false
				socketWriteIfConnected("of" + String(i + 1))
            }
        }
        else {
            buzzersDisabled = false
			for i in 0..<Settings.shared.numTeams {
                buzzerButtons[i].isEnabled = true
				buzzerButtons[i].state = .off
				buzzersEnabled[i] = true
				socketWriteIfConnected("on" + String(i + 1))
            }
        }
    }
	
	@IBAction func disassociateTeamPress(_ sender: NSButtonCell) {
		socketWriteIfConnected("di\(sender.tag)")
	}

    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
		switch(tabViewItem!) {
		case tabitemIdle:
			socketWriteIfConnected("vibuzzer")
			quizView.setRound(round: RoundType.idle)
		case tabitemTest:
			socketWriteIfConnected("vibuzzer")
			quizView.setRound(round: RoundType.test)
		case tabitemBuzzers:
			socketWriteIfConnected("vibuzzer")
			quizView.setRound(round: RoundType.buzzers)
        case tabitemMusic:
            socketWriteIfConnected("vibuzzer")
            quizView.setRound(round: RoundType.music)
		case tabitemtruefalse:
			socketWriteIfConnected("vihigherlower")
			quizView.setRound(round: RoundType.trueFalse)
		case tabitemTimer:
			socketWriteIfConnected("vibuzzer")
			quizView.setRound(round: RoundType.timer)
		case tabitemGeography:
			socketWriteIfConnected("vigeo")
			socketWriteIfConnected("imstart.jpg")
			quizView.setRound(round: RoundType.geography)
		case tabitemNumbers:
			socketWriteIfConnected("vinumbers")
			quizView.setRound(round: RoundType.numbers)
			numbersActualAnswer.intValue = 0
			numbersAllowAnswers.state = .on
			numbersTeamGuesses.stringValue = ""
		case tabitemText:
			socketWriteIfConnected("vitext")
			quizView.setRound(round: RoundType.text)
			textStepper.intValue = 1
			textQuestionNumber.stringValue = "1"
			textTeamGuesses.stringValue = ""
			textAllowAnswers.state = .on
		case tabitemScores:
			socketWriteIfConnected("vibuzzer")
			quizView.setRound(round: RoundType.scores)
		case tabitemPointless:
			socketWriteIfConnected("vitext")
			quizView.setRound(round: RoundType.pointless)
		default:
			break
		}
    }
    
    @IBAction func resetRound(_ sender: AnyObject) {
		quizView.reset()

		if (tabView.selectedTabViewItem == tabitemGeography) {
			socketWriteIfConnected("vigeo")
			socketWriteIfConnected("imstart.jpg")
		} else if (tabView.selectedTabViewItem == tabitemText) {
			socketWriteIfConnected("vitext")
			textStepper.intValue = 1
			textQuestionNumber.stringValue = "1"
			textTeamGuesses.stringValue = ""
			textAllowAnswers.state = .on
		} else if (tabView.selectedTabViewItem == tabitemNumbers) {
			socketWriteIfConnected("vinumbers")
			quizView.setRound(round: RoundType.numbers)
			numbersActualAnswer.intValue = 0
			numbersAllowAnswers.state = .on
			numbersTeamGuesses.stringValue = ""
		} else if (tabView.selectedTabViewItem == tabitemtruefalse) {
			socketWriteIfConnected("ha")
		}
    }
	
	//--------------------------------------------------------------------------------------------------------------------------
	//MARK: - Websockets
	//--------------------------------------------------------------------------------------------------------------------------
	
	var socket = WebSocket(request: URLRequest(url: URL(string: "ws://localhost:8091/")!))
	var socketIsConnected = false
						   
	func socketWriteIfConnected(_ s : String) {
		if socketIsConnected {
			socket.write(string: s)
		}
	}
	
	public func websocketDidReceiveMessage(text: String) {
		if(text.count >= 2) {
			switch(String(text.prefix(2))) {
			case "co":
				break;
			case "zz":
				//A team has buzzed
				if let idx = Int(String(text[text.index(text.startIndex, offsetBy: 2)...])) {
					let team = idx - 1 // Make zero-indexed
					if (!buzzersDisabled && team < Settings.shared.numTeams && buzzersEnabled[team]) {
						quizView.buzzerPressed(team: team, type: .websocket, buzzcocksMode: buzzcocksMode.state == .on, buzzerQueueMode: buzzerQueueMode.state == .on, quietMode: quieterBuzzes.state == .on, buzzerSounds: buzzerSounds.state == .on, blankVideo: blankVideo.state == .on)
						DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
							self.quizView.buzzerReleased(team: team, type: .websocket)
						}
					}
				}
			case "lr":
				//Recived a list of connected clients
				let trm = text.dropFirst(2) //Drop the "lr"
				let teamnumbers = trm.split(separator: ",").compactMap { Int($0) }
				
				let allStats = [st1, st2, st3, st4, st5, st6, st7, st8, st9, st10, st11, st12, st13, st14, st15]
				for i in 0..<allStats.count {
					let box = allStats[i]!
					box.fillColor = teamnumbers.contains(i+1) ? NSColor.green : NSColor.black
				}
			case "ii":
				//A team has answered in the Geography round
				let details = text.suffix(text.count - 2)
				let vals = details.components(separatedBy: ",")
				if(vals.count >= 3) {
					if let team = Int(vals[0]), let x = Int(vals[1]), let y = Int(vals[2]) {
						quizView.geographyScene.teamAnswered(team: team - 1, x: x, y: y, skips: skipButtons) //make zero indexed
					}
				} else {
					print("Invalid Geography guess")
				}
			case "hi":
				//A team has voted "true or higher"
				if let idx = Int(String(text[text.index(text.startIndex, offsetBy: 2)...])) {
					let team = idx - 1 // Make zero-indexed
					if (!buzzersDisabled && team < Settings.shared.numTeams) {
						quizView.truefalseScene.teamGuess(teamid: team, guess: true)
						
						if quizView.truefalseScene.counting {
							socketWriteIfConnected("hh" + String(team+1))
						}
					}
				}
			case "lo":
				//A team has voted "false or lower"
				if let idx = Int(String(text[text.index(text.startIndex, offsetBy: 2)...])) {
					let team = idx - 1 // Make zero-indexed
					if (!buzzersDisabled && team < Settings.shared.numTeams) {
						quizView.truefalseScene.teamGuess(teamid: team, guess: false)
						
						if quizView.truefalseScene.counting {
							socketWriteIfConnected("hl" + String(team+1))
						}
					}
				}
			case "tt":
				
				//A team has guessed a textual answer. Parse it and route to appropriate scene
				if (
					(tabView.selectedTabViewItem == tabitemText && textAllowAnswers.state == .on) ||
					(tabView.selectedTabViewItem == tabitemNumbers && numbersAllowAnswers.state == .on) ||
					(tabView.selectedTabViewItem == tabitemPointless && pointlessAllowAnswers.state == .on) ) {
					
					let details = text.suffix(text.count - 2)
					let vals = details.components(separatedBy: ",")
					if(vals.count >= 2) {
						if let team = Int(vals[0]) {
							let guessText = String(vals[1].prefix(20)) //TODO Max size of 20 is too low?
							
							//Now route the logic according to the current round
							switch tabView.selectedTabViewItem {
							case tabitemText:
								// Update the guesses in the controller window
								textTeamGuesses.stringValue = (0..<Settings.shared.numTeams).compactMap { team -> String? in
									if let tg = quizView.textScene.teamGuesses[team] {
										return "Team \(team + 1): \(tg.guess) (\(tg.roundid))"
									}
									return nil
								}.joined(separator: "\n")
								
								quizView.textScene.teamGuess(
									teamid: team - 1, //make zero indexed
									guess: guessText,
									roundid: Int(textQuestionNumber.intValue),
									showroundno: (textShowQuestionNumbers.state == .on) ? true : false
								)
								
							case tabitemNumbers:
								let guess = Int(guessText)
								if guess != nil {
									quizView.numbersScene.teamGuess(teamid: team - 1, guess: guess!)
								}
								
								// Update the guesses in the controller window
								numbersTeamGuesses.stringValue = (0..<Settings.shared.numTeams).compactMap { team -> String? in
									if let tg = quizView.numbersScene.teamGuesses[team] {
										return "Team \(team + 1): \(tg)"
									}
									return nil
								}.joined(separator: "\n")
								
							case tabitemPointless:
								quizView.pointlessScene.teamGuess(team: team-1, guess: guessText)
								
							default:
								break
							}
						} else {
							print("Invalid Text guess: Bad Int conversion")
						}
					} else {
						print("Invalid Text guess: Bad comma separation")
					}
				}
			default:
				print("Unknown message: " + text)
			}
		}
	}
	
	func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
		switch event {
		case .connected(let headers):
			socketIsConnected = true
			print("websocket is connected: \(headers)")
		case .disconnected(let reason, let code):
			socketIsConnected = false
			print("websocket is disconnected: \(reason) with code: \(code)")
			DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
				self.socket.connect()
			}
		case .text(let string):
			websocketDidReceiveMessage(text: string)
		case .binary(let data):
			print("Received binary data: \(data.count)")
		case .ping(_):
			break
		case .pong(_):
			break
		case .viabilityChanged(_):
			break
		case .reconnectSuggested(_):
			break
		case .cancelled:
			socketIsConnected = false
		case .error(let error):
			socketIsConnected = false
			if let e = error as? WSError {
				print("websocket encountered an error: \(e.message)")
			} else if let e = error {
				print("websocket encountered an error: \(e.localizedDescription)")
			} else {
				print("websocket encountered an error")
			}
		case .peerClosed:
			break
		}
	}
	
	
	
	//--------------------------------------------------------------------------------------------------------------------------
	//MARK: - Round-specific controls and actions
	//--------------------------------------------------------------------------------------------------------------------------
	
	//MARK: - Buzzer
	//--------------------------------------------------------------------------------------------------------------------------
	
	@IBOutlet weak var buzzerSounds: NSButton!
	@IBOutlet weak var quieterBuzzes: NSButton!
	@IBOutlet weak var buzzerTimerTime: NSTextField!

	@IBAction func buzzersNextTeam(_ sender: AnyObject) {
		quizView.buzzerScene.nextTeam()
	}
	
	@IBAction func startBuzzerTimer(_ sender: Any) {
		if let secs = Int(buzzerTimerTime.stringValue) {
			quizView.buzzerScene.startTimer(secs)
		}
	}
	
	@IBAction func stopBuzzerTimer(_ sender: Any) {
		quizView.buzzerScene.stopTimer()
	}
	
	
	//MARK: - Music/Video
	//--------------------------------------------------------------------------------------------------------------------------
	
	@IBOutlet weak var buzzcocksMode: NSButton!
	@IBOutlet weak var buzzerQueueMode: NSButton!
	@IBOutlet weak var blankVideo: NSButton!
	@IBOutlet weak var musicFile: NSPopUpButton!
	@IBOutlet weak var videoFile: NSPopUpButton!
	
	
	@IBAction func musicNextTeam(_ sender: AnyObject) {
		quizView.musicScene.nextTeam()
	}
	
	@IBAction func musicPlay(_ sender: AnyObject) {
		quizView.musicScene.resumeMusic()
	}
	
	@IBAction func musicPause(_ sender: AnyObject) {
		quizView.musicScene.pauseMusic()
	}
	
	@IBAction func musicStop(_ sender: AnyObject) {
		quizView.musicScene.stopMusic()
	}

	@IBAction func musicChooseFile(_ sender: NSPopUpButton) {
		if Settings.shared.musicPath != "" {
			if let fileName = sender.selectedItem?.title {
				let path =  Settings.shared.musicPath + "/" + fileName
				quizView.musicScene.initMusic(file: path)
			}
		}
		else {
			print("Error choosing music file")
		}
	}
	
	@IBAction func playVideo(_ sender: Any) {
		quizView.musicScene.resumeVideo()
	}
	
	@IBAction func prepareVideo(_ sender: NSPopUpButton) {
		if Settings.shared.musicPath != "" {
			if let fileName = sender.selectedItem?.title {
				let path = Settings.shared.musicPath + "/" + fileName
				quizView.musicScene.prepareVideo(file: path)
			}
			else {
				print("Error choosing video file")
			}
		}
	}
	
	
	//MARK: - Timer
	//--------------------------------------------------------------------------------------------------------------------------
	
	@IBOutlet weak var timerShowCounter: NSButton!
	
	@IBAction func startTimer(_ sender: AnyObject) {
		quizView.timerScene.startTimer(music: false)
	}
	
	@IBAction func stopTimer(_ sender: AnyObject) {
		quizView.timerScene.stopTimer()
	}
	
	@IBAction func timerIncrement(_ sender: AnyObject) {
		quizView.timerScene.timerIncrement()
	}
	
	@IBAction func timerDecrement(_ sender: AnyObject) {
		quizView.timerScene.timerDecrement()
	}
	
	@IBAction func timerStartWithMusic(_ sender: Any) {
		quizView.timerScene.startTimer(music: true)
	}
	
	@IBAction func timerShowCounterChange(_ sender: NSButton) {
		quizView.timerScene.showCounter(timerShowCounter.state == .on)
	}
	
	
	//MARK: - Text and numbers
	//--------------------------------------------------------------------------------------------------------------------------
	
	@IBOutlet var textAllowAnswers: NSButton!
	@IBOutlet var textShowQuestionNumbers: NSButton!
	@IBOutlet var textQuestionNumber: NSTextField!
	@IBOutlet var textStepper: NSStepper!
	@IBOutlet var textTeamGuesses: NSTextField!
	@IBOutlet weak var uniqueFile: NSPopUpButton!
	
	@IBAction func textStepperChange(_ sender: Any) {
		textQuestionNumber.stringValue = textStepper.stringValue
	}
	@IBAction func textShowGuesses(_ sender: Any) {
		textAllowAnswers.state = .off
		quizView.textScene.showGuesses(showroundno: (textShowQuestionNumbers.state == .on) ? true : false)
	}
	
	@IBAction func textScoreUnique(_ sender: Any) {
		quizView.textScene.scoreUnique()
	}

	@IBAction func uniqueChooseFile(_ sender: NSPopUpButton) {
		if Settings.shared.uniquePath != "" {
			if let fileName = sender.selectedItem?.title {
				let path = Settings.shared.uniquePath + "/" + fileName
				quizView.textScene.initUnique(file: path)
			}
			else {
				print("Error choosing unique list")
			}
		}
	}
	
	@IBOutlet weak var numbersAllowAnswers: NSButton!
	@IBOutlet weak var numbersActualAnswer: NSTextField!
	@IBOutlet var numbersTeamGuesses: NSTextField!
	
	@IBAction func numbersShowAnswers(_ sender: NSButton) {
		numbersAllowAnswers.state = .off
		quizView.numbersScene.showGuesses(actualAnswer: Int(numbersActualAnswer!.intValue))
	}
	
	
	//MARK: - Scores
	//--------------------------------------------------------------------------------------------------------------------------
	
	@IBOutlet var scoresOutput: NSTextField!
	@IBOutlet var scoresText: NSTextView!
	
	@IBAction func scoresInitText(_ sender: Any) {
		var s = ""
		for x in 1...Settings.shared.numTeams {
			s = s + "\(x),\n"
		}
		scoresText.string = s
	}
	
	@IBAction func scoresParseAndReset(_ sender: Any) {
		quizView.scoresScene.parseAndReset(scoreText: scoresText.string)
	}
	
	@IBAction func scoresShowNext(_ sender: Any) {
		quizView.scoresScene.next()
	}
	

	//MARK: - True/False
	//--------------------------------------------------------------------------------------------------------------------------
	
	@IBOutlet weak var trueButton: NSButton!
	@IBOutlet weak var falseButton: NSButton!
	@IBOutlet weak var trueFalseToggle: NSButton!
	@IBOutlet weak var truefalseSounds: NSButton!

	@IBAction func trueFalseStart(_ sender: NSButton) {
		quizView.truefalseScene.start(sounds: truefalseSounds.state == .on)
	}
	
	@IBAction func trueFalseStartNoTimer(_ sender: NSButton) {
		quizView.truefalseScene.startNoTimer(sounds: truefalseSounds.state == .on)
	}
	
	@IBAction func trueFalseTrue(_ sender: NSButton) {
		quizView.truefalseScene.showAnswer(ans: true)
	}
	
	@IBAction func trueFalseFalse(_ sender: NSButton) {
		quizView.truefalseScene.showAnswer(ans: false)
	}
	
	@IBAction func trueFalseToggled(_ sender: Any) {
		if trueFalseToggle.state == .on {
			trueButton.title = "True"
			falseButton.title = "False"
			trueFalseToggle.title = "True/False Mode"
			socketWriteIfConnected("h2")
		} else {
			trueButton.title = "Higher"
			falseButton.title = "Lower"
			trueFalseToggle.title = "Higher/Lower Mode"
			socketWriteIfConnected("h1")
		}
		quizView.truefalseScene.setMode(self.trueFalseToggle.state == .on)
	}
	
	//MARK: - Test
	//--------------------------------------------------------------------------------------------------------------------------
	

	
	//MARK: - Geography
	//--------------------------------------------------------------------------------------------------------------------------
	
	@IBOutlet var skip1: NSButton!
	@IBOutlet var skip2: NSButton!
	@IBOutlet var skip3: NSButton!
	@IBOutlet var skip4: NSButton!
	@IBOutlet var skip5: NSButton!
	@IBOutlet var skip6: NSButton!
	@IBOutlet var skip7: NSButton!
	@IBOutlet var skip8: NSButton!
	@IBOutlet var skip9: NSButton!
	@IBOutlet var skip10: NSButton!
	@IBOutlet var skip11: NSButton!
	@IBOutlet var skip12: NSButton!
	@IBOutlet var skip13: NSButton!
	@IBOutlet var skip14: NSButton!
	@IBOutlet var skip15: NSButton!
	@IBOutlet var skip16: NSButton!
	var skipButtons = [NSButton]()
	
	@IBOutlet var geoAnswerX: NSTextField!
	@IBOutlet var geoAnswerY: NSTextField!
	@IBOutlet var geoQuestionNumber: NSTextField!
	@IBOutlet var geoStepper: NSStepper!
	
	@IBAction func geoStepperChange(_ sender: Any) {
		geoQuestionNumber.stringValue = geoStepper.stringValue
	}
	
	@IBAction func geoStartQuestion(_ sender: Any) {
		quizView.reset()
		socketWriteIfConnected("vigeo")
		socketWriteIfConnected("imgeo" + geoStepper.stringValue + ".jpg")
		quizView.geographyScene.setQuestion(question: Int(geoStepper.intValue))
	}
	
	@IBAction func geoShowWinner(_ sender: Any) {
		quizView.geographyScene.showWinner(answerx: Int(geoAnswerX.intValue), answery: Int(geoAnswerY.intValue))
	}
	
	
	//MARK: - Pointless
	//--------------------------------------------------------------------------------------------------------------------------
	@IBOutlet weak var pointlessQuestionSelector: NSPopUpButton!
	@IBOutlet weak var pointlessTextQuestion: NSTextField!
	@IBOutlet weak var pointlessTextAnswers: NSTextField!
	@IBOutlet weak var pointlessAllowAnswers: NSButton!
	@IBOutlet var pointlessTable: NSTableView!
	
	@IBAction func pointlessShowAnswers(_ sender: Any) {
		quizView.pointlessScene.showAnswers()
	}

	@IBAction func pointlessRunScoring(_ sender: Any) {
		quizView.pointlessScene.runScoring()
	}
	
	@IBAction func pointlessQuestionSelected(_ sender: Any) {
		if Settings.shared.pointlessPath != "" {
			if let title = pointlessQuestionSelector.selectedItem?.title {
				let path = Settings.shared.pointlessPath + "/" + title
				quizView.pointlessScene.changeToQuestion(path: path)
			}
		}
	}

	@IBAction func pointlessTest(_ sender: Any) {
		quizView.pointlessScene.debugTest()
	}
	
	@IBAction func pointlessTableChange(_ sender: Any) {
	}
	
}

