//
//  QuizAdminPanel.swift
//  Quiz Server
//
//  Copyright © 2026 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa

/// Settings for the whole quiz rather than for one round. Like Client Admin it is not a round,
/// so choosing its tab leaves the display alone. Everything here is kept in `Settings.shared`.
class QuizAdminPanel: NSObject {

	weak var host: ControllerWindowController!

	/// The tab's view. The radio buttons are told apart by their action, and their tags are
	/// the animations' numbers.
	@IBOutlet weak var settingsView: NSView!
	@IBOutlet weak var treeBrightnessSlider: NSSlider!
	@IBOutlet weak var treeBrightnessLabel: NSTextField!

	/// Held so that the test probe can read the settings through the panel
	private let settings = Settings.shared

	/// The controls start from the settings, not whatever the xib says
	func setUp() {
		for radio in settingsView.subviews.compactMap({ $0 as? NSButton }) {
			switch radio.action {
			case #selector(stringAnimationChosen(_:)):
				radio.state = radio.tag == settings.idleStringAnimation.rawValue ? .on : .off
			case #selector(treeAnimationChosen(_:)):
				radio.state = radio.tag == settings.idleTreeAnimation.rawValue ? .on : .off
			default:
				break
			}
		}
		treeBrightnessSlider.integerValue = settings.treeBrightness
		showBrightness()
	}

	/// The idle rounds pick the animations up as they are entered, so only one on screen now
	/// needs telling
	private func applyIdleLights() {
		if host.quizDisplay.currentRound.isIdle {
			QuizWebSocket.shared?.idleLights()
		}
	}

	@IBAction func stringAnimationChosen(_ sender: NSButton) {
		guard let animation = QuizWebSocket.StringAnimation(rawValue: sender.tag) else { return }
		settings.idleStringAnimation = animation
		applyIdleLights()
	}

	@IBAction func treeAnimationChosen(_ sender: NSButton) {
		guard let animation = QuizWebSocket.TreeAnimation(rawValue: sender.tag) else { return }
		settings.idleTreeAnimation = animation
		applyIdleLights()
	}

	@IBAction func treeBrightnessMoved(_ sender: NSSlider) {
		settings.treeBrightness = sender.integerValue
		showBrightness()
		QuizWebSocket.shared?.treeBrightness(settings.treeBrightness)
	}

	private func showBrightness() {
		treeBrightnessLabel.stringValue = String(settings.treeBrightness)
	}
}
