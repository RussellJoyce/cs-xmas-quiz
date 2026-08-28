//
//  TeamGuessNode.swift
//  Quiz Server
//
//  Created by Ian Gray on 11/12/2023.
//  Copyright © 2023 Russell Joyce & Ian Gray. All rights reserved.
//

import Foundation
import Cocoa
import SpriteKit

/// A team's box in the rounds where the answer is a choice rather than something written
class TeamGuessNode: SKNode {
	
	var width : Int = 0
	var height : Int = 0
	var teamNo : Int
	var fontsize : CGFloat
	var bgBox : SKShapeNode
	
	static let bgColour = NSColor(calibratedHue: 0, saturation: 0.0, brightness: 0.9, alpha: 0.9)
	static let bgColourTrue = NSColor(calibratedHue: 0.3, saturation: 0.4, brightness: 0.9, alpha: 0.9)
	static let bgColourFalse = NSColor(calibratedHue: 0, saturation: 0.4, brightness: 0.9, alpha: 0.9)
	static let bgColourDisabled = NSColor(calibratedHue: 0, saturation: 0.0, brightness: 0.4, alpha: 0.9)
	static let bgColourGuessed = NSColor(calibratedHue: 0.5, saturation: 0.5, brightness: 0.9, alpha: 0.9)
	static let bgColourCorrect = NSColor(calibratedHue: 0.34, saturation: 0.75, brightness: 0.95, alpha: 1.0)
	static let textColStd = NSColor.black
	static let textColOut = NSColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1)
	
	var guessLabel = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	
	func setEnabled(_ e : Bool) {
		if e {
			bgBox.fillColor = TeamGuessNode.bgColour
			guessLabel.fontColor = TeamGuessNode.textColStd
		} else {
			bgBox.fillColor = TeamGuessNode.bgColourDisabled
			guessLabel.fontColor = TeamGuessNode.textColOut
		}
	}
	
	func setGuessColour(_ g : Bool) {
		bgBox.fillColor = g ? TeamGuessNode.bgColourTrue : TeamGuessNode.bgColourFalse
	}
	
	func setIfGuessed(_ g : Bool) {
		bgBox.fillColor = g ? TeamGuessNode.bgColourGuessed : TeamGuessNode.bgColour
	}
	
	/// One hue per option, spread around the wheel so that a wall of boxes reads as a
	/// tally at a glance. `option` is 1-based, as it is on the wire.
	///
	/// The spread stops short of a full turn, so the last option never comes back round
	/// to the same red the first one started at.
	static func optionColour(_ option: Int, of count: Int) -> NSColor {
		guard count > 0, option >= 1, option <= count else {
			return TeamGuessNode.bgColour
		}
		let hue = (CGFloat(option - 1) / CGFloat(count)) * 0.82
		return NSColor(calibratedHue: hue, saturation: 0.45, brightness: 0.95, alpha: 0.95)
	}
	
	func setOptionColour(_ option: Int, of count: Int) {
		bgBox.fillColor = TeamGuessNode.optionColour(option, of: count)
		guessLabel.fontColor = TeamGuessNode.textColStd
	}
	
	/// The reveal, for a team that got it wrong: it sinks back without disappearing, so the
	/// room can still see what it answered.
	func fadeAsWrong(duration: TimeInterval = 0.7) {
		let fade = SKAction.group([SKAction.fadeAlpha(to: 0.22, duration: duration),
								   SKAction.scale(to: 0.9, duration: duration)])
		fade.timingMode = .easeInEaseOut
		self.run(fade)
	}
	
	/// The reveal, for a team that got it right.
	func highlightAsCorrect(duration: TimeInterval = 0.7) {
		bgBox.fillColor = TeamGuessNode.bgColourCorrect
		guessLabel.fontColor = TeamGuessNode.textColStd
		let grow = SKAction.sequence([SKAction.scale(to: 1.15, duration: duration * 0.4),
									  SKAction.scale(to: 1.05, duration: duration * 0.6)])
		grow.timingMode = .easeInEaseOut
		self.run(SKAction.group([SKAction.fadeAlpha(to: 1.0, duration: duration * 0.3), grow]))
	}
	
	/// Undoes whatever a reveal did to the box, so the next question starts level.
	func clearReveal() {
		self.removeAllActions()
		self.alpha = 1.0
		self.setScale(1.0)
	}
	
	init(team: Int, width: Int, height: Int, position : CGPoint, fontsize : CGFloat) {
		bgBox = SKShapeNode(rectOf: CGSize(width: width, height: height))
		bgBox.zPosition = 5
		bgBox.position = CGPoint.zero
		bgBox.fillColor = TeamGuessNode.bgColour
		bgBox.lineWidth = 2.0
		
		guessLabel.text = "aaa"
		guessLabel.fontSize = fontsize
		guessLabel.fontColor = NSColor.black
		guessLabel.horizontalAlignmentMode = .center
		guessLabel.verticalAlignmentMode = .center
		guessLabel.zPosition = 6
		guessLabel.position = CGPoint(x: 0, y: 0)
		
		self.width = width
		self.height = height
		self.teamNo = team
		self.fontsize = fontsize
		
		super.init()
		
		self.position = position
		self.addChild(bgBox)
		self.addChild(guessLabel)
	}
	
	func pulseBox() {
		let pulseSequence = SKAction.sequence([SKAction.scale(to: 1.1, duration: 0.1), SKAction.scale(to: 1.0, duration: 0.5)])
		pulseSequence.timingMode = .easeInEaseOut
		self.run(pulseSequence)
	}
	
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
}
