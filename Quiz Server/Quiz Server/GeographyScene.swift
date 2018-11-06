//
//  GeographyScene.swift
//  Quiz Server
//
//  Created by Russell Joyce on 28/11/2016.
//  Copyright © 2016 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import SpriteKit

class GeographyScene: SKScene {
	
	var leds: QuizLeds?
	fileprivate var setUp = false
	var numTeams = 8
	var answering = false
	var teamguesses : [(x : Int, y: Int)?] = []
	
	let text = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	let mainImage = SKSpriteNode(imageNamed: "geostart")
	
	var geogReveal = -1
	
	func setUpScene(size: CGSize, leds: QuizLeds?, numTeams: Int) {
		if setUp {
			return
		}
		setUp = true
		
		reset()
		
		self.size = size
		self.leds = leds
		self.numTeams = numTeams
		
		let bgImage = SKSpriteNode(imageNamed: "snowflakes-background")
		bgImage.zPosition = 0.0
		bgImage.position = CGPoint(x:self.frame.midX, y:self.frame.midY)
		bgImage.size = self.size
		
		self.addChild(bgImage)

		mainImage.position = CGPoint(x: 0, y: 50.0)
		mainImage.size.width = 1300.0
		mainImage.size.height = 867.0
		mainImage.zPosition = 1.0
		bgImage.addChild(mainImage)
		
		
		text.fontSize = 70
		text.fontColor = NSColor.black
		text.horizontalAlignmentMode = .left
		text.verticalAlignmentMode = .baseline
		text.zPosition = 6.0
		text.position = CGPoint(x: 50, y: 50)
		
		self.addChild(text)

	}
	
	func setQuestion(question: Int) {
		if(question > 0 && question <= 10) {
			print("Question " + String(question))
			mainImage.texture = SKTexture(imageNamed:"geo" + String(question))
		}
	}
	
	
	func percentToCoords(coord : (x: Int, y: Int)) -> CGPoint {
		let vx = Double(mainImage.size.width) * Double(coord.x) / 100
		let vy = Double(mainImage.size.height) * Double(coord.y) / 100
		return CGPoint(x: CGFloat(vx) - CGFloat(mainImage.size.width / 2), y: -(CGFloat(vy) - CGFloat(mainImage.size.height / 2)))
	}
	
	
	func addSplash(point : CGPoint, col : NSColor) {
		let psplash = SKEmitterNode(fileNamed: "location")!
		psplash.position = point
		psplash.zPosition = 10.0
		psplash.particleColor = col
		psplash.particleColorSequence = nil
		psplash.particleSpeed = 150
		psplash.particleBirthRate = 4000
		psplash.numParticlesToEmit = 2000
		psplash.removeWhenDone()
		mainImage.addChild(psplash)
	}
	
	func addPositionMarker(point: CGPoint, col: NSColor, team: Int) {
		let p = SKEmitterNode(fileNamed: "location")!
		p.position = point
		p.zPosition = 10.0
		p.particleColor = col
		p.particleColorSequence = nil
		mainImage.addChild(p)
		
		if team > 0 && team <= 10 {
			let numbers = SKEmitterNode(fileNamed: "locationnumber")!
			numbers.position = point
			numbers.zPosition = 9.0
			numbers.particleTexture = SKTexture(imageNamed: "number\(team)")
			mainImage.addChild(numbers)
		}
	}
	
	
	var sorted : [(d : Double, team : Int)] = []
	
	func showWinner(answerx: Int, answery: Int) {
		if(answerx > 100 || answery > 100) {
			return;
		}
		
		if answering == false {
			answering = true;
			mainImage.removeAllChildren()
			
			/*teamguesses[0] = (10, 10)
			teamguesses[1] = (20, 20)
			teamguesses[2] = (30, 30)
			teamguesses[3] = (40, 40)
			teamguesses[4] = (10, 50)
			teamguesses[5] = (20, 50)
			teamguesses[6] = (30, 60)
			teamguesses[7] = (40, 70)*/
			
			var distances : [(d : Double, team : Int)] = []
			for i in 0 ..< teamguesses.count {
				if let g = teamguesses[i] {
					
					let dx = abs(g.x - answerx)
					let dy = abs(g.y - answery)
					let dist : Double = sqrt(Double(dx*dx + dy*dy))
					
					distances += [(d: dist, team: i)]
				}
			}
			sorted = distances.sorted(by: {$0.d < $1.d})

			geogReveal = sorted.count - 1
			
			
			let homecoords = percentToCoords(coord: (x: answerx, y: answery))
			let pstar = SKEmitterNode(fileNamed: "locationstar")!
			pstar.position = homecoords
			pstar.zPosition = 5.0
			mainImage.addChild(pstar)
			
			addPositionMarker(point: homecoords, col: NSColor(calibratedHue: 0.0, saturation: 0.0, brightness: 0.0, alpha: 1.0), team: 0)
			addPositionMarker(point: homecoords, col: NSColor(calibratedHue: 0.0, saturation: 0.0, brightness: 1.0, alpha: 1.0), team: 0)
			addSplash(point: homecoords, col: NSColor(calibratedHue: 0.0, saturation: 0.0, brightness: 1.0, alpha: 1.0))
			
			text.fontSize = 70
			text.text = "The answer is..."
		} else {
			if geogReveal >= 0 && geogReveal < sorted.count {
				teamAnswer(id: sorted[geogReveal].team, order: geogReveal + 1)
				geogReveal -= 1
			}
		}
	}
	
	func prefix(_ num : Int) -> String {
		switch(num) {
		case 1:
			return String(num) + "st"
		case 2:
			return String(num) + "nd"
		case 3:
			return String(num) + "rd"
		default:
			return String(num) + "th"
		}
	}
	
	
	func teamAnswer(id : Int, order : Int) {

		if(order == sorted.count) {
			text.fontSize = 35
			text.text = prefix(order) + ": Team " + String(id + 1)
		} else {
			text.text! += "   " + prefix(order) + ": Team " + String(id + 1)
		}
		
		if teamguesses[id] != nil {
			let teampos = percentToCoords(coord : (
				x: (teamguesses[id]?.x)!,
				y: (teamguesses[id]?.y)!
			))
			var teamHue = CGFloat(id) / 8.0
			if teamHue > 1.0 {
				teamHue -= 1.0
			}
			let pcol = NSColor(calibratedHue: teamHue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
			
			addPositionMarker(point: teampos, col: pcol, team: id+1)
			addSplash(point: teampos, col: pcol)
		} else {
			print("ERROR teamguesses[team.id] is nil")
		}
	}
	
	
	
	func teamAnswered(team: Int, x: Int, y: Int) {
		if !answering {
			print("Team: " + String(team) + " X: " + String(x) + " Y: " + String(y))
			if(team < teamguesses.count) {
				teamguesses[team] = (x, y)
			}
			updateText()
		}
	}
	
	
	func updateText() {
		text.fontSize = 70
		text.text = "Teams Remaining: "
		for i in 0 ..< numTeams {
			if teamguesses[i] == nil {
				text.text! += String(i+1) + " "
			}
		}
	}
	
	func reset() {
		answering = false
		teamguesses = []
		for _ in 0 ..< numTeams {
			teamguesses += [nil]
		}
		updateText()
		mainImage.removeAllChildren()
		mainImage.texture = SKTexture(imageNamed: "geostart")
	}
}
