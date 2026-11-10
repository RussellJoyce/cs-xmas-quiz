//
//  TreeRingsView.swift
//  Quiz Server
//
//  Draws the desk trees published by treesim as a row of LED rings in the controller window.
//

import Cocoa

class TreeRingsView: NSView, SimulatorMonitor {

	/// Draw the bytes sent to the LEDs as they are, rather than how bright the LEDs look.
	/// See `screenLevel`.
	var showWireValues = false { didSet { needsDisplay = true } }

	let expandedHeight: CGFloat = 64

	private let reader = TreeFrameReader()
	private var live = false
	private var trees: [TreeFrameReader.Tree] = []
	private var status = ""

	//Caps on the drawing, so that a few trees in a wide window do not become dinner plates
	private let maxCellWidth: CGFloat = 76
	private let labelHeight: CGFloat = 13

	//MARK: - Polling

	/// Only marks itself dirty when something changed. Unlike the strip, the trees animate
	/// all the time, so in practice this is every frame while treesim runs.
	func poll() -> Bool {
		let (live, trees) = reader.poll()
		let status = TreeRingsView.statusText(live: live, trees: trees)
		if live != self.live || status != self.status || trees != self.trees {
			needsDisplay = true
		}
		self.live = live
		self.trees = trees
		self.status = status
		return live
	}

	private static func statusText(live: Bool, trees: [TreeFrameReader.Tree]) -> String {
		guard live else { return "Tree simulator not running" }
		let connected = trees.filter { $0.process != .dead && $0.connected }
		var text = "Tree simulator — \(connected.count) of \(trees.count) connected"
		if let last = connected.first?.last, !last.isEmpty { text += " — last '\(last)'" }
		return text
	}

	//MARK: - Colour

	/// The bytes sent to a WS2812 set its PWM duty, so they are linear in light (the firmware
	/// has already gamma corrected them for the eye). Drawn as they are, a monitor treats them
	/// as sRGB, and the rings look much darker than the trees do on a desk. Encoding the light
	/// level as sRGB puts it on screen at about the brightness the LED has. treesim does the same.
	private static let screenLevel: [CGFloat] = (0..<256).map { i in
		let l = Double(i) / 255
		return CGFloat(l <= 0.0031308 ? 12.92 * l : 1.055 * pow(l, 1 / 2.4) - 0.055)
	}

	private func colour(_ pixels: [UInt8], _ led: Int) -> (CGFloat, CGFloat, CGFloat)? {
		let o = led * 3
		guard pixels.count >= o + 3 else { return nil }
		let r = pixels[o], g = pixels[o + 1], b = pixels[o + 2]
		if r == 0 && g == 0 && b == 0 { return nil }
		if showWireValues { return (CGFloat(r) / 255, CGFloat(g) / 255, CGFloat(b) / 255) }
		return (TreeRingsView.screenLevel[Int(r)], TreeRingsView.screenLevel[Int(g)],
		        TreeRingsView.screenLevel[Int(b)])
	}

	//MARK: - Drawing

	override var isFlipped: Bool { false }

	override func draw(_ dirtyRect: NSRect) {
		guard let ctx = NSGraphicsContext.current?.cgContext else { return }
		drawStatus()

		guard live, !trees.isEmpty else { return }
		let area = NSRect(x: 0, y: 0, width: bounds.width,
		                  height: max(0, bounds.height - SimulatorMonitorLayout.statusHeight))
		guard area.height > labelHeight + 8 else { return }

		ctx.setFillColor(NSColor.black.cgColor)
		ctx.fill(area)

		let cell = min(maxCellWidth, area.width / CGFloat(trees.count))
		let ringArea = area.height - labelHeight - 4
		//Eight dots round a circle of radius R are 0.77R apart, so dots of 0.28R leave a gap
		let radius = max(2, min(cell / 2 - 4, ringArea / 2 - 2) / 1.28)
		let dot = radius * 0.28

		for (i, tree) in trees.enumerated() {
			let cx = area.minX + cell * (CGFloat(i) + 0.5)
			let cy = area.minY + labelHeight + 2 + ringArea / 2
			let running = tree.process == .running

			for led in 0..<TreeFrameReader.ledsPerTree {
				//LED 0 at the top, then clockwise
				let angle = CGFloat.pi / 2 - CGFloat(led) * 2 * .pi / CGFloat(TreeFrameReader.ledsPerTree)
				let x: CGFloat = cx + radius * cos(angle)
				let y: CGFloat = cy + radius * sin(angle)
				let rect = NSRect(x: x - dot, y: y - dot, width: dot * 2, height: dot * 2)
				if tree.process != .dead, let (r, g, b) = colour(tree.pixels, led) {
					ctx.setFillColor(red: r, green: g, blue: b, alpha: running ? 1 : 0.4)
					ctx.fillEllipse(in: rect)
				} else {
					//Unlit, or a tree that is not running: an outline, so the ring stays visible
					ctx.setStrokeColor(gray: 0.3, alpha: 1)
					ctx.setLineWidth(1)
					ctx.strokeEllipse(in: rect.insetBy(dx: 0.5, dy: 0.5))
				}
			}

			drawLabel(for: tree, number: i, centredOn: cx, width: cell, y: area.minY + 2)
		}
	}

	private func drawLabel(for tree: TreeFrameReader.Tree, number: Int, centredOn cx: CGFloat,
	                       width: CGFloat, y: CGFloat) {
		let text: String
		let colour: NSColor
		switch (tree.process, tree.connected, tree.place) {
		case (.dead, _, _):            text = "\(number) dead";    colour = .tertiaryLabelColor
		case (.frozen, _, _):          text = "\(number) frozen";  colour = .systemYellow
		case (.running, false, _):     text = "\(number) waiting"; colour = .systemRed
		case (.running, true, nil):    text = "\(number) no place"; colour = .systemGreen
		case (.running, true, let p?): text = "\(number): \(p.index) of \(p.count)"; colour = .systemGreen
		}
		let attributes: [NSAttributedString.Key: Any] = [
			.font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular),
			.foregroundColor: colour
		]
		let s = text as NSString
		let size = s.size(withAttributes: attributes)
		s.draw(at: NSPoint(x: cx - min(size.width, width) / 2, y: y), withAttributes: attributes)
	}

	private func drawStatus() {
		let attributes: [NSAttributedString.Key: Any] = [
			.font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
			.foregroundColor: live ? NSColor.secondaryLabelColor : NSColor.tertiaryLabelColor
		]
		(status as NSString).draw(at: NSPoint(x: 2, y: bounds.height - SimulatorMonitorLayout.statusHeight + 4),
		                          withAttributes: attributes)
	}
}
