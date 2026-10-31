//
//  SnowScenery.swift
//  Quiz Server
//
//  Created by Ian Gray on 2026-10-05.
//  Copyright © 2026 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa

/// What sort of thing snow is settling on, which decides how the snow behaves on it and
/// how it is shed.
enum SnowCatcherKind {
	/// `branch` is a ledge across the front of a tree (see `SnowShape.ledges`)
	case letter, tree, house, floor, branch

	/// Snow this thin stays put however steep the surface beneath it
	var stick: CGFloat {
		switch self {
		case .letter, .floor: return 1.2
		case .tree: return 6
		case .house: return 9
		case .branch: return 2
		}
	}

	/// Added to the tuned angle of repose. Roofs and branches hold snow on steeper slopes
	/// than the letters do, as in the pictures this is after.
	var extraRepose: CGFloat {
		switch self {
		case .letter, .floor: return 0
		case .tree: return 0.9
		case .house: return 0.7
		case .branch: return 0.5
		}
	}

	/// How much snow it has on it when the scene opens
	var startingDepth: CGFloat {
		switch self {
		case .letter: return 6
		case .tree: return 16
		case .house: return 24
		case .floor: return 30
		case .branch: return 8
		}
	}

	/// Whether it leans and shakes to shed its snow. A house just lets it slide off the roof.
	var moves: Bool {
		self != .house
	}
}


/// Something in the snow scene that snow settles on: its outline, as parts whose union is
/// solid, and how to draw it, both in the same coordinates with y up.
struct SnowShape {
	let kind: SnowCatcherKind
	let parts: [CGPath]
	let draw: (CGContext) -> Void
	/// Where smoke comes out, if anywhere
	var smoke: CGPoint? = nil
	/// Fairy light bulbs, which the scene sets twinkling
	var lights: [(point: CGPoint, colour: CGColor)] = []
	/// Branches across the front of the shape, each a line of points left to right. Snow
	/// can settle on these as well as on the outline, giving a tree depth.
	var ledges: [[CGPoint]] = []
}


/// The scenery for `SnowIdleScene`, in the flat vector style of a Christmas card: a
/// painted backdrop that never changes, and the houses, trees and letters that catch snow.
///
/// Sizes are for a scene 1080 points high and scaled to the real one.
enum SnowScenery {

	//MARK: - Palette

	private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
		NSColor(calibratedRed: r, green: g, blue: b, alpha: a).cgColor
	}

	static let windowLight = rgb(1.0, 0.80, 0.42)
	static let windowGlow = rgb(1.0, 0.70, 0.30, 0.9)
	static let frame = rgb(0.24, 0.14, 0.10)
	static let roof = rgb(0.30, 0.13, 0.15)
	static let brick = rgb(0.56, 0.25, 0.18)
	static let trunk = rgb(0.30, 0.18, 0.12)

	/// Height above the bottom of the scene that the village stands on, as a fraction of its height
	static let villageLine: CGFloat = 0.2


	//MARK: - Backdrop

	/// Everything behind the village, painted once: night sky, stars and moon, distant
	/// mountains, a wooded ridge, and the snowfield the village stands on.
	static func backdrop(size: CGSize, scale: CGFloat = 2) -> CGImage {
		let w = size.width, h = size.height
		let context = CGContext(data: nil, width: Int(w * scale), height: Int(h * scale), bitsPerComponent: 8, bytesPerRow: 0,
								space: CGColorSpaceCreateDeviceRGB(),
								bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
		context.scaleBy(x: scale, y: scale)
		var random = SeededRandom(seed: 2026)

		//Sky, darkest overhead and lightening towards the horizon
		let sky = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
							 colors: [rgb(0.02, 0.04, 0.12), rgb(0.07, 0.12, 0.27), rgb(0.20, 0.30, 0.46)] as CFArray,
							 locations: [0, 0.55, 1])!
		context.drawLinearGradient(sky, start: CGPoint(x: 0, y: h), end: CGPoint(x: 0, y: h * 0.15), options: [.drawsAfterEndLocation])

		//Stars, fewer and fainter towards the horizon
		for _ in 0..<160 {
			let y = h * CGFloat.random(in: 0.45...1, using: &random)
			let r = CGFloat.random(in: 0.6...1.6, using: &random)
			let alpha = CGFloat.random(in: 0.2...0.8, using: &random) * (y / h)
			context.setFillColor(rgb(1, 1, 0.95, alpha))
			context.fillEllipse(in: CGRect(x: CGFloat.random(in: 0...w, using: &random) - r, y: y - r, width: 2 * r, height: 2 * r))
		}

		drawMoon(in: context, at: CGPoint(x: w * 0.1, y: h * 0.86), radius: h * 0.05)

		//Distant mountains: peaks, with a saddle between each pair
		let peaks: [(CGFloat, CGFloat)] = [(-0.05, 0.26), (0.08, 0.38), (0.19, 0.30), (0.31, 0.44), (0.44, 0.33),
										   (0.56, 0.41), (0.70, 0.31), (0.83, 0.39), (0.95, 0.29), (1.05, 0.33)]
		var outline = [CGPoint]()
		for (i, peak) in peaks.enumerated() {
			outline.append(CGPoint(x: peak.0 * w, y: peak.1 * h))
			if i < peaks.count - 1 {
				let next = peaks[i + 1]
				outline.append(CGPoint(x: (peak.0 + next.0) / 2 * w, y: min(peak.1, next.1) * h * 0.78))
			}
		}
		let range = CGMutablePath()
		range.addLines(between: [CGPoint(x: 0, y: 0)] + outline + [CGPoint(x: w, y: 0)])
		range.closeSubpath()
		context.addPath(range)
		context.setFillColor(rgb(0.25, 0.34, 0.50))
		context.fillPath()

		//Snow on each peak, its corners on the mountain's own sides a little way down towards
		//the saddles, and a ragged snow line between them that stays inside the mountain.
		//Clipped to the range as well, so that it can never show against the sky.
		context.saveGState()
		context.addPath(range)
		context.clip()
		context.setFillColor(rgb(0.76, 0.82, 0.92))
		for i in stride(from: 2, to: outline.count - 2, by: 2) {
			let top = outline[i]
			let left = top + (outline[i - 1] - top) * 0.3
			let right = top + (outline[i + 1] - top) * 0.27
			let along = { (t: CGFloat, dip: CGFloat) -> CGPoint in
				CGPoint(x: left.x + (right.x - left.x) * t, y: left.y + (right.y - left.y) * t - dip * (top.y - min(left.y, right.y)))
			}
			let cap = CGMutablePath()
			cap.addLines(between: [top, right, along(0.75, 0.05), along(0.55, 0.3), along(0.35, 0.08), along(0.18, 0.25), left])
			cap.closeSubpath()
			context.addPath(cap)
			context.fillPath()
		}
		context.restoreGState()

		//A nearer wooded ridge
		let ridgeColour = rgb(0.15, 0.22, 0.36)
		let ridgeHeight = { (x: CGFloat) -> CGFloat in
			h * (0.235 + 0.025 * sin(x / w * 7.0 + 1.0) + 0.012 * sin(x / w * 17.0))
		}
		let ridge = CGMutablePath()
		ridge.move(to: .zero)
		for x in stride(from: CGFloat(0), through: w, by: 8) {
			ridge.addLine(to: CGPoint(x: x, y: ridgeHeight(x)))
		}
		ridge.addLine(to: CGPoint(x: w, y: 0))
		ridge.closeSubpath()
		context.addPath(ridge)
		context.setFillColor(ridgeColour)
		context.fillPath()

		var x: CGFloat = 0
		while x < w {
			let treeH = h * CGFloat.random(in: 0.03...0.075, using: &random)
			let y = ridgeHeight(x) - 3
			context.move(to: CGPoint(x: x - treeH * 0.28, y: y))
			context.addLine(to: CGPoint(x: x, y: y + treeH))
			context.addLine(to: CGPoint(x: x + treeH * 0.28, y: y))
			context.closePath()
			x += CGFloat.random(in: 6...22, using: &random)
		}
		context.setFillColor(rgb(0.12, 0.19, 0.31))
		context.fillPath()

		//The snowfield, from just behind the village to the bottom of the screen
		let fieldTop = { (x: CGFloat) -> CGFloat in
			h * (villageLine + 0.03 + 0.012 * sin(x / w * 5.0 + 2.0))
		}
		let field = CGMutablePath()
		field.move(to: .zero)
		for x in stride(from: CGFloat(0), through: w, by: 8) {
			field.addLine(to: CGPoint(x: x, y: fieldTop(x)))
		}
		field.addLine(to: CGPoint(x: w, y: 0))
		field.closeSubpath()
		context.saveGState()
		context.addPath(field)
		context.clip()
		let snow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
							  colors: [rgb(0.80, 0.86, 0.95), rgb(0.55, 0.64, 0.82)] as CFArray, locations: [0, 1])!
		context.drawLinearGradient(snow, start: CGPoint(x: 0, y: h * (villageLine + 0.05)), end: .zero, options: [])
		context.restoreGState()

		return context.makeImage()!
	}

	/// A crescent moon in a soft halo
	private static func drawMoon(in context: CGContext, at centre: CGPoint, radius r: CGFloat) {
		let halo = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
							  colors: [rgb(0.9, 0.92, 1.0, 0.22), rgb(0.9, 0.92, 1.0, 0)] as CFArray, locations: [0, 1])!
		context.drawRadialGradient(halo, startCenter: centre, startRadius: r * 0.8, endCenter: centre, endRadius: r * 4,
								   options: [.drawsBeforeStartLocation])

		//The disc less an offset bite, as one outline, so there is no seam where the two meet
		let disc = CGRect(x: centre.x - r, y: centre.y - r, width: 2 * r, height: 2 * r)
		let bite = disc.offsetBy(dx: r * 0.45, dy: r * 0.25)
		context.addPath(CGPath(ellipseIn: disc, transform: nil).subtracting(CGPath(ellipseIn: bite, transform: nil)))
		context.setFillColor(rgb(0.98, 0.96, 0.86))
		context.fillPath()
	}


	//MARK: - The village

	/// Where something that catches snow goes: its shape, where the shape's origin lands in
	/// the scene, and how near the viewer it is.
	struct Placement {
		let shape: SnowShape
		let origin: CGPoint
		let zPosition: CGFloat
	}

	/// A row of houses with pines between them along the village line, and two big pines
	/// in front at the sides of the screen.
	static func village(size: CGSize) -> [Placement] {
		let w = size.width, h = size.height
		let s = h / 1080
		let line = h * villageLine
		var placements = [Placement]()

		//Centre as a fraction of the width, then width, wall height and roof height
		let houses: [(CGFloat, CGFloat, CGFloat, CGFloat, Bool, CGColor, CGFloat)] = [
			(0.270, 150, 105, 75, false, rgb(0.90, 0.52, 0.20), 0.72),
			(0.385, 115, 145, 60, false, rgb(0.66, 0.19, 0.20), 0.30),
			(0.520, 200, 100, 58, true, rgb(0.86, 0.66, 0.26), 0.70),
			(0.655, 130, 125, 80, false, rgb(0.18, 0.48, 0.50), 0.25),
			(0.780, 170, 95, 62, true, rgb(0.52, 0.40, 0.66), 0.30)
		]
		for (cx, width, wall, roofH, hipped, colour, chimney) in houses {
			let shape = house(width: width * s, wall: wall * s, roof: roofH * s, hipped: hipped,
							  colour: colour, chimneyAt: chimney, scale: s)
			placements.append(Placement(shape: shape, origin: CGPoint(x: cx * w - width * s / 2, y: line), zPosition: 8))
		}

		for (cx, height) in [(0.200, 175), (0.330, 150), (0.455, 135), (0.590, 185), (0.720, 145)] as [(CGFloat, CGFloat)] {
			let shape = pine(height: height * s, light: rgb(0.10, 0.30, 0.27), dark: rgb(0.06, 0.21, 0.20))
			placements.append(Placement(shape: shape, origin: CGPoint(x: cx * w, y: line - 6 * s), zPosition: 9))
		}

		for (cx, height) in [(0.05, 0.58), (0.955, 0.62)] as [(CGFloat, CGFloat)] {
			let shape = pine(height: height * h, light: rgb(0.06, 0.20, 0.19), dark: rgb(0.03, 0.13, 0.14),
							 branches: rgb(0.08, 0.25, 0.23))
			placements.append(Placement(shape: shape, origin: CGPoint(x: cx * w, y: -0.03 * h), zPosition: 12))
		}
		return placements
	}

	/// A house, its bottom left corner at the origin. A gabled house faces us end on, with the
	/// wall carried up into the gable under a band of roof; a hipped one is side on, all roof.
	static func house(width w: CGFloat, wall: CGFloat, roof roofH: CGFloat, hipped: Bool,
					  colour: CGColor, chimneyAt chimneyX: CGFloat, scale s: CGFloat) -> SnowShape {
		let overhang = 10 * s
		let walls = CGPath(rect: CGRect(x: 0, y: 0, width: w, height: wall), transform: nil)

		let roofPath = CGMutablePath()
		if hipped {
			roofPath.addLines(between: [CGPoint(x: -overhang, y: wall), CGPoint(x: w * 0.22, y: wall + roofH),
										CGPoint(x: w * 0.78, y: wall + roofH), CGPoint(x: w + overhang, y: wall)])
		} else {
			roofPath.addLines(between: [CGPoint(x: -overhang, y: wall), CGPoint(x: w / 2, y: wall + roofH),
										CGPoint(x: w + overhang, y: wall)])
		}
		roofPath.closeSubpath()

		//The chimney rises from inside the roof, so it has to be where the roof is high enough
		let chimneyW = 16 * s
		let chimneyCentre = w * chimneyX
		let chimneyTop = wall + roofH + 14 * s
		let chimney = CGPath(rect: CGRect(x: chimneyCentre - chimneyW / 2, y: wall + roofH * 0.3,
										  width: chimneyW, height: chimneyTop - (wall + roofH * 0.3)), transform: nil)

		//A single storey leaves a bare band of wall under the eaves, so it gets fairy lights
		//there and a wreath over the door
		let floors = wall > 115 * s ? 2 : 1
		let perFloor = w > 160 * s ? 3 : 2
		let doorSlot = perFloor == 3 ? 1 : 0
		let doorX = w * CGFloat(doorSlot + 1) / CGFloat(perFloor + 1)
		let lights = floors == 1 ? fairyLights(width: w, hangingAt: wall - 10 * s, scale: s) : []

		let draw = { (context: CGContext) in
			//Chimney first, so the roof overlaps its foot
			context.setFillColor(brick)
			context.addPath(chimney)
			context.fillPath()
			context.setFillColor(frame)
			context.fill(CGRect(x: chimneyCentre - chimneyW / 2 - 2 * s, y: chimneyTop - 5 * s, width: chimneyW + 4 * s, height: 5 * s))

			context.setFillColor(colour)
			context.addPath(walls)
			context.fillPath()
			//A darker plinth along the foot of the walls
			context.setFillColor(rgb(0, 0, 0, 0.18))
			context.fill(CGRect(x: 0, y: 0, width: w, height: 8 * s))

			context.setFillColor(roof)
			context.addPath(roofPath)
			context.fillPath()
			if !hipped {
				//The gable: wall colour inside a band of roof
				let band = 11 * s
				let gable = CGMutablePath()
				gable.addLines(between: [CGPoint(x: -overhang + band * 1.8, y: wall), CGPoint(x: w / 2, y: wall + roofH - band * 1.5),
										 CGPoint(x: w + overhang - band * 1.8, y: wall)])
				gable.closeSubpath()
				context.setFillColor(colour)
				context.addPath(gable)
				context.fillPath()
				if roofH > 65 * s {
					drawWindow(in: context, CGRect(x: w / 2 - 9 * s, y: wall + roofH * 0.25, width: 18 * s, height: 18 * s), round: true, scale: s)
				}
			}
			//Shadow under the eaves
			context.setFillColor(rgb(0, 0, 0, 0.22))
			context.fill(CGRect(x: 0, y: wall - 7 * s, width: w, height: 7 * s))

			//A door, and windows either side and above
			for floor in 0..<floors {
				for slot in 0..<perFloor {
					let cx = w * CGFloat(slot + 1) / CGFloat(perFloor + 1)
					if floor == 0 && slot == doorSlot {
						context.setFillColor(frame)
						context.fill(CGRect(x: cx - 12 * s, y: 0, width: 24 * s, height: 46 * s))
						context.setFillColor(windowLight)
						context.fill(CGRect(x: cx - 7 * s, y: 32 * s, width: 14 * s, height: 8 * s))
					} else {
						let y = floor == 0 ? 18 * s : wall * 0.58
						drawWindow(in: context, CGRect(x: cx - 11 * s, y: y, width: 22 * s, height: 28 * s), round: false, scale: s)
					}
				}
			}

			if floors == 1 {
				drawWreath(in: context, at: CGPoint(x: doorX, y: 46 * s + (wall - 30 * s - 46 * s) / 2 + 2 * s), radius: 9 * s, scale: s)
				drawFairyLights(in: context, lights, width: w, hangingAt: wall - 10 * s, scale: s)
			}
		}

		return SnowShape(kind: .house, parts: [walls, roofPath, chimney], draw: draw,
						 smoke: CGPoint(x: chimneyCentre, y: chimneyTop), lights: lights)
	}

	private static let bulbColours = [rgb(0.95, 0.20, 0.20), rgb(1.0, 0.78, 0.25), rgb(0.25, 0.85, 0.35), rgb(0.30, 0.55, 1.0)]

	/// The swags a string of lights hangs in, along the wall `hangingAt` up, each a
	/// quadratic curve between two hooks
	private static func swags(width w: CGFloat, hangingAt y: CGFloat, scale s: CGFloat) -> [(CGPoint, CGPoint, CGPoint)] {
		let count = max(2, Int((w / (48 * s)).rounded()))
		let inset = 6 * s
		let span = (w - 2 * inset) / CGFloat(count)
		return (0..<count).map { i in
			let a = CGPoint(x: inset + CGFloat(i) * span, y: y)
			let b = CGPoint(x: a.x + span, y: y)
			return (a, CGPoint(x: (a.x + b.x) / 2, y: y - 20 * s), b)
		}
	}

	/// Where the bulbs go: evenly along each swag, in repeating colours
	private static func fairyLights(width w: CGFloat, hangingAt y: CGFloat, scale s: CGFloat) -> [(point: CGPoint, colour: CGColor)] {
		var lights = [(point: CGPoint, colour: CGColor)]()
		for (a, control, b) in swags(width: w, hangingAt: y, scale: s) {
			for k in 1...3 {
				let t = CGFloat(k) / 4
				let u = 1 - t
				let p = CGPoint(x: u * u * a.x + 2 * u * t * control.x + t * t * b.x,
								y: u * u * a.y + 2 * u * t * control.y + t * t * b.y)
				lights.append((p, bulbColours[lights.count % bulbColours.count]))
			}
		}
		return lights
	}

	private static func drawFairyLights(in context: CGContext, _ lights: [(point: CGPoint, colour: CGColor)],
										width w: CGFloat, hangingAt y: CGFloat, scale s: CGFloat) {
		context.setStrokeColor(rgb(0.10, 0.12, 0.10))
		context.setLineWidth(1.2 * s)
		for (a, control, b) in swags(width: w, hangingAt: y, scale: s) {
			context.move(to: a)
			context.addQuadCurve(to: b, control: control)
		}
		context.strokePath()
		for light in lights {
			context.saveGState()
			context.setShadow(offset: .zero, blur: 6 * s, color: light.colour)
			context.setFillColor(light.colour)
			context.fillEllipse(in: CGRect(x: light.point.x - 2.6 * s, y: light.point.y - 3.6 * s, width: 5.2 * s, height: 6 * s))
			context.restoreGState()
		}
	}

	/// A holly wreath: a ring of leaves, a few berries, and a red bow at the bottom
	private static func drawWreath(in context: CGContext, at centre: CGPoint, radius r: CGFloat, scale s: CGFloat) {
		let leaves = [rgb(0.08, 0.36, 0.18), rgb(0.12, 0.48, 0.24)]
		for i in 0..<16 {
			let angle = CGFloat(i) / 16 * 2 * .pi
			let p = CGPoint(x: centre.x + cos(angle) * r, y: centre.y + sin(angle) * r)
			let leaf = r * 0.42
			context.setFillColor(leaves[i % 2])
			context.fillEllipse(in: CGRect(x: p.x - leaf, y: p.y - leaf, width: 2 * leaf, height: 2 * leaf))
		}
		context.setFillColor(rgb(0.85, 0.10, 0.12))
		for angle in [0.4, 1.9, 2.7, 4.0, 5.6] as [CGFloat] {
			let p = CGPoint(x: centre.x + cos(angle) * r * 1.05, y: centre.y + sin(angle) * r * 1.05)
			context.fillEllipse(in: CGRect(x: p.x - 1.6 * s, y: p.y - 1.6 * s, width: 3.2 * s, height: 3.2 * s))
		}
		//The bow: two loops and two tails either side of a knot, at the bottom of the ring
		let knot = CGPoint(x: centre.x, y: centre.y - r)
		let bow = CGMutablePath()
		bow.addLines(between: [knot, CGPoint(x: knot.x - 6 * s, y: knot.y + 4 * s), CGPoint(x: knot.x - 6 * s, y: knot.y - 3 * s)])
		bow.closeSubpath()
		bow.addLines(between: [knot, CGPoint(x: knot.x + 6 * s, y: knot.y + 4 * s), CGPoint(x: knot.x + 6 * s, y: knot.y - 3 * s)])
		bow.closeSubpath()
		bow.addLines(between: [knot, CGPoint(x: knot.x - 4 * s, y: knot.y - 9 * s), CGPoint(x: knot.x - 1 * s, y: knot.y - 9 * s)])
		bow.closeSubpath()
		bow.addLines(between: [knot, CGPoint(x: knot.x + 4 * s, y: knot.y - 9 * s), CGPoint(x: knot.x + 1 * s, y: knot.y - 9 * s)])
		bow.closeSubpath()
		context.addPath(bow)
		context.fillPath()
		context.fillEllipse(in: CGRect(x: knot.x - 2 * s, y: knot.y - 2 * s, width: 4 * s, height: 4 * s))
	}

	/// A lit window glowing into the night
	private static func drawWindow(in context: CGContext, _ rect: CGRect, round: Bool, scale s: CGFloat) {
		context.saveGState()
		context.setShadow(offset: .zero, blur: 14 * s, color: windowGlow)
		context.setFillColor(windowLight)
		if round {
			context.fillEllipse(in: rect)
		} else {
			context.fill(rect)
		}
		context.restoreGState()

		context.setStrokeColor(frame)
		context.setLineWidth(2 * s)
		if round {
			context.strokeEllipse(in: rect)
		} else {
			context.stroke(rect)
			context.move(to: CGPoint(x: rect.midX, y: rect.minY))
			context.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
			context.move(to: CGPoint(x: rect.minX, y: rect.midY))
			context.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
			context.strokePath()
		}
	}

	/// A pine, its trunk's foot at the origin: four tiers of branches, narrowing upwards,
	/// each with a curved hem and shaded on its right. Given a `branches` colour, it also has
	/// branches reaching out of each tier towards us, drawn in that colour, for snow to
	/// settle on across the front of the tree.
	static func pine(height h: CGFloat, light: CGColor, dark: CGColor, branches: CGColor? = nil) -> SnowShape {
		let stem = CGPath(rect: CGRect(x: -0.035 * h, y: 0, width: 0.07 * h, height: 0.16 * h), transform: nil)

		let tiers = 4
		let tierH = 0.34 * h
		let step = (h - tierH - 0.08 * h) / CGFloat(tiers - 1)
		var tierPaths = [CGPath]()
		for i in 0..<tiers {
			let base = 0.08 * h + CGFloat(i) * step
			let halfWidth = 0.36 * h * (1 - CGFloat(i) * 0.21)
			let tier = CGMutablePath()
			tier.move(to: CGPoint(x: -halfWidth, y: base))
			tier.addLine(to: CGPoint(x: 0, y: base + tierH))
			tier.addLine(to: CGPoint(x: halfWidth, y: base))
			tier.addQuadCurve(to: CGPoint(x: -halfWidth, y: base), control: CGPoint(x: 0, y: base + 0.09 * h))
			tier.closeSubpath()
			tierPaths.append(tier)
		}

		//Each tier's branches sit in the band of it left showing below the tier above, clear
		//of the hem above and below. Two to four to a tier, placed at random but never on
		//top of one another, and each its own length, droop and tilt, so that no two trees,
		//or tiers, look alike. Drooping at the ends, each gathers snow in the middle and
		//thins out towards the tips.
		var ledgesByTier = [[[CGPoint]]](repeating: [], count: tiers)
		if branches != nil {
			var random = SeededRandom(seed: UInt64(h))
			for i in 0..<tiers {
				let base = 0.08 * h + CGFloat(i) * step
				let halfWidth = 0.36 * h * (1 - CGFloat(i) * 0.21)
				let widthAt = { (y: CGFloat) in halfWidth * (1 - (y - base) / tierH) }
				let band = (base + 0.055 * h)...(base + step - 0.03 * h)
				let wanted = Int.random(in: (i == tiers - 1 ? 2...3 : 2...4), using: &random)

				var placed = [(y: CGFloat, from: CGFloat, to: CGFloat)]()
				for _ in 0..<40 where placed.count < wanted {
					let y = CGFloat.random(in: band, using: &random)
					let reach = 0.88 * widthAt(y)
					let length = widthAt(y) * CGFloat.random(in: 0.45...1.0, using: &random)
					let slack = max(0, reach - length / 2)
					let centre = CGFloat.random(in: -slack...slack, using: &random)
					let from = centre - length / 2, to = centre + length / 2
					let clashes = placed.contains { other in
						abs(other.y - y) < 0.045 * h && from < other.to + 6 && to > other.from - 6
					}
					if !clashes {
						placed.append((y, from, to))
					}
				}
				for p in placed {
					let length = p.to - p.from
					ledgesByTier[i].append(ledge(from: p.from, to: p.to, at: p.y,
												 droop: length * CGFloat.random(in: 0.06...0.18, using: &random),
												 tilt: length * CGFloat.random(in: -0.06...0.06, using: &random)))
				}
			}
		}

		let draw = { (context: CGContext) in
			context.setFillColor(trunk)
			context.addPath(stem)
			context.fillPath()
			for (i, tier) in tierPaths.enumerated() {
				context.saveGState()
				context.addPath(tier)
				context.clip()
				context.setFillColor(light)
				context.fill(tier.boundingBoxOfPath)
				context.setFillColor(dark)
				var shade = tier.boundingBoxOfPath
				shade.origin.x = 0
				context.fill(shade)
				context.restoreGState()

				//This tier's branches, before the tier above is drawn over their roots
				if let branches = branches {
					context.setFillColor(branches)
					for line in ledgesByTier[i] {
						//Longer branches are sturdier
						let length = line.last!.x - line.first!.x
						context.addPath(branch(under: line, thickness: min(0.03 * h, 0.01 * h + 0.05 * length)))
						context.fillPath()
					}
				}
			}
		}
		return SnowShape(kind: .tree, parts: [stem] + tierPaths, draw: draw, ledges: ledgesByTier.flatMap { $0 })
	}

	/// A drooping line of points from `from` to `to`, at `y` in the middle, falling `droop`
	/// towards each end, with the right end `tilt` higher than the left
	private static func ledge(from: CGFloat, to: CGFloat, at y: CGFloat, droop: CGFloat, tilt: CGFloat) -> [CGPoint] {
		let half = (to - from) / 2
		let middle = from + half
		return stride(from: from, through: to, by: 4).map { x in
			let u = (x - middle) / half
			return CGPoint(x: x, y: y - droop * u * u + tilt * u / 2)
		}
	}

	/// The branch a ledge rests on: a band hanging below the line, thickest in the middle
	private static func branch(under line: [CGPoint], thickness: CGFloat) -> CGPath {
		let path = CGMutablePath()
		path.addLines(between: line)
		let first = line.first!.x, span = line.last!.x - first
		for p in line.reversed() {
			let u = (p.x - first) / span * 2 - 1
			path.addLine(to: CGPoint(x: p.x, y: p.y - thickness * (1 - u * u * 0.7)))
		}
		path.closeSubpath()
		return path
	}


	//MARK: - The title

	/// A letter of the title: red, darkening downwards, with a soft shadow
	static func letter(glyph path: CGPath) -> SnowShape {
		let bounds = path.boundingBoxOfPath
		let draw = { (context: CGContext) in
			context.saveGState()
			context.setShadow(offset: CGSize(width: 3, height: -5), blur: 14, color: rgb(0, 0, 0, 0.8))
			context.addPath(path)
			context.setFillColor(rgb(0.55, 0.04, 0.08))
			context.fillPath()
			context.restoreGState()

			context.saveGState()
			context.addPath(path)
			context.clip()
			let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
									  colors: [rgb(0.93, 0.22, 0.22), rgb(0.62, 0.05, 0.10)] as CFArray, locations: [0, 1])!
			context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: bounds.maxY), end: CGPoint(x: 0, y: bounds.minY), options: [])
			context.restoreGState()
		}
		return SnowShape(kind: .letter, parts: [path], draw: draw)
	}
}


private func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
private func - (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
private func * (a: CGPoint, k: CGFloat) -> CGPoint { CGPoint(x: a.x * k, y: a.y * k) }


/// The same scenery every time: a small linear congruential generator
private struct SeededRandom: RandomNumberGenerator {
	private var state: UInt64

	init(seed: UInt64) {
		state = seed
	}

	mutating func next() -> UInt64 {
		state = state &* 6364136223846793005 &+ 1442695040888963407
		return state
	}
}
