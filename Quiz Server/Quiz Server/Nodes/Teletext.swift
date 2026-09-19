//
//  Teletext.swift
//  Quiz Server
//
//  Created by Ian Gray on 2026-09-17.
//  Copyright © 2026 Russell Joyce & Ian Gray. All rights reserved.
//
//  A small teletext engine: a grid of character cells, the seven-colour palette, and a
//  renderer that turns a grid into a texture. IdleCeefaxScene builds pages out of this.
//

import Cocoa
import SpriteKit


// MARK: - Colours

enum TeletextColour {
	case black, red, green, yellow, blue, magenta, cyan, white

	var nsColour: NSColor {
		switch self {
		case .black:   return NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: 1)
		case .red:     return NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1)
		case .green:   return NSColor(calibratedRed: 0, green: 1, blue: 0, alpha: 1)
		case .yellow:  return NSColor(calibratedRed: 1, green: 1, blue: 0, alpha: 1)
		case .blue:    return NSColor(calibratedRed: 0, green: 0, blue: 1, alpha: 1)
		case .magenta: return NSColor(calibratedRed: 1, green: 0, blue: 1, alpha: 1)
		case .cyan:    return NSColor(calibratedRed: 0, green: 1, blue: 1, alpha: 1)
		case .white:   return NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: 1)
		}
	}

	var isBlack: Bool { if case .black = self { return true }; return false }
}


// MARK: - Cells

/// One character cell of a page.
struct TeletextCell {
	enum Glyph: Equatable {
		case blank
		case char(Character)
		/// Block graphics: a 2x3 grid of blocks within the cell. Bit 0 is top-left,
		/// bit 1 top-right, bit 2 middle-left, bit 3 middle-right, bit 4 bottom-left,
		/// bit 5 bottom-right.
		case mosaic(UInt8)
	}

	var glyph: Glyph = .blank
	var fg: TeletextColour = .white
	var bg: TeletextColour = .black
	/// Flashing cells are drawn into a separate layer, which is blinked over the top.
	var flashing = false
	/// Drawn at double height, hanging down over the row below (which `write` clears).
	var doubleHeight = false
}


// MARK: - Grid

/// A rectangle of character cells. A page is one of these; so is the header row, and so
/// is anything overlaid on top of a page.
///
/// Rows and columns are both zero-based, and writes that fall outside are dropped rather
/// than trapping, so page layout code does not have to be defensive.
struct TeletextGrid {

	/// Teletext is 40 columns across and 25 rows down, of which row 0 is the header.
	static let standardColumns = 40
	static let bodyRows = 24

	let columns: Int
	private(set) var rows: [[TeletextCell]]

	var rowCount: Int { rows.count }

	init(rowCount: Int, columns: Int = TeletextGrid.standardColumns, bg: TeletextColour = .black) {
		self.columns = columns
		var blank = TeletextCell()
		blank.bg = bg
		self.rows = Array(repeating: Array(repeating: blank, count: columns), count: rowCount)
	}

	subscript(row: Int, col: Int) -> TeletextCell {
		get { rows[row][col] }
		set { rows[row][col] = newValue }
	}

	/// Whether anything on the grid needs the blinking layer drawing at all.
	var hasFlashing: Bool {
		rows.contains { $0.contains { $0.flashing } }
	}


	/// Puts `text` into the grid, one character per cell.
	mutating func write(_ text: String, row: Int, col: Int,
						fg: TeletextColour = .white, bg: TeletextColour = .black,
						flashing: Bool = false, double: Bool = false) {
		guard rows.indices.contains(row) else { return }

		for (offset, character) in text.enumerated() {
			let c = col + offset
			guard c >= 0, c < columns else { continue }
			rows[row][c] = TeletextCell(glyph: character == " " ? .blank : .char(character),
										fg: fg, bg: bg,
										flashing: flashing, doubleHeight: double)
		}

		//The bottom half of a double-height glyph is drawn from the row above, so the row
		//below just has to keep out of the way while carrying the same background.
		if double, rows.indices.contains(row + 1) {
			for offset in 0..<text.count {
				let c = col + offset
				guard c >= 0, c < columns else { continue }
				rows[row + 1][c] = TeletextCell(fg: fg, bg: bg)
			}
		}
	}

	/// As `write`, but centred across the full width of the grid.
	mutating func centre(_ text: String, row: Int,
						 fg: TeletextColour = .white, bg: TeletextColour = .black,
						 flashing: Bool = false, double: Bool = false) {
		write(text, row: row, col: max(0, (columns - text.count) / 2),
			  fg: fg, bg: bg, flashing: flashing, double: double)
	}

	/// Clears whole rows to a background colour, for the coloured bars a page header sits in.
	mutating func fill(rows rowRange: ClosedRange<Int>, bg: TeletextColour) {
		var blank = TeletextCell()
		blank.bg = bg
		for row in rowRange where rows.indices.contains(row) {
			self.rows[row] = Array(repeating: blank, count: columns)
		}
	}

	/// Paints block graphics from an ASCII picture. Each character cell takes two columns
	/// and three rows of the picture, so a 16x21 picture fills 8x7 cells. Any character
	/// other than a space or `.` is a filled block.
	///
	/// Cells whose six blocks are all empty are left alone rather than blanked, so a
	/// picture can be laid over something already on the page.
	mutating func art(_ picture: String, row: Int, col: Int,
					  fg: TeletextColour, bg: TeletextColour = .black) {
		let lines = picture.split(separator: "\n", omittingEmptySubsequences: false).map(Array.init)
		let blockOffsets = [(0, 0), (0, 1), (1, 0), (1, 1), (2, 0), (2, 1)]
		let cellRows = (lines.count + 2) / 3
		let cellCols = ((lines.map(\.count).max() ?? 0) + 1) / 2

		for r in 0..<cellRows {
			for c in 0..<cellCols {
				var bits: UInt8 = 0
				for bit in 0..<blockOffsets.count {
					let y = r * 3 + blockOffsets[bit].0
					let x = c * 2 + blockOffsets[bit].1
					guard y < lines.count, x < lines[y].count else { continue }
					if lines[y][x] != " " && lines[y][x] != "." {
						bits |= UInt8(1 << bit)
					}
				}
				guard bits != 0 else { continue }

				let gridRow = row + r, gridCol = col + c
				guard rows.indices.contains(gridRow), gridCol >= 0, gridCol < columns else { continue }
				rows[gridRow][gridCol] = TeletextCell(glyph: .mosaic(bits), fg: fg, bg: bg)
			}
		}
	}

	/// The coloured link bar along the bottom of a real page, spread evenly across the row.
	mutating func fastext(_ links: [(TeletextColour, String)], row: Int) {
		guard !links.isEmpty else { return }
		let slot = columns / links.count
		for (index, link) in links.enumerated() {
			write(link.1, row: row, col: index * slot + 1, fg: link.0)
		}
	}
}


// MARK: - Page

/// One page of the service: a grid, the number shown in the header, and how long the
/// carousel should leave it up.
struct TeletextPage {
	var number: Int
	var dwell: TimeInterval
	var grid: TeletextGrid

	/// Pages whose contents change every time they come round set this, and the scene
	/// calls it on the way in. Leave it nil for a page that is the same every time.
	var refresh: (() -> TeletextGrid)?

	init(number: Int, dwell: TimeInterval = 12) {
		self.number = number
		self.dwell = dwell
		self.grid = TeletextGrid(rowCount: TeletextGrid.bodyRows)
	}
}


// MARK: - Renderer

/// Draws grids into bitmaps. Text is the slow part, so callers render only when something
/// has actually changed rather than every frame.
enum TeletextRenderer {

	/// Pixels per point. The display is 1080-line, but 2x keeps it crisp in a window on a
	/// Retina Mac, and these bitmaps are only made on a page change.
	static let scale: CGFloat = 2

	/// Bedstead, by Ben Harris (bjh21.me.uk/bedstead), is an outline recreation of the
	/// Mullard SAA5050 teletext character generator, released into the public domain. It
	/// ships in Fonts/ and is registered below, with Menlo as a fallback if it is missing.
	private static let fontName = "Bedstead"
	private static let fallbackFontName = "Menlo-Bold"

	/// Registers the bundled font once, so the scene does not depend on it also being
	/// installed system-wide. Failure is fine: `font(for:)` falls back.
	private static let fontIsRegistered: Bool = {
		if NSFont(name: fontName, size: 12) != nil {
			return true
		}
		guard let url = Bundle.main.url(forResource: "bedstead", withExtension: "otf") else {
			return false
		}
		CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
		return NSFont(name: fontName, size: 12) != nil
	}()

	/// The font sized so that one character cell of the typeface covers one cell of the
	/// grid exactly, and how far it has to be stretched sideways to get there.
	///
	/// An SAA5050 character cell is six pixels across and ten down, but on a 4:3 screen
	/// 40 columns by 25 rows makes each cell wider than that — teletext pixels were not
	/// square. Stretching the glyphs to fill the cell is what reproduces that, and it is
	/// why the vertical strokes come out fatter than the horizontal ones.
	private static func font(for cellSize: CGSize) -> (font: NSFont, stretch: CGFloat, baseline: CGFloat) {
		let name = fontIsRegistered ? fontName : fallbackFontName
		let probe = NSFont(name: name, size: 100) ?? NSFont.monospacedSystemFont(ofSize: 100, weight: .bold)

		//Bedstead's ascender-to-descender box is exactly its character cell, so matching
		//that to the row height leaves no gaps between rows.
		let boxRatio = max((probe.ascender - probe.descender) / 100, 0.01)
		let size = cellSize.height / boxRatio
		let font = NSFont(name: name, size: size) ?? NSFont.monospacedSystemFont(ofSize: size, weight: .bold)

		let advance = ("M" as NSString).size(withAttributes: [.font: font]).width
		let stretch = max(cellSize.width / max(advance, 0.01), 1)
		//Where the baseline sits above the bottom of the cell, once the glyph box is
		//centred in it. For Bedstead that is simply its descender depth.
		let baseline = ((cellSize.height - (font.ascender - font.descender)) / 2) - font.descender

		return (font, stretch, baseline)
	}


	/// - Parameter flashingOnly: true draws only the glyphs of flashing cells, on a
	///   transparent background, ready to be blinked over the top of the main layer.
	/// - Returns: nil if the grid is empty, or if there is nothing to draw in this pass.
	static func render(_ grid: TeletextGrid, cellSize: CGSize, flashingOnly: Bool) -> CGImage? {
		guard grid.rowCount > 0, grid.columns > 0 else { return nil }
		if flashingOnly && !grid.hasFlashing { return nil }

		let width = cellSize.width * CGFloat(grid.columns)
		let height = cellSize.height * CGFloat(grid.rowCount)
		let pixelWidth = Int((width * scale).rounded())
		let pixelHeight = Int((height * scale).rounded())

		guard let ctx = CGContext(data: nil, width: pixelWidth, height: pixelHeight,
								  bitsPerComponent: 8, bytesPerRow: 0,
								  space: CGColorSpaceCreateDeviceRGB(),
								  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
			return nil
		}
		ctx.scaleBy(x: scale, y: scale)

		let previous = NSGraphicsContext.current
		NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
		defer { NSGraphicsContext.current = previous }

		let (cellFont, stretch, baseline) = font(for: cellSize)

		//Backgrounds and block graphics are solid colour meeting at cell edges, so
		//antialiasing them just puts seams between neighbours.
		ctx.setShouldAntialias(false)
		if !flashingOnly {
			//Black is a colour here, not a hole: a newsflash laid over a page has to
			//cover the page rather than let it show through.
			ctx.setFillColor(TeletextColour.black.nsColour.cgColor)
			ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

			for row in 0..<grid.rowCount {
				for col in 0..<grid.columns {
					let cell = grid[row, col]
					guard !cell.bg.isBlack else { continue }
					ctx.setFillColor(cell.bg.nsColour.cgColor)
					ctx.fill(rect(row: row, col: col, cellSize: cellSize, height: height))
				}
			}
		}

		for row in 0..<grid.rowCount {
			for col in 0..<grid.columns {
				let cell = grid[row, col]
				guard cell.flashing == flashingOnly, case .mosaic(let bits) = cell.glyph else { continue }
				drawMosaic(bits, in: rect(row: row, col: col, cellSize: cellSize, height: height),
						   colour: cell.fg, ctx: ctx)
			}
		}

		ctx.setShouldAntialias(true)

		for row in 0..<grid.rowCount {
			for col in 0..<grid.columns {
				let cell = grid[row, col]
				guard cell.flashing == flashingOnly, case .char(let character) = cell.glyph else { continue }

				//Core Text rather than AppKit drawing, so that the pen lands on the
				//baseline rather than on a bounding box whose height includes leading.
				let line = CTLineCreateWithAttributedString(
					NSAttributedString(string: String(character),
									   attributes: [.font: cellFont,
													.foregroundColor: cell.fg.nsColour]))

				let cellRect = rect(row: row, col: col, cellSize: cellSize, height: height)

				//Double height is a vertical stretch over this row and the one below,
				//which is what the real thing did.
				ctx.saveGState()
				ctx.translateBy(x: cellRect.minX,
								y: cell.doubleHeight ? cellRect.minY - cellSize.height : cellRect.minY)
				ctx.scaleBy(x: stretch, y: cell.doubleHeight ? 2 : 1)
				ctx.textPosition = CGPoint(x: 0, y: baseline)
				CTLineDraw(line, ctx)
				ctx.restoreGState()
			}
		}

		return ctx.makeImage()
	}


	/// Cell rectangles are worked out from the top down, because that is how pages read.
	private static func rect(row: Int, col: Int, cellSize: CGSize, height: CGFloat) -> CGRect {
		CGRect(x: CGFloat(col) * cellSize.width,
			   y: height - (CGFloat(row + 1) * cellSize.height),
			   width: cellSize.width, height: cellSize.height)
	}

	private static func drawMosaic(_ bits: UInt8, in cellRect: CGRect, colour: TeletextColour, ctx: CGContext) {
		let blockWidth = cellRect.width / 2
		let blockHeight = cellRect.height / 3
		ctx.setFillColor(colour.nsColour.cgColor)

		for bit in 0..<6 where bits & UInt8(1 << bit) != 0 {
			let column = bit % 2
			let rowFromTop = bit / 2
			ctx.fill(CGRect(x: cellRect.minX + (CGFloat(column) * blockWidth),
							y: cellRect.maxY - (CGFloat(rowFromTop + 1) * blockHeight),
							width: blockWidth, height: blockHeight))
		}
	}
}
