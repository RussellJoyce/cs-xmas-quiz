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


/// One line of the state a client is sent when it reconnects mid-round.
/// Sent inside `QuizCommand.resync`.
enum ClientState: Equatable {

	/// "vs" — go to this round's view *without* resetting it.
	case view(RoundType)

	/// "on"/"of" — whether this team is still in
	case playing(Bool)

	/// "im" — the geography image the phones should be showing
	case geographyImage(String)

	/// "mo" — the multiple choice options, as `MultiChoiceScene` renders them
	case multiChoiceOptions(String)

	/// "ms" — the option this team has already chosen
	case multiChoiceAnswer(Int)

	/// "h2"/"h1" — true/false wording rather than higher/lower
	case trueFalseMode(Bool)

	/// "hh"/"hl"/"hn" — the answer this team has already given, or nil for none
	case higherLowerAnswer(Bool?)

	var wire: String {
		switch self {
		case .view(let round):            return "vs" + round.clientView
		case .playing(let playing):       return playing ? "on" : "of"
		case .geographyImage(let file):   return "im" + file
		case .multiChoiceOptions(let o):  return "mo" + o
		case .multiChoiceAnswer(let opt): return "ms\(opt)"
		case .trueFalseMode(let tf):      return tf ? "h2" : "h1"
		case .higherLowerAnswer(let ans):
			guard let ans else { return "hn" }
			return ans ? "hh" : "hl"
		}
	}
}


/// A command from the quiz software to the node server, which passes it on to the teams'
/// phones. The counterpart to `QuizMessage`, which travels the other way.
///
/// Every `team` here is 0-based, as the scenes and the host's arrays count teams. The
/// 1-based numbering the wire uses is applied in `wire` and nowhere else.
enum QuizCommand: Equatable {

	/// "ls" — ask which clients are connected. The reply arrives as `QuizMessage.clientList`.
	case listClients

	/// "vi" — put every phone on this round's view, resetting whatever was on it
	case showView(RoundType)

	/// "on"/"of" — whether a team is still in
	case setPlaying(team: Int, playing: Bool)

	/// "im" — show this geography image
	case geographyImage(String)

	/// "mo" — the multiple choice options, which also clears the last question's selection
	case multiChoiceOptions(String)

	/// "ms" — light this team's tile, the round having accepted their answer
	case multiChoiceAccepted(team: Int, option: Int)

	/// "hh"/"hl" — acknowledge a team's higher/lower answer
	case higherLowerAccepted(team: Int, higher: Bool)

	/// "h2"/"h1" — true/false wording rather than higher/lower
	case trueFalseMode(Bool)

	/// "ha" — clear the emphasis on whatever the phones are showing
	case clearEmphasis

	/// "di" — disassociate a team's device, which then has to reconnect
	case disconnect(team: Int)

	/// "wr" — start a race between two Wikipedia page ids
	case startRace(from: Int, to: Int)

	/// "we" — freeze every client and work out the standings
	case endRace

	/// "wk" — ask the server to resend one team's race state
	case resendRaceState(team: Int)

	/// "to" — one line of catch-up state, addressed to a single team
	case resync(team: Int, state: ClientState)

	var wire: String {
		//The wire counts teams from one
		func number(_ team: Int) -> Int { team + 1 }

		switch self {
		case .listClients:                 return "ls"
		case .showView(let round):         return "vi" + round.clientView
		case .setPlaying(let t, let p):    return (p ? "on" : "of") + String(number(t))
		case .geographyImage(let file):    return "im" + file
		case .multiChoiceOptions(let o):   return "mo" + o
		case .multiChoiceAccepted(let t, let opt): return "ms\(number(t)),\(opt)"
		case .higherLowerAccepted(let t, let h):   return (h ? "hh" : "hl") + String(number(t))
		case .trueFalseMode(let tf):       return tf ? "h2" : "h1"
		case .clearEmphasis:               return "ha"
		case .disconnect(let t):           return "di\(number(t))"
		case .startRace(let from, let to): return "wr\(from),\(to)"
		case .endRace:                     return "we"
		case .resendRaceState(let t):      return "wk\(number(t))"
		case .resync(let t, let state):    return "to\(number(t)),\(state.wire)"
		}
	}
}
