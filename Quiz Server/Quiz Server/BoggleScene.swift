//
//  TimedScoresScene.swift
//  Quiz Server
//
//  Created by Russell Joyce on 28/11/2016.
//  Copyright © 2016 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import SpriteKit
import Starscream

struct BoggleQuestion {
	let grid: String
	let score: Int
}

class BoggleScene: SKScene {
	
	var leds: QuizLeds?
	var webSocket: WebSocket?
	fileprivate var setUp = false
	var numTeams = 10
	
	private var teamScores = [Int]()
	private var teamScoreNodes = [SKLabelNode]()
	private var time: Int = 120
	private var timer: Timer?
	private var active = false
	
	let timerText = SKLabelNode(fontNamed: "Electronic Highway Sign")
	let timerShadowText = SKLabelNode(fontNamed: "Electronic Highway Sign")
	let timerTextNode = SKNode()
	
	let blopSound = SKAction.playSoundFileNamed("blop", waitForCompletion: false)
	let hornSound = SKAction.playSoundFileNamed("airhorn", waitForCompletion: false)
	
	var idleGrids = [String]()
	var questions = [BoggleQuestion]()
	var currentQuestion = 0
	
	func setUpScene(size: CGSize, leds: QuizLeds?, numTeams: Int) {
		if setUp {
			return
		}
		setUp = true
		
		self.size = size
		self.leds = leds
		self.numTeams = numTeams
		
		teamScores = [Int](repeating: 0, count: numTeams)
		
		let plist = Bundle.main.path(forResource: "Boggle", ofType:"plist")
		let grids = NSDictionary(contentsOfFile:plist!)
		idleGrids = grids?.value(forKey: "idleGrids") as! [String]
		let questionGrids = grids?.value(forKey: "questionGrids") as! [NSDictionary]
		for gridItem in questionGrids {
			let score = gridItem.value(forKey: "score") as! Int
			let grid = gridItem.value(forKey: "grid") as! String
			let question = BoggleQuestion(grid: grid, score: score)
			questions.append(question)
		}
		
		self.backgroundColor = NSColor.black
		
		let bgImage = SKSpriteNode(imageNamed: "background2")
		bgImage.zPosition = 0
		bgImage.position = CGPoint(x:self.frame.midX, y:self.frame.midY)
		bgImage.size = self.size
		self.addChild(bgImage)
		
		timerTextNode.position = CGPoint(x: (self.size.width / 2) - (897.0 / 2), y: self.size.height - 270)
		timerText.fontSize = 300
		timerText.fontColor = NSColor.white
		timerText.horizontalAlignmentMode = .left
		timerText.verticalAlignmentMode = .baseline
		timerText.zPosition = 6
		timerText.position = CGPoint.zero
		timerShadowText.fontSize = 300
		timerShadowText.fontColor = NSColor.black
		timerShadowText.horizontalAlignmentMode = .left
		timerShadowText.verticalAlignmentMode = .baseline
		timerShadowText.zPosition = 5
		timerShadowText.position = CGPoint.zero
		let textShadow = SKEffectNode()
		textShadow.shouldEnableEffects = true
		textShadow.shouldRasterize = true
		textShadow.zPosition = 5
		let filter = CIFilter(name: "CIGaussianBlur")
		filter?.setDefaults()
		filter?.setValue(20, forKey: "inputRadius")
		textShadow.filter = filter;
		textShadow.addChild(timerShadowText)
		timerTextNode.addChild(timerText)
		timerTextNode.addChild(textShadow)
		self.addChild(timerTextNode)
		
		let scorePath = CGMutablePath()
		let scoreLine = SKShapeNode(path:scorePath)
		scorePath.move(to: CGPoint(x: 100.0, y: 620.0))
		scorePath.addLine(to: CGPoint(x: 1820.0, y: 620.0))
		scoreLine.path = scorePath
		scoreLine.strokeColor = SKColor.green
		scoreLine.lineWidth = 6.0
		scoreLine.zPosition = 20
		self.addChild(scoreLine)
		
		let bonusPath = CGMutablePath()
		let bonusLine = SKShapeNode(path:bonusPath)
		bonusPath.move(to: CGPoint(x: 100.0, y: 745.0))
		bonusPath.addLine(to: CGPoint(x: 1820.0, y: 745.0))
		bonusLine.path = bonusPath
		bonusLine.strokeColor = SKColor.yellow
		bonusLine.lineWidth = 6.0
		bonusLine.zPosition = 20
		self.addChild(bonusLine)
		
		let basePath = CGMutablePath()
		let baseLine = SKShapeNode(path:basePath)
		basePath.move(to: CGPoint(x: 100.0, y: 120.0))
		basePath.addLine(to: CGPoint(x: 1820.0, y: 120.0))
		baseLine.path = basePath
		baseLine.strokeColor = SKColor.white
		baseLine.lineWidth = 6.0
		baseLine.zPosition = 20
		self.addChild(baseLine)
		
		for i in 0..<numTeams {
			let x = 100.0 + ((1720.0 * (Double(i) + 0.5)) / Double(numTeams))
			
			let teamScoreText = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
			teamScoreText.horizontalAlignmentMode = .center
			teamScoreText.verticalAlignmentMode = .baseline
			teamScoreText.position = CGPoint(x: x, y: 130)
			teamScoreText.zPosition = 5
			teamScoreText.text = "000"
			teamScoreNodes.append(teamScoreText)
			self.addChild(teamScoreText)
			
			let teamNameText = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
			teamNameText.fontSize = 48
			teamNameText.horizontalAlignmentMode = .center
			teamNameText.verticalAlignmentMode = .baseline
			teamNameText.position = CGPoint(x: x, y: 65)
			teamNameText.zPosition = 5
			teamNameText.text = "Team \(i + 1)"
			self.addChild(teamNameText)
			
			let teamNameShadowText = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
			teamNameShadowText.fontSize = 48
			teamNameShadowText.fontColor = NSColor.black
			teamNameShadowText.horizontalAlignmentMode = .center
			teamNameShadowText.verticalAlignmentMode = .baseline
			teamNameShadowText.position = CGPoint.zero
			teamNameShadowText.zPosition = 4
			teamNameShadowText.text = "Team \(i + 1)"
			let teamNameShadow = SKEffectNode()
			teamNameShadow.shouldEnableEffects = true
			teamNameShadow.shouldRasterize = true
			teamNameShadow.zPosition = 4
			let filter = CIFilter(name: "CIGaussianBlur")
			filter?.setDefaults()
			filter?.setValue(10, forKey: "inputRadius")
			teamNameShadow.filter = filter;
			teamNameShadow.addChild(teamNameShadowText)
			teamNameShadow.position = CGPoint(x: x, y: 65)
			self.addChild(teamNameShadow)
		}
	}
	
	func reset(setGrid: Bool = true) {
		clearTeamScores()
		stopTimer()
		updateTime(seconds: 120)
		if setGrid {
			sendIdleGrid()
		}
	}
	
	func setQuestion(questionNum: Int) {
		currentQuestion = questionNum
	}
	
	func sendIdleGrid() {
		let index = Int(arc4random_uniform(UInt32(idleGrids.count)))
		let grid = idleGrids[index]
		sendGrid(grid: grid)
	}
	
	func sendQuestionGrid() {
		let grid = questions[currentQuestion].grid
		sendGrid(grid: grid)
	}
	
	func sendGrid(grid: String) {
		if let webSocket = webSocket, webSocket.isConnected {
			webSocket.write(string: "br") // Reset Boggle on Node server
			webSocket.write(string: "bg{\"cmd\":\"set\",\"grid\":\"\(grid)\"}") // Send grid to clients
		}
	}
	
	func updateTime(seconds: Int) {
		time = seconds
		let secs = time % 60
		let mins = time / 60
		let timeString = String(format: "%02d:%02d", mins, secs)
		timerText.text = timeString
		timerShadowText.text = timeString
	}
	
	func startTimer() {
		if !active {
			reset(setGrid: false)
			sendQuestionGrid()
			timer?.invalidate()
			timer = Timer(timeInterval: 1.0, target: self, selector: #selector(timerTick), userInfo: nil, repeats: true)
			RunLoop.main.add(timer!, forMode: .commonModes)
			active = true
		}
	}
	
	func stopTimer() {
		if active {
			active = false
			timer?.invalidate()
			sendIdleGrid()
			self.run(hornSound)
			leds?.stringPointlessCorrect()
			let p = SKEmitterNode(fileNamed: "SparksUp2")!
			p.position = CGPoint(x: self.centrePoint.x, y: 0)
			p.zPosition = 10
			p.removeWhenDone()
			self.addChild(p)
		}
	}
	
	func timerTick() {
		updateTime(seconds: time - 1);
		
		if time == 0 {
			stopTimer()
		}
	}
	
	func clearTeamScores() {
		teamScores = [Int](repeating: 0, count: numTeams)
		updateScores()
	}
	
	func setTeamScore(team: Int, score: Int) {
		if active && teamScores[team] != score {
			teamScores[team] = score
			self.run(blopSound)
			updateScores()
		}
	}
	
	func updateScores() {
		for i in 0..<numTeams {
			teamScoreNodes[i].text = String(teamScores[i])
		}
	}
}
