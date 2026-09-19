//
//  ControllerWindowController.swift
//  Quiz Server
//
//  Created by Russell Joyce on 18/11/2014.
//  Copyright (c) 2014 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa

/// One round's controls on the controller window.
protocol RoundPanel: AnyObject {
	/// The round these controls drive
	var round: RoundType { get }

	/// The window the controls live in. Set once, as the window loads.
	var host: ControllerWindowController! { get set }

	/// Hand the round any UI element from this window that it draws into
	func connectControls()

	/// One-time setup once the scenes exist
	func setUp()

	/// Stop anything still running. Called as the window closes.
	func tearDown()

	/// Put the controls back to the round's starting state. `presenting` is true for a
	/// round change, false for a reset in place
	func reset(presenting: Bool)

	/// Anything a catching-up client needs that belongs to the round
	var clientRoundState: [String] { get }

	/// An answer `team` has already given, if the round tracks one. `team` is 0-based
	func clientTeamState(team: Int) -> [String]

	/// Whether the round is taking typed answers from the phones at the moment
	var acceptingTextAnswers: Bool { get }

	/// A typed answer from a team that is playing, already trimmed. `team` is 0-based.
	func receive(textGuess: String, from team: Int)
}

extension RoundPanel {
	func connectControls() {}
	func setUp() {}
	func tearDown() {}
	func reset(presenting: Bool) {}
	var clientRoundState: [String] { [] }
	func clientTeamState(team: Int) -> [String] { [] }
	var acceptingTextAnswers: Bool { false }
	func receive(textGuess: String, from team: Int) {}
}


class ControllerWindowController: NSWindowController, NSWindowDelegate, NSTabViewDelegate,
								  NSTableViewDataSource, NSTableViewDelegate, QuizWebSocketDelegate {
    
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
	@IBOutlet weak var tabitemIdleCeefax: NSTabViewItem!
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
	@IBOutlet weak var tabitemWikiRace: NSTabViewItem!
	
	//MARK: - General
	//--------------------------------------------------------------------------------------------------------------------------
	/// The single controller window, shown by `StartupView` once the settings are chosen.
	/// Loading its nib reads the launch configuration out of `Settings.shared`.
	static let shared = ControllerWindowController(windowNibName: "ControllerWindow")

	/// Who is playing. Rebuilt in `windowDidLoad`, once the team count is known.
	private var roster = TeamRoster(teams: 0)
	/// The numbered buttons, trimmed to the teams that exist
	private var buzzerButtons = [NSButton]()
	let quizDisplay = QuizDisplayController()

	@IBOutlet var buzzerPanel: BuzzerPanel!
	@IBOutlet var musicPanel: MusicPanel!
	@IBOutlet var timerPanel: TimerPanel!
	@IBOutlet var trueFalsePanel: TrueFalsePanel!
	@IBOutlet var multiChoicePanel: MultiChoicePanel!
	@IBOutlet var geographyPanel: GeographyPanel!
	@IBOutlet var wikiRacePanel: WikiRacePanel!
	@IBOutlet var textPanel: TextPanel!
	@IBOutlet var numbersPanel: NumbersPanel!
	@IBOutlet var wavelengthPanel: WavelengthPanel!
	@IBOutlet var pointlessPanel: PointlessPanel!
	@IBOutlet var scoresPanel: ScoresPanel!
	private var panels = [RoundType: RoundPanel]()
	
	private var ceefaxPageControl: CeefaxPageControl?
	private var clientListTimer: Timer!
	
    override func windowDidLoad() {
        super.windowDidLoad()

		//Connect to Node server
		print("Connect to Node server...")
		window?.title = "Quiz Control - NOT CONNECTED"
		QuizWebSocket.shared = socket
		socket.delegate = self
		socket.connect()

		
		// Trim number of buttons down to match number of teams
		// We only handle 15 test buzzers up here
		let allBuzzerButtons : [NSButton] = [buzzerButton1, buzzerButton2, buzzerButton3, buzzerButton4, buzzerButton5, buzzerButton6, buzzerButton7, buzzerButton8, buzzerButton9, buzzerButton10, buzzerButton11, buzzerButton12, buzzerButton13, buzzerButton14, buzzerButton15]
		buzzerButtons = Array(allBuzzerButtons.prefix(Settings.shared.numTeams))
		roster = TeamRoster(teams: Settings.shared.numTeams)
		syncBuzzerButtons()
		
		let allPanels: [RoundPanel] = [buzzerPanel, musicPanel, timerPanel, trueFalsePanel,
									   multiChoicePanel, geographyPanel, wikiRacePanel, textPanel,
									   numbersPanel, wavelengthPanel, pointlessPanel, scoresPanel]
		for panel in allPanels {
			panel.host = self
			panels[panel.round] = panel
		}

		//The scenes lay these out in buildScene, which present() triggers, so they have to
		//be handed over first
		allPanels.forEach { $0.connectControls() }

		quizDisplay.present()

		ceefaxPageControl = CeefaxPageControl(in: tabitemIdleCeefax?.view, scene: quizDisplay.idleCeefaxScene)

		allPanels.forEach { $0.setUp() }

		configureSidebar()

		//Default to Idle on load regardless of what we left it on in Interface Builder
		isReady = true
		enterRound(.idle, presenting: true)

        // Start periodic task to ask the server what clients are connected
        clientListTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(clientListTask), userInfo: nil, repeats: true)

		installLEDStrip(window: window)
    }
	
	func windowWillClose(_ notification: Notification) {
		clientListTimer?.invalidate()
		panels.values.forEach { $0.tearDown() }
		socket.ledsOff()
	}

	@objc private func clientListTask() {
		//Periodically check to see what clients are connected. The reply will be "lr" and the handler will parse this to set the indicators
		socketWriteIfConnected("ls")
	}
	
	//MARK: - General controls
	//-----------------------------------------------------------------------------------------------------------
	
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
			if !roster.isChosen(sender.tag) {
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
			//Enabling or disabling the client. A checked button is a team knocked out.
			rosterChanged(roster.set(sender.tag, playing: sender.state == .off))
		}
	}
	
	/// Stops everybody at once, without losing the individual choices
	@IBAction func disableAllBuzzers(_ sender: NSButton) {
		rosterChanged(roster.setAllDisabled(sender.state == .on))
	}

	private func rosterChanged(_ changed: [Int]) {
		for team in changed {
			socketWriteIfConnected((roster.isPlaying(team) ? "on" : "of") + String(team + 1))
		}
		syncBuzzerButtons()
		pushTeamParticipation()
	}

	/// Redraws the numbered buttons from the roster
	private func syncBuzzerButtons() {
		for (team, button) in buzzerButtons.enumerated() {
			button.state = roster.isChosen(team) ? .off : .on
			button.isEnabled = !roster.allDisabled
		}
	}

	/// Tells the live round who is playing. Called whenever the enable buttons change and whenever a round starts
	func pushTeamParticipation() {
		quizDisplay.setParticipating(roster.flags)
	}


	//MARK: - Repairing a client
	//-----------------------------------------------------------------------------------------------------------
	@IBOutlet weak var resyncModeBtn: NSButton!
	@IBOutlet weak var repairWarningLabel: NSTextField!
	@IBOutlet weak var disconnectAllButton: NSButton!

	/// True when the team buttons resync rather than disconnect
	private var resyncMode: Bool {
		resyncModeBtn?.state == .on
	}

	@IBAction func resyncModePress(_ sender: NSButton) {
		resetDisconnectAllButton()
		repairWarningLabel?.stringValue = resyncMode
			? "Resync tells a team's device what the current state of play is. Safe to press at any time."
			: "WARNING: Pressing these buttons will disassociate that team's device and they will have to reconnect."
	}

	@IBAction func disassociateTeamPress(_ sender: NSButtonCell) {
		if resyncMode {
			resyncTeam(sender.tag)
		} else {
			socketWriteIfConnected("di\(sender.tag)")
		}
	}

	/// Set when "Disconnect All" is armed, so a second click within the timeout actually does it
	private var disconnectAllConfirmTimer: Timer?

	@IBAction func disconnectAllPress(_ sender: NSButton) {
		if resyncMode {
			for team in 1...Settings.shared.numTeams {
				resyncTeam(team)
			}
			return
		}

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
		disconnectAllButton?.title = resyncMode ? "Resync All" : "Disconnect All"
	}

	/// Sends one team everything it needs to show the current state of play.
	/// `team` is 1-based, as the button tags and the wire protocol both are.
	private func resyncTeam(_ team: Int) {
		guard team >= 1 && team <= Settings.shared.numTeams else { return }
		for message in clientState(for: team) {
			socketWriteIfConnected("to\(team),\(message)")
		}
		//ask the node server to resend that team's race state
		if quizDisplay.currentRound == .wikirace {
			socketWriteIfConnected("wk\(team)")
		}
	}

	/// Everything a client needs in order to show the current state of play
	/// These are messages as a client reads them, which is not always how the quiz software
	/// writes them: normally the node server strips the team off "on3" or "ms3,4" on the way
	/// past. `team` is 1-based.
	private func clientState(for team: Int) -> [String] {
		let idx = team - 1 //The scenes index their teams from zero
		let round = quizDisplay.currentRound
		var messages = [String]()

		//"vs" rather than "vi": a device already on the right view must keep the answer its
		//team is part way through typing or dragging. "vi" is a reset and would throw it away.
		messages.append("vs" + round.clientView)

		//Decoration belonging to the round rather than to any one team
		messages += panels[round]?.clientRoundState ?? []
		
		//Is this team enabled?
		messages.append(roster.isPlaying(idx) ? "on" : "of")

		//An answer this team has already given
		//This is likely to be unnecessary, but it is here for completeness
		messages += panels[round]?.clientTeamState(team: idx) ?? []

		return messages
	}

	/// The round a tab stands for, or nil for a tab that is a control panel rather than a round
	private func round(for item: NSTabViewItem) -> RoundType? {
		for row in sidebarRows {
			if case .round(let candidate, let round, _) = row, candidate === item {
				return round
			}
		}
		return nil
	}

	/// Puts `round` into its starting state: the scene, the teams' phones, and the host's controls.
	/// `presenting` is true for a round change, false for a reset in place.
	func enterRound(_ round: RoundType, presenting: Bool) {
		if presenting {
			quizDisplay.setRound(round: round) //presents the scene, and resets it on the way in
		} else {
			quizDisplay.reset()
		}

		socketWriteIfConnected("vi" + round.clientView)
		resetControls(for: round, presenting: presenting)

		//Whichever round we are now in needs to know who is playing
		pushTeamParticipation()
	}

	/// Reset re-arms the question the host is on, so it clears answers but keeps their
	/// place in the round. A round change puts that place back to the start.
	private func resetControls(for round: RoundType, presenting: Bool) {
		panels[round]?.reset(presenting: presenting)
		if round == .idleCeefax {
			ceefaxPageControl?.refresh()
		}
	}

    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
		guard let tabViewItem = tabViewItem else { return }
		guard isReady, let round = round(for: tabViewItem) else { return }
		
		enterRound(round, presenting: true)

		//Keeps the highlight correct if something other than a click moved us
		selectSidebarRow(for: tabViewItem)
    }
    
    @IBAction func resetRound(_ sender: AnyObject) {
		enterRound(quizDisplay.currentRound, presenting: false)
    }
	
	//--------------------------------------------------------------------------------------------------------------------------
	//MARK: - Sidebar
	//--------------------------------------------------------------------------------------------------------------------------

	private enum SidebarRow {
		case group(String)
		case round(NSTabViewItem, RoundType?, String)
	}

	private var sidebarRows = [SidebarRow]()
	private var isReady = false
	@IBOutlet weak var sidebarTable: NSTableView!

	private func buildSidebarRows() {
		sidebarRows = [
			.group("Show"),
			.round(tabitemIdle, .idle, "🎄 Idle"),
			.round(tabitemIdleCeefax, .idleCeefax, "📺 Idle (Ceefax)"),
			.round(tabitemScores, .scores, "📋 Scores"),
			
			.group("Rounds"),
			.round(tabitemBuzzers, .buzzers, "🔊 Buzzers"),
			.round(tabitemMusic, .music, "🎶 Music + Video"),
			.round(tabitemtruefalse, .trueFalse, "✅ True / False"),
			.round(tabitemMultiChoice, .multichoice, "🎲 Multiple Choice"),
			.round(tabitemGeography, .geography, "🌍 Geography"),
			.round(tabitemWikiRace, .wikirace, "🔗 Wikirace"),
			.round(tabitemText, .text, "✍️ Text"),
			.round(tabitemNumbers, .numbers, "🔢 Numbers"),
			.round(tabitemWavelength, .wavelength, "🌊 Wavelength"),
			.round(tabitemPointless, .pointless, "0️⃣ Pointless"),
			.round(tabitemTimer, .timer, "🕓 Timer"),

			.group("Admin"),
			.round(tabitemTest, .test, "🧪 Test Screen"),
			.round(tabitemDisconnect, nil, "🔧 Repair Client")
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
			if case .round(let candidate, _, _) = row {
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
		case .round(_, _, let name):
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
		if case .round(let item, _, _) = sidebarRows[table.selectedRow] {
			//Selecting the item is all this does. Everything that happens on a round change
			//still happens in tabView(_:didSelect:)
			tabView.selectTabViewItem(item)
		}
	}

	@IBAction func sidebarLockPressed(_ sender: Any) {
		sidebarTable.isEnabled = (sender as! NSButton).state == .off
	}
	
	
	
	//MARK: - Websockets
	//--------------------------------------------------------------------------------------------------------------------------
	
	var socket = QuizWebSocket(url: URL(string: "ws://localhost:8091/")!)

	func socketWriteIfConnected(_ s : String) {
		socket.send(s)
	}
	
	/// Routes one decoded message to whichever round or control it belongs to.
	func webSocket(didReceive message: QuizMessage) {
		switch message {
		case .connected:
			break

		case .clientList(let teams):
			//A green box for every team that currently has a client connected
			let allStats = [st1, st2, st3, st4, st5, st6, st7, st8, st9, st10, st11, st12, st13, st14, st15]
			for (i, box) in allStats.enumerated() {
				box?.fillColor = teams.contains(i + 1) ? NSColor.green : NSColor.black
			}

		case .buzz(let team):
			guard roster.isPlaying(team.index) else { break }
			quizDisplay.buzzerPressed(team: team.index, type: .websocket, options: buzzerOptions)

		case .higherLower(let team, let higher):
			guard roster.isPlaying(team.index) else { break }
			quizDisplay.truefalseScene.teamGuess(teamid: team.index, guess: higher)
			if quizDisplay.truefalseScene.counting {
				socketWriteIfConnected((higher ? "hh" : "hl") + String(team.number))
			}

		case .geographyGuess(let team, let x, let y):
			guard roster.isPlaying(team.index) else { break }
			quizDisplay.geographyScene.teamAnswered(team: team.index, x: x, y: y)

		case .wavelengthGuess(let team, let value):
			guard roster.isPlaying(team.index) else { break }
			quizDisplay.wavelengthScene.teamGuess(team: team.index, value: value)
			wavelengthPanel.updateGuesses()

		case .multiChoiceGuess(let team, let option):
			guard roster.isPlaying(team.index), multiChoicePanel.counting else { break }
			if let taken = multiChoicePanel.teamGuessed(team: team.index, option: option) {
				//If the round rejected it we wont light the tile on the client
				socketWriteIfConnected("ms\(team.number),\(taken)")
			}

		case .textGuess(let team, let text):
			receiveTextGuess(team: team, text: text)

		case .wikiMoved(let team, let hops, let away, let title):
			if roster.isPlaying(team.index) {
				quizDisplay.wikiRaceScene.teamMoved(team: team.index, title: title, hops: hops, away: away)
			}
			wikiRacePanel.refreshPath()

		case .wikiArrived(let team, let hops, let seconds):
			guard roster.isPlaying(team.index) else { break }
			quizDisplay.wikiRaceScene.teamArrived(team: team.index, hops: hops, seconds: seconds)

		case .wikiStanding(let team, let rank, let finished, let seconds, let hops, let away):
			quizDisplay.wikiRaceScene.raceStanding(team: team.index, rank: rank, finished: finished,
			                                       secs: seconds, hops: hops, away: away)

		case .wikiTrail(let team, let titles):
			quizDisplay.wikiRaceScene.raceTrails[team.index] = titles
			wikiRacePanel.refreshPath()
		}
	}

	/// A typed answer, which three different rounds accept. Each has its own "allow answers"
	/// toggle, and an answer arriving while that is off is dropped.
	private func receiveTextGuess(team: Team, text: String) {
		guard let panel = panels[quizDisplay.currentRound], panel.acceptingTextAnswers else { return }
		//Ignore teams the host has disabled
		guard roster.isPlaying(team.index) else { return }

		panel.receive(textGuess: String(text.prefix(20)), from: team.index) //TODO Max size of 20 is too low?
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


	//--------------------------------------------------------------------------------------------------------------------------
	//MARK: - Buzzer options
	//--------------------------------------------------------------------------------------------------------------------------
	
	@IBOutlet weak var buzzerSounds: NSButton!
	@IBOutlet weak var quieterBuzzes: NSButton!
	@IBOutlet weak var buzzerQueueMode: NSButton!
	@IBOutlet weak var buzzcocksMode: NSButton!
	@IBOutlet weak var blankVideo: NSButton!

	private var buzzerOptions: BuzzerOptions {
		BuzzerOptions(buzzcocksMode: buzzcocksMode.state == .on,
					  buzzerQueueMode: buzzerQueueMode.state == .on,
					  quietMode: quieterBuzzes.state == .on,
					  buzzerSounds: buzzerSounds.state == .on,
					  blankVideo: blankVideo.state == .on)
	}
}
