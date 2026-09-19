//
//  IdleCeefaxScene.swift
//  Quiz Server
//
//  Created by Ian Gray on 2026-09-17.
//  Copyright © 2026 Russell Joyce & Ian Gray. All rights reserved.
//
//  An idle screen pretending to be Ceefax: a handful of pages on a carousel, a header
//  clock that ticks, and the page number rolling over while the next page "arrives".
//  The pages themselves live in CeefaxPages.
//

import Cocoa
import SpriteKit


class IdleCeefaxScene: QuizScene {

	/// Teletext was made for a 4:3 television, so the page is pillarboxed rather than
	/// stretched across the whole display.
	private let pageAspect: CGFloat = 4.0 / 3.0

	/// Faint horizontal lines over the top, which is most of what sells it as a television.
	private let showScanlines = true

	/// How long the page number spends rolling over between pages.
	private let tuningDuration: TimeInterval = 0.9

	/// How long a newsflash stays up after a team buzzes.
	private let newsflashDuration: TimeInterval = 5.0

	/// Which screen row a newsflash is pasted over.
	private let newsflashRow = 21

	private var teletext: TeletextNode!

	private var pages = [TeletextPage]()
	private var pageIndex = 0

	//Carousel and clock state, all driven from `update(_:)` so that it stops dead while
	//this is not the scene on screen.
	private var lastUpdateTime: TimeInterval = 0
	private var timeOnPage: TimeInterval = 0
	private var tuningRemaining: TimeInterval = 0
	private var timeToNextRoll: TimeInterval = 0
	private var displayedNumber = 100
	private var lastClockSecond = -1

	private var newsflashRemaining: TimeInterval = 0

	/// A page the host has parked on from the controller window, which stops the
	/// carousel. Nil is the normal case: cycle through everything.
	private var heldPage: Int?

	private let dayFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_GB")
		formatter.dateFormat = "EEE d MMM"
		return formatter
	}()

	private let clockFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.locale = Locale(identifier: "en_GB")
		formatter.dateFormat = "HH:mm/ss"
		return formatter
	}()


	// MARK: - Scene

	override func buildScene() {
		backgroundColor = .black

		let pageHeight = self.size.height
		let pageWidth = pageHeight * pageAspect
		let cellSize = CGSize(width: pageWidth / CGFloat(TeletextGrid.standardColumns),
							  height: pageHeight / CGFloat(TeletextGrid.bodyRows + 1))

		teletext = TeletextNode(cellSize: cellSize)
		teletext.position = CGPoint(x: (self.size.width - pageWidth) / 2, y: pageHeight)
		teletext.zPosition = 10
		addChild(teletext)

		if showScanlines, let lines = scanlineTexture() {
			let overlay = SKSpriteNode(texture: lines)
			overlay.position = self.centrePoint
			overlay.size = self.size
			overlay.zPosition = 50
			overlay.alpha = 0.55
			addChild(overlay)
		}

		buildPages()
	}


	override func update(_ currentTime: TimeInterval) {
		guard !isPaused else { return }
		if lastUpdateTime == 0 {
			lastUpdateTime = currentTime
		}
		let delta = min(currentTime - lastUpdateTime, 1.0)
		lastUpdateTime = currentTime

		if tuningRemaining > 0 {
			//Rolling the number between pages, the way a real set did while it waited for
			//the page to come round again.
			tuningRemaining -= delta
			timeToNextRoll -= delta
			if timeToNextRoll <= 0 {
				timeToNextRoll = 0.07
				displayedNumber = Int.random(in: 100...899)
				updateHeader(force: true)
			}
			if tuningRemaining <= 0 {
				showPage(at: (pageIndex + 1) % max(pages.count, 1))
			}
		} else if heldPage == nil {
			timeOnPage += delta
			if timeOnPage >= currentDwell {
				startTuning()
			}
		}

		if newsflashRemaining > 0 {
			newsflashRemaining -= delta
			if newsflashRemaining <= 0 {
				teletext.setOverlay(nil, atRow: newsflashRow)
			}
		}

		updateHeader(force: false)
		teletext.refresh()
	}


	override func reset() {
		QuizWebSocket.shared?.megamas()
		newsflashRemaining = 0
		teletext?.setOverlay(nil, atRow: newsflashRow)
		tuningRemaining = 0
		heldPage = nil
		showPage(at: 0)
	}


	override func teardown() {
		//Force the next update() to re-baseline rather than seeing one huge delta and
		//flicking straight past a page on re-entry.
		lastUpdateTime = 0
	}


	override func buzzerPressed(team: Int, type: BuzzerType, options: BuzzerOptions) {
		QuizWebSocket.shared?.setTargetTeam(team)
		teletext.setOverlay(CeefaxPages.newsflash(team: team), atRow: newsflashRow)
		newsflashRemaining = newsflashDuration
	}


	// MARK: - Carousel

	/// The pages in the carousel, in the order they are shown. The controller window
	/// builds its page picker from this, so adding a page to `CeefaxPages` is enough.
	var pageNumbers: [Int] {
		pages.map(\.number)
	}

	/// Parks the display on one page and stops the carousel. Passing nil sets it going
	/// again from wherever it is. Unknown page numbers are ignored.
	func holdPage(number: Int?) {
		guard let number else {
			heldPage = nil
			timeOnPage = 0
			return
		}
		guard let index = pages.firstIndex(where: { $0.number == number }) else { return }
		heldPage = number
		showPage(at: index)
	}


	private var currentDwell: TimeInterval {
		pages.indices.contains(pageIndex) ? pages[pageIndex].dwell : 12
	}

	private func buildPages() {
		pages = CeefaxPages.carousel()
		if !pages.contains(where: { $0.number == heldPage }) {
			heldPage = nil
		}
		if teletext != nil {
			showPage(at: min(pageIndex, pages.count - 1))
		}
	}

	private func startTuning() {
		guard pages.count > 1 else {
			timeOnPage = 0
			return
		}
		tuningRemaining = tuningDuration
		timeToNextRoll = 0
		teletext.page = nil
	}

	private func showPage(at index: Int) {
		guard !pages.isEmpty else { return }
		pageIndex = min(max(index, 0), pages.count - 1)
		timeOnPage = 0
		tuningRemaining = 0
		displayedNumber = pages[pageIndex].number
		//A page that changes every time it is shown rebuilds itself on the way in.
		if let refresh = pages[pageIndex].refresh {
			pages[pageIndex].grid = refresh()
		}
		teletext.page = pages[pageIndex].grid
		updateHeader(force: true)
	}

	/// The header only needs redrawing when the clock ticks over, or when the page number
	/// under it has moved.
	private func updateHeader(force: Bool) {
		let now = Date()
		let second = Calendar.current.component(.second, from: now)
		guard force || second != lastClockSecond else { return }
		lastClockSecond = second
		teletext.header = IdleCeefaxScene.headerGrid(pageNumber: displayedNumber, now: now,
													 day: dayFormatter, clock: clockFormatter)
	}

	/// `P100 CEEFAX 100 Wed 17 Dec 20:14/32`, as it was.
	static func headerGrid(pageNumber: Int, now: Date,
						   day: DateFormatter, clock: DateFormatter) -> TeletextGrid {
		var grid = TeletextGrid(rowCount: 1)
		grid.write("P\(pageNumber)", row: 0, col: 0, fg: .white)
		grid.write("CEEFAX", row: 0, col: 6, fg: .cyan)
		grid.write("\(pageNumber)", row: 0, col: 13, fg: .white)
		grid.write(day.string(from: now), row: 0, col: 18, fg: .yellow)
		grid.write(clock.string(from: now), row: 0, col: 31, fg: .white)
		return grid
	}


	// MARK: - Scanlines

	/// One pixel column of scanlines, stretched across the screen. Only the vertical
	/// detail matters, so there is no point making it any wider.
	private func scanlineTexture() -> SKTexture? {
		let height = Int(self.size.height)
		guard height > 0,
			  let ctx = CGContext(data: nil, width: 1, height: height,
								  bitsPerComponent: 8, bytesPerRow: 0,
								  space: CGColorSpaceCreateDeviceRGB(),
								  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
			return nil
		}
		ctx.setFillColor(NSColor.black.cgColor)
		for y in stride(from: 0, to: height, by: 3) {
			ctx.fill(CGRect(x: 0, y: y, width: 1, height: 1))
		}
		guard let image = ctx.makeImage() else { return nil }
		return SKTexture(cgImage: image)
	}
}
