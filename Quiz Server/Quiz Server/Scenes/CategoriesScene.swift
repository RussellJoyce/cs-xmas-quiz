//
//  CategoriesScene.swift
//  Quiz Server
//
//  Created by Ian Gray on 2026-11-23.
//  Copyright © 2026 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import SpriteKit

/// A category with twenty or thirty right answers, shown as a board of blank slots.
/// Teams buzz in for the right to guess; the host marks each guess as one of the answers,
/// which fills its slot, or types it in as wrong, which adds it to the strip along the bottom.
class CategoriesScene: QuizScene {

	// MARK: The question

	/// The part of the file's first line before " - ", shown as the heading
	private(set) var heading = ""
	/// Whatever followed the " - ", if anything
	private(set) var subheading = ""
	/// In the file's order, which is also the order of the slots
	private(set) var answers = [String]()

	// MARK: The state of play

	/// Answers found, by index into `answers`, in the order they were marked. This is also the
	/// order of the slots, so the board does not give away where in the alphabet the rest lie.
	private(set) var foundOrder = [Int]()
	/// One per answer
	var found: [Bool] { answers.indices.map { foundOrder.contains($0) } }
	/// In the order the host typed them
	private(set) var wrongGuesses = [String]()
	/// Whether the answers nobody found are showing
	private(set) var revealed = false
	/// Teams in the order they buzzed, zero-based
	private(set) var buzzes = [Int]()
	private var teamEnabled = [Bool]()

	// MARK: Nodes

	private var headingLabel: SKLabelNode?
	private var subheadingLabel: SKLabelNode?
	private var counterLabel: SKLabelNode?
	private var slots = [Slot]()
	private var wrongNodes = [SKNode]()
	private var buzzBoxes = [BuzzerTeamNode]()
	private var bokeh: SKEmitterNode?
	private var pulseAction: SKAction?

	// MARK: Media

	private let foundSound = Sound.effect("circle_illuminates")
	private let wrongSound = Sound.effect("counter_wrong")
	private let revealSound = Sound.effect("display_sweep")
	private let removeSound = Sound.effect("quietbuzz2")
	private let buzzNoise = Sound.effect("buzzer")

	// MARK: Layout

	private static let font = "PT Sans Caption Bold"
	/// The board fills the left of the screen; the buzz stack has the column on the right
	private static let boardLeft: CGFloat = 40
	private static let boardRight: CGFloat = 1520
	private static let buzzColumnX: CGFloat = 1730
	private static let wrongStripTop: CGFloat = 170
	private static let wrongStripBottom: CGFloat = 25
	private static let maxBuzzes = 5

	private static let hiddenFill = NSColor(white: 1.0, alpha: 0.07)
	private static let hiddenStroke = NSColor(white: 1.0, alpha: 0.22)
	private static let foundFill = NSColor(calibratedRed: 0.08, green: 0.52, blue: 0.28, alpha: 0.95)
	private static let foundStroke = NSColor(calibratedRed: 1.0, green: 0.84, blue: 0.35, alpha: 1.0)
	private static let missedFill = NSColor(white: 1.0, alpha: 0.12)
	private static let missedText = NSColor(white: 0.8, alpha: 0.6)
	private static let wrongFill = NSColor(calibratedRed: 0.45, green: 0.05, blue: 0.08, alpha: 0.9)
	private static let wrongText = NSColor(calibratedRed: 1.0, green: 0.55, blue: 0.55, alpha: 1.0)

	/// One place on the board. Slots are filled in the order answers are found, not answer order.
	private struct Slot {
		let box: SKShapeNode
		let label: SKLabelNode
		let size: CGSize
		let maxTextWidth: CGFloat
		let fontSize: CGFloat
	}


	override func buildScene() {
		let background = radialGradientImage(size: size,
											 colors: [NSColor(calibratedRed: 0.10, green: 0.30, blue: 0.32, alpha: 1),
													  NSColor(calibratedRed: 0.04, green: 0.12, blue: 0.16, alpha: 1),
													  NSColor(calibratedRed: 0.01, green: 0.03, blue: 0.05, alpha: 1)],
											 locations: [0.0, 0.5, 1.0],
											 centre: CGPoint(x: size.width * 0.4, y: size.height * 0.6),
											 radius: hypot(size.width, size.height) * 0.6)
		let filterNode = addPulsableBackground(texture: SKTexture(image: background))
		pulseAction = Utils.createFilterPulse(upTime: 0.05, downTime: 0.4, filterNode: filterNode)

		bokeh = addBokehBackground(replacing: bokeh, textureName: "spark", zPosition: 0.5) {
			$0.particleBirthRate = 6
			$0.particleColor = NSColor(calibratedRed: 1.0, green: 0.85, blue: 0.5, alpha: 1)
			$0.particleColorBlendFactor = 1
			$0.particleBlendMode = .add
		}

		let heading = SKLabelNode(fontNamed: CategoriesScene.font)
		heading.fontSize = 68
		heading.fontColor = .white
		heading.verticalAlignmentMode = .center
		heading.position = CGPoint(x: boardCentreX, y: size.height - 75)
		heading.zPosition = 10
		addChild(heading)
		headingLabel = heading

		let subheading = SKLabelNode(fontNamed: CategoriesScene.font)
		subheading.fontSize = 30
		subheading.fontColor = NSColor(white: 1.0, alpha: 0.75)
		subheading.verticalAlignmentMode = .center
		subheading.position = CGPoint(x: boardCentreX, y: size.height - 135)
		subheading.zPosition = 10
		addChild(subheading)
		subheadingLabel = subheading

		let counter = SKLabelNode(fontNamed: CategoriesScene.font)
		counter.fontSize = 64
		counter.fontColor = CategoriesScene.foundStroke
		counter.verticalAlignmentMode = .center
		counter.position = CGPoint(x: CategoriesScene.buzzColumnX, y: size.height - 90)
		counter.zPosition = 10
		addChild(counter)
		counterLabel = counter

		layOutQuestion()
	}

	private var boardCentreX: CGFloat { (CategoriesScene.boardLeft + CategoriesScene.boardRight) / 2 }


	// MARK: - Questions

	/// Loads a question file: a title line, then one right answer per line.
	/// Returns a description of the problem if the file could not be used.
	@discardableResult
	func changeToQuestion(path: String) -> String? {
		guard let data = Utils.readQuestionFile(path) else {
			load(title: "", answers: [])
			return "Could not read question file:\n\(path)"
		}
		//Markdown headings and list bullets are allowed, so the files read well in an editor
		let lines = data.components(separatedBy: .newlines)
			.map { CategoriesScene.stripMarkdown($0) }
			.filter { !$0.isEmpty }
		guard let title = lines.first else {
			load(title: "", answers: [])
			return "Question file is empty:\n\(path)"
		}
		load(title: title, answers: Array(lines.dropFirst()))
		return nil
	}

	private static func stripMarkdown(_ line: String) -> String {
		var text = line.trimmingCharacters(in: .whitespaces)
		while text.hasPrefix("#") { text.removeFirst() }
		for bullet in ["- ", "* ", "+ "] where text.hasPrefix(bullet) {
			text.removeFirst(bullet.count)
		}
		return text.trimmingCharacters(in: .whitespaces)
	}

	private func load(title: String, answers: [String]) {
		if let split = title.range(of: " - ") {
			heading = String(title[..<split.lowerBound]).trimmingCharacters(in: .whitespaces)
			subheading = String(title[split.upperBound...]).trimmingCharacters(in: .whitespaces)
		} else {
			heading = title
			subheading = ""
		}
		self.answers = answers
		clearPlay()
		if isSetUp {
			layOutQuestion()
		}
	}


	// MARK: - Marking

	/// Marks an answer found, or takes the mark away again
	func setFound(_ index: Int, _ isFound: Bool) {
		guard answers.indices.contains(index), foundOrder.contains(index) != isFound else { return }
		if isFound {
			foundOrder.append(index)
			run(foundSound)
			backgroundEffect?.run(pulseAction!)
			QuizWebSocket.shared?.pulseGreen()
			refreshSlot(foundOrder.count - 1, animated: true)
		} else {
			//Those found after it move up a place to close the gap
			let slot = foundOrder.firstIndex(of: index)!
			foundOrder.remove(at: slot)
			run(removeSound)
			for later in slot..<slots.count {
				removeAction(forKey: "reveal\(later)")
				refreshSlot(later, animated: false)
			}
		}
		refreshCounter()
	}

	/// Adds a wrong guess to the strip. A guess that is in fact one of the answers is marked
	/// found instead, as the host has typed it into the wrong place, and a repeat is ignored.
	/// Returns the index of the answer it matched, if it did.
	@discardableResult
	func addWrongGuess(_ guess: String) -> Int? {
		let text = guess.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !text.isEmpty else { return nil }
		let key = Utils.sanitiseString(text)

		if let match = answers.firstIndex(where: { Utils.sanitiseString($0) == key }) {
			setFound(match, true)
			return match
		}
		guard !wrongGuesses.contains(where: { Utils.sanitiseString($0) == key }) else { return nil }

		wrongGuesses.append(text)
		run(wrongSound)
		QuizWebSocket.shared?.pulseRed()
		layOutWrongGuesses(popIndex: wrongGuesses.count - 1)
		return nil
	}

	func removeWrongGuess(at index: Int) {
		guard wrongGuesses.indices.contains(index) else { return }
		wrongGuesses.remove(at: index)
		run(removeSound)
		layOutWrongGuesses(popIndex: nil)
	}

	/// Shows or hides the answers nobody found
	func setRevealed(_ reveal: Bool) {
		guard reveal != revealed else { return }
		revealed = reveal
		if reveal { run(revealSound) }

		var delay: TimeInterval = 0
		for slot in foundOrder.count..<slots.count {
			if reveal {
				//Ripple across the board rather than all at once
				run(SKAction.sequence([.wait(forDuration: delay), .run { [weak self] in self?.refreshSlot(slot, animated: true) }]),
					withKey: "reveal\(slot)")
				delay += 0.06
			} else {
				removeAction(forKey: "reveal\(slot)")
				refreshSlot(slot, animated: false)
			}
		}
	}


	// MARK: - Buzzers

	/// Always a queue, and always a sound for the first buzz. The buzzer options that would say
	/// otherwise live on the Buzzers tab, out of the host's reach during this round.
	override func buzzerPressed(team: Int, type: BuzzerType, options: BuzzerOptions) {
		guard teamEnabled.indices.contains(team), teamEnabled[team], buzzes.count < CategoriesScene.maxBuzzes else { return }
		teamEnabled[team] = false
		buzzes.append(team)

		let isFirst = buzzes.count == 1
		if isFirst {
			run(buzzNoise)
			QuizWebSocket.shared?.buzz(team: team)
		}

		//No entrance effects: they are too much beside the board
		let box = isFirst
			? BuzzerTeamNode(team: team, width: 340, height: 110, fontSize: 64, addGlow: true,
							 entranceFlash: false, style: .glossy)
			: BuzzerTeamNode(team: team, width: 290, height: 72, fontSize: 44,
							 entranceFlash: false, style: .glossy)
		let firstY = size.height - 260
		box.position = CGPoint(x: CategoriesScene.buzzColumnX,
							   y: isFirst ? firstY : firstY - 115 - CGFloat(buzzes.count - 2) * 90)
		box.zPosition = 20
		buzzBoxes.append(box)
		addChild(box)
		backgroundEffect?.run(pulseAction!)
	}

	/// Empties the buzz stack and lets every team buzz again
	func clearBuzzes() {
		buzzBoxes.forEach { $0.removeFromParent() }
		buzzBoxes.removeAll()
		buzzes.removeAll()
		teamEnabled = [Bool](repeating: true, count: Settings.shared.numTeams)
		QuizWebSocket.shared?.ledsOff()
	}


	// MARK: - Resetting

	override func reset() {
		clearPlay()
		if isSetUp {
			layOutQuestion()
		}
	}

	private func clearPlay() {
		foundOrder.removeAll()
		wrongGuesses.removeAll()
		revealed = false
		clearBuzzes()
	}


	// MARK: - Drawing

	/// Rebuilds the board for the current question and state of play
	private func layOutQuestion() {
		headingLabel?.text = heading
		subheadingLabel?.text = subheading
		fit(headingLabel, width: CategoriesScene.boardRight - CategoriesScene.boardLeft, fontSize: 68)
		fit(subheadingLabel, width: CategoriesScene.boardRight - CategoriesScene.boardLeft, fontSize: 30)

		slots.forEach { $0.box.removeFromParent() }
		slots.removeAll()
		layOutSlots()
		for slot in slots.indices {
			removeAction(forKey: "reveal\(slot)")
			refreshSlot(slot, animated: false)
		}
		layOutWrongGuesses(popIndex: nil)
		refreshCounter()
	}

	private func layOutSlots() {
		let count = answers.count
		guard count > 0 else { return }

		let columns: Int
		switch count {
		case 0...10:  columns = 2
		case 11...36: columns = 3
		default:      columns = 4
		}
		let rows = Int((Double(count) / Double(columns)).rounded(.up))

		let top = size.height - (subheading.isEmpty ? 150 : 190)
		let bottom = CategoriesScene.wrongStripTop + 15
		let cellWidth = (CategoriesScene.boardRight - CategoriesScene.boardLeft) / CGFloat(columns)
		let cellHeight = (top - bottom) / CGFloat(rows)
		let boxWidth = cellWidth - 16
		let boxHeight = min(90, cellHeight * 0.84)
		let fontSize = min(44, boxHeight * 0.6)

		for index in 0..<count {
			//Down the columns, so the answers read as a list in the order they were found
			let column = index / rows
			let row = index % rows
			let centre = CGPoint(x: CategoriesScene.boardLeft + (CGFloat(column) + 0.5) * cellWidth,
								 y: top - (CGFloat(row) + 0.5) * cellHeight)

			let box = SKShapeNode(rectOf: CGSize(width: boxWidth, height: boxHeight), cornerRadius: boxHeight * 0.2)
			box.position = centre
			box.zPosition = 5
			box.lineWidth = 2
			addChild(box)

			let label = SKLabelNode(fontNamed: CategoriesScene.font)
			label.verticalAlignmentMode = .center
			label.horizontalAlignmentMode = .center
			label.zPosition = 1
			box.addChild(label)

			slots.append(Slot(box: box, label: label, size: CGSize(width: boxWidth, height: boxHeight),
							  maxTextWidth: boxWidth - 24, fontSize: fontSize))
		}
	}

	/// What a slot shows: an answer found, by index into `answers`, or one missed
	private enum SlotContent { case hidden, found(Int), missed(Int) }

	/// The found answers fill the slots from the first, in the order they were found. Once
	/// revealed, the missed ones follow them in the file's order.
	private func content(ofSlot slot: Int) -> SlotContent {
		if slot < foundOrder.count { return .found(foundOrder[slot]) }
		guard revealed else { return .hidden }
		let missed = answers.indices.filter { !foundOrder.contains($0) }
		let place = slot - foundOrder.count
		return missed.indices.contains(place) ? .missed(missed[place]) : .hidden
	}

	private func refreshSlot(_ slotIndex: Int, animated: Bool) {
		guard slots.indices.contains(slotIndex) else { return }
		let slot = slots[slotIndex]
		slot.box.removeAllActions()
		slot.box.setScale(1)
		slot.label.removeAllActions()
		slot.label.alpha = 1

		switch content(ofSlot: slotIndex) {
		case .hidden:
			slot.box.fillColor = CategoriesScene.hiddenFill
			slot.box.strokeColor = CategoriesScene.hiddenStroke
			//Not just invisible: nothing on the scene may give an answer away
			slot.label.text = nil
		case .found(let index):
			slot.box.strokeColor = CategoriesScene.foundStroke
			slot.label.text = answers[index]
			slot.label.fontColor = .white
			fit(slot.label, width: slot.maxTextWidth, fontSize: slot.fontSize)
			if animated {
				slot.box.fillColor = .white
				slot.box.setScale(1.25)
				let pop = SKAction.scale(to: 1.0, duration: 0.3)
				pop.timingMode = .easeOut
				let fade = SKAction.customAction(withDuration: 0.5) { node, elapsed in
					let t = elapsed / 0.5
					(node as? SKShapeNode)?.fillColor = NSColor.white.blended(withFraction: t, of: CategoriesScene.foundFill) ?? CategoriesScene.foundFill
				}
				slot.box.run(.group([pop, fade]))
				//A short burst from the whole slot, not left running: it is a continuous emitter
				//and would hide the answer
				let sparks = addEmitter(named: "SparksPointless", at: slot.box.position, zPosition: 6, autoRemove: false) {
					$0.particlePositionRange = CGVector(dx: slot.size.width, dy: slot.size.height)
					$0.emissionAngleRange = .pi * 2
				}
				let ttl = TimeInterval(sparks.particleLifetime + sparks.particleLifetimeRange / 2)
				sparks.run(.sequence([.wait(forDuration: 0.25),
									  .run { sparks.particleBirthRate = 0 },
									  .wait(forDuration: ttl),
									  .removeFromParent()]))
			} else {
				slot.box.fillColor = CategoriesScene.foundFill
			}
		case .missed(let index):
			slot.box.fillColor = CategoriesScene.missedFill
			slot.box.strokeColor = CategoriesScene.hiddenStroke
			slot.label.text = answers[index]
			slot.label.fontColor = CategoriesScene.missedText
			fit(slot.label, width: slot.maxTextWidth, fontSize: slot.fontSize)
			if animated {
				slot.label.alpha = 0
				slot.label.run(.fadeIn(withDuration: 0.4))
			}
		}
	}

	private func refreshCounter() {
		counterLabel?.text = answers.isEmpty ? "" : "\(foundOrder.count) / \(answers.count)"
	}

	/// The wrong guesses flow along the bottom as red tags, shrinking if they need a third row
	private func layOutWrongGuesses(popIndex: Int?) {
		wrongNodes.forEach { $0.removeFromParent() }
		wrongNodes.removeAll()
		guard !wrongGuesses.isEmpty else { return }

		let width = CategoriesScene.buzzColumnX + 170 - CategoriesScene.boardLeft
		let height = CategoriesScene.wrongStripTop - CategoriesScene.wrongStripBottom

		//The largest size at which they all fit
		var chosen: (fontSize: CGFloat, placed: [(CGPoint, CGSize, SKLabelNode)])?
		for fontSize: CGFloat in [36, 30, 25, 21, 18] {
			let placed = flowWrongGuesses(fontSize: fontSize, width: width)
			chosen = (fontSize, placed)
			let used = placed.map { CategoriesScene.wrongStripTop - $0.0.y + $0.1.height / 2 }.max() ?? 0
			if used <= height { break }
		}
		guard let (_, placed) = chosen else { return }

		for (index, (centre, size, label)) in placed.enumerated() {
			let tag = SKShapeNode(rectOf: size, cornerRadius: size.height / 2)
			tag.fillColor = CategoriesScene.wrongFill
			tag.strokeColor = CategoriesScene.wrongText.withAlphaComponent(0.6)
			tag.lineWidth = 2
			tag.position = centre
			tag.zPosition = 8
			tag.addChild(label)
			addChild(tag)
			wrongNodes.append(tag)

			if index == popIndex {
				tag.setScale(1.6)
				tag.alpha = 0
				let scale = SKAction.scale(to: 1, duration: 0.25)
				scale.timingMode = .easeOut
				tag.run(.group([scale, .fadeIn(withDuration: 0.2)]))
			}
		}
	}

	private func flowWrongGuesses(fontSize: CGFloat, width: CGFloat) -> [(CGPoint, CGSize, SKLabelNode)] {
		let tagHeight = fontSize * 1.5
		let gap: CGFloat = 14
		var x = CategoriesScene.boardLeft
		var y = CategoriesScene.wrongStripTop - tagHeight / 2
		var out = [(CGPoint, CGSize, SKLabelNode)]()

		for guess in wrongGuesses {
			let label = SKLabelNode(fontNamed: CategoriesScene.font)
			label.text = "✗ " + guess
			label.fontSize = fontSize
			label.fontColor = CategoriesScene.wrongText
			label.verticalAlignmentMode = .center
			label.horizontalAlignmentMode = .center
			label.zPosition = 1
			fit(label, width: width - fontSize, fontSize: fontSize)

			let tagWidth = label.frame.width + fontSize
			if x + tagWidth > CategoriesScene.boardLeft + width && x > CategoriesScene.boardLeft {
				x = CategoriesScene.boardLeft
				y -= tagHeight + 10
			}
			out.append((CGPoint(x: x + tagWidth / 2, y: y), CGSize(width: tagWidth, height: tagHeight), label))
			x += tagWidth + gap
		}
		return out
	}

	/// Sets the label's size, shrinking it if need be to keep it within `width`
	private func fit(_ label: SKLabelNode?, width: CGFloat, fontSize: CGFloat) {
		guard let label else { return }
		label.fontSize = fontSize
		let natural = label.frame.width
		if natural > width && natural > 0 {
			label.fontSize = floor(fontSize * width / natural)
		}
	}
}



// MARK: - Controller window

class CategoriesPanel: NSObject, RoundPanel {

	let round = RoundType.categories
	weak var host: ControllerWindowController!

	@IBOutlet weak var questionSelector: NSPopUpButton!
	@IBOutlet weak var wrongGuessField: NSTextField!
	@IBOutlet weak var revealButton: NSButton!
	@IBOutlet weak var statusText: NSTextField!
	/// Document view of the answers' scroll view. The answer and wrong-guess buttons are made here,
	/// one per line of the question file.
	@IBOutlet weak var answerList: NSView!

	private(set) var answerButtons = [NSButton]()
	private(set) var wrongButtons = [NSButton]()
	private var loadedQuestion: String?

	private var scene: CategoriesScene { host.quizDisplay.categoriesScene }

	func setUp() {
		for file in Utils.questionFiles(in: Settings.shared.categoriesPath, extensions: ["md", "txt"]) {
			questionSelector.addItem(withTitle: file)
		}
		if questionSelector.numberOfItems > 0 {
			questionSelected(questionSelector!)
		} else {
			statusText.stringValue = "No questions in \(Settings.shared.categoriesPath)"
		}
	}

	func reset(presenting: Bool) {
		wrongGuessField.stringValue = ""
		rebuildList()
	}

	@IBAction func questionSelected(_ sender: Any) {
		guard let title = questionSelector.selectedItem?.title, title != loadedQuestion else { return }
		loadedQuestion = title
		let problem = scene.changeToQuestion(path: Settings.shared.categoriesPath + "/" + title)
		statusText.stringValue = problem ?? ""
		if host.quizDisplay.currentRound == round {
			host.enterRound(round, presenting: false)
		} else {
			rebuildList()
		}
	}

	@objc func answerToggled(_ sender: NSButton) {
		scene.setFound(sender.tag, sender.state == .on)
		refreshStatus()
	}

	/// The text field's action as well as the button's, so Return adds the guess
	@IBAction func addWrongGuess(_ sender: Any) {
		let guess = wrongGuessField.stringValue
		wrongGuessField.stringValue = ""
		if let matched = scene.addWrongGuess(guess) {
			statusText.stringValue = "\"\(guess)\" is right: marked \(scene.answers[matched])"
			answerButtons[matched].state = .on
		}
		rebuildWrongButtons()
		refreshStatus(keepMessage: true)
	}

	@objc func removeWrongGuess(_ sender: NSButton) {
		scene.removeWrongGuess(at: sender.tag)
		rebuildWrongButtons()
		refreshStatus()
	}

	@IBAction func revealToggled(_ sender: Any) {
		scene.setRevealed(revealButton.state == .on)
	}

	@IBAction func clearBuzzes(_ sender: Any) {
		scene.clearBuzzes()
	}

	private func refreshStatus(keepMessage: Bool = false) {
		guard !keepMessage || statusText.stringValue.isEmpty else { return }
		let found = scene.foundOrder.count
		statusText.stringValue = "\(found) of \(scene.answers.count) found, \(scene.wrongGuesses.count) wrong"
	}

	// MARK: The list of answers

	private static let rowHeight: CGFloat = 22
	private static let columns = 3

	private var answerRows: Int {
		Int((Double(scene.answers.count) / Double(CategoriesPanel.columns)).rounded(.up))
	}

	/// Puts the list back in step with the scene, as after a reset or a new question
	private func rebuildList() {
		answerButtons.forEach { $0.removeFromSuperview() }
		answerButtons.removeAll()

		let width = answerList.frame.width
		let columnWidth = (width - 8) / CGFloat(CategoriesPanel.columns)
		let rows = answerRows
		//Alphabetical for the host whatever the file's order. answerButtons stays in the file's
		//order, as the tags are, so only the position on the panel changes.
		let found = scene.found
		let alphabetical = scene.answers.indices.sorted {
			scene.answers[$0].localizedStandardCompare(scene.answers[$1]) == .orderedAscending
		}
		var place = [Int](repeating: 0, count: scene.answers.count)
		for (rank, index) in alphabetical.enumerated() { place[index] = rank }

		for (index, answer) in scene.answers.enumerated() {
			let toggle = NSButton(checkboxWithTitle: answer, target: self, action: #selector(answerToggled(_:)))
			toggle.tag = index
			toggle.state = found[index] ? .on : .off
			//Down the columns
			let column = place[index] / rows, row = place[index] % rows
			toggle.frame = NSRect(x: 4 + CGFloat(column) * columnWidth, y: 2 + CGFloat(row) * CategoriesPanel.rowHeight,
								  width: columnWidth - 4, height: CategoriesPanel.rowHeight - 4)
			answerList.addSubview(toggle)
			answerButtons.append(toggle)
		}
		revealButton.state = scene.revealed ? .on : .off
		rebuildWrongButtons()
		refreshStatus()
	}

	/// Wrong guesses go under the answers, one button each. Clicking one takes it off.
	private func rebuildWrongButtons() {
		wrongButtons.forEach { $0.removeFromSuperview() }
		wrongButtons.removeAll()

		let width = answerList.frame.width
		var x: CGFloat = 4
		var y = 8 + CGFloat(answerRows) * CategoriesPanel.rowHeight
		for (index, guess) in scene.wrongGuesses.enumerated() {
			let button = NSButton(title: "✗ " + guess, target: self, action: #selector(removeWrongGuess(_:)))
			button.tag = index
			button.bezelStyle = .inline
			button.contentTintColor = .systemRed
			button.toolTip = "Click to take this wrong guess off the screen"
			button.sizeToFit()
			if x + button.frame.width > width - 4 && x > 4 {
				x = 4
				y += CategoriesPanel.rowHeight
			}
			button.setFrameOrigin(NSPoint(x: x, y: y))
			answerList.addSubview(button)
			wrongButtons.append(button)
			x += button.frame.width + 6
		}

		let height = y + CategoriesPanel.rowHeight + 4
		answerList.setFrameSize(NSSize(width: width, height: max(height, answerList.enclosingScrollView?.contentSize.height ?? 0)))
	}
}
