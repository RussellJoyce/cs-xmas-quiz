//
//  LEDStripView.swift
//  Quiz Server
//
//  Draws the LED strip published by ledsim across the bottom of the controller window.
//

import Cocoa

// MARK: - LEDStripView

class LEDStripView: NSView {

	enum Order {
		/// Pixel n is the nth LED along the real strip: what the strip actually looks like.
		case wiring
		/// Through `ledlookup`, the order the animations address. The strip is folded, so a
		/// sweep that is contiguous here appears at both ends in wiring order.
		case animation
	}

	//Animation order by default: the strip is folded, so this is the line as it appears on
	//the wall. Wiring order is only useful for checking the mapping itself.
	var order: Order = .animation { didSet { needsDisplay = true } }

	private var pixels: [UInt8] = []
	private var count = 0
	private var lookup: [UInt8] = []
	private var state: LEDFrameReader.State = .absent
	private var status = ""
	private var lastSeq: UInt32 = .max

	/// Height of the status line. The view is exactly this tall while the simulator is not
	/// running, and the strip occupies whatever is left when it is.
	static let statusHeight: CGFloat = 18
	private let ledInset: CGFloat = 1

	/// Only marks itself dirty when something actually changed, so a settled animation
	/// leaves the view idle rather than repainting 60 times a second.
	func update(state: LEDFrameReader.State, frame: LEDFrameReader.Frame?, lookup: [UInt8], fps: Double?) {
		let newStatus = LEDStripView.statusText(state: state, frame: frame, fps: fps, order: order)
		var changed = state != self.state || newStatus != status
		if let frame = frame, frame.seq != lastSeq {
			pixels = frame.pixels
			count = frame.count
			lastSeq = frame.seq
			changed = true
		}
		self.state = state
		self.status = newStatus
		self.lookup = lookup
		if changed { needsDisplay = true }
	}

	private static func statusText(state: LEDFrameReader.State, frame: LEDFrameReader.Frame?,
								   fps: Double?, order: Order) -> String {
		switch state {
		case .absent:
			return "LED simulator not running"
		case .live:
			let mode = order == .wiring ? "wiring order" : "animation order"
			guard let fps = fps else { return "LED simulator — \(mode)" }
			let rate = fps < 1 ? "holding" : String(format: "%.0f fps", fps)
			return "LED simulator — \(mode) — \(rate)"
		}
	}

	override var isFlipped: Bool { false }

	override func draw(_ dirtyRect: NSRect) {
		guard let ctx = NSGraphicsContext.current?.cgContext else { return }

		//The status line sits on the window's own background so that the view is just a
		//label while there is no simulator. Only the strip itself gets the black ground.
		drawStatus()

		guard state == .live, count > 0, pixels.count >= count * 3 else { return }

		let strip = NSRect(x: 0, y: 0, width: bounds.width,
		                   height: max(0, bounds.height - LEDStripView.statusHeight))
		guard strip.height > 0 else { return }

		ctx.setFillColor(NSColor.black.cgColor)
		ctx.fill(strip)

		let width = strip.width / CGFloat(count)
		for i in 0..<count {
			let source = (order == .animation && lookup.count > i) ? i : Int(lookup[i])
			guard source < count else { continue }
			let o = source * 3
			ctx.setFillColor(red: CGFloat(pixels[o]) / 255.0,
			                 green: CGFloat(pixels[o + 1]) / 255.0,
			                 blue: CGFloat(pixels[o + 2]) / 255.0,
			                 alpha: 1.0)
			//Insets are dropped once the cells get narrow, otherwise the gaps eat the strip.
			let inset = width > 4 ? ledInset : 0
			ctx.fill(NSRect(x: strip.minX + CGFloat(i) * width + inset / 2, y: strip.minY,
			                width: max(0.5, width - inset), height: strip.height))
		}
	}

	private func drawStatus() {
		let attributes: [NSAttributedString.Key: Any] = [
			.font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
			.foregroundColor: state == .live ? NSColor.secondaryLabelColor
			                                 : NSColor.tertiaryLabelColor
		]
		let text = status as NSString
		text.draw(at: NSPoint(x: 2, y: bounds.height - LEDStripView.statusHeight + 4), withAttributes: attributes)
	}
}


// MARK: - Control

/// Shows what the LED strip is doing, read from the shared frame file that ledsim publishes
private var ledStrip: LEDStripView?
private var ledStripTimer: Timer?
private let ledReader = LEDFrameReader()
private let ledStripHeight: CGFloat = 28
private let ledStripMargin: CGFloat = 4
private var ledStripExpanded = false
private var ledAbsentSince: Date?

func installLEDStrip(window : NSWindow?) {
	guard let window = window, let content = window.contentView else { return }

	//Starts collapsed: just the status line. The poll below expands it if a simulator is already running.
	growWindow(window, by: LEDStripView.statusHeight + ledStripMargin * 2)

	let strip = LEDStripView(frame: NSRect(x: 8, y: ledStripMargin, width: content.bounds.width - 16, height: LEDStripView.statusHeight))
	strip.autoresizingMask = [.width, .maxYMargin]
	content.addSubview(strip)
	ledStrip = strip
	ledStripTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in pollLEDStrip() }
}

private func pollLEDStrip() {
	guard let strip = ledStrip else { return }
	let (state, frame) = ledReader.poll()
	strip.update(state: state, frame: frame, lookup: ledReader.lookup, fps: ledReader.framesPerSecond)
	setLEDStripExpanded(shouldExpandLEDStrip(for: state))
}

private func shouldExpandLEDStrip(for state: LEDFrameReader.State) -> Bool {
	switch state {
	case .live:
		ledAbsentSince = nil
		return true
	case .absent:
		let since = ledAbsentSince ?? Date()
		ledAbsentSince = since
		return ledStripExpanded && Date().timeIntervalSince(since) < 1.5
	}
}

private func setLEDStripExpanded(_ expanded: Bool) {
	guard expanded != ledStripExpanded, let window = ledStrip?.window, let content = window.contentView else { return }
	ledStripExpanded = expanded
	growWindow(window, by: expanded ? ledStripHeight : -ledStripHeight)
	ledStrip?.frame = NSRect(x: 8, y: ledStripMargin,
							 width: content.bounds.width - 16,
							 height: LEDStripView.statusHeight + (expanded ? ledStripHeight : 0))
}

/// Grows or shrinks the window downwards, leaving the title bar where the user put it.
private func growWindow(_ window: NSWindow, by delta: CGFloat) {
	var frame = window.frame
	frame.origin.y -= delta
	frame.size.height += delta
	if let screen = window.screen {
		frame = window.constrainFrameRect(frame, to: screen)
	}
	window.setFrame(frame, display: true)
}
