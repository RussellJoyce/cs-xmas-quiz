//
//  TeamAnswerNode.swift
//  Quiz Server
//
//  Created by Ian Gray on 2026-08-11.
//  Copyright © 2026 Russell Joyce & Ian Gray. All rights reserved.
//

import Foundation
import Cocoa
import SpriteKit

/// A team's box in the rounds that show every team's written answer at once: a numbered
/// panel with room for the answer and, optionally, the clue it was given at.
///
/// TextScene and NumbersScene each had their own near-identical copy of this. Both now
/// take their `fontSize` from `TeamGridLayout`, so the two rounds match; the text round
/// may shrink individual boxes below that to fit a long answer, but never above it.
class TeamAnswerNode: SKNode {

	var guessLabel = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	var roundLabel = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	var singleLabel = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	var teamNoLabel : SKLabelNode
	var bgBox : SKShapeNode

	var width : Int = 0
	var height : Int = 0
	var teamNo : Int

	let fontSize : CGFloat
	private var animatedNodes = [SKNode]()

	static let bgColour = NSColor(calibratedHue: 0, saturation: 0.0, brightness: 0.9, alpha: 0.9)

	/// - Parameters:
	///   - fontSize: size of the answer and team-number labels, normally taken straight
	///     from `TeamGridLayout.fontSize` so that every grid round matches.
	///   - showsRoundLabel: adds the smaller grey line under the answer naming the clue
	///     the team guessed at. Only the text round uses it.
	init(team: Int, width: Int, height: Int, position : CGPoint, fontSize: CGFloat, showsRoundLabel: Bool = false) {

		let bigFontSize = fontSize
		let smallFontSize : CGFloat = height >= 150 ? 38 : 28
		self.fontSize = fontSize

		bgBox = SKShapeNode(rectOf: CGSize(width: width, height: height))
		bgBox.zPosition = 5
		bgBox.position = CGPoint.zero
		bgBox.fillColor = TeamAnswerNode.bgColour
		bgBox.lineWidth = 2.0

		guessLabel.text = "abcedfghijklmnopqrstuv"
		guessLabel.fontSize = bigFontSize
		guessLabel.fontColor = NSColor.black
		guessLabel.horizontalAlignmentMode = .left
		guessLabel.verticalAlignmentMode = .center
		guessLabel.zPosition = 6
		guessLabel.position = CGPoint(x: -((width/2) - 120), y: Int(0.2*Double(height)))

		roundLabel.text = "(round number)"
		roundLabel.fontSize = smallFontSize
		roundLabel.fontColor = NSColor(calibratedRed: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
		roundLabel.horizontalAlignmentMode = .left
		roundLabel.verticalAlignmentMode = .center
		roundLabel.zPosition = 6
		roundLabel.position = CGPoint(x: -((width/2) - 120), y: Int(-0.27*Double(height)))

		singleLabel.text = "this is an answer answ"
		singleLabel.fontSize = bigFontSize
		singleLabel.fontColor = NSColor.black
		singleLabel.horizontalAlignmentMode = .left
		singleLabel.verticalAlignmentMode = .center
		singleLabel.zPosition = 6
		singleLabel.position = CGPoint(x: -((width/2) - 120), y: 0)

		teamNoLabel = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		teamNoLabel.text = "\(team + 1)."
		teamNoLabel.fontSize = bigFontSize
		teamNoLabel.fontColor = NSColor.black
		teamNoLabel.horizontalAlignmentMode = .left
		teamNoLabel.verticalAlignmentMode = .center
		teamNoLabel.zPosition = 6
		teamNoLabel.position = CGPoint(x: -((width/2) - 20), y: 0)

		self.width = width
		self.height = height
		self.teamNo = team

		super.init()

		self.position = position
		self.addChild(teamNoLabel)
		self.addChild(bgBox)
		self.addChild(guessLabel)
		self.addChild(singleLabel)

		animatedNodes = [teamNoLabel, bgBox, guessLabel, singleLabel]

		if showsRoundLabel {
			self.addChild(roundLabel)
			animatedNodes.append(roundLabel)
		}
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func setTextSize(size : CGFloat) {
		guessLabel.fontSize = size
		singleLabel.fontSize = size
	}

	func resetTextSize() {
		guessLabel.fontSize = fontSize
		singleLabel.fontSize = fontSize
	}

	/// Sparks up the left edge of the box in the team's colour and pops it briefly,
	/// to draw the eye to whichever team has just answered.
	func emphasise() {
		//Sparks fade up into the team's colour and back out again
		let clear = Utils.teamColour(teamNo, alpha: 0.0)
		let opaque = Utils.teamColour(teamNo)

		self.addEmitter(named: "TextSceneSparks", at: CGPoint(x: -((self.width/2) - 40), y: 0), zPosition: 7) {
			$0.particleColorSequence = SKKeyframeSequence(
				keyframeValues: [clear, clear, opaque, opaque, clear],
				times: [0.0, 0.1, 0.1, 0.3, 0.7]
			)
		}

		let grow = SKAction.scale(to: 1.2, duration: 0.05)
		grow.timingMode = .easeOut
		let shrink = SKAction.scale(to: 1, duration: 0.2)
		shrink.timingMode = .easeIn
		let anim = SKAction.sequence([grow, shrink])
		animatedNodes.forEach { $0.run(anim) }
	}
}
