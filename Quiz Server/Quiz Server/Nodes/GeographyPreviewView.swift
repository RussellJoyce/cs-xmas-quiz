//
//  GeographyPreviewView.swift
//  Quiz Server
//
//  Created by Ian Gray on 2026-08-30.
//  Copyright © 2026 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa

/// Shows the geography question the host has picked, with a marker at the answer position
/// they have typed in. Lets them check the answer lands where they meant before revealing it.
class GeographyPreviewView: NSView {

	/// The question image, or nil when nothing is selected.
	var image: NSImage? {
		didSet { needsDisplay = true }
	}

	/// The answer, as percentages from the top left
	var marker: (x: Int, y: Int)? {
		didSet { needsDisplay = true }
	}

	private static let dotRadius: CGFloat = 5

	override func draw(_ dirtyRect: NSRect) {
		NSColor.windowBackgroundColor.setFill()
		bounds.fill()

		guard let image = image else {
			return
		}

		let frame = imageFrame(for: image.size)
		image.draw(in: frame)

		NSColor.separatorColor.setStroke()
		NSBezierPath(rect: frame).stroke()

		guard let marker = marker else {
			return
		}

		//The round measures down from the top of the image; AppKit draws up from the bottom
		let x = frame.minX + frame.width * CGFloat(marker.x) / 100
		let y = frame.maxY - frame.height * CGFloat(marker.y) / 100

		let dot = NSBezierPath(ovalIn: NSRect(x: x - GeographyPreviewView.dotRadius,
											  y: y - GeographyPreviewView.dotRadius,
											  width: GeographyPreviewView.dotRadius * 2,
											  height: GeographyPreviewView.dotRadius * 2))
		NSColor.systemRed.setFill()
		dot.fill()
		//A white rim so the dot stays visible against a red or dark part of the map
		NSColor.white.setStroke()
		dot.lineWidth = 1.5
		dot.stroke()
	}

	/// The image letterboxed inside the view. The marker is placed against this rather than
	/// against the view's bounds, so it sits where it will on the main display.
	private func imageFrame(for size: NSSize) -> NSRect {
		guard size.width > 0, size.height > 0 else {
			return bounds
		}
		let scale = min(bounds.width / size.width, bounds.height / size.height)
		let scaled = NSSize(width: size.width * scale, height: size.height * scale)
		return NSRect(x: bounds.midX - scaled.width / 2,
					  y: bounds.midY - scaled.height / 2,
					  width: scaled.width,
					  height: scaled.height)
	}
}
