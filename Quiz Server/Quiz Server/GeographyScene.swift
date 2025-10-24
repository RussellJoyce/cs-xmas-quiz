//
//  GeographyScene.swift
//  Quiz Server
//
//  Created by Russell Joyce on 28/11/2016.
//  Copyright © 2016 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import SpriteKit
import Starscream

class GeographyScene: SKScene {
	
	fileprivate var setUp = false
	var answering = false
	var teamguesses : [(x : Int, y: Int)?] = []
	var imagesPath : String?
	var webSocket: WebSocket?
	
	let text = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	let mainImage = SKSpriteNode(imageNamed: "geostart")
	let answersText = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	
	var geogReveal = -1
	
	func setUpScene(size: CGSize, webSocket : WebSocket?) {
		if setUp {
			return
		}
		setUp = true
		
		reset()
		
		self.size = size
		self.webSocket = webSocket
		
		let bgImage = SKSpriteNode(imageNamed: "snowflakes-background")
		bgImage.zPosition = 0.0
		bgImage.position = CGPoint(x:self.frame.midX, y:self.frame.midY)
		bgImage.size = self.size
		
		self.addChild(bgImage)
		
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
			print("Question " + String(question))
			if let imagesPath = imagesPath {
				let imagePath = "\(imagesPath)/geo\(question).jpg"
				let image = NSImage(contentsOfFile: imagePath)
				if let image = image {
					mainImage.texture = SKTexture(image: image)
				}
				else {
					mainImage.texture = SKTexture(imageNamed: "geostart")
				}
			}
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
		
		if team > 0 && team <= 19 {
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
			
			// Quick dirty test code
			if(Settings.shared.debug) {
				teamguesses[0] = (10, 10)
				teamguesses[1] = (15, 15)
				teamguesses[2] = (20, 20)
				teamguesses[3] = (25, 25)
				teamguesses[4] = (30, 30)
				teamguesses[5] = (35, 35)
				teamguesses[6] = (40, 40)
				teamguesses[7] = (45, 45)
				teamguesses[8] = (50, 50)
				teamguesses[9] = (55, 55)
				teamguesses[10] = (60, 60)
				teamguesses[11] = (65, 65)
				teamguesses[12] = (70, 70)
				teamguesses[13] = (75, 75)
			}
			
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
	
	func emojiNum(_ num : Int) -> String {
		switch(num) {
		case 1:
			return "1️⃣"
		case 2:
			return "2️⃣"
		case 3:
			return "3️⃣"
		case 4:
			return "4️⃣"
		case 5:
			return "5️⃣"
		case 6:
			return "6️⃣"
		case 7:
			return "7️⃣"
		case 8:
			return "8️⃣"
		case 9:
			return "9️⃣"
		case 10:
			return "🔟"
		default:
			return "🆖"
		}
	}
	
	
	func teamAnswer(id : Int, order : Int) {

		if(order == sorted.count) {
			text.text = ""
			answersText.text = emojiNum(order) + ": Team " + String(id + 1) + "\n"
		} else {
			if(order == 1) {
				answersText.text! += emojiNum(order) + ": Team " + String(id + 1) + " ⭐️\n"
			} else if(order <= 3) {
				answersText.text! += emojiNum(order) + ": Team " + String(id + 1) + " 🎉\n"
			} else if(order <= sorted.count / 2) {
				answersText.text! += emojiNum(order) + ": Team " + String(id + 1) + " 👍\n"
			} else {
				answersText.text! += emojiNum(order) + ": Team " + String(id + 1) + "\n"
			}
		}
		
		if teamguesses[id] != nil {
			let teampos = percentToCoords(coord : (
				x: (teamguesses[id]?.x)!,
				y: (teamguesses[id]?.y)!
			))
			var teamHue = CGFloat(id) / 10.0
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
	
	
	
	func teamAnswered(team: Int, x: Int, y: Int, skips : [NSButton]) {
		if !answering {
			print("Team: " + String(team) + " X: " + String(x) + " Y: " + String(y))
			if(team < teamguesses.count) {
				teamguesses[team] = (x, y)
			}
			updateTextWithSkips(skips)
			webSocket?.pulseTeamColour(team: team)
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
	
	func reset() {
		webSocket?.ledsOff()
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
