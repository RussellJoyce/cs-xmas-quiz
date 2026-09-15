//
//  QuizProtocol.swift
//

import Foundation


/// The scenes index their teams from zero, so most callers want `index`.
struct Team: Equatable {
	/// 1-based, as the wire and the clients count teams
	let number: Int

	/// 0-based, as the scenes and the host's arrays count teams
	var index: Int { number - 1 }

	init(number: Int) {
		self.number = number
	}

	init?(wire: some StringProtocol) {
		guard let number = Int(wire), number >= 1 else { return nil }
		self.init(number: number)
	}
}


/// A message from the node server to the quiz software.
enum QuizMessage: Equatable {

	/// "co" — legacy connection acknowledgement. Nothing sends it any more.
	case connected

	/// "lr<team>,<team>,..." — which teams currently have a client connected, 1-based.
	/// The list is allowed to be empty, meaning nobody is connected.
	case clientList(teams: [Int])

	/// "zz<team>" — a team has buzzed.
	case buzz(team: Team)

	/// "hi<team>" / "lo<team>" — a vote in the true/false round.
	/// `higher` is true for "true or higher".
	case higherLower(team: Team, higher: Bool)

	/// "ii<team>,<x>,<y>" — a team has put a pin in the map.
	case geographyGuess(team: Team, x: Int, y: Int)

	/// "wv<team>,<value>" — a team has moved its wavelength slider.
	case wavelengthGuess(team: Team, value: Int)

	/// "mc<team>,<option>" — a team has picked a multiple choice option, 1-based.
	case multiChoiceGuess(team: Team, option: Int)

	/// "tt<team>,<text>" — a typed answer, used by the text, numbers and pointless rounds.
	/// `text` is the raw field; capping its length is the receiver's business.
	case textGuess(team: Team, text: String)

	/// "wp<team>,<hops>,<away>,<title>" — a team has moved to another article.
	/// The title is last precisely because it may itself contain commas.
	case wikiMoved(team: Team, hops: Int, away: Int, title: String)

	/// "ww<team>,<hops>,<seconds>" — a team has reached the target article.
	case wikiArrived(team: Team, hops: Int, seconds: Int)

	/// "wd<team>,<rank>,<finished>,<secs>,<hops>,<away>" — one team's final standing,
	/// sent for every team once the host ends the race.
	case wikiStanding(team: Team, rank: Int, finished: Bool, seconds: Int, hops: Int, away: Int)

	/// "wt<team>,<title>|<title>|..." — a team's whole trail, for the host to look back over.
	/// Pipe separated because titles hold commas.
	case wikiTrail(team: Team, titles: [String])


	/// Decodes one message, or returns nil
	init?(_ text: String) {
		guard text.count >= 2 else { return nil }

		let code = String(text.prefix(2))
		let payload = text.dropFirst(2)

		//Comma-separated fields of the payload, for the messages shaped that way
		func fields(_ count: Int) -> [Substring]? {
			let parts = payload.split(separator: ",", omittingEmptySubsequences: false)
			return parts.count >= count ? parts : nil
		}

		switch code {
		case "co":
			self = .connected

		case "lr":
			//Anything that is not a number is dropped, as it always has been
			self = .clientList(teams: payload.split(separator: ",").compactMap { Int($0) })

		case "zz":
			guard let team = Team(wire: payload) else { return nil }
			self = .buzz(team: team)

		case "hi", "lo":
			guard let team = Team(wire: payload) else { return nil }
			self = .higherLower(team: team, higher: code == "hi")

		case "ii":
			guard let f = fields(3), let team = Team(wire: f[0]),
			      let x = Int(f[1]), let y = Int(f[2]) else { return nil }
			self = .geographyGuess(team: team, x: x, y: y)

		case "wv":
			guard let f = fields(2), let team = Team(wire: f[0]),
			      let value = Int(f[1]) else { return nil }
			self = .wavelengthGuess(team: team, value: value)

		case "mc":
			guard let f = fields(2), let team = Team(wire: f[0]),
			      let option = Int(f[1]) else { return nil }
			self = .multiChoiceGuess(team: team, option: option)

		case "tt":
			//TODO: Only the field up to the next comma is taken, an answer containing a comma is cut short
			guard let f = fields(2), let team = Team(wire: f[0]) else { return nil }
			self = .textGuess(team: team, text: String(f[1]))

		case "wp":
			guard let f = fields(4), let team = Team(wire: f[0]),
			      let hops = Int(f[1]), let away = Int(f[2]) else { return nil }
			self = .wikiMoved(team: team, hops: hops, away: away,
			                  title: f[3...].joined(separator: ","))

		case "ww":
			guard let f = fields(3), let team = Team(wire: f[0]),
			      let hops = Int(f[1]), let seconds = Int(f[2]) else { return nil }
			self = .wikiArrived(team: team, hops: hops, seconds: seconds)

		case "wd":
			guard let f = fields(6), let team = Team(wire: f[0]),
			      let rank = Int(f[1]), let finished = Int(f[2]), let seconds = Int(f[3]),
			      let hops = Int(f[4]), let away = Int(f[5]) else { return nil }
			self = .wikiStanding(team: team, rank: rank, finished: finished == 1,
			                     seconds: seconds, hops: hops, away: away)

		case "wt":
			guard let comma = payload.firstIndex(of: ","),
			      let team = Team(wire: payload[..<comma]) else { return nil }
			let titles = payload[payload.index(after: comma)...].components(separatedBy: "|")
			self = .wikiTrail(team: team, titles: titles)

		default:
			return nil
		}
	}
}
