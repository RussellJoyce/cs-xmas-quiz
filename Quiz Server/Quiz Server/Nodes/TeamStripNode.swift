//
//  TeamStripNode.swift
//  Quiz Server
//
//  Created by Ian Gray on 2026-08-13.
//  Copyright © 2026 Russell Joyce & Ian Gray. All rights reserved.
//

import Foundation
import Cocoa
import SpriteKit

/// The row of team numbers along the bottom of the screen, and the flourish a number makes
/// when its team does something.
class TeamStripNode: SKNode {

	enum Mode {
		/// Dark until a team does something, then lights up and goes out again
		case spotlight
		/// Lit until a team answers, then goes out and stays out
		case remaining
	}

	struct Timing {
		/// How long the number takes to appear. Only visible in `.spotlight`
		var fadeIn: TimeInterval = 0.15
		
		/// How far the number jumps before settling back, and how long it takes to settle.
		var popScale: CGFloat = 1.2
		var popDuration: TimeInterval = 0.2
		
		/// The white-to-team-colour bleed.
		var colourDelay: TimeInterval = 0.15
		var colourDuration: TimeInterval = 0.4
		
		/// When the number starts fading, measured from the trigger
		var fadeDelay: TimeInterval = 1.5
		var fadeOut: TimeInterval = 1.5
	}

	/// One team's slot in the strip. The labels are held by reference rather than fished back
	/// out of `children` and cast, which is how the reset to white quietly stopped happening
	/// when the labels became outlined ones: `for case let x as SKLabelNode` is a filter, so a
	/// type that never matches is an empty loop and not an error.
	private struct TeamNumber {
		let node: SKNode
		let labels: [OutlinedLabelNode]
	}

	private let mode: Mode
	private let timing: Timing
	private var teamNodes = [TeamNumber]()

	/// The alpha a number sits at when it is not mid-flourish.
	private var restingAlpha: CGFloat {
		mode == .spotlight ? 0.0 : 1.0
	}

	/// - Parameter width: the scene's width. The row is spread across all of it, so the node itself belongs at the origin.
	init(mode: Mode, width: CGFloat, timing: Timing = Timing()) {
		self.mode = mode
		self.timing = timing
		super.init()

		self.zPosition = 100
		build(width: width)
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	private func build(width: CGFloat) {
		let numTeams = Settings.shared.numTeams
		guard numTeams > 0 else { return }

		let margin: CGFloat = 32
		let spacing = (width - (margin * 2)) / CGFloat(numTeams)
		let baseY = margin

		for team in 0..<numTeams {
			let composite = SKNode()
			composite.position = CGPoint(x: margin + spacing * (CGFloat(team) + 0.5), y: 0)
			composite.alpha = restingAlpha

			/*let teamLabel = SKLabelNode(fontNamed: "Neutra Display Titling")
			teamLabel.text = "Team"
			teamLabel.fontSize = 20
			teamLabel.fontColor = .white
			teamLabel.horizontalAlignmentMode = .center
			teamLabel.verticalAlignmentMode = .bottom
			teamLabel.position = CGPoint(x: 0, y: baseY + 80)*/

			/*let numLabel = OutlinedLabelNode(fontNamed: "Neutra Display Titling")
			numLabel.text = "\(team + 1)"
			numLabel.fontSize = 80
			numLabel.fontColor = .white
			numLabel.horizontalAlignmentMode = .center
			numLabel.verticalAlignmentMode = .top
			numLabel.position = CGPoint(x: 0, y: baseY + 78)*/
			
			let teamLabel = OutlinedLabelNode(
				text: "Team",
				fontNamed: "Neutra Display Titling",
				fontSize: 20,
				outlineWidth: 2
			)
			teamLabel.position = CGPoint(x: 0, y: baseY + 93)

			let numLabel = OutlinedLabelNode(
				text: "\(team + 1)",
				fontNamed: "Neutra Display Titling",
				fontSize: 80
			)
			numLabel.position = CGPoint(x: 0, y: baseY + 50)
			
			composite.addChild(teamLabel)
			composite.addChild(numLabel)

			self.addChild(composite)
			teamNodes.append(TeamNumber(node: composite, labels: [teamLabel, numLabel]))
		}
	}

	/// This team has just done something: light its number up, colour it in, and let it fade.
	func trigger(team: Int) {
		guard team >= 0 && team < teamNodes.count else { return }
		let entry = teamNodes[team]
		let node = entry.node
		let labels = entry.labels

		//Back to white first, so that a team triggering again part way through the last
		//flourish starts from the beginning rather than bleeding on from where it got to
		node.removeAllActions()
		for label in labels {
			label.removeAllActions()
			label.fontColor = .white
		}

		addSparkRing(around: node)

		node.run(SKAction.fadeAlpha(to: 1.0, duration: timing.fadeIn))

		node.setScale(timing.popScale)
		let shrink = SKAction.scale(to: 1, duration: timing.popDuration)
		shrink.timingMode = .easeIn
		node.run(shrink)

		let teamColour = Utils.teamColour(team)
		let bleed = SKAction.customAction(withDuration: timing.colourDuration) { [timing, labels] _, elapsed in
			let fraction = timing.colourDuration > 0 ? CGFloat(elapsed) / CGFloat(timing.colourDuration) : 1.0
			for label in labels {
				label.fontColor = NSColor.white.blended(withFraction: fraction, of: teamColour) ?? .white
			}
		}
		node.run(SKAction.sequence([SKAction.wait(forDuration: timing.colourDelay), bleed]))

		//Run separately from the colour rather than after it, so that `fadeDelay` stays
		//measured from the trigger and the two can overlap
		node.run(SKAction.sequence([
			SKAction.wait(forDuration: timing.fadeDelay),
			SKAction.fadeAlpha(to: 0.0, duration: timing.fadeOut)
		]))
	}

	/// Everything back to the mode's resting state, with nothing in flight.
	func reset() {
		let lit = restingAlpha > 0
		setLit { _ in lit }
	}

	/// Lights or clears numbers with no flourish
	/// Only meaningful in `.remaining` — in `.spotlight` the numbers are meant to be dark.
	func setLit(_ isLit: (Int) -> Bool) {
		for (team, entry) in teamNodes.enumerated() {
			entry.node.removeAllActions()
			entry.node.alpha = isLit(team) ? 1.0 : 0.0
			entry.node.setScale(1.0)
			for label in entry.labels {
				label.removeAllActions()
				label.fontColor = .white
			}
		}
	}

	/// Sparks thrown out in a circle around the number. SpriteKit cannot emit along a ring,
	/// so the ring is made of emitters scattered around it, each pointing outwards.
	private func addSparkRing(around node: SKNode) {
		let radius: CGFloat = 50
		for _ in 0..<40 {
			let angle = CGFloat.random(in: 0..<2 * .pi)
			addEmitter(named: "teambuzzed",
					   at: CGPoint(x: node.position.x + cos(angle) * radius,
								   y: node.position.y + 90 + sin(angle) * radius),
					   zPosition: -1) {
				$0.emissionAngle = angle
			}
		}
	}
}

