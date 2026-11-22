//
//  WavelengthBarView.swift
//  Quiz Server
//
//  A small copy of the wavelength bar for the controller window, with the rolled target marked on it

import Cocoa

class WavelengthBarView: NSView {

	/// Where the marker sits, or nil for no marker.
	var value: Int? {
		didSet { if value != oldValue { needsDisplay = true } }
	}

	/// Drawn faintly while the numbers are still spinning, solid once the roll has stopped.
	var settled = true {
		didSet { if settled != oldValue { needsDisplay = true } }
	}

	private let sideMargin: CGFloat = 14
	private let pointerHeight: CGFloat = 18
	private let labelHeight: CGFloat = 28
	private let tickLength: CGFloat = 6

	private var barRect: NSRect {
		let top = bounds.maxY - pointerHeight - 4
		let bottom = bounds.minY + labelHeight
		return NSRect(x: bounds.minX + sideMargin, y: bottom,
					  width: bounds.width - (sideMargin * 2), height: max(10, top - bottom))
	}

	private func xFor(value: Int) -> CGFloat {
		let bar = barRect
		let span = CGFloat(WavelengthScene.maxValue - WavelengthScene.minValue)
		let clamped = min(WavelengthScene.maxValue, max(WavelengthScene.minValue, value))
		return bar.minX + (CGFloat(clamped - WavelengthScene.minValue) / span) * bar.width
	}

	override func draw(_ dirtyRect: NSRect) {
		let bar = barRect
		let rounded = NSBezierPath(roundedRect: bar, xRadius: 5, yRadius: 5)

		NSGradient(colors: WavelengthScene.barColours, atLocations: WavelengthScene.barLocations,
				   colorSpace: .deviceRGB)?.draw(in: rounded, angle: 0)
		NSColor.labelColor.withAlphaComponent(0.6).setStroke()
		rounded.lineWidth = 1.5
		rounded.stroke()

		drawScale(below: bar)

		if let value = value {
			drawMarker(at: xFor(value: value), bar: bar, value: value)
		}
	}

	/// Ticks and numbers every ten, plus the two ends, as on the main display.
	private func drawScale(below bar: NSRect) {
		var values = [WavelengthScene.minValue]
		values += stride(from: 10, through: 90, by: 10)
		values += [WavelengthScene.maxValue]

		for value in values {
			let x = xFor(value: value)
			let isEnd = (value == WavelengthScene.minValue || value == WavelengthScene.maxValue)

			NSColor.secondaryLabelColor.setFill()
			NSRect(x: x - 0.75, y: bar.minY - tickLength, width: 1.5, height: tickLength).fill()

			let attributes: [NSAttributedString.Key: Any] = [
				.font: NSFont.boldSystemFont(ofSize: isEnd ? 14 : 11),
				.foregroundColor: isEnd ? NSColor.labelColor : NSColor.secondaryLabelColor
			]
			let text = NSAttributedString(string: "\(value)", attributes: attributes)
			let size = text.size()
			text.draw(at: NSPoint(x: x - (size.width / 2), y: bar.minY - tickLength - 2 - size.height))
		}
	}

	/// A line through the bar with a pointer above it
	private func drawMarker(at x: CGFloat, bar: NSRect, value: Int) {
		let alpha: CGFloat = settled ? 1.0 : 0.45
		let fill = NSColor.white.withAlphaComponent(alpha)
		let edge = NSColor.black.withAlphaComponent(alpha)

		let line = NSBezierPath(roundedRect: NSRect(x: x - 3, y: bar.minY - 4, width: 6, height: bar.height + 8),
								xRadius: 3, yRadius: 3)
		fill.setFill()
		line.fill()
		edge.setStroke()
		line.lineWidth = 1.5
		line.stroke()

		let pointer = NSBezierPath()
		let tipY = bar.maxY + 3
		pointer.move(to: NSPoint(x: x, y: tipY))
		pointer.line(to: NSPoint(x: x - 10, y: tipY + pointerHeight))
		pointer.line(to: NSPoint(x: x + 10, y: tipY + pointerHeight))
		pointer.close()
		fill.setFill()
		pointer.fill()
		edge.setStroke()
		pointer.lineWidth = 1.5
		pointer.stroke()
	}
}
