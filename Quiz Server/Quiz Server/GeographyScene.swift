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
	
	var teamguesses : [(x : Int, y: Int)?] = []
	
	let text = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	let mainImage = SKSpriteNode(imageNamed: "2")
	
	func setUpScene(size: CGSize, leds: QuizLeds?, numTeams: Int) {
		if setUp {
			return
		}
		setUp = true
		
		reset()
		
		self.size = size
		self.leds = leds
		self.numTeams = numTeams
		
		let bgImage = SKSpriteNode(imageNamed: "purple-texture-blurred")
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
		text.fontColor = NSColor.white
		text.horizontalAlignmentMode = .left
		text.verticalAlignmentMode = .baseline
		text.zPosition = 6.0
		text.position = CGPoint(x: 50, y: 50)
		
		self.addChild(text)

	}
	
	func setQuestion(question: Int) {
		print("Question " + String(question))
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
		psplash.particleSpeed = 100
		psplash.particleBirthRate = 4000
		psplash.numParticlesToEmit = 1000
		psplash.removeWhenDone()
		mainImage.addChild(psplash)
	}
	
	func addPositionMarker(point : CGPoint, col : NSColor) {
		let p = SKEmitterNode(fileNamed: "location")!
		p.position = point
		p.zPosition = 10.0
		p.particleColor = col
		p.particleColorSequence = nil
		mainImage.addChild(p)
	}
	
	
	func showWinner(answerx: Int, answery: Int) {
		if(answerx > 100 || answery > 100) {
			return;
		}
		mainImage.removeAllChildren()
		
		
		//DEBUG
		teamguesses[0] = (x: 10, y: 80)
		teamguesses[1] = (x: 10, y: 10)
		teamguesses[2] = (x: 30, y: 30)
		teamguesses[3] = (x: 60, y: 60)
		
		
		var distances : [(d : Double, team : Int)] = []
		for i in 0 ..< teamguesses.count {
			if let g = teamguesses[i] {
				
				let dx = abs(g.x - answerx)
				let dy = abs(g.y - answery)
				let dist : Double = sqrt(Double(dx*dx + dy*dy))
				
				distances += [(d: dist, team: i)]
			}
		}
		let sorted = distances.sorted(by: {$0.d > $1.d})

		let homecoords = percentToCoords(coord: (x: answerx, y: answery))
		
		addPositionMarker(point: homecoords, col: NSColor(calibratedHue: 0.0, saturation: 0.0, brightness: 0.0, alpha: 1.0))
		addPositionMarker(point: homecoords, col: NSColor(calibratedHue: 0.0, saturation: 0.0, brightness: 1.0, alpha: 1.0))
		addSplash(point: homecoords, col: NSColor(calibratedHue: 0.0, saturation: 0.0, brightness: 1.0, alpha: 1.0))
		
		
		
		for i in 0 ..< sorted.count {
			let timer = Timer(fireAt: Date().addingTimeInterval(Double((i*2) + 4)), interval: 0, target: self,
			                  selector: #selector(teamAnswer),
			                  userInfo: sorted[i], repeats: false)
			RunLoop.main.add(timer, forMode: RunLoopMode.commonModes)
		}
	}
	
	
	func teamAnswer(timer : Timer) {
		let team : (d : Double, team : Int) = timer.userInfo as! (d : Double, team : Int)
		
		text.text = "Team " + String(team.team + 1) + " with distance " + String.localizedStringWithFormat("%.2f", team.d)

		let teampos = percentToCoords(coord : (
			x: (teamguesses[team.team]?.x)!,
			y: (teamguesses[team.team]?.y)!
		))
		let teamHue = CGFloat(team.team) / 10.0
		let pcol = NSColor(calibratedHue: teamHue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
		
		addPositionMarker(point: teampos, col: pcol)
		addSplash(point: teampos, col: pcol)
	}
	
	
	
	func teamAnswered(team: Int, x: Int, y: Int) {
		print("Team: " + String(team) + " X: " + String(x) + " Y: " + String(y))
		if(team < teamguesses.count) {
			teamguesses[team] = (x, y)
		}
		updateText()
	}
	
	
	func updateText() {
		text.text = "Teams Remaining: "
		for i in 0 ..< numTeams {
			if teamguesses[i] == nil {
				text.text! += String(i+1) + " "
			}
		}
	}
	
	func reset() {
		teamguesses = []
		for _ in 0 ..< numTeams {
			teamguesses += [nil]
		}
		updateText()
		mainImage.removeAllChildren()
	}
}
