//
//  CeefaxPages.swift
//  Quiz Server
//
//  Created by Ian Gray on 2026-09-17.
//  Copyright © 2026 Russell Joyce & Ian Gray. All rights reserved.
//
//  The contents of the Ceefax idle screen. This is the part worth rewriting each year;
//  IdleCeefaxScene only concerns itself with putting them on the display.
//

import Foundation


enum CeefaxPages {

	/// Every page of the service, in the order the carousel shows them.
	static func carousel() -> [TeletextPage] {
		[index(), news(), howToPlay()]
	}


	// MARK: - Pages

	static func index() -> TeletextPage {
		var page = TeletextPage(number: 100, dwell: 14)
		page.grid.fill(rows: 0...1, bg: .blue)
		page.grid.centre("CHRISTMAS QUIZ", row: 0, fg: .yellow, bg: .blue, double: true)

		page.grid.centre("DEPARTMENT OF COMPUTER SCIENCE", row: 3, fg: .cyan)
		page.grid.centre("UNIVERSITY OF YORK", row: 4, fg: .cyan)

		page.grid.write("INDEX", row: 6, col: 2, fg: .green)
		let contents = [(101, "News Headlines"), (150, "How To Play"), (200, "Sport"),
						(302, "Weather"), (888, "Subtitles")]
		for (offset, entry) in contents.enumerated() {
			page.grid.write("\(entry.0)", row: 8 + offset, col: 3, fg: .cyan)
			page.grid.write(entry.1, row: 8 + offset, col: 8, fg: .white)
		}

		page.grid.write("Join in at", row: 16, col: 3, fg: .green)
		page.grid.write("christmasquiz.win", row: 18, col: 3, fg: .yellow, double: true)

		page.grid.art(tree, row: 8, col: 27, fg: .green)
		page.grid.write("*", row: 7, col: 30, fg: .yellow, flashing: true)
		page.grid.write("*", row: 9, col: 28, fg: .cyan, flashing: true)
		page.grid.write("*", row: 10, col: 33, fg: .magenta, flashing: true)

		addFastext(to: &page.grid)
		return page
	}


	/// The headlines change every time the page comes round, so this page rebuilds
	/// itself rather than being laid out once at startup.
	/// The headlines change every time the page comes round, so this page rebuilds
	/// itself rather than being laid out once at startup.
	static func news() -> TeletextPage {
		var page = TeletextPage(number: 101, dwell: 18)
		//The page starts bare on purpose. The scene calls refresh() on the way in, so
		//dealing headlines here would burn some on a page nobody ever sees.
		page.grid = newsGrid(showing: []).grid
		page.refresh = {
			let dealt = nextHeadlines(headlinesPerPage)
			let laidOut = newsGrid(showing: dealt)
			//Whatever did not fit was still dealt, so it goes back to the front of the
			//deck rather than being quietly skipped in the rotation.
			returnToDeck(dealt.dropFirst(laidOut.shown))
			return laidOut.grid
		}
		return page
	}

	/// How many headlines to try to fit. Longer ones take two rows each, so the page
	/// shows as many of these as there is room for and puts the rest back.
	private static let headlinesPerPage = 8

	/// The lead stories, set at double height the way the top of a real headline page was.
	private static let leadHeadlines = 2

	/// The page number of the first "full story", which no more exists than the stories
	/// do. They count up from there down the page.
	private static let firstStoryPage = 102

	/// - Returns: the finished page, and how many of `headlines` actually fitted on it.
	private static func newsGrid(showing headlines: [String]) -> (grid: TeletextGrid, shown: Int) {
		var grid = TeletextGrid(rowCount: TeletextGrid.bodyRows)
		grid.fill(rows: 0...1, bg: .red)
		grid.centre("NEWS HEADLINES", row: 0, fg: .white, bg: .red, double: true)

		//Every headline gets a page number for the story behind it, right justified in a
		//column of its own. The text wraps short of that column so the two never meet.
		let numberColumn = TeletextGrid.standardColumns - 4
		let wrapWidth = numberColumn - 2

		//The fastext bar owns the last row, so the headlines stop short of it.
		let lastRow = TeletextGrid.bodyRows - 2
		var row = 3
		var shown = 0

		for (index, headline) in headlines.enumerated() {
			let isLead = index < leadHeadlines
			//Double height costs two grid rows per line of text.
			let rowsPerLine = isLead ? 2 : 1
			let lines = wrapped(headline, width: wrapWidth)
			guard row + (lines.count * rowsPerLine) - 1 <= lastRow else { break }

			grid.write("\(firstStoryPage + index)", row: row, col: numberColumn,
					   fg: .cyan, double: isLead)
			for line in lines {
				grid.write(line, row: row, col: 1, fg: .white, double: isLead)
				row += rowsPerLine
			}
			shown = index + 1

			//The leads run together as one block, as do the rest; the gap goes between
			//the two, which is where the real pages put it.
			if index == leadHeadlines - 1 {
				row += 1
			}
		}

		addFastext(to: &grid)
		return (grid, shown)
	}


	// MARK: - Headlines

	/// Dealt from a shuffled deck rather than picked at random, so the page works
	/// through the whole list before anything comes round a second time.
	private static var headlineDeck = [String]()

	private static func nextHeadlines(_ count: Int) -> [String] {
		guard !headlines.isEmpty else { return [] }

		var dealt = [String]()
		while dealt.count < count {
			if headlineDeck.isEmpty {
				//Reshuffling mid-page would otherwise be able to repeat a headline on
				//the same page, so anything already dealt goes to the back of the deck.
				var next = headlines.shuffled()
				let alreadyShown = next.filter(dealt.contains)
				next.removeAll(where: dealt.contains)
				headlineDeck = next + alreadyShown
			}
			dealt.append(headlineDeck.removeFirst())
		}
		return dealt
	}

	/// Puts headlines that were dealt but not used back at the front of the deck, so
	/// they lead the next page rather than being lost from the rotation.
	private static func returnToDeck<C: Collection>(_ headlines: C) where C.Element == String {
		headlineDeck.insert(contentsOf: headlines, at: 0)
	}

	/// Breaks a headline over as many rows as it needs, keeping words whole.
	private static func wrapped(_ text: String, width: Int) -> [String] {
		var lines = [String]()
		var line = ""
		for word in text.split(separator: " ") {
			let candidate = line.isEmpty ? String(word) : line + " " + word
			if candidate.count <= width {
				line = candidate
			} else {
				if !line.isEmpty { lines.append(line) }
				line = String(word)
			}
		}
		if !line.isEmpty { lines.append(line) }
		return lines
	}

	private static let headlines = [
		//".................................."
		"Portillo's teeth removed to boost pound.",
		"Where now for man raised by puffins?",
		"Nato annulled after delegate swallows treaty.",
		"Euro MPs' new headsets play the sound of screaming.",
		"Richard Hammond bathmat poisonous, say lab.",
		"Fist-headed man destroys central Portsmouth.",
		"Car drives past window in town.",
		"Leicester man wins right to eat sister.",
		"X-Factor star to marry cabbage.",
		"Irn Bru panic as fans stockpile.",
		"Ian Beale wins Eurovision.",
		"\"Feel my spectacles\" roars drunken Starmer.",
		"Boiled dog can do maths claims scientist.",
		"Mick Hucknall strangled by own music.",
		"Child made of paint wins by-election.",
		"In-store wolves \"a mistake\" admits Topshop.",
		"Noel Edmunds to fight duck says publicist.",
		"Study finds Tuesday is fictional.",
		"Otter refuses to name accomplice. Trial continues.",
		"Metro Centre escalator claims third victim.",
		"Farage discovered inside bin.",
	]


	static func howToPlay() -> TeletextPage {
		var page = TeletextPage(number: 150, dwell: 16)
		for bauble in baubles {
			page.grid.art(thread(cells: bauble.row - bauble.threadFrom, onRight: bauble.threadOnRight),
						  row: bauble.threadFrom, col: bauble.threadCol, fg: .red)
			page.grid.art(bauble.picture, row: bauble.row, col: bauble.col, fg: bauble.colour)
		}

		page.grid.write("HOW TO PLAY", row: 0, col: 27, fg: .yellow, double: true)

		page.grid.write("1", row: 17, col: 2, fg: .cyan)
		page.grid.write("Join the quiz wi-fi", row: 17, col: 5, fg: .white)

		page.grid.write("2", row: 19, col: 2, fg: .cyan)
		page.grid.write("Point a phone at", row: 19, col: 5, fg: .white)
		page.grid.write("christmasquiz.win", row: 19, col: 22, fg: .yellow)

		page.grid.write("3", row: 21, col: 2, fg: .cyan)
		page.grid.write("Choose your team number", row: 21, col: 5, fg: .white)

		addFastext(to: &page.grid)
		return page
	}

	// MARK: - Newsflash

	private static let newsflashLines = [
		"Questons asked in parliament",
		"Investigations are ongoing",
		"Emergency services scrambled",
		"Officials decline to comment",
		"\"Dark times for the country\" - PM",
		"\"Fault of immigrants\" - Badenoch",
		"National IQ results fall",
		"Coldplay to host benefit gig",
		"Experts advise caution",
		"Effect on house prices revealed",
		"Trump raises tariffs on Yorkshire",
		"War is coming. Repent your sins.",
		"\"It was a nightmare\" - victim",
		"King to address nation"
	]

	/// The strip thrown over the bottom of whatever page is up when a team buzzes.
	static func newsflash(team: Int) -> TeletextGrid {
		var grid = TeletextGrid(rowCount: 3)
		grid.fill(rows: 0...0, bg: .red)
		grid.write(" NEWSFLASH ", row: 0, col: 1, fg: .yellow, bg: .red, flashing: true)
		grid.write("Team \(team + 1) is pressing the button.", row: 1, col: 1, fg: .white)
		grid.write(newsflashLines.randomElement() ?? "", row: 2, col: 1, fg: .cyan)
		return grid
	}


	// MARK: - Furniture

	/// The coloured link bar every page carries along the bottom.
	private static func addFastext(to grid: inout TeletextGrid) {
		grid.fastext([(.red, "News"), (.green, "Sport"), (.yellow, "Weather"), (.cyan, " Index")], row: TeletextGrid.bodyRows - 1)
	}


	// MARK: - Baubles

	private struct Bauble {
		let picture: String
		let colour: TeletextColour
		let col: Int
		let row: Int
		let threadCol: Int
		let threadOnRight: Bool
		let threadFrom: Int
	}

	private static let baubles = [
		Bauble(picture: ball,     colour: .cyan,   col: 1,  row: 6, threadCol: 4,  threadOnRight: false, threadFrom: 0),
		Bauble(picture: bigBall,  colour: .red,    col: 9,  row: 8, threadCol: 13, threadOnRight: false, threadFrom: 0),
		Bauble(picture: teardrop, colour: .blue,   col: 19, row: 5, threadCol: 22, threadOnRight: false, threadFrom: 0),
		Bauble(picture: bell,     colour: .yellow, col: 27, row: 9, threadCol: 30, threadOnRight: false, threadFrom: 2),
		Bauble(picture: spindle,  colour: .white,  col: 35, row: 7, threadCol: 36, threadOnRight: true,  threadFrom: 2)
	]

	/// A thread for a bauble to hang from: one block wide, `cells` character cells tall.
	private static func thread(cells: Int, onRight: Bool) -> String {
		Array(repeating: onRight ? ".#" : "#.", count: max(cells, 0) * 3).joined(separator: "\n")
	}

	private static let ball = """
	.....####.....
	..............
	.....####.....
	...########...
	..##########..
	.############.
	.############.
	##############
	##############
	##############
	##############
	##############
	##############
	##############
	.############.
	.############.
	..##########..
	...########...
	.....####.....
	..............
	"""

	private static let bigBall = """
	.......####.......
	..................
	.......####.......
	.....########.....
	...############...
	..##############..
	.################.
	.################.
	##################
	##################
	##################
	##################
	##################
	##################
	##################
	##################
	.################.
	.################.
	..##############..
	...############...
	.....########.....
	.......####.......
	..................
	"""

	private static let teardrop = """
	.....####.....
	..............
	.....####.....
	...########...
	..##########..
	.############.
	##############
	##############
	##############
	##############
	##############
	##############
	.############.
	.############.
	..##########..
	..##########..
	...########...
	...########...
	....######....
	....######....
	.....####.....
	.....####.....
	.....####.....
	......##......
	......##......
	......##......
	......##......
	......##......
	..............
	"""

	private static let bell = """
	......##......
	..............
	......##......
	.....####.....
	....######....
	....######....
	...########...
	...########...
	..##########..
	..##########..
	.############.
	.############.
	##############
	##############
	##############
	##############
	##############
	##############
	##############
	..............
	"""

	private static let spindle = """
	..####..
	........
	..####..
	.######.
	########
	########
	########
	########
	.######.
	.######.
	.######.
	..####..
	..####..
	..####..
	..####..
	...##...
	...##...
	...##...
	...##...
	...##...
	...##...
	...##...
	...##...
	...##...
	...##...
	........
	"""


	// MARK: - Block graphics

	private static let tree = """
	.......##.......
	.......##.......
	......####......
	......####......
	.....######.....
	.....######.....
	....########....
	...##########...
	....########....
	...##########...
	..############..
	...##########...
	..############..
	.##############.
	..############..
	.##############.
	################
	.##############.
	.......##.......
	.......##.......
	......####......
	"""

}
