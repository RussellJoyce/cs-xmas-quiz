//
//  GeographyScene.swift
//  Quiz Server
//
//  Created by Russell Joyce on 28/11/2016.
//  Copyright © 2016 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import SpriteKit

class GeographyScene: QuizScene {
	
	var answering = false
	var teamguesses : [(x : Int, y: Int)?] = []
	
	let text = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	let mainImage = SKSpriteNode(imageNamed: "geostart")
	let answersText = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	
	var geogReveal = -1
	
	override func buildScene() {
		reset()

		let bgImage = addBackground(imageNamed: "snowflakes-background")

		mainImage.position = CGPoint(x: 150, y: 50.0)
		mainImage.size.width = 1300.0
		mainImage.size.height = 867.0
		mainImage.zPosition = 1.0
		bgImage.addChild(mainImage)
		
		let border = SKShapeNode(rect: mainImage.frame)
		border.fillColor = NSColor.clear
		border.strokeColor = NSColor.black
		border.lineWidth = 5
		border.zPosition = 1000.0
		bgImage.addChild(border)
		
		text.fontSize = 70
		text.fontColor = NSColor.black
		text.horizontalAlignmentMode = .left
		text.verticalAlignmentMode = .baseline
		text.zPosition = 6.0
		text.position = CGPoint(x: 50, y: 50)
		text.numberOfLines = 0
		
		answersText.fontSize = 55
		answersText.fontColor = NSColor.black
		answersText.horizontalAlignmentMode = .left
		answersText.verticalAlignmentMode = .top
		answersText.zPosition = 6.0
		answersText.position = CGPoint(x: 50, y: self.frame.height - 100)
		answersText.numberOfLines = 10

		
		self.addChild(text)
		self.addChild(answersText)

	}
	
	func setQuestion(question: Int) {
		if(question > 0 && question <= 10) {
			let imagePath = "\(Settings.shared.geographyImagesPath)/geo\(question).jpg"
			let image = NSImage(contentsOfFile: imagePath)
			if let image = image {
				mainImage.texture = SKTexture(image: image)
			}
			else {
				mainImage.texture = SKTexture(imageNamed: "geostart")
			}
		}
	}
	
	
	func percentToCoords(coord : (x: Int, y: Int)) -> CGPoint {
		let vx = Double(mainImage.size.width) * Double(coord.x) / 100
		let vy = Double(mainImage.size.height) * Double(coord.y) / 100
		return CGPoint(x: CGFloat(vx) - CGFloat(mainImage.size.width / 2), y: -(CGFloat(vy) - CGFloat(mainImage.size.height / 2)))
	}
	
	
	func addSplash(point : CGPoint, col : NSColor) {
		mainImage.addEmitter(named: "location", at: point, zPosition: 10.0) {
			$0.particleColor = col
			$0.particleColorSequence = nil
			$0.particleSpeed = 150
			$0.particleBirthRate = 4000
			$0.numParticlesToEmit = 2000
		}
	}
	
	func addPositionMarker(point: CGPoint, col: NSColor, team: Int) {
		mainImage.addEmitter(named: "location", at: point, zPosition: 10.0, autoRemove: false) {
			$0.particleColor = col
			$0.particleColorSequence = nil
		}

		if team > 0 && team <= 19 {
			mainImage.addEmitter(named: "locationnumber", at: point, zPosition: 9.0, autoRemove: false) {
				$0.particleTexture = SKTexture(imageNamed: "number\(team)")
			}
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
			mainImage.addEmitter(named: "locationstar", at: homecoords, zPosition: 5.0, autoRemove: false)
			
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
	
	func teamAnswer(id : Int, order : Int) {

		if(order == sorted.count) {
			text.text = ""
			answersText.text = Utils.numberAsEmoji(order) + ": Team " + String(id + 1) + "\n"
		} else {
			if(order == 1) {
				answersText.text! += Utils.numberAsEmoji(order) + ": Team " + String(id + 1) + " ⭐️\n"
			} else if(order <= 3) {
				answersText.text! += Utils.numberAsEmoji(order) + ": Team " + String(id + 1) + " 🎉\n"
			} else if(order <= sorted.count / 2) {
				answersText.text! += Utils.numberAsEmoji(order) + ": Team " + String(id + 1) + " 👍\n"
			} else {
				answersText.text! += Utils.numberAsEmoji(order) + ": Team " + String(id + 1) + "\n"
			}
		}
		
		if teamguesses[id] != nil {
			let teampos = percentToCoords(coord : (
				x: (teamguesses[id]?.x)!,
				y: (teamguesses[id]?.y)!
			))
			let pcol = Utils.teamColour(id)
			
			addPositionMarker(point: teampos, col: pcol, team: id+1)
			addSplash(point: teampos, col: pcol)
		} else {
			print("ERROR teamguesses[team.id] is nil")
		}
	}
	
	
	
	func teamAnswered(team: Int, x: Int, y: Int, skips : [NSButton]) {
		if !answering {
			print("Team: " + String(team) + " X: " + String(x) + " Y: " + String(y))
			if(team < teamguesses.count) {
				teamguesses[team] = (x, y)
			}
			updateTextWithSkips(skips)
			QuizWebSocket.shared?.pulseTeamColour(team)
		}
	}
	
	
	func updateText() {
		answersText.text = ""
		text.fontSize = 70
		text.text = "Teams Remaining: "
		for i in 0 ..< Settings.shared.numTeams {
			if teamguesses[i] == nil {
				text.text! += String(i+1) + " "
			}
		}
	}
	
	func updateTextWithSkips(_ skips : [NSButton]) {
		answersText.text = ""
		text.fontSize = 70
		text.text = "Teams Remaining: "
		for i in 0 ..< Settings.shared.numTeams {
			if teamguesses[i] == nil && skips[i].state == .on {
				text.text! += String(i+1) + " "
			}
		}
	}
	
	override func reset() {
		QuizWebSocket.shared?.ledsOff()
		answering = false
		teamguesses = []
		for _ in 0 ..< Settings.shared.numTeams {
			teamguesses += [nil]
		}
		updateText()
		mainImage.removeAllChildren()
		mainImage.texture = SKTexture(imageNamed: "geostart")
	}
}
