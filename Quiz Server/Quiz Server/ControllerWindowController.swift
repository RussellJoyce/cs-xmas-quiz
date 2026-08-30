//
//  ControllerWindowController.swift
//  Quiz Server
//
//  Created by Russell Joyce on 18/11/2014.
//  Copyright (c) 2014 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa

class ControllerWindowController: NSWindowController, NSWindowDelegate, NSTabViewDelegate, NSTableViewDataSource, NSTableViewDelegate, QuizWebSocketDelegate {
    
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
	
	@IBOutlet weak var tabView: NSTabView!
	@IBOutlet weak var tabitemtruefalse: NSTabViewItem!
	@IBOutlet weak var tabitemTimer: NSTabViewItem!
	@IBOutlet weak var tabitemIdle: NSTabViewItem!
	@IBOutlet weak var tabitemTest: NSTabViewItem!
	@IBOutlet weak var tabitemBuzzers: NSTabViewItem!
	@IBOutlet weak var tabitemMusic: NSTabViewItem!
	@IBOutlet weak var tabitemGeography: NSTabViewItem!
	@IBOutlet weak var tabitemText: NSTabViewItem!
	@IBOutlet weak var tabitemNumbers: NSTabViewItem!
	@IBOutlet weak var tabitemScores: NSTabViewItem!
	@IBOutlet weak var tabitemPointless: NSTabViewItem!
	@IBOutlet weak var tabitemWavelength: NSTabViewItem!
	@IBOutlet weak var tabitemMultiChoice: NSTabViewItem!
	@IBOutlet weak var tabitemDisconnect: NSTabViewItem!
	
	//MARK: - General
	//--------------------------------------------------------------------------------------------------------------------------
	/// The single controller window, shown by `StartupView` once the settings are chosen.
	/// Loading its nib reads the launch configuration out of `Settings.shared`.
	static let shared = ControllerWindowController(windowNibName: "ControllerWindow")

	var buzzersEnabled = [Bool]()
	var buzzersDisabled = false
	var buzzerButtons = [NSButton]()
	let quizDisplay = QuizDisplayController()
	
	
    override func windowDidLoad() {
        super.windowDidLoad()

		//Connect any output UI elements
		quizDisplay.scoresScene.output = scoresOutput

		if let scrollView = pointlessQuestion, let textView = scrollView.documentView as? NSTextView {
			quizDisplay.pointlessScene.textQuestion = textView
		} else {
			print("Warning: Could not set PointlessScene's textQuestion (not found or not NSTextView)")
		}
		
		quizDisplay.pointlessScene.answerTable = pointlessTable
		quizDisplay.pointlessScene.descending = pointlessDescending
		quizDisplay.musicScene.useLEDs = musicUseLEDs
		
		//Connect to Node server
		print("Connect to Node server...")
		window?.title = "Quiz Control - NOT CONNECTED"
		QuizWebSocket.shared = socket
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
		
		quizDisplay.present()
        
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
		
		configureSidebar()

		//Default to Idle on load regardless of what we left it on in Interface Builder
		startRound(.idle)

        // Start periodic task to ask the server what clients are connected
        clientListTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(clientListTask), userInfo: nil, repeats: true)
    }
	
	func windowWillClose(_ notification: Notification) {
		clientListTimer?.invalidate()
		wavelengthRollTimer?.invalidate()
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
			//If we were disabled (which is not actually .disabled because then we couldn't press it)
			if buzzersEnabled[sender.tag] == false {
				//Leave it disabled
				sender.state = .on
			} else {
				//Otherwise fire a virtual buzzer press
				if (sender.state == NSControl.StateValue.on) {
					quizDisplay.buzzerPressed(team: sender.tag, type: .test, options: buzzerOptions)
					sender.state = NSControl.StateValue.off
				}
			}
        }
        else {
			//Enabling or disabling the client
            if (sender.state == NSControl.StateValue.on) {
                buzzersEnabled[sender.tag] = false
				socketWriteIfConnected("of" + String(sender.tag + 1))
            }
            else {
                buzzersEnabled[sender.tag] = true
				socketWriteIfConnected("on" + String(sender.tag + 1))
            }
			pushTeamParticipation()
        }
    }
    
    @IBAction func disableAllBuzzers(_ sender: NSButton) {
        if (sender.state == NSControl.StateValue.on) {
            buzzersDisabled = true
            for i in 0..<Settings.shared.numTeams {
				if i < buzzerButtons.count {
					buzzerButtons[i].isEnabled = false
					buzzersEnabled[i] = false
					socketWriteIfConnected("of" + String(i + 1))
				}
            }
        }
        else {
            buzzersDisabled = false
			for i in 0..<Settings.shared.numTeams {
				if i < buzzerButtons.count {
					buzzerButtons[i].isEnabled = true
					buzzerButtons[i].state = .off
					buzzersEnabled[i] = true
					socketWriteIfConnected("on" + String(i + 1))
				}
            }
        }
		pushTeamParticipation()
    }
	
	/// Which teams are playing, by zero-based team number
	var enabledTeams: [Bool] {
		(0..<Settings.shared.numTeams).map { isTeamEnabled($0) }
	}

	func isTeamEnabled(_ team: Int) -> Bool {
		guard !buzzersDisabled, team >= 0, team < Settings.shared.numTeams else { return false }
		return team < buzzersEnabled.count ? buzzersEnabled[team] : true
	}

	/// Tells the live round who is playing. Called whenever the enable buttons change and whenever a round starts
	private func pushTeamParticipation() {
		quizDisplay.setParticipating(enabledTeams)
	}

	@IBAction func disassociateTeamPress(_ sender: NSButtonCell) {
		socketWriteIfConnected("di\(sender.tag)")
	}

	@IBOutlet weak var disconnectAllButton: NSButton!

	/// Set when "Disconnect All" is armed, so a second click within the timeout actually does it
	private var disconnectAllConfirmTimer: Timer?

	@IBAction func disconnectAllPress(_ sender: NSButton) {
		if disconnectAllConfirmTimer != nil {
			resetDisconnectAllButton()
			for team in 1...Settings.shared.numTeams {
				socketWriteIfConnected("di\(team)")
			}
			return
		}

		//First click just arms the button. It disarms itself if the second click doesn't come.
		sender.title = "Sure?"
		disconnectAllConfirmTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
			self?.resetDisconnectAllButton()
		}
	}

	private func resetDisconnectAllButton() {
		disconnectAllConfirmTimer?.invalidate()
		disconnectAllConfirmTimer = nil
		disconnectAllButton?.title = "Disconnect All"
	}

	/// Puts the teams' phones into the view that goes with the current round.
	private func pushClientView() {
		socketWriteIfConnected("vi" + quizDisplay.currentRound.clientView)
	}

	/// Moves the main display and the teams' phones to `round` together.
	private func startRound(_ round: RoundType) {
		socketWriteIfConnected("vi" + round.clientView)
		quizDisplay.setRound(round: round)
	}

    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
		guard let tabViewItem = tabViewItem else { return }
		switch(tabViewItem) {
		case tabitemIdle:
			startRound(.idle)
		case tabitemTest:
			startRound(.test)
		case tabitemBuzzers:
			startRound(.buzzers)
		case tabitemMusic:
			startRound(.music)
		case tabitemtruefalse:
			startRound(.trueFalse)
		case tabitemTimer:
			startRound(.timer)
		case tabitemGeography:
			startRound(.geography)
			socketWriteIfConnected("imstart.jpg")
		case tabitemNumbers:
			startRound(.numbers)
			resetNumbersControls()
		case tabitemText:
			startRound(.text)
			resetTextControls()
		case tabitemScores:
			startRound(.scores)
		case tabitemPointless:
			startRound(.pointless)
		case tabitemWavelength:
			startRound(.wavelength)
			resetWavelengthControls()
		case tabitemMultiChoice:
			startRound(.multichoice)
			resetMultiChoiceControls()
		default:
			break
		}
		//Whichever round we have just moved to needs to know who is playing
		pushTeamParticipation()
		
		//Keeps the highlight correct if something other than a click moved us
		selectSidebarRow(for: tabViewItem)
    }
    
    @IBAction func resetRound(_ sender: AnyObject) {
		quizDisplay.reset()
		pushTeamParticipation()
		pushClientView()
		
		switch quizDisplay.currentRound {
		case .geography:
			socketWriteIfConnected("imstart.jpg")
		case .text:
			resetTextControls()
		case .numbers:
			resetNumbersControls()
		case .wavelength:
			resetWavelengthControls()
		case .multichoice:
			resetMultiChoiceControls()
		default:
			break
		}
    }
	
	//--------------------------------------------------------------------------------------------------------------------------
	//MARK: - Sidebar
	//--------------------------------------------------------------------------------------------------------------------------

	private enum SidebarRow {
		case group(String)
		case round(NSTabViewItem, String)
	}

	private var sidebarRows = [SidebarRow]()

	@IBOutlet weak var sidebarTable: NSTableView!

	private func buildSidebarRows() {
		sidebarRows = [
			.group("Show"),
			.round(tabitemIdle, "🎄 Idle"),
			.round(tabitemScores, "📋 Scores"),
			
			.group("Rounds"),
			.round(tabitemBuzzers, "🔊 Buzzers"),
			.round(tabitemMusic, "🎶 Music + Video"),
			.round(tabitemtruefalse, "✅ True / False"),
			.round(tabitemMultiChoice, "🎲 Multiple Choice"),
			.round(tabitemGeography, "🌍 Geography"),
			.round(tabitemText, "✍️ Text"),
			.round(tabitemNumbers, "🔢 Numbers"),
			.round(tabitemWavelength, "🌊 Wavelength"),
			.round(tabitemPointless, "0️⃣ Pointless"),
			.round(tabitemTimer, "🕓 Timer"),

			.group("Admin"),
			.round(tabitemTest, "🧪 Test Screen"),
			.round(tabitemDisconnect, "❌ Disconnect")
		]
	}

	private func configureSidebar() {
		buildSidebarRows()
		sidebarTable.style = .sourceList
		sidebarTable.reloadData()
		selectSidebarRow(for: tabitemIdle)
		sidebarTable.scrollRowToVisible(0)
	}

	/// Moves the sidebar's highlight to whichever row stands for `item`
	private func selectSidebarRow(for item: NSTabViewItem?) {
		guard let item = item, let table = sidebarTable else {
			return
		}
		let index = sidebarRows.firstIndex { row in
			if case .round(let candidate, _) = row {
				return candidate === item
			}
			return false
		}
		if let index = index, table.selectedRow != index {
			table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
			table.scrollRowToVisible(index)
		}
	}

	func numberOfRows(in tableView: NSTableView) -> Int {
		return sidebarRows.count
	}

	func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
		if case .group = sidebarRows[row] {
			return true
		}
		return false
	}

	func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
		return !self.tableView(tableView, isGroupRow: row)
	}

	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		let title: String
		let identifier: String
		switch sidebarRows[row] {
		case .group(let name):
			title = name
			identifier = "SidebarGroupCell"
		case .round(_, let name):
			title = name
			identifier = "SidebarRoundCell"
		}

		let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(identifier), owner: self) as? NSTableCellView
		cell?.textField?.stringValue = title
		return cell
	}

	func tableViewSelectionDidChange(_ notification: Notification) {
		guard let table = sidebarTable, table.selectedRow >= 0 else {
			return
		}
		if case .round(let item, _) = sidebarRows[table.selectedRow] {
			//Selecting the item is all this does. Everything that happens on a round change
			//still happens in tabView(_:didSelect:)
			tabView.selectTabViewItem(item)
		}
	}

	//MARK: - Websockets
	//--------------------------------------------------------------------------------------------------------------------------
	
	var socket = QuizWebSocket(url: URL(string: "ws://localhost:8091/")!)

	func socketWriteIfConnected(_ s : String) {
		socket.send(s)
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
					if isTeamEnabled(team) {
						quizDisplay.buzzerPressed(team: team, type: .websocket, options: buzzerOptions)
					}
				}
			case "lr":
				//Recived a list of connected clients
				let trm = text.dropFirst(2) //Drop the "lr"
				let teamnumbers = trm.split(separator: ",").compactMap { Int($0) }
				
				let allStats = [st1, st2, st3, st4, st5, st6, st7, st8, st9, st10, st11, st12, st13, st14, st15]
				for i in 0..<allStats.count {
					if let box = allStats[i] {
						box.fillColor = teamnumbers.contains(i+1) ? NSColor.green : NSColor.black
					}
				}
			case "ii":
				//A team has answered in the Geography round
				let details = text.suffix(text.count - 2)
				let vals = details.components(separatedBy: ",")
				if(vals.count >= 3) {
					if let team = Int(vals[0]), let x = Int(vals[1]), let y = Int(vals[2]),
					   isTeamEnabled(team - 1) { //make zero indexed
						quizDisplay.geographyScene.teamAnswered(team: team - 1, x: x, y: y)
					}
				} else {
					print("Invalid Geography guess")
				}
			case "wv":
				//A team has moved their slider in the Wavelength round
				let details = text.suffix(text.count - 2)
				let vals = details.components(separatedBy: ",")
				if vals.count >= 2, let team = Int(vals[0]), let value = Int(vals[1]),
				   isTeamEnabled(team - 1) { //make zero indexed
					quizDisplay.wavelengthScene.teamGuess(team: team - 1, value: value)
					updateWavelengthGuesses()
				} else {
					print("Invalid Wavelength guess")
				}
			case "hi":
				//A team has voted "true or higher"
				if let idx = Int(String(text[text.index(text.startIndex, offsetBy: 2)...])) {
					let team = idx - 1 // Make zero-indexed
					if isTeamEnabled(team) {
						quizDisplay.truefalseScene.teamGuess(teamid: team, guess: true)
						
						if quizDisplay.truefalseScene.counting {
							socketWriteIfConnected("hh" + String(team+1))
						}
					}
				}
			case "lo":
				//A team has voted "false or lower"
				if let idx = Int(String(text[text.index(text.startIndex, offsetBy: 2)...])) {
					let team = idx - 1 // Make zero-indexed
					if isTeamEnabled(team) {
						quizDisplay.truefalseScene.teamGuess(teamid: team, guess: false)
						
						if quizDisplay.truefalseScene.counting {
							socketWriteIfConnected("hl" + String(team+1))
						}
					}
				}
			case "mc":
				//A team has picked one of the multiple choice options
				let details = text.suffix(text.count - 2)
				let vals = details.components(separatedBy: ",")
				if vals.count >= 2, let team = Int(vals[0]), let option = Int(vals[1]) {
					if isTeamEnabled(team - 1) && quizDisplay.multiChoiceScene.counting {
						quizDisplay.multiChoiceScene.teamGuess(teamid: team - 1, option: option) //make zero indexed
						if let taken = quizDisplay.multiChoiceScene.teamGuesses[team - 1] {
							//If the round rejected it we wont light the tile on the client
							socketWriteIfConnected("ms\(team),\(taken)")
						}
						updateMultiChoiceGuesses()
					}
				} else {
					print("Invalid multiple choice answer")
				}
			case "tt":
				
				//A team has guessed a textual answer. Parse it and route to appropriate scene
				if (
					(quizDisplay.currentRound == .text && textAllowAnswers.state == .on) ||
					(quizDisplay.currentRound == .numbers && numbersAllowAnswers.state == .on) ||
					(quizDisplay.currentRound == .pointless && pointlessAllowAnswers.state == .on) ) {
					
					let details = text.suffix(text.count - 2)
					let vals = details.components(separatedBy: ",")
					if(vals.count >= 2) {
						if let team = Int(vals[0]) {
							//Ignore teams the host has disabled
							guard isTeamEnabled(team - 1) else { //make zero indexed
								break
							}

							let guessText = String(vals[1].prefix(20)) //TODO Max size of 20 is too low?
							
							//Now route the logic according to the current round
							switch quizDisplay.currentRound {
							case .text:
								quizDisplay.textScene.teamGuess(
									teamid: team - 1, //make zero indexed
									guess: guessText,
									roundid: Int(textQuestionNumber.intValue),
									showroundno: (textShowQuestionNumbers.state == .on) ? true : false
								)
								
								// Update the guesses in the controller window
								textTeamGuesses.stringValue = (0..<Settings.shared.numTeams).compactMap { team -> String? in
									if let tg = quizDisplay.textScene.teamGuesses[team] {
										return "Team \(team + 1): \(tg.guess) (\(tg.roundid))"
									}
									return nil
								}.joined(separator: "\n")
							case .numbers:
								let guess = Int(guessText)
								if guess != nil {
									quizDisplay.numbersScene.teamGuess(teamid: team - 1, guess: guess!)
								}
								
								// Update the guesses in the controller window
								numbersTeamGuesses.stringValue = (0..<Settings.shared.numTeams).compactMap { team -> String? in
									if let tg = quizDisplay.numbersScene.teamGuesses[team] {
										return "Team \(team + 1): \(tg)"
									}
									return nil
								}.joined(separator: "\n")
								
							case .pointless:
								quizDisplay.pointlessScene.teamGuess(team: team-1, guess: guessText)
								
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
	
	func webSocketDidConnect() {
		window?.title = "Quiz Control - connected"
		// Very first time we connect, activate Megamas
		if !Settings.shared.websocketHasPreviouslyConnected {
			socket.megamas()
			Settings.shared.websocketHasPreviouslyConnected = true
		}
	}

	func webSocketDidDisconnect() {
		window?.title = "Quiz Control - NOT CONNECTED"
	}

	func webSocketDidReceiveMessage(_ text: String) {
		websocketDidReceiveMessage(text: text)
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
		quizDisplay.buzzerScene.nextTeam()
	}
	
	@IBAction func startBuzzerTimer(_ sender: Any) {
		if let secs = Int(buzzerTimerTime.stringValue) {
			quizDisplay.buzzerScene.startTimer(secs)
		}
	}
	
	@IBAction func stopBuzzerTimer(_ sender: Any) {
		quizDisplay.buzzerScene.stopTimer()
	}
	
	
	//MARK: - Music/Video
	//--------------------------------------------------------------------------------------------------------------------------
	
	@IBOutlet weak var buzzcocksMode: NSButton!
	@IBOutlet weak var buzzerQueueMode: NSButton!
	@IBOutlet weak var blankVideo: NSButton!

	/// The current state of the buzzer toggles, gathered for whichever round is live.
	private var buzzerOptions: BuzzerOptions {
		BuzzerOptions(buzzcocksMode: buzzcocksMode.state == .on,
					  buzzerQueueMode: buzzerQueueMode.state == .on,
					  quietMode: quieterBuzzes.state == .on,
					  buzzerSounds: buzzerSounds.state == .on,
					  blankVideo: blankVideo.state == .on)
	}
	@IBOutlet weak var musicFile: NSPopUpButton!
	@IBOutlet weak var videoFile: NSPopUpButton!
	@IBOutlet weak var musicUseLEDs: NSButton!
	
	@IBAction func musicNextTeam(_ sender: AnyObject) {
		quizDisplay.musicScene.nextTeam()
	}
	
	@IBAction func musicPlay(_ sender: AnyObject) {
		quizDisplay.musicScene.resumeMusic()
	}
	
	@IBAction func musicPause(_ sender: AnyObject) {
		quizDisplay.musicScene.pauseMusic()
	}
	
	@IBAction func musicStop(_ sender: AnyObject) {
		quizDisplay.musicScene.stopMusic()
	}

	@IBAction func musicChooseFile(_ sender: NSPopUpButton) {
		if Settings.shared.musicPath != "" {
			if let fileName = sender.selectedItem?.title {
				let path =  Settings.shared.musicPath + "/" + fileName
				quizDisplay.musicScene.initMusic(file: path)
			}
		}
		else {
			print("Error choosing music file")
		}
	}
	
	@IBAction func playVideo(_ sender: Any) {
		quizDisplay.musicScene.resumeVideo()
	}
	
	@IBAction func prepareVideo(_ sender: NSPopUpButton) {
		if Settings.shared.musicPath != "" {
			if let fileName = sender.selectedItem?.title {
				let path = Settings.shared.musicPath + "/" + fileName
				quizDisplay.musicScene.prepareVideo(file: path)
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
		quizDisplay.timerScene.startTimer(music: false)
	}
	
	@IBAction func stopTimer(_ sender: AnyObject) {
		quizDisplay.timerScene.stopTimer()
	}
	
	@IBAction func timerIncrement(_ sender: AnyObject) {
		quizDisplay.timerScene.timerIncrement()
	}
	
	@IBAction func timerDecrement(_ sender: AnyObject) {
		quizDisplay.timerScene.timerDecrement()
	}
	
	@IBAction func timerStartWithMusic(_ sender: Any) {
		quizDisplay.timerScene.startTimer(music: true)
	}
	
	@IBAction func timerShowCounterChange(_ sender: NSButton) {
		quizDisplay.timerScene.showCounter(timerShowCounter.state == .on)
	}
	
	
	//MARK: - Text and numbers
	//--------------------------------------------------------------------------------------------------------------------------
	
	@IBOutlet weak var textAllowAnswers: NSButton!
	@IBOutlet weak var textShowQuestionNumbers: NSButton!
	@IBOutlet weak var textQuestionNumber: NSTextField!
	@IBOutlet weak var textStepper: NSStepper!
	@IBOutlet weak var textTeamGuesses: NSTextField!
	@IBOutlet weak var uniqueFile: NSPopUpButton!
	
	/// Back to question one with answering open and no guesses shown.
	private func resetTextControls() {
		textStepper.intValue = 1
		textQuestionNumber.stringValue = "1"
		textTeamGuesses.stringValue = ""
		textAllowAnswers.state = .on
	}

	@IBAction func textStepperChange(_ sender: Any) {
		textQuestionNumber.stringValue = textStepper.stringValue
	}
	@IBAction func textShowGuesses(_ sender: Any) {
		textAllowAnswers.state = .off
		quizDisplay.textScene.showGuesses(showroundno: (textShowQuestionNumbers.state == .on) ? true : false)
	}
	
	@IBAction func textScoreUnique(_ sender: Any) {
		quizDisplay.textScene.scoreUnique()
	}

	@IBAction func uniqueChooseFile(_ sender: NSPopUpButton) {
		if Settings.shared.uniquePath != "" {
			if let fileName = sender.selectedItem?.title {
				let path = Settings.shared.uniquePath + "/" + fileName
				quizDisplay.textScene.initUnique(file: path)
			}
			else {
				print("Error choosing unique list")
			}
		}
	}
	
	@IBOutlet weak var numbersAllowAnswers: NSButton!
	@IBOutlet weak var numbersActualAnswer: NSTextField!
	@IBOutlet weak var numbersTeamGuesses: NSTextField!
	
	/// Clears the answer and the guess list, and reopens answering.
	private func resetNumbersControls() {
		numbersActualAnswer.intValue = 0
		numbersAllowAnswers.state = .on
		numbersTeamGuesses.stringValue = ""
	}

	@IBAction func numbersShowAnswers(_ sender: NSButton) {
		numbersAllowAnswers.state = .off
		quizDisplay.numbersScene.showGuesses(actualAnswer: Int(numbersActualAnswer!.intValue))
	}
	
	
	//MARK: - Scores
	//--------------------------------------------------------------------------------------------------------------------------
	
	@IBOutlet weak var scoresOutput: NSTextField!
	@IBOutlet weak var scoresText: NSTextView!
	
	@IBAction func scoresInitText(_ sender: Any) {
		var s = ""
		for x in 1...Settings.shared.numTeams {
			s = s + "\(x),\n"
		}
		scoresText.string = s
	}
	
	@IBAction func scoresParseAndReset(_ sender: Any) {
		quizDisplay.scoresScene.parseAndReset(scoreText: scoresText.string)
	}
	
	@IBAction func scoresShowNext(_ sender: Any) {
		quizDisplay.scoresScene.next()
	}
	

	//MARK: - True/False
	//--------------------------------------------------------------------------------------------------------------------------
	
	@IBOutlet weak var trueButton: NSButton!
	@IBOutlet weak var falseButton: NSButton!
	@IBOutlet weak var trueFalseToggle: NSButton!
	@IBOutlet weak var truefalseSounds: NSButton!

	@IBAction func trueFalseStart(_ sender: NSButton) {
		quizDisplay.truefalseScene.start(sounds: truefalseSounds.state == .on)
	}
	
	@IBAction func trueFalseStartNoTimer(_ sender: NSButton) {
		quizDisplay.truefalseScene.startNoTimer(sounds: truefalseSounds.state == .on)
	}
	
	@IBAction func trueFalseTrue(_ sender: NSButton) {
		quizDisplay.truefalseScene.showAnswer(ans: true)
	}
	
	@IBAction func trueFalseFalse(_ sender: NSButton) {
		quizDisplay.truefalseScene.showAnswer(ans: false)
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
		quizDisplay.truefalseScene.setMode(self.trueFalseToggle.state == .on)
	}
	
	//MARK: - Multiple choice
	//--------------------------------------------------------------------------------------------------------------------------

	@IBOutlet weak var multiOptionsStepper: NSStepper!
	@IBOutlet weak var multiOptionsNumber: NSTextField!
	@IBOutlet weak var multiStyleToggle: NSButton!
	@IBOutlet weak var multiSounds: NSButton!
	@IBOutlet weak var multiStartButton: NSButton!
	@IBOutlet weak var multiTeamGuesses: NSTextField!
	@IBOutlet weak var multiTime10: NSButton!
	@IBOutlet weak var multiTime20: NSButton!
	@IBOutlet weak var multiTime30: NSButton!
	@IBOutlet weak var multiAnswer1: NSButton!
	@IBOutlet weak var multiAnswer2: NSButton!
	@IBOutlet weak var multiAnswer3: NSButton!
	@IBOutlet weak var multiAnswer4: NSButton!
	@IBOutlet weak var multiAnswer5: NSButton!
	@IBOutlet weak var multiAnswer6: NSButton!

	/// Seconds on the clock, as chosen by the three time buttons.
	private var multiTimeout = MultiChoiceScene.defaultTimeout

	private var multiAnswerButtons: [NSButton?] {
		[multiAnswer1, multiAnswer2, multiAnswer3, multiAnswer4, multiAnswer5, multiAnswer6]
	}

	private var multiStyle: MultiChoiceScene.LabelStyle {
		(multiStyleToggle?.state ?? .on) == .on ? .letters : .numbers
	}

	@IBAction func multiOptionsStepperChange(_ sender: Any) {
		pushMultiChoiceOptions()
	}

	@IBAction func multiStyleToggled(_ sender: Any) {
		multiStyleToggle.title = multiStyle == .letters ? "Letters (A B C)" : "Numbers (1 2 3)"
		pushMultiChoiceOptions()
	}

	/// The three time buttons carry the time length as their tag
	@IBAction func multiTimeChange(_ sender: NSButton) {
		multiTimeout = sender.tag
		for button in [multiTime10, multiTime20, multiTime30] {
			button?.state = (button?.tag == multiTimeout) ? .on : .off
		}
		pushMultiChoiceOptions()
	}

	@IBAction func multiStart(_ sender: NSButton) {
		if quizDisplay.multiChoiceScene.counting {
			quizDisplay.multiChoiceScene.stop()
		} else {
			//The teams' phones still show the last question's selection until they are told
			//otherwise, and 'mo' is what clears them.
			socketWriteIfConnected("mo" + quizDisplay.multiChoiceScene.optionsMessage)
			multiTeamGuesses?.stringValue = ""
			quizDisplay.multiChoiceScene.start(sounds: multiSounds.state == .on)
		}
		updateMultiChoiceStartButton()
	}

	@IBAction func multiAnswerPressed(_ sender: NSButton) {
		quizDisplay.multiChoiceScene.showAnswer(option: sender.tag)
		updateMultiChoiceStartButton()
		updateMultiChoiceGuesses()
	}

	private func pushMultiChoiceOptions() {
		if quizDisplay.multiChoiceScene.counting {
			print("Multiple choice: ignoring a setup change while the question is running")
			syncMultiChoiceControls()
			return
		}

		let options = Int(multiOptionsStepper?.intValue ?? Int32(MultiChoiceScene.defaultOptions))
		let payload = quizDisplay.multiChoiceScene.configure(options: options, style: multiStyle, timeout: multiTimeout)
		socketWriteIfConnected("mo" + payload)
		multiTeamGuesses?.stringValue = ""
		syncMultiChoiceControls()
	}

	/// Puts the controls back in step with whatever the scene actually holds.
	private func syncMultiChoiceControls() {
		let scene = quizDisplay.multiChoiceScene
		multiOptionsStepper?.intValue = Int32(scene.optionCount)
		multiOptionsNumber?.stringValue = String(scene.optionCount)

		//Only the answers that exist can be the right one
		for (index, button) in multiAnswerButtons.enumerated() {
			let option = index + 1
			button?.title = scene.labelStyle.label(option)
			button?.isEnabled = option <= scene.optionCount
		}
		updateMultiChoiceStartButton()
	}

	private func updateMultiChoiceStartButton() {
		multiStartButton?.title = quizDisplay.multiChoiceScene.counting ? "Stop" : "Start"
	}
	
	private func updateMultiChoiceGuesses() {
		let scene = quizDisplay.multiChoiceScene
		multiTeamGuesses?.stringValue = (0..<Settings.shared.numTeams).compactMap { team -> String? in
			guard team < scene.teamGuesses.count, let guess = scene.teamGuesses[team] else {
				return nil
			}
			return "Team \(team + 1): \(scene.labelStyle.label(guess))"
		}.joined(separator: "\n")
	}

	private func resetMultiChoiceControls() {
		multiTimeout = MultiChoiceScene.defaultTimeout
		for button in [multiTime10, multiTime20, multiTime30] {
			button?.state = (button?.tag == multiTimeout) ? .on : .off
		}
		multiTeamGuesses?.stringValue = ""
		pushMultiChoiceOptions()
	}

	//MARK: - Test
	//--------------------------------------------------------------------------------------------------------------------------
	

	
	//MARK: - Geography
	//--------------------------------------------------------------------------------------------------------------------------
	
	@IBOutlet weak var geoAnswerX: NSTextField!
	@IBOutlet weak var geoAnswerY: NSTextField!
	@IBOutlet weak var geoQuestionNumber: NSTextField!
	@IBOutlet weak var geoStepper: NSStepper!
	
	@IBAction func geoStepperChange(_ sender: Any) {
		geoQuestionNumber.stringValue = geoStepper.stringValue
	}
	
	@IBAction func geoStartQuestion(_ sender: Any) {
		quizDisplay.reset()
		pushClientView()
		socketWriteIfConnected("imgeo" + geoStepper.stringValue + ".jpg")
		quizDisplay.geographyScene.setQuestion(question: Int(geoStepper.intValue))
		pushTeamParticipation()
	}
	
	@IBAction func geoShowWinner(_ sender: Any) {
		quizDisplay.geographyScene.showWinner(answerx: Int(geoAnswerX.intValue), answery: Int(geoAnswerY.intValue))
	}
	
	
	//MARK: - Wavelength
	//--------------------------------------------------------------------------------------------------------------------------

	@IBOutlet weak var wavelengthNumber: NSTextField!
	@IBOutlet weak var wavelengthRollButton: NSButton!
	/// The guesses, and then the placings once scoring has run. A text view rather than a
	/// label so that a long list scrolls instead of being quietly cut off at the bottom.
	@IBOutlet var wavelengthTeamGuesses: NSTextView!

	/// The number the host has rolled, or nil if the wheel has not been stopped yet
	private var wavelengthTarget: Int?
	private var wavelengthRollTimer: Timer?

	private var wavelengthRandomValue: Int {
		Int.random(in: WavelengthScene.minValue...WavelengthScene.maxValue)
	}

	/// The roll button starts the numbers spinning and the next press stops them
	@IBAction func wavelengthRoll(_ sender: NSButton) {
		if wavelengthRollTimer != nil {
			wavelengthRollTimer?.invalidate()
			wavelengthRollTimer = nil
			wavelengthTarget = wavelengthRandomValue
			wavelengthNumber.stringValue = String(wavelengthTarget!)
			wavelengthRollButton.title = "Roll -> 🎲"
		} else {
			wavelengthTarget = nil
			wavelengthRollButton.title = "Stop"
			wavelengthRollTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
				guard let self = self else { return }
				self.wavelengthNumber.stringValue = String(self.wavelengthRandomValue)
			}
		}
	}

	@IBAction func wavelengthReveal(_ sender: Any) {
		quizDisplay.wavelengthScene.reveal()
		updateWavelengthGuesses()
	}

	@IBAction func wavelengthScore(_ sender: Any) {
		//Only the first press needs the number. After that the scene scores against whatever
		//it actually swept to, so the roll being restarted here cannot change the result.
		if !quizDisplay.wavelengthScene.swept && wavelengthTarget == nil {
			print("Wavelength: nothing to score against, the number has not been rolled yet")
			return
		}
		quizDisplay.wavelengthScene.score(target: wavelengthTarget ?? 0)
		//The second press works out the placings, so pick them up for the host's list
		updateWavelengthGuesses()
		updateWavelengthRollEnabled()
	}

	/// The roll is locked once the sweep has run. The answer is fixed to the number the sweep
	/// landed on from that point, so reaching for Roll could only spin the label against a
	/// display that has already moved past it.
	private func updateWavelengthRollEnabled() {
		wavelengthRollButton?.isEnabled = !quizDisplay.wavelengthScene.swept
	}

	private func resetWavelengthControls() {
		wavelengthRollTimer?.invalidate()
		wavelengthRollTimer = nil
		wavelengthTarget = nil
		wavelengthNumber?.stringValue = "--"
		wavelengthRollButton?.title = "Roll -> 🎲"
		wavelengthTeamGuesses?.string = ""
		updateWavelengthRollEnabled()
	}

	private func updateWavelengthGuesses() {
		//Once scoring has run, the list becomes the result: ordered best first and saying in
		//words where each team came. The main display shows rank by how a marker is dressed,
		//which a crowded bar can make hard to read, so the host always has it unambiguously.
		let placings = quizDisplay.wavelengthScene.placings
		if !placings.isEmpty {
			wavelengthTeamGuesses?.string = placings.map { placing in
				"\(WavelengthScene.tierName(placing.tier)) — Team \(placing.team + 1): \(placing.guess) (out by \(placing.distance))"
			}.joined(separator: "\n")
			return
		}

		let guesses = quizDisplay.wavelengthScene.teamGuesses
		wavelengthTeamGuesses?.string = (0..<Settings.shared.numTeams).compactMap { team -> String? in
			if guesses.indices.contains(team), let guess = guesses[team] {
				return "Team \(team + 1): \(guess)"
			}
			return nil
		}.joined(separator: "\n")
	}


	//MARK: - Pointless
	//--------------------------------------------------------------------------------------------------------------------------
	@IBOutlet weak var pointlessQuestionSelector: NSPopUpButton!
	@IBOutlet weak var pointlessTextQuestion: NSTextField!
	@IBOutlet weak var pointlessTextAnswers: NSTextField!
	@IBOutlet weak var pointlessAllowAnswers: NSButton!
	@IBOutlet weak var pointlessTable: NSTableView!
	@IBOutlet weak var pointlessDescending: NSButton!
	@IBOutlet weak var pointlessQuestion: NSScrollView!
	
	@IBAction func pointlessShowAnswers(_ sender: Any) {
		quizDisplay.pointlessScene.showAnswers()
	}

	@IBAction func pointlessRunScoring(_ sender: Any) {
		quizDisplay.pointlessScene.runScoring()
	}
	
	@IBAction func pointlessQuestionSelected(_ sender: Any) {
		if Settings.shared.pointlessPath != "" {
			if let title = pointlessQuestionSelector.selectedItem?.title {
				let path = Settings.shared.pointlessPath + "/" + title
				quizDisplay.pointlessScene.changeToQuestion(path: path)
			}
		}
	}

	@IBAction func pointlessTest(_ sender: Any) {
		quizDisplay.pointlessScene.debugTest()
	}
	
	@IBAction func pointlessTableChange(_ sender: Any) {
	}
	
}

