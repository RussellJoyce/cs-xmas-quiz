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
import Starscream



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
	var fontsize : CGFloat
	
	static let bgColour = NSColor(calibratedHue: 0, saturation: 0.0, brightness: 0.9, alpha: 0.9)
	
	init(team: Int, width: Int, height: Int, position : CGPoint, fontsize : CGFloat) {
				
		bgBox = SKShapeNode(rectOf: CGSize(width: width, height: height))
		bgBox.zPosition = 5
		bgBox.position = CGPoint.zero
		bgBox.fillColor = NumbersTeamNode.bgColour
		bgBox.lineWidth = 2.0
		
		guessLabel.text = "abcedfghijklmnopqrstuv"
		guessLabel.fontSize = fontsize
		guessLabel.fontColor = NSColor.black
		guessLabel.horizontalAlignmentMode = .left
		guessLabel.verticalAlignmentMode = .center
		guessLabel.zPosition = 6
		guessLabel.position = CGPoint(x: -((width/2) - 120), y: 30)
		
		singleLabel.text = "this is an answer answ"
		singleLabel.fontSize = fontsize
		singleLabel.fontColor = NSColor.black
		singleLabel.horizontalAlignmentMode = .left
		singleLabel.verticalAlignmentMode = .center
		singleLabel.zPosition = 6
		singleLabel.position = CGPoint(x: -((width/2) - 120), y: 0)
		
		teamNoLabel = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		teamNoLabel.text = "\(team + 1)."
		teamNoLabel.fontSize = fontsize
		teamNoLabel.fontColor = NSColor.black
		teamNoLabel.horizontalAlignmentMode = .left
		teamNoLabel.verticalAlignmentMode = .center
		teamNoLabel.zPosition = 6
		teamNoLabel.position = CGPoint(x: -((width/2) - 20), y: 0)
		
		self.width = width
		self.height = height
		self.teamNo = team
		self.fontsize = fontsize
		
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
		guessLabel.fontSize = fontsize
		singleLabel.fontSize = fontsize
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
	var webSocket: WebSocket?
	fileprivate var setUp = false
	var numTeams = 10
	var teamBoxes = [NumbersTeamNode]()
	let blopSound = SKAction.playSoundFileNamed("blop", waitForCompletion: false)
	let hornSound = SKAction.playSoundFileNamed("tada", waitForCompletion: false)
	var revealed = false
	var emitters = [SKEmitterNode]()

	func setUpScene(size: CGSize, numTeams: Int, webSocket : WebSocket?) {
		if setUp {
			return
		}
		setUp = true
		
		self.size = size
		self.webSocket = webSocket
		self.numTeams = numTeams
		self.revealed = false
		
		let bgImage = SKSpriteNode(imageNamed: "blue-snow")
		bgImage.zPosition = 0
		bgImage.position = CGPoint(x:self.frame.midX, y:self.frame.midY)
		bgImage.size = self.size
		
		self.addChild(bgImage)
		
		let halfway = Int((Double(numTeams) / 2).rounded(.up))
		
		var boxheight : Int = 150
		if(numTeams > 10) {
			boxheight = 100
		}
		
		for team in 0..<numTeams {
			var yOffset : Int
			if team >= halfway {
				yOffset = ((halfway-1) - (team - halfway)) * Int(Double(boxheight)*1.3)
			} else {
				yOffset = ((halfway-1) - team) * Int(Double(boxheight)*1.3)
			}
			
			//let yOffset = (team >= 5) ? ((4 - (team - 5)) * 200) : ((4 - team) * 200)
			let position = CGPoint(
				x: (team < halfway) ? self.centrePoint.x - 500 : self.centrePoint.x + 500,
				y: CGFloat(boxheight + 10 + yOffset)
			)
			let box = NumbersTeamNode(team: team, width: 700, height: boxheight, position: position, fontsize: numTeams >= 10 ? 60 : 40)
			
			box.zPosition = 1
			teamBoxes.append(box)
			self.addChild(box)
			
			teamGuesses.append(nil)
		}
	}

	func teamGuess(teamid : Int, guess : Int) {
		self.run(blopSound)
		webSocket?.pulseTeamColour(team: teamid)
		teamGuesses[teamid] = guess
		teamBoxes[teamid].resetTextSize()
		teamBoxes[teamid].guessLabel.text = ""
		teamBoxes[teamid].singleLabel.text = "••••••••"
		
		teamBoxes[teamid].emphasise()
	}
	
	func showGuesses(actualAnswer : Int) {
		//First press just plays a big honk and shows everything
		if(!revealed) {
			self.run(hornSound)
			webSocket?.pulseWhite()
			
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
					teamBoxes[team].setTextSize(size: numTeams >= 10 ? 60 : 40)
					teamBoxes[team].singleLabel.text = "\(tg)"
					teamBoxes[team].guessLabel.text = ""
				} else {
					teamBoxes[team].guessLabel.text = ""
					teamBoxes[team].singleLabel.text = ""
				}
			}
			
			revealed = true
			
		}
		//Second press colours everything to show team scores
		else {
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
				NSColor(calibratedRed: 0.1, green: 1.0, blue: 0.3, alpha: 0.9),
				NSColor(calibratedRed: 1.0, green: 1.0, blue: 0.1, alpha: 0.9),
				NSColor(calibratedRed: 0.6, green: 0.6, blue: 1.0, alpha: 0.9),
			]
			
			//We need to handle draws, so it isn't as easy as saying that index 0 is the winner, index 1 is the second etc.
			var win = 0 //This is the "rank" we are at. 0 is "winner", 1 is "second place", 2 is "top half", higher is "loser"
			var teNo = 0
			var lastDist : Int = teamDistances[teNo].distance //Will be 0 if someone guessed correctly
			while win < winColours.count {
				if teNo >= teamDistances.count {
					break
				}
				
				if win == 0 || win == 1 {
					if teamDistances[teNo].distance > lastDist {
						win = win + 1
						lastDist = teamDistances[teNo].distance
					}
				} else {
					if teNo > (teamDistances.count / 2 - 1) && teamDistances[teNo].distance != teamDistances[teNo-1].distance {
						break
					}
				}
				
				//Animate the team box to the target colour to indicate "win level"
				teamBoxes[teamDistances[teNo].team].bgBox.run(SKAction.colorTransitionAction(fromColor: NumbersTeamNode.bgColour, toColor: winColours[win]))
				teamBoxes[teamDistances[teNo].team].bgBox.run(SKAction.scale(to: 1.1, duration: 0.5))
				
				//Give winners some stars
				if win == 0 {
					for _ in 0...5 {
						let pstar = SKEmitterNode(fileNamed: "locationstar")!
						var starpoint : CGPoint = teamBoxes[teamDistances[teNo].team].bgBox.centrePoint
						//starpoint.y += CGFloat(Int.random(in: -70...70))
						starpoint.x -= 310
						pstar.position = starpoint
						pstar.zPosition = 5.0
						teamBoxes[teamDistances[teNo].team].addChild(pstar)
						emitters.append(pstar)
					}
				}
				
				if win < 2 {
					addGlowParticles(team: teamDistances[teNo].team)
				}
				
				teNo = teNo + 1
			}
		}
	}
	
	func addGlowParticles(team : Int) {
		let pstar = SKEmitterNode(fileNamed: "BuzzGlow")!
		pstar.particlePositionRange = CGVector(dx: 750, dy: 130)
		pstar.particleSpeed = 10
		pstar.particleBirthRate = 70
		pstar.particleAlpha = 0.4
		pstar.particleScale = 0.8
		pstar.position = teamBoxes[team].bgBox.centrePoint
		pstar.zPosition = 5.0
		teamBoxes[team].addChild(pstar)
		emitters.append(pstar)
	}
	

	func reset() {
		webSocket?.ledsOff()
		self.revealed = false
		
		for team in 0..<numTeams {
			teamGuesses[team] = nil
			teamBoxes[team].guessLabel.text = ""
			teamBoxes[team].singleLabel.text = ""
			teamBoxes[team].resetTextSize()
			teamBoxes[team].bgBox.fillColor = NumbersTeamNode.bgColour
			teamBoxes[team].bgBox.run(SKAction.scale(to: 1, duration: 0.2))
		}
		
		for e in emitters {
			e.removeFromParent()
		}
		emitters.removeAll()
		
		//Quick dirty test code
		/*teamGuess(teamid : 0, guess : 0)
		teamGuess(teamid : 1, guess : 10)
		teamGuess(teamid : 2, guess : 20)
		teamGuess(teamid : 3, guess : 30)
		teamGuess(teamid : 4, guess : 40)
		teamGuess(teamid : 5, guess : 50)
		teamGuess(teamid : 6, guess : 50)
		teamGuess(teamid : 7, guess : 55)
		teamGuess(teamid : 8, guess : 60)
		teamGuess(teamid : 9, guess : 70)
		teamGuess(teamid : 10, guess : 70)
		teamGuess(teamid : 11, guess : 70)
		teamGuess(teamid : 12, guess : 70)
		teamGuess(teamid : 13, guess : 80)*/
		
		
		/*teamGuess(teamid : 0, guess : 0)
		teamGuess(teamid : 1, guess : 1)
		teamGuess(teamid : 2, guess : 2)
		teamGuess(teamid : 3, guess : 3)
		teamGuess(teamid : 4, guess : 4)
		teamGuess(teamid : 5, guess : 5)
		teamGuess(teamid : 6, guess : 6)
		teamGuess(teamid : 7, guess : 7)
		teamGuess(teamid : 8, guess : 8)
		teamGuess(teamid : 9, guess : 9)
		teamGuess(teamid : 10, guess : 10)
		teamGuess(teamid : 11, guess : 11)
		teamGuess(teamid : 12, guess : 12)
		teamGuess(teamid : 13, guess : 13)*/
		
	}

}
