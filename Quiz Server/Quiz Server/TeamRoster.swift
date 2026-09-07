//
//  TeamRoster.swift

import Foundation


/// Who is playing, by zero-based team number.

struct TeamRoster {

	/// Per-team playing, ignoring the master toggle
	private var chosen: [Bool]

	private(set) var allDisabled = false

	init(teams: Int) {
		chosen = Array(repeating: true, count: max(0, teams))
	}

	var count: Int { chosen.count }

	/// Is this team playing right now
	func isPlaying(_ team: Int) -> Bool {
		guard !allDisabled, chosen.indices.contains(team) else { return false }
		return chosen[team]
	}

	/// Is this team switched this team on
	func isChosen(_ team: Int) -> Bool {
		chosen.indices.contains(team) ? chosen[team] : false
	}

	/// Which teams are playing, indexed by zero-based team number
	var flags: [Bool] {
		(0..<count).map { isPlaying($0) }
	}

	/// Records the host's choice for one team.
	/// - Returns: the teams whose playing state actually moved
	mutating func set(_ team: Int, playing: Bool) -> [Int] {
		guard chosen.indices.contains(team), chosen[team] != playing else { return [] }
		chosen[team] = playing
		return allDisabled ? [] : [team]
	}

	/// Stops or restarts everybody at once, leaving the per-team choices untouched.
	/// - Returns: the teams whose playing state actually moved.
	mutating func setAllDisabled(_ disabled: Bool) -> [Int] {
		guard disabled != allDisabled else { return [] }
		allDisabled = disabled
		return (0..<count).filter { chosen[$0] }
	}
}
