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

	var teamStrip: TeamStripNode!
	/// Which teams are in this question, from the controller's team checkboxes.
	/// Does not actually affect any logic, just the display
	private var participating = [Bool]()

	let text = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	let mainImage = SKSpriteNode(imageNamed: "geostart")
	let answersText = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
	
	var geogReveal = -1
	
	override func buildScene() {
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
		text.position = CGPoint(x: 50, y: 220)
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

		teamStrip = TeamStripNode(mode: .remaining, width: self.size.width,
								  timing: TeamStripNode.Timing(fadeIn: 0,
															   popScale: 1.25,
															   popDuration: 0.2,
															   colourDelay: 0,
															   colourDuration: 0.4,
															   fadeDelay: 0.8,
															   fadeOut: 1.0))
		self.addChild(teamStrip)

		reset() //Will set up the teamStrip
	}


	override func setParticipating(_ teams: [Bool]) {
		participating = teams
		refreshStrip()
	}

	private func isParticipating(_ team: Int) -> Bool {
		return team < participating.count ? participating[team] : true
	}

	private func refreshStrip() {
		teamStrip.setLit { team in
			isParticipating(team) && (team < teamguesses.count ? teamguesses[team] == nil : true)
		}
	}
	
	/// The image the round sits on when no question is up. The phones load it by name from
	/// the same folder; the main display uses the bundled "geostart" asset for this state.
	static let startImage = "start.jpg"

	/// What the question picker will offer from the geography folder.
	static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "heic", "webp"]

	/// Shows one image from the geography folder, named as the host picked it.
	func setQuestion(file: String) {
		let imagePath = "\(Settings.shared.geographyImagesPath)/\(file)"
		if let image = NSImage(contentsOfFile: imagePath) {
			mainImage.texture = SKTexture(image: image)
		}
		else {
			print("Geography: could not load \(imagePath)")
			mainImage.texture = SKTexture(imageNamed: "geostart")
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
				if let g = teamguesses[i], isParticipating(i) {
					
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
	
	
	
	func teamAnswered(team: Int, x: Int, y: Int) {
		if !answering {
			print("Team: " + String(team) + " X: " + String(x) + " Y: " + String(y))
			var firstAnswer = false
			if(team < teamguesses.count) {
				firstAnswer = (teamguesses[team] == nil)
				teamguesses[team] = (x, y)
			}
			if firstAnswer && isParticipating(team) {
				teamStrip.trigger(team: team)
			}
			QuizWebSocket.shared?.pulseTeamColour(team)
		}
	}


	override func reset() {
		QuizWebSocket.shared?.ledsOff()
		answering = false
		teamguesses = []
		for _ in 0 ..< Settings.shared.numTeams {
			teamguesses += [nil]
		}
		refreshStrip()
		text.text = ""
		answersText.text = ""
		mainImage.removeAllChildren()
		mainImage.texture = SKTexture(imageNamed: "geostart")
	}
}
