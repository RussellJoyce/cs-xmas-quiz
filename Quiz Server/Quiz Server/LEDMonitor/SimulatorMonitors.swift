//
//  SimulatorMonitors.swift
//  Quiz Server
//
//  The views along the bottom of the controller window that show what the LED simulators
//  are doing: ledsim's strip and treesim's trees. Each one is a single status line while its
//  simulator is not running, and grows the window to make room when one appears.
//

import Cocoa

/// A panel showing one simulator
protocol SimulatorMonitor: NSView {
	/// Height to add below the status line while the simulator is running
	var expandedHeight: CGFloat { get }
	/// Reads the simulator, redrawing if anything changed. True while it is running.
	func poll() -> Bool
}

enum SimulatorMonitorLayout {
	/// Height of a monitor's status line: all of it while its simulator is not running
	static let statusHeight: CGFloat = 18
	static let margin: CGFloat = 4
	/// How long a simulator may be gone before its panel collapses, so that restarting one
	/// does not make the window jump
	static let collapseAfter: TimeInterval = 1.5
}

private final class MonitorSlot {
	let view: SimulatorMonitor
	var expanded = false
	var absentSince: Date?

	init(_ view: SimulatorMonitor) { self.view = view }

	var height: CGFloat {
		SimulatorMonitorLayout.statusHeight + (expanded ? view.expandedHeight : 0)
	}

	func shouldExpand(live: Bool) -> Bool {
		if live {
			absentSince = nil
			return true
		}
		let since = absentSince ?? Date()
		absentSince = since
		return expanded && Date().timeIntervalSince(since) < SimulatorMonitorLayout.collapseAfter
	}
}

/// Top to bottom
private var monitors: [MonitorSlot] = []
private var monitorTimer: Timer?

func installSimulatorMonitors(window: NSWindow?) {
	guard let window = window, let content = window.contentView else { return }

	monitors = [MonitorSlot(TreeRingsView(frame: .zero)), MonitorSlot(LEDStripView(frame: .zero))]

	//Starts collapsed: just the status lines. The poll below expands any whose simulator is
	//already running.
	growWindow(window, by: totalHeight())
	for m in monitors {
		m.view.autoresizingMask = [.width, .maxYMargin]
		content.addSubview(m.view)
	}
	layoutMonitors(in: content)
	monitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in pollMonitors() }
}

private func pollMonitors() {
	guard let window = monitors.first?.view.window, let content = window.contentView else { return }
	let before = totalHeight()
	var changed = false
	for m in monitors {
		let expand = m.shouldExpand(live: m.view.poll())
		if expand != m.expanded {
			m.expanded = expand
			changed = true
		}
	}
	guard changed else { return }
	growWindow(window, by: totalHeight() - before)
	layoutMonitors(in: content)
}

/// Everything the monitors take up, margins included
private func totalHeight() -> CGFloat {
	monitors.reduce(SimulatorMonitorLayout.margin) { $0 + $1.height + SimulatorMonitorLayout.margin }
}

/// Stacked up from the bottom of the window, in the order given, the first at the top
private func layoutMonitors(in content: NSView) {
	var y = SimulatorMonitorLayout.margin
	for m in monitors.reversed() {
		m.view.frame = NSRect(x: 8, y: y, width: content.bounds.width - 16, height: m.height)
		y += m.height + SimulatorMonitorLayout.margin
	}
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
