//
//  TextScene.swift
//  Quiz Server
//
//  Created by Ian Gray on 13/11/2017.
//  Copyright © 2017 Russell Joyce & Ian Gray. All rights reserved.
//

import Foundation
import Cocoa
import SpriteKit



func lerp(a : CGFloat, b : CGFloat, fraction : CGFloat) -> CGFloat {
    return (b-a) * fraction + a
}

struct ColorComponents {
    var red = CGFloat(0)
    var green = CGFloat(0)
    var blue = CGFloat(0)
    var alpha = CGFloat(0)
}

extension NSColor {
    func toComponents() -> ColorComponents {
        var components = ColorComponents()
        getRed(&components.red, green: &components.green, blue: &components.blue, alpha: &components.alpha)
        return components
    }
}

extension SKAction {
    static func colorTransitionAction(fromColor : NSColor, toColor : NSColor, duration : Double = 0.4) -> SKAction {
        return SKAction.customAction(withDuration: duration, actionBlock: { (node : SKNode!, elapsedTime : CGFloat) -> Void in
            let fraction = CGFloat(elapsedTime / CGFloat(duration))
            let startColorComponents = fromColor.toComponents()
            let endColorComponents = toColor.toComponents()
            let transColor = NSColor(red: lerp(a: startColorComponents.red, b: endColorComponents.red, fraction: fraction),
                                     green: lerp(a: startColorComponents.green, b: endColorComponents.green, fraction: fraction),
                                     blue: lerp(a: startColorComponents.blue, b: endColorComponents.blue, fraction: fraction),
                                     alpha: lerp(a: startColorComponents.alpha, b: endColorComponents.alpha, fraction: fraction))
            (node as? SKShapeNode)?.fillColor = transColor
        }
        )
    }
}



class NumbersTeamNode: SKNode {
	
	var guessLabel = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	var singleLabel = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	var width : Int = 0
	var height : Int = 0
	var bgBox : SKShapeNode
	var teamNoLabel : SKLabelNode
	var teamNo : Int
	
	static let bgColour = NSColor(calibratedHue: 0, saturation: 0.0, brightness: 0.9, alpha: 0.9)
	
	init(team: Int, width: Int, height: Int, position : CGPoint) {
				
		bgBox = SKShapeNode(rectOf: CGSize(width: width, height: height))
		bgBox.zPosition = 5
		bgBox.position = CGPoint.zero
		bgBox.fillColor = NumbersTeamNode.bgColour
		bgBox.lineWidth = 2.0
		
		guessLabel.text = "abcedfghijklmnopqrstuv"
		guessLabel.fontSize = 60
		guessLabel.fontColor = NSColor.black
		guessLabel.horizontalAlignmentMode = .left
		guessLabel.verticalAlignmentMode = .center
		guessLabel.zPosition = 6
		guessLabel.position = CGPoint(x: -((width/2) - 120), y: 30)
		
		singleLabel.text = "this is an answer answ"
		singleLabel.fontSize = 60
		singleLabel.fontColor = NSColor.black
		singleLabel.horizontalAlignmentMode = .left
		singleLabel.verticalAlignmentMode = .center
		singleLabel.zPosition = 6
		singleLabel.position = CGPoint(x: -((width/2) - 120), y: 0)
		
		teamNoLabel = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		teamNoLabel.text = "\(team + 1)."
		teamNoLabel.fontSize = 60
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
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func setTextSize(size : CGFloat) {
		guessLabel.fontSize = size
		singleLabel.fontSize = size
	}
	
	func resetTextSize() {
		guessLabel.fontSize = 60
		singleLabel.fontSize = 60
	}
	
	func emphasise() {
		var teamHue = CGFloat(teamNo) / 10.0
		if teamHue > 1.0 {
			teamHue -= 1.0
		}
		
		let parts = SKEmitterNode(fileNamed: "TextSceneSparks")!
		parts.position = CGPoint(x: -((self.width/2) - 40), y: 0)
		parts.zPosition = 7
		
		parts.particleColorSequence = SKKeyframeSequence(
			keyframeValues: [
				SKColor(calibratedHue: teamHue, saturation: 1.0, brightness: 1.0, alpha: 0.0),
				SKColor(calibratedHue: teamHue, saturation: 1.0, brightness: 1.0, alpha: 0.0),
				SKColor(calibratedHue: teamHue, saturation: 1.0, brightness: 1.0, alpha: 1.0),
				SKColor(calibratedHue: teamHue, saturation: 1.0, brightness: 1.0, alpha: 1.0),
				SKColor(calibratedHue: teamHue, saturation: 1.0, brightness: 1.0, alpha: 0.0),
			], times: [0.0, 0.1, 0.1, 0.3, 0.7]
		)
		
		parts.removeWhenDone()
		self.addChild(parts)
		
		let grow = SKAction.scale(to: 1.2, duration: 0.05)
		grow.timingMode = .easeOut
		let shrink = SKAction.scale(to: 1, duration: 0.2)
		shrink.timingMode = .easeIn
		let anim = SKAction.sequence([grow, shrink])
		teamNoLabel.run(anim)
		bgBox.run(anim)
		guessLabel.run(anim)
		singleLabel.run(anim)
	}
	
}



class NumbersScene: SKScene {
	
	var teamGuesses = [Int?]()
	var leds: QuizLeds?
	fileprivate var setUp = false
	var numTeams = 10
	var teamBoxes = [NumbersTeamNode]()
	let blopSound = SKAction.playSoundFileNamed("blop", waitForCompletion: false)
	let hornSound = SKAction.playSoundFileNamed("tada", waitForCompletion: false)
	var revealed = false

	func setUpScene(size: CGSize, leds: QuizLeds?, numTeams: Int) {
		if setUp {
			return
		}
		setUp = true
		
		self.size = size
		self.leds = leds
		self.numTeams = numTeams
		self.revealed = false
		
		let bgImage = SKSpriteNode(imageNamed: "blue-snow")
		bgImage.zPosition = 0
		bgImage.position = CGPoint(x:self.frame.midX, y:self.frame.midY)
		bgImage.size = self.size
		
		self.addChild(bgImage)
		
		for team in 0..<numTeams {
			let yOffset = (team >= 5) ? ((4 - (team - 5)) * 200) : ((4 - team) * 200)
			let position = CGPoint(
				x: (team < 5) ? self.centrePoint.x - 500 : self.centrePoint.x + 500,
				y: CGFloat(160 + yOffset)
			)
			let box = NumbersTeamNode(team: team, width: 700, height: 150, position: position)
			
			box.zPosition = 1
			teamBoxes.append(box)
			self.addChild(box)
			
			teamGuesses.append(nil)
		}
	}

	func teamGuess(teamid : Int, guess : Int) {
		self.run(blopSound)
		leds?.stringPulseTeamColour(team: teamid)
		teamGuesses[teamid] = guess
		teamBoxes[teamid].resetTextSize()
		teamBoxes[teamid].guessLabel.text = ""
		teamBoxes[teamid].singleLabel.text = "••••••••"
		
		teamBoxes[teamid].emphasise()
	}
	
	func showGuesses(actualAnswer : Int) {
		if(!revealed) {
			self.run(hornSound)
			leds?.stringPointlessCorrect()
			
			let emoji = ["tree", "santa", "spaceinvader", "robot", "snowman", "present", "floppydisk", "snowflake"]
			
			for i in 0..<80 {
				let p = SKEmitterNode(fileNamed: "emojsplosion")!
				p.particleTexture = SKTexture(imageNamed: emoji[Int(arc4random_uniform(UInt32(emoji.count)))])
				p.position = CGPoint(x: Int(arc4random_uniform(UInt32(self.size.width))), y: Int(arc4random_uniform(UInt32(self.size.height))))
				p.zPosition = CGFloat(100 + i)
				p.removeWhenDone()
				self.addChild(p)
			}
			
			for team in 0..<numTeams {
				if let tg = teamGuesses[team] {
					teamBoxes[team].setTextSize(size: 60)
					teamBoxes[team].singleLabel.text = "\(tg)"
					teamBoxes[team].guessLabel.text = ""
				} else {
					teamBoxes[team].guessLabel.text = ""
					teamBoxes[team].singleLabel.text = ""
				}
			}
			
			revealed = true
			
		} else {
			//Work out which is closest to the actual answer
			var teamDistances = [(team : Int, distance : Int)]()
			
			for team in 0..<numTeams {
				if let teamGuessText = teamBoxes[team].singleLabel.text {
					if let teamGuessInt = Int(teamGuessText) {
						let dist = abs(teamGuessInt - actualAnswer)
						teamDistances.append((team, dist))
					}
				}
			}
			
			teamDistances = teamDistances.sorted(by: {$0.distance < $1.distance})

			let winColours = [
				NSColor(calibratedRed: 0.1, green: 1.0, blue: 0.1, alpha: 0.9),
				NSColor(calibratedRed: 1.0, green: 1.0, blue: 0.1, alpha: 0.9),
				//NSColor(calibratedRed: 1.0, green: 0.1, blue: 0.1, alpha: 0.9),
			]
			
			var win = -1
			var teNo = 0
			var lastDist : Int = -1
			while win < winColours.count {
				if teNo >= teamDistances.count {
					break
				}
				
				if teamDistances[teNo].distance <= lastDist {
					teamBoxes[teamDistances[teNo].team].bgBox.run(SKAction.colorTransitionAction(fromColor: NumbersTeamNode.bgColour, toColor: winColours[win]))
					teamBoxes[teamDistances[teNo].team].bgBox.run(SKAction.scale(to: 1.2, duration: 0.5))
				} else {
					win = win + 1
					if(win >= winColours.count) {
						break
					}
					
					lastDist = teamDistances[teNo].distance
					teamBoxes[teamDistances[teNo].team].bgBox.run(SKAction.colorTransitionAction(fromColor: NumbersTeamNode.bgColour, toColor: winColours[win]))
					teamBoxes[teamDistances[teNo].team].bgBox.run(SKAction.scale(to: 1.2, duration: 0.5))
				}
				teNo = teNo + 1
			}
		}
	}
	
	func reset() {
        leds?.stringOff()
		self.revealed = false
		
		for team in 0..<numTeams {
			teamGuesses[team] = nil
			teamBoxes[team].guessLabel.text = ""
			teamBoxes[team].singleLabel.text = ""
			teamBoxes[team].resetTextSize()
			teamBoxes[team].bgBox.fillColor = NumbersTeamNode.bgColour
			teamBoxes[team].bgBox.run(SKAction.scale(to: 1, duration: 0.2))
		}
		
		/*teamGuess(teamid : 1, guess : 10)
		teamGuess(teamid : 2, guess : 20)
		teamGuess(teamid : 3, guess : 30)
		teamGuess(teamid : 4, guess : 40)
		teamGuess(teamid : 5, guess : 50)
		teamGuess(teamid : 6, guess : 50)
		teamGuess(teamid : 7, guess : 50)*/
	}

}
