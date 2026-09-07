//
//  WikiRaceScene.swift
//  Quiz Server
//
//  Created by Ian Gray on 2026-09-05.
//  Copyright © 2026 Russell Joyce & Ian Gray. All rights reserved.
//

import Foundation
import Cocoa
import SpriteKit

class WikiRaceScene: QuizScene {

	/// Where one team has got to.
	struct Progress {
		var title = ""
		var hops = 0
		var away = -1
		var finishedIn: Int?
		var hasStarted: Bool { return !title.isEmpty }
	}

	private(set) var progress = [Progress]()
	private var teamBoxes = [TeamAnswerNode]()
	private var participating = [Bool]()

	private let titleLabel = OutlinedLabelNode(text: "Wikirace", fontNamed: ".AppleSystemUIFontBold", fontSize: 44, fontColor: .white)
	private let targetLabel = OutlinedLabelNode(text: "", fontNamed: ".AppleSystemUIFontBold", fontSize: 72, fontColor: NSColor(calibratedRed: 0.27, green: 0.84, blue: 0.65, alpha: 1.0))

	private let blopSound = SKAction.playSoundFileNamed("blop", waitForCompletion: false)
	private let arrivedSound = SKAction.playSoundFileNamed("tada", waitForCompletion: false)

	var showDistance = false {
		didSet { refreshAll() }
	}

	private var startTitle = ""
	private var targetTitle = ""


	override func buildScene() {
		addBackground(imageNamed: "snowflakes-background")

		titleLabel.position = CGPoint(x: self.centrePoint.x, y: self.size.height - 62)
		titleLabel.zPosition = 10
		self.addChild(titleLabel)

		targetLabel.position = CGPoint(x: self.centrePoint.x, y: self.size.height - 138)
		targetLabel.zPosition = 10
		self.addChild(targetLabel)

		reset()
	}

	// MARK: - Types and Structures
	
	struct WikiRacePuzzle {
		let start: Int
		let target: Int
		let startTitle: String
		let targetTitle: String
		let hops: Int
		let route: [String]
		var menuTitle: String {
			return "\(startTitle)  →  \(targetTitle)   (\(hops) hops)"
		}
	}
	
	struct WikiRaceStanding {
		let team: Int
		let rank: Int
		let finished: Bool
		let seconds: Int
		let hops: Int
		let away: Int //Links still to go. Zero for a team that arrived.
	}
	
	var raceTrails = [Int: [String]]()
	var raceStandings = [WikiRaceStanding]()
	var raceBestRoute = [String]()
	var puzzles = [WikiRacePuzzle]()
	
	// MARK: - Puzzles and Paths

	func loadPuzzles(from directory: String) {
		guard !directory.isEmpty else { return }
		let file = "\(directory)/puzzles.json"
		guard let data = FileManager.default.contents(atPath: file) else {return }

		guard let raw = try? JSONSerialization.jsonObject(with: data),
			  let rows = raw as? [[String: Any]] else {
			print("puzzles.json in \(directory) could not be read.")
			return
		}

		for row in rows {
			guard let start = row["start"] as? Int,
				  let target = row["target"] as? Int,
				  let startTitle = row["startTitle"] as? String,
				  let targetTitle = row["targetTitle"] as? String else { continue }
			let route = row["route"] as? [String] ?? []
			puzzles.append(WikiRacePuzzle(start: start, target: target, startTitle: startTitle, targetTitle: targetTitle, hops: row["hops"] as? Int ?? 0, route: route))
		}
	}
	
	func renderPath(for team : Int) -> String {
		var lines = [String]()

		let trail = raceTrails[team] ?? []
		if trail.isEmpty {
			lines.append("Team \(team + 1) has not moved yet.")
		} else {
			let hops = trail.count - 1
			lines.append("Team \(team + 1) — \(hops) hop\(hops == 1 ? "" : "s")")
			for (step, title) in trail.enumerated() {
				lines.append(step == 0 ? "     \(title)" : "  \(step). \(title)")
			}
		}

		if let standing = raceStandings.first(where: { $0.team == team }) {
			lines.append("")
			if standing.finished {
				lines.append("Arrived in \(standing.seconds)s, placed \(standing.rank).")
			} else {
				lines.append("Did not arrive: \(standing.away) link\(standing.away == 1 ? "" : "s") short, placed \(standing.rank).")
			}
		}
		return lines.joined(separator: "\n")
	}
	
	
	func shortestPath() -> String {
		var lines = [String]()
		if !raceBestRoute.isEmpty {
			lines.append("Shortest possible (\(raceBestRoute.count - 1) hops):")
			lines.append("  " + raceBestRoute.joined(separator: " → "))
		}
		return lines.joined(separator: "\n")
	}
	

	// MARK: - Round state

	/// Names the race on the display and resets data structures. Called when the host starts one.
	func setRace(start: String, target: String) {
		raceTrails.removeAll()
		raceStandings.removeAll()
		raceBestRoute.removeAll()
		
		//Every team starts on the same article
		for team in 0..<Settings.shared.numTeams {
			raceTrails[team] = [start]
		}
		
		startTitle = start
		targetTitle = target
		titleLabel.text = "From \(start) to..."
		targetLabel.text = target
		//Step down font size til it fits
		targetLabel.fontSize = 72
		while targetLabel.calculateAccumulatedFrame().width > self.size.width - 120 && targetLabel.fontSize > 32 {
			targetLabel.fontSize -= 4
		}
		resetTeams()
	}

	private func resetTeams() {
		progress = Array(repeating: Progress(), count: Settings.shared.numTeams)
		rebuildBoxes()
		refreshAll()
	}

	private struct RaceLayout {
		let boxWidth: Int
		let boxHeight: Int
		let fontSize: CGFloat
		let positions: [CGPoint]
	}

	/// Height kept clear at the top of the screen for the header.
	private static let headerHeight: CGFloat = 220

	private func raceLayout() -> RaceLayout {
		let teams = max(1, Settings.shared.numTeams)
		let perColumn = Int((Double(teams) / 2).rounded(.up))

		let top = self.size.height - WikiRaceScene.headerHeight
		let bottom: CGFloat = 60
		let rowSpacing = (top - bottom) / CGFloat(perColumn)

		//Boxes are wider than the other rounds' because article titles are much longer
		//than the answers those boxes were built for.
		let boxWidth = 680
		let boxHeight = Int(min(rowSpacing - 18, 110))

		var positions = [CGPoint]()
		for team in 0..<teams {
			let row = (team < perColumn) ? team : (team - perColumn)
			let side: CGFloat = (team < perColumn) ? -1 : 1
			positions.append(CGPoint(x: self.centrePoint.x + side * 480,
									 y: top - rowSpacing * (CGFloat(row) + 0.5)))
		}

		return RaceLayout(boxWidth: boxWidth, boxHeight: boxHeight,
						  fontSize: boxHeight >= 100 ? 38 : 32, positions: positions)
	}

	/// A team that has arrived keeps a recoloured box and a pile of spent emitters, and
	/// TeamAnswerNode owns its own labels, so the cheapest way back to a clean row is a new
	/// box in the same place rather than picking the old one apart.
	private func rebuildBoxes() {
		let layout = raceLayout()
		for box in teamBoxes {
			box.removeFromParent()
		}
		teamBoxes.removeAll()
		for team in 0..<Settings.shared.numTeams {
			let box = TeamAnswerNode(team: team, width: layout.boxWidth, height: layout.boxHeight,
									 position: layout.positions[team], fontSize: layout.fontSize,
									 showsRoundLabel: true)
			box.zPosition = 1
			teamBoxes.append(box)
			self.addChild(box)
		}
	}


	// MARK: - Live updates

	/// A team has moved to another article. `away` is how many links it still has to go,
	/// which is only shown if the host has asked for it.
	func teamMoved(team: Int, title: String, hops: Int, away: Int) {
		guard team >= 0 && team < progress.count, isParticipating(team) else { return }
		guard progress[team].finishedIn == nil else { return }

		progress[team].title = title
		progress[team].hops = hops
		progress[team].away = away

		raceTrails[team, default: []].append(title)
		
		self.run(blopSound)
		QuizWebSocket.shared?.pulseTeamColour(team)
		refresh(team)
		teamBoxes[team].emphasise()
	}

	/// A team has reached the target. Its box gives up on the article title and says so.
	func teamArrived(team: Int, hops: Int, seconds: Int) {
		guard team >= 0 && team < progress.count, isParticipating(team) else { return }
		guard progress[team].finishedIn == nil else { return }

		progress[team].hops = hops
		progress[team].away = 0
		progress[team].finishedIn = seconds

		self.run(arrivedSound)
		QuizWebSocket.shared?.pulseTeamColourQuick(team)
		refresh(team)
		celebrate(team: team)
	}

	/// Fireworks over the box of a team that has just arrived, in their own colour.
	private func celebrate(team: Int) {
		guard team < teamBoxes.count else { return }
		let box = teamBoxes[team]
		let colour = Utils.teamColour(team)

		box.bgBox.fillColor = NSColor(calibratedRed: 0.15, green: 0.62, blue: 0.42, alpha: 0.95)
		box.guessLabel.fontColor = .white
		box.roundLabel.fontColor = NSColor(calibratedWhite: 0.85, alpha: 1.0)
		box.teamNoLabel.fontColor = .white

		box.addEmitter(named: "fireworks", at: CGPoint(x: 0, y: 0), zPosition: 20) {
			$0.particleColor = colour
			$0.particleColorSequence = nil
			$0.numParticlesToEmit = 260
		}
		box.addEmitter(named: "SparksUp", at: CGPoint(x: -(CGFloat(box.width) / 2) + 40, y: 0), zPosition: 21) {
			$0.particleColor = colour
			$0.particleColorSequence = nil
			$0.numParticlesToEmit = 180
		}

		//A bigger pop than a normal move, so an arrival is unmistakable across the room.
		let grow = SKAction.scale(to: 1.35, duration: 0.12)
		grow.timingMode = .easeOut
		let settle = SKAction.scale(to: 1.0, duration: 0.35)
		settle.timingMode = .easeIn
		box.run(SKAction.sequence([grow, settle]))
	}

	
	func raceStanding(team: Int, rank: Int, finished: Bool, secs: Int, hops: Int, away: Int) {
		let wr = WikiRaceStanding(team: team, rank: rank, finished: finished, seconds: secs, hops: hops, away: away)
		raceStandings.append(wr)
	}

	// MARK: - Drawing a box

	private func refreshAll() {
		for team in 0..<min(progress.count, teamBoxes.count) {
			refresh(team)
		}
	}

	private func refresh(_ team: Int) {
		guard team < teamBoxes.count && team < progress.count else { return }
		let box = teamBoxes[team]
		let state = progress[team]

		box.resetTextSize()

		if let seconds = state.finishedIn {
			box.guessLabel.text = "🏁 Finished!"
			box.roundLabel.text = "\(state.hops) hop\(state.hops == 1 ? "" : "s") in \(timeString(seconds))"
			box.singleLabel.text = ""
			return
		}

		box.guessLabel.text = state.hasStarted ? state.title : "…"
		box.singleLabel.text = ""

		var detail = "\(state.hops) hop\(state.hops == 1 ? "" : "s")"
		if showDistance && state.away >= 0 {
			detail += "   •   \(state.away) away"
		}
		box.roundLabel.text = state.hasStarted ? detail : ""

		shrinkToFit(box)
	}

	/// Article titles are far longer than the answers these boxes were built for
	/// ("Coordinated Universal Time" against "42"), so a long one is stepped down until it
	/// fits rather than running off the side of the box.
	private func shrinkToFit(_ box: TeamAnswerNode) {
		let available = CGFloat(box.width) - 150
		var size = box.fontSize
		while box.guessLabel.frame.width > available && size > 18 {
			size -= 2
			box.setTextSize(size: size)
		}
	}

	private func timeString(_ seconds: Int) -> String {
		return "\(seconds / 60):\(String(format: "%02d", seconds % 60))"
	}


	// MARK: - QuizScene

	override func setParticipating(_ teams: [Bool]) {
		participating = teams
		for team in 0..<min(Settings.shared.numTeams, teamBoxes.count) {
			teamBoxes[team].setPlaying(isParticipating(team))
		}
	}

	private func isParticipating(_ team: Int) -> Bool {
		//Defaults to in, for the window before the controller has said anything
		return team < participating.count ? participating[team] : true
	}

	override func reset() {
		QuizWebSocket.shared?.ledsOff()
		startTitle = ""
		targetTitle = ""
		titleLabel.text = "Wikirace"
		targetLabel.text = ""
		resetTeams()
		setParticipating(participating)
	}
}
