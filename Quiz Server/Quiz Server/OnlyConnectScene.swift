//
//  OnlyConnectScene.swift
//  Quiz Server
//
//  Created by Ian Gray on 2026-10-29.
//  Copyright © 2026 Russell Joyce & Ian Gray. All rights reserved.
//

import Foundation
import Cocoa
import SpriteKit


// MARK: - The wall

/// One connecting wall: four groups of four clues, and the order the tiles are shown in.
/// Every team plays the same wall in the same order, so that the phone in a team's hands
/// matches the big screen they are all looking at.
struct OnlyConnectWall {

	struct Group {
		/// What links the four, if the question file says
		let connection: String?
		let clues: [String]
	}

	static let size = 16

	let groups: [Group]

	/// The tile at display position `i` (0-based) is clue `order[i] % 4` of group `order[i] / 4`
	let order: [Int]

	func word(at position: Int) -> String {
		let tile = order[position]
		return groups[tile / 4].clues[tile % 4]
	}

	func group(at position: Int) -> Int {
		order[position] / 4
	}

	/// The display positions, 0-based, of one group's tiles
	func positions(of group: Int) -> [Int] {
		(0..<Self.size).filter { self.group(at: $0) == group }
	}

	/// Every word in display order, as the phones are sent it
	var words: [String] {
		(0..<Self.size).map { word(at: $0) }
	}

	/// Reads a question file:
	///
	///     Coffee: Lungo, Espresso, Flat White, Irish
	///     Mr ___: Vain, Brightside, Sandman, Bojangles
	///     Exposure, Filter, DSLR, Focus
	///     Wishful, Blue sky, Negative, Lateral
	///
	/// One group per line, its four clues separated by commas, with the connection optionally
	/// in front of a colon (so a clue cannot itself contain a colon). Blank lines, lines
	/// starting with #, and lines with no commas at all, such as a "Question 1" heading, are
	/// skipped.
	///
	/// The order is shuffled from the file's own contents, so a question always comes up the
	/// same way, and restarting the quiz software mid-round does not move the tiles.
	///
	/// - Returns: the wall, or a description of what is wrong with the file
	static func parse(_ text: String) -> Result<OnlyConnectWall, WallError> {
		var groups = [Group]()

		for rawLine in text.components(separatedBy: .newlines) {
			let line = rawLine.trimmingCharacters(in: .whitespaces)
			guard !line.isEmpty, !line.hasPrefix("#"), line.contains(",") else { continue }

			var connection: String? = nil
			var clueText = Substring(line)
			if let colon = line.firstIndex(of: ":") {
				let name = line[..<colon].trimmingCharacters(in: .whitespaces)
				connection = name.isEmpty ? nil : name
				clueText = line[line.index(after: colon)...]
			}

			let clues = clueText.split(separator: ",", omittingEmptySubsequences: false)
				.map { $0.trimmingCharacters(in: .whitespaces) }
			guard clues.count == 4, !clues.contains(where: { $0.isEmpty }) else {
				return .failure(.wrongClueCount(line: line))
			}
			//The phones are sent the wall pipe separated
			if let bad = clues.first(where: { $0.contains("|") }) {
				return .failure(.reservedCharacter(clue: bad))
			}
			groups.append(Group(connection: connection, clues: clues))
		}

		guard groups.count == 4 else {
			return .failure(.wrongGroupCount(groups.count))
		}

		var rng = SeededGenerator(seed: fnv1a(text))
		var order = Array(0..<size)
		//A group that happens to land as a whole row would be no puzzle at all
		repeat {
			order.shuffle(using: &rng)
		} while (0..<4).contains { row in
			Set(order[(row * 4)..<(row * 4 + 4)].map { $0 / 4 }).count == 1
		}

		return .success(OnlyConnectWall(groups: groups, order: order))
	}

	enum WallError: Error, CustomStringConvertible {
		case wrongGroupCount(Int)
		case wrongClueCount(line: String)
		case reservedCharacter(clue: String)

		var description: String {
			switch self {
			case .wrongGroupCount(let n): return "Needs 4 groups, found \(n)"
			case .wrongClueCount(let line): return "Needs 4 clues: \(line)"
			case .reservedCharacter(let clue): return "A clue cannot contain '|': \(clue)"
			}
		}
	}

	/// Swift's own hashing is seeded afresh on every launch, so it cannot give a stable order
	private static func fnv1a(_ text: String) -> UInt64 {
		var hash: UInt64 = 0xcbf29ce484222325
		for byte in text.utf8 {
			hash ^= UInt64(byte)
			hash = hash &* 0x100000001b3
		}
		return hash
	}
}


/// SplitMix64, which is all a shuffle needs, and repeatable from its seed
struct SeededGenerator: RandomNumberGenerator {
	private var state: UInt64

	init(seed: UInt64) {
		state = seed
	}

	mutating func next() -> UInt64 {
		state &+= 0x9E3779B97F4A7C15
		var z = state
		z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
		z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
		return z ^ (z >> 31)
	}
}


/// How far one team has got with the wall
struct WallProgress {
	/// Groups found, in the order they were found
	var found = [Int]()
	var wrong = 0
	/// Seconds from the start of the wall to the last group, once there is one
	var finishedAfter: TimeInterval?

	var finished: Bool { found.count == 4 }
}


// MARK: - The scene

class OnlyConnectScene: QuizScene {

	enum Phase {
		/// Tiles face down, waiting for the host to start
		case waiting
		case running
		/// Over, either because the host stopped it or because everyone finished
		case stopped
	}

	/// What became of a guess
	enum Verdict {
		/// The groups solved, as 0-based positions. Two of them when the guess was the
		/// third group, because the fourth then solves itself.
		case solved([[Int]])
		/// Four tiles that are not a group, as 0-based positions
		case wrong([Int])
		/// Not a guess that can be judged: the wall is not running, or the tiles are not
		/// four different unsolved ones. Nothing is counted against the team.
		case ignored
	}

	private(set) var wall: OnlyConnectWall?
	private(set) var phase = Phase.waiting
	private(set) var progress = [WallProgress]()
	private var startedAt: Date?

	/// 0 for none, 1 once the tiles are sorted into their groups, and then one more for each
	/// connection shown
	private(set) var revealStep = 0

	private var participating = [Bool]()

	private var tiles = [WallTileNode]()
	private var teamNodes = [WallTeamNode]()
	private var clockLabel: OutlinedLabelNode!
	private var connectionLabels = [OutlinedLabelNode]()

	let solvedSound = SKAction.playSoundFileNamed("notification-3", waitForCompletion: false)
	let wrongSound = SKAction.playSoundFileNamed("wrong", waitForCompletion: false)
	let finishedSound = SKAction.playSoundFileNamed("notification-3", waitForCompletion: false)
	let revealSound = SKAction.playSoundFileNamed("display_sweep", waitForCompletion: false)

	//MARK: Layout

	/// The wall sits right of centre, leaving the left for two columns of teams
	private static let gridLeft: CGFloat = 860
	private static let gridRightMargin: CGFloat = 50
	private static let gridTopMargin: CGFloat = 140
	private static let gridBottom: CGFloat = 50
	private static let gap: CGFloat = 14

	private static let teamLeft: CGFloat = 40
	private static let teamWidth: CGFloat = 375
	private static let teamColumnGap: CGFloat = 20

	private var tileSize: CGSize {
		let width = (size.width - Self.gridRightMargin - Self.gridLeft - (3 * Self.gap)) / 4
		let height = (size.height - Self.gridTopMargin - Self.gridBottom - (3 * Self.gap)) / 4
		return CGSize(width: width, height: height)
	}

	private func slotCentre(row: Int, column: Int) -> CGPoint {
		let tile = tileSize
		return CGPoint(x: Self.gridLeft + tile.width / 2 + CGFloat(column) * (tile.width + Self.gap),
					   y: size.height - Self.gridTopMargin - tile.height / 2 - CGFloat(row) * (tile.height + Self.gap))
	}

	private var gridCentreX: CGFloat {
		(Self.gridLeft + size.width - Self.gridRightMargin) / 2
	}

	/// Group colours for the reveal
	static let groupColours = [
		NSColor(calibratedRed: 0.12, green: 0.36, blue: 0.68, alpha: 1.0),
		NSColor(calibratedRed: 0.05, green: 0.52, blue: 0.48, alpha: 1.0),
		NSColor(calibratedRed: 0.47, green: 0.26, blue: 0.66, alpha: 1.0),
		NSColor(calibratedRed: 0.72, green: 0.42, blue: 0.10, alpha: 1.0)
	]

	override func buildScene() {
		addBackground(texture: SKTexture(image: verticalGradientImage(size: size, colors: [
			NSColor(calibratedRed: 0.05, green: 0.10, blue: 0.22, alpha: 1.0),
			NSColor(calibratedRed: 0.01, green: 0.02, blue: 0.06, alpha: 1.0)])))

		let tile = tileSize
		for position in 0..<OnlyConnectWall.size {
			let node = WallTileNode(size: tile)
			node.position = slotCentre(row: position / 4, column: position % 4)
			node.zPosition = 10
			tiles.append(node)
			addChild(node)
		}

		//The connections are shown over their row once the wall has been sorted
		for row in 0..<4 {
			let label = OutlinedLabelNode(text: "", fontNamed: ".AppleSystemUIFontBold", fontSize: 72, fontColor: .white, outlineWidth: 6)
			label.position = CGPoint(x: gridCentreX, y: slotCentre(row: row, column: 0).y)
			label.zPosition = 20
			label.alpha = 0
			connectionLabels.append(label)
			addChild(label)
		}

		clockLabel = OutlinedLabelNode(text: "0:00", fontNamed: ".AppleSystemUIFontBold", fontSize: 80, fontColor: .white, outlineWidth: 5)
		clockLabel.position = CGPoint(x: gridCentreX, y: size.height - Self.gridTopMargin / 2)
		clockLabel.zPosition = 10
		addChild(clockLabel)

		//Two columns of teams down the left, filled column by column
		let numTeams = Settings.shared.numTeams
		let rows = max(1, Int((Double(numTeams) / 2).rounded(.up)))
		let pitch = min(160, (size.height - 80) / CGFloat(rows))
		let boxHeight = pitch - 14
		for team in 0..<numTeams {
			let column = team / rows
			let row = team % rows
			let node = WallTeamNode(team: team, size: CGSize(width: Self.teamWidth, height: boxHeight))
			node.position = CGPoint(
				x: Self.teamLeft + Self.teamWidth / 2 + CGFloat(column) * (Self.teamWidth + Self.teamColumnGap),
				y: size.height - 40 - pitch / 2 - CGFloat(row) * pitch)
			node.zPosition = 10
			teamNodes.append(node)
			addChild(node)
		}

		reset()
	}

	//MARK: Setting up

	/// A new question, or nil for none. Leaves the wall face down.
	func load(_ wall: OnlyConnectWall?) {
		self.wall = wall
		reset()
	}

	override func reset() {
		phase = .waiting
		startedAt = nil
		revealStep = 0
		progress = [WallProgress](repeating: WallProgress(), count: Settings.shared.numTeams)
		clockLabel?.text = "0:00"

		for (position, tile) in tiles.enumerated() {
			tile.removeAllActions()
			tile.position = slotCentre(row: position / 4, column: position % 4)
			tile.alpha = 1
			tile.showFaceDown()
		}
		for label in connectionLabels {
			label.removeAllActions()
			label.alpha = 0
		}
		for node in teamNodes {
			node.reset()
		}
		refreshParticipation()
	}

	override func setParticipating(_ teams: [Bool]) {
		participating = teams
		refreshParticipation()
	}

	private func isParticipating(_ team: Int) -> Bool {
		team < participating.count ? participating[team] : true
	}

	private func refreshParticipation() {
		for (team, node) in teamNodes.enumerated() {
			node.alpha = isParticipating(team) ? 1.0 : 0.3
		}
	}

	//MARK: Running

	func start() {
		guard let wall, phase == .waiting else { return }
		phase = .running
		startedAt = Date()

		//Turned over left to right, top to bottom
		for (position, tile) in tiles.enumerated() {
			let word = wall.word(at: position)
			tile.run(.sequence([
				.wait(forDuration: 0.04 * Double(position)),
				.scaleX(to: 0, duration: 0.12),
				.run { tile.showWord(word) },
				.scaleX(to: 1, duration: 0.12)
			]))
		}
		run(revealSound)
	}

	func stop() {
		guard phase == .running else { return }
		phase = .stopped
		updateClock()
		QuizWebSocket.shared?.pulseWhite()
	}

	var elapsed: TimeInterval {
		guard let startedAt else { return 0 }
		return Date().timeIntervalSince(startedAt)
	}

	/// Every team that is playing has found all four groups
	var everyoneFinished: Bool {
		let playing = (0..<progress.count).filter { isParticipating($0) }
		return !playing.isEmpty && playing.allSatisfy { progress[$0].finished }
	}

	override func update(_ currentTime: TimeInterval) {
		if phase == .running {
			updateClock()
		}
	}

	private func updateClock() {
		let text = Self.format(elapsed)
		if clockLabel.text != text {
			clockLabel.text = text
		}
	}

	static func format(_ seconds: TimeInterval) -> String {
		let whole = Int(seconds)
		return String(format: "%d:%02d", whole / 60, whole % 60)
	}

	/// Where a team came among those that have finished, counting from 1
	func rank(of team: Int) -> Int? {
		guard let time = progress[team].finishedAfter else { return nil }
		return 1 + progress.filter { ($0.finishedAfter ?? .infinity) < time }.count
	}

	//MARK: Guesses

	/// Judges four tiles from one team. `positions` are 0-based.
	func guess(team: Int, positions: [Int]) -> Verdict {
		guard let wall, phase == .running,
			  team >= 0, team < progress.count,
			  !progress[team].finished,
			  positions.count == 4, Set(positions).count == 4,
			  positions.allSatisfy({ $0 >= 0 && $0 < OnlyConnectWall.size }) else {
			return .ignored
		}
		let groups = Set(positions.map { wall.group(at: $0) })
		guard groups.isDisjoint(with: progress[team].found) else {
			return .ignored
		}

		guard groups.count == 1, let group = groups.first else {
			progress[team].wrong += 1
			teamNodes[team].showWrong(count: progress[team].wrong)
			run(wrongSound)
			return .wrong(positions)
		}

		var solved = [group]
		progress[team].found.append(group)
		//With three found, the last four can only be the fourth group
		if progress[team].found.count == 3, let last = (0..<4).first(where: { !progress[team].found.contains($0) }) {
			progress[team].found.append(last)
			solved.append(last)
		}
		teamNodes[team].showFound(count: progress[team].found.count)

		if progress[team].finished {
			progress[team].finishedAfter = elapsed
			teamNodes[team].showFinished(time: Self.format(elapsed), rank: rank(of: team) ?? 0)
			run(finishedSound)
			QuizWebSocket.shared?.pulseTeamColour(team)
		} else {
			run(solvedSound)
		}
		return .solved(solved.map { wall.positions(of: $0) })
	}

	//MARK: Reveal

	/// The rows whose connection has a name, in the order they are shown
	private var namedRows: [Int] {
		guard let wall else { return [] }
		return (0..<4).filter { wall.groups[$0].connection != nil }
	}

	/// What the next press of the reveal button will do, or nil when there is nothing left
	var nextRevealTitle: String? {
		guard wall != nil, phase != .waiting else { return nil }
		if revealStep == 0 {
			return "Sort into groups"
		}
		let shown = revealStep - 1
		return shown < namedRows.count ? "Show connection \(shown + 1)" : nil
	}

	/// Sorts the wall into its groups, then shows the connections one at a time.
	/// Stops the wall first if it is still running.
	func revealNext() {
		guard let wall, phase != .waiting else { return }
		stop()

		if revealStep == 0 {
			revealStep = 1
			//Each group gets its own row, keeping the order the tiles were in
			for group in 0..<4 {
				for (column, position) in wall.positions(of: group).enumerated() {
					let tile = tiles[position]
					let move = SKAction.move(to: slotCentre(row: group, column: column), duration: 0.6)
					move.timingMode = .easeInEaseOut
					tile.run(.sequence([.wait(forDuration: 0.15 * Double(group)), move]))
					tile.showWord(wall.word(at: position), colour: Self.groupColours[group])
				}
			}
			run(revealSound)
			return
		}

		let shown = revealStep - 1
		guard shown < namedRows.count else { return }
		revealStep += 1

		let row = namedRows[shown]
		let label = connectionLabels[row]
		label.text = wall.groups[row].connection
		//Shrunk to fit across the wall rather than wrapped
		let room = size.width - Self.gridRightMargin - Self.gridLeft - 40
		label.setScale(1)
		let width = label.calculateAccumulatedFrame().width
		if width > room {
			label.setScale(room / width)
		}
		label.run(.fadeIn(withDuration: 0.3))
		for position in wall.positions(of: row) {
			tiles[position].run(.fadeAlpha(to: 0.3, duration: 0.3))
		}
		QuizWebSocket.shared?.pulseWhite()
	}
}


// MARK: - Nodes

/// One tile of the wall
class WallTileNode: SKNode {

	private let box: SKShapeNode
	private let label = SKLabelNode()
	private let tileSize: CGSize

	static let faceDownColour = NSColor(calibratedRed: 0.20, green: 0.27, blue: 0.40, alpha: 0.6)
	static let faceUpColour = NSColor(calibratedRed: 0.85, green: 0.91, blue: 0.97, alpha: 1.0)
	static let faceUpText = NSColor(calibratedRed: 0.08, green: 0.16, blue: 0.30, alpha: 1.0)

	private static let padding: CGFloat = 16
	private static let maxFontSize: CGFloat = 56
	private static let minFontSize: CGFloat = 16

	init(size: CGSize) {
		tileSize = size
		box = SKShapeNode(rectOf: size, cornerRadius: 14)
		box.lineWidth = 3
		super.init()

		label.numberOfLines = 0
		label.preferredMaxLayoutWidth = size.width - 2 * Self.padding
		label.horizontalAlignmentMode = .center
		label.verticalAlignmentMode = .center
		label.zPosition = 1

		addChild(box)
		addChild(label)
		showFaceDown()
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func showFaceDown() {
		box.fillColor = Self.faceDownColour
		box.strokeColor = Self.faceDownColour.withAlphaComponent(0.9)
		label.attributedText = nil
	}

	/// - Parameter colour: the tile's group colour once sorted, or nil for the plain face
	func showWord(_ word: String, colour: NSColor? = nil) {
		box.fillColor = colour ?? Self.faceUpColour
		box.strokeColor = (colour ?? Self.faceUpColour).blended(withFraction: 0.3, of: .white) ?? .white
		label.attributedText = Self.fitted(word, colour: colour == nil ? Self.faceUpText : .white,
										   in: CGSize(width: tileSize.width - 2 * Self.padding,
													  height: tileSize.height - 2 * Self.padding))
	}

	/// The largest size at which every word fits across the tile, so that a long word
	/// shrinks rather than being broken in the middle, and the whole clue fits down it.
	private static func fitted(_ text: String, colour: NSColor, in room: CGSize) -> NSAttributedString {
		let paragraph = NSMutableParagraphStyle()
		paragraph.alignment = .center
		paragraph.lineBreakMode = .byWordWrapping

		var fontSize = maxFontSize
		while true {
			let attributes: [NSAttributedString.Key: Any] = [
				.font: NSFont.boldSystemFont(ofSize: fontSize),
				.foregroundColor: colour,
				.paragraphStyle: paragraph
			]
			let string = NSAttributedString(string: text, attributes: attributes)
			let widest = text.split(separator: " ")
				.map { NSAttributedString(string: String($0), attributes: attributes).size().width }
				.max() ?? 0
			let height = string.boundingRect(with: CGSize(width: room.width, height: .greatestFiniteMagnitude),
											 options: [.usesLineFragmentOrigin, .usesFontLeading]).height
			if fontSize <= minFontSize || (widest <= room.width && height <= room.height) {
				return string
			}
			fontSize -= 2
		}
	}
}


/// One team's box down the side: groups found, wrong guesses, and time once finished
class WallTeamNode: SKNode {

	private let team: Int
	private let box: SKShapeNode
	private var pips = [SKShapeNode]()
	private let timeLabel = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	private let wrongLabel = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	private let wrongCaption = SKLabelNode(fontNamed: ".AppleSystemUIFont")

	static let pipColour = NSColor(calibratedRed: 0.25, green: 0.85, blue: 0.40, alpha: 1.0)
	static let wrongColour = NSColor(calibratedRed: 1.0, green: 0.35, blue: 0.35, alpha: 1.0)
	private static let restingFill = NSColor(calibratedWhite: 1.0, alpha: 0.08)

	init(team: Int, size: CGSize) {
		self.team = team
		box = SKShapeNode(rectOf: size, cornerRadius: 10)
		super.init()

		box.fillColor = Self.restingFill
		box.strokeColor = Utils.teamColour(team, saturation: 0.7)
		box.lineWidth = 3
		addChild(box)

		//The team number, in a square of its colour at the left
		let side = size.height - 16
		let square = SKShapeNode(rectOf: CGSize(width: side, height: side), cornerRadius: 8)
		square.fillColor = Utils.teamColour(team, saturation: 0.75, brightness: 0.8)
		square.strokeColor = .clear
		square.position = CGPoint(x: -size.width / 2 + 8 + side / 2, y: 0)
		addChild(square)
		let number = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		number.text = String(team + 1)
		number.fontSize = side * 0.6
		number.verticalAlignmentMode = .center
		number.horizontalAlignmentMode = .center
		square.addChild(number)

		//A pip for each group a team has to find, with the finishing time beneath them. The
		//fourth group solves itself along with the third, so it gets no pip of its own.
		let middleLeft = -size.width / 2 + 16 + side + 4
		let pip = size.height * 0.26
		for i in 0..<3 {
			let node = SKShapeNode(rectOf: CGSize(width: pip, height: pip), cornerRadius: 4)
			node.lineWidth = 2
			node.position = CGPoint(x: middleLeft + pip / 2 + CGFloat(i) * (pip + 8), y: size.height * 0.18)
			pips.append(node)
			addChild(node)
		}
		timeLabel.fontSize = size.height * 0.26
		timeLabel.fontColor = .white
		timeLabel.horizontalAlignmentMode = .left
		timeLabel.verticalAlignmentMode = .center
		timeLabel.position = CGPoint(x: middleLeft, y: -size.height * 0.2)
		addChild(timeLabel)

		//Wrong guesses at the right, big enough to read from the back. Right-aligned, so that
		//a count in double figures grows into the space left of it.
		let wrongX = size.width / 2 - 14
		wrongLabel.fontSize = size.height * 0.5
		wrongLabel.fontColor = Self.wrongColour
		wrongLabel.horizontalAlignmentMode = .right
		wrongLabel.verticalAlignmentMode = .center
		wrongLabel.position = CGPoint(x: wrongX, y: size.height * 0.1)
		addChild(wrongLabel)
		wrongCaption.text = "wrong"
		wrongCaption.fontSize = size.height * 0.16
		wrongCaption.fontColor = NSColor(calibratedWhite: 0.75, alpha: 1.0)
		wrongCaption.horizontalAlignmentMode = .right
		wrongCaption.verticalAlignmentMode = .center
		wrongCaption.position = CGPoint(x: wrongX, y: -size.height * 0.3)
		addChild(wrongCaption)

		reset()
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func reset() {
		removeAllActions()
		box.removeAllActions()
		box.fillColor = Self.restingFill
		setFound(0)
		wrongLabel.text = "0"
		timeLabel.text = ""
	}

	/// Lights a pip per group found, the third standing for the last two
	private func setFound(_ count: Int) {
		for (i, pip) in pips.enumerated() {
			pip.fillColor = i < count ? Self.pipColour : .clear
			pip.strokeColor = i < count ? Self.pipColour : NSColor(calibratedWhite: 1.0, alpha: 0.4)
		}
	}

	func showFound(count: Int) {
		setFound(count)
		if count > 0 {
			pips[min(count, pips.count) - 1].run(.sequence([.scale(to: 1.4, duration: 0.1), .scale(to: 1.0, duration: 0.2)]))
		}
		flash(Self.pipColour)
	}

	func showWrong(count: Int) {
		wrongLabel.text = String(count)
		wrongLabel.run(.sequence([.scale(to: 1.4, duration: 0.08), .scale(to: 1.0, duration: 0.2)]))
		flash(Self.wrongColour)
		let x = position.x
		run(.sequence([
			.moveTo(x: x - 8, duration: 0.04), .moveTo(x: x + 8, duration: 0.08),
			.moveTo(x: x - 5, duration: 0.07), .moveTo(x: x, duration: 0.05)
		]))
	}

	func showFinished(time: String, rank: Int) {
		timeLabel.text = "\(time)  \(Self.ordinal(rank))"
		box.removeAllActions()
		box.fillColor = Utils.teamColour(team, saturation: 0.6, brightness: 0.45)
	}

	private func flash(_ colour: NSColor) {
		let settled = box.fillColor
		box.removeAllActions()
		box.fillColor = colour.withAlphaComponent(0.6)
		box.run(.sequence([.wait(forDuration: 0.25), .run { [weak self] in
			guard let self, self.box.fillColor != settled else { return }
			self.box.fillColor = settled
		}]))
	}

	static func ordinal(_ n: Int) -> String {
		let suffix: String
		switch (n % 10, n % 100) {
		case (_, 11...13): suffix = "th"
		case (1, _): suffix = "st"
		case (2, _): suffix = "nd"
		case (3, _): suffix = "rd"
		default: suffix = "th"
		}
		return "\(n)\(suffix)"
	}
}


// MARK: - Controller window

class OnlyConnectPanel: NSObject, RoundPanel {

	let round = RoundType.onlyConnect
	weak var host: ControllerWindowController!

	@IBOutlet weak var questionSelector: NSPopUpButton!
	@IBOutlet weak var startButton: NSButton!
	@IBOutlet weak var revealButton: NSButton!
	@IBOutlet var statusText: NSTextView!

	/// Why the chosen question could not be used, if it could not
	private var loadError: String?

	private var scene: OnlyConnectScene { host.quizDisplay.onlyConnectScene }

	private var isLive: Bool { host.quizDisplay.currentRound == round }

	func setUp() {
		questionSelector.removeAllItems()
		for file in Utils.questionFiles(in: Settings.shared.onlyConnectPath) {
			questionSelector.addItem(withTitle: file)
		}
		if questionSelector.numberOfItems > 0 {
			questionSelected(questionSelector!)
		} else {
			loadError = "No questions in \(Settings.shared.onlyConnectPath)"
			refreshControls()
		}
	}

	func reset(presenting: Bool) {
		pushWall()
		refreshControls()
	}

	func clientTeamState(team: Int) -> [ClientState] {
		guard let wall = scene.wall, scene.phase != .waiting, team < scene.progress.count else {
			return [.wall([])]
		}
		return [.wall(wall.words)]
			+ scene.progress[team].found.map { .wallSolved(Self.wire(wall.positions(of: $0))) }
			+ (scene.phase == .stopped ? [.wallFrozen] : [])
	}

	/// Positions go out 1-based
	private static func wire(_ positions: [Int]) -> [Int] {
		positions.map { $0 + 1 }
	}

	@IBAction func questionSelected(_ sender: Any) {
		guard let title = questionSelector.selectedItem?.title else { return }
		let path = Settings.shared.onlyConnectPath + "/" + title

		var wall: OnlyConnectWall? = nil
		if let text = Utils.readQuestionFile(path) {
			switch OnlyConnectWall.parse(text) {
			case .success(let parsed):
				wall = parsed
				loadError = nil
			case .failure(let error):
				loadError = "\(title): \(error)"
			}
		} else {
			loadError = "Could not read \(title)"
		}

		scene.load(wall)
		if isLive {
			pushWall()
		}
		refreshControls()
	}

	@IBAction func startStop(_ sender: Any) {
		switch scene.phase {
		case .waiting:
			scene.start()
		case .running:
			scene.stop()
		case .stopped:
			return
		}
		pushWall()
		refreshControls()
	}

	@IBAction func reveal(_ sender: Any) {
		let wasRunning = scene.phase == .running
		scene.revealNext()
		if wasRunning {
			pushWall()
		}
		refreshControls()
	}

	/// Four tiles from a team's phone, 1-based as they arrive
	func guess(team: Int, positions: [Int]) {
		guard isLive else { return }

		switch scene.guess(team: team, positions: positions.map { $0 - 1 }) {
		case .solved(let groups):
			for group in groups {
				host.send(.resync(team: team, state: .wallSolved(Self.wire(group))))
			}
		case .wrong(let tiles):
			host.send(.resync(team: team, state: .wallWrong(Self.wire(tiles))))
		case .ignored:
			//Whatever the phone thought was going on, put it right
			sendState(team: team)
		}

		if scene.phase == .running && scene.everyoneFinished {
			scene.stop()
			pushWall()
		}
		refreshControls()
	}

	/// A phone asking for its wall, which it does whenever it arrives on the view
	func sendState(team: Int) {
		guard isLive else { return }
		for state in clientTeamState(team: team) {
			host.send(.resync(team: team, state: state))
		}
	}

	/// Puts every team's phone in step with the wall
	private func pushWall() {
		guard isLive else { return }
		for team in 0..<Settings.shared.numTeams {
			sendState(team: team)
		}
	}

	private func refreshControls() {
		switch scene.phase {
		case .waiting:
			startButton?.title = "Start"
			startButton?.isEnabled = scene.wall != nil
		case .running:
			startButton?.title = "Stop"
			startButton?.isEnabled = true
		case .stopped:
			startButton?.title = "Finished"
			startButton?.isEnabled = false
		}

		let next = scene.nextRevealTitle
		revealButton?.title = next ?? "Reveal"
		revealButton?.isEnabled = next != nil

		statusText?.string = statusLines().joined(separator: "\n")
	}

	/// The answers, for the host, and then how every team is doing
	private func statusLines() -> [String] {
		if let loadError {
			return ["⚠️ " + loadError]
		}
		guard let wall = scene.wall else { return [] }

		var lines = wall.groups.map { group in
			(group.connection.map { $0 + ": " } ?? "") + group.clues.joined(separator: ", ")
		}
		lines.append("")

		//Finished teams in the order they finished, then the rest by team number
		let teams = (0..<scene.progress.count).sorted { a, b in
			let ta = scene.progress[a].finishedAfter ?? .infinity
			let tb = scene.progress[b].finishedAfter ?? .infinity
			return ta != tb ? ta < tb : a < b
		}
		for team in teams {
			let p = scene.progress[team]
			var line = "Team \(team + 1): \(p.found.count) found, \(p.wrong) wrong"
			if let time = p.finishedAfter, let rank = scene.rank(of: team) {
				line += ", \(OnlyConnectScene.format(time)) (\(WallTeamNode.ordinal(rank)))"
			}
			lines.append(line)
		}
		return lines
	}
}
