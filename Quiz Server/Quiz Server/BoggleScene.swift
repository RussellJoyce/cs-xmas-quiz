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

class BoggleScene: SKScene {
	
	var leds: QuizLeds?
	var webSocket: WebSocket?
	fileprivate var setUp = false
	var numTeams = 10
	
	private var teamScores = [Int]()
	private var teamNodes = [SKNode]()
	private var time: Int = 120
	private var timer: Timer?
	private var active = false
	
	let timerText = SKLabelNode(fontNamed: "Electronic Highway Sign")
	let timerShadowText = SKLabelNode(fontNamed: "Electronic Highway Sign")
	let timerTextNode = SKNode()
	
	let tickSound = SKAction.playSoundFileNamed("tick", waitForCompletion: false)
	let blopSound = SKAction.playSoundFileNamed("blop", waitForCompletion: false)
	let hornSound = SKAction.playSoundFileNamed("airhorn", waitForCompletion: false)
	
	var idleGrids = [String]()
	var questionGrids = [String]()
	
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
		idleGrids = grids?.value(forKey: "IdleGrids") as! [String]
		questionGrids = grids?.value(forKey: "QuestionGrids") as! [String]
		
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
		timerShadowText.fontColor = NSColor(white: 0.1, alpha: 1.0)
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
		
		for i in 0..<numTeams {
			let teamNameText = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
			teamNameText.horizontalAlignmentMode = .right
			teamNameText.verticalAlignmentMode = .baseline
			teamNameText.position = CGPoint.zero
			teamNameText.zPosition = 5
			teamNameText.name = "teamNameText"
			teamNameText.text = "Team \(i + 1):"
			
			let teamScoreText = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
			teamScoreText.horizontalAlignmentMode = .left
			teamScoreText.verticalAlignmentMode = .baseline
			teamScoreText.position = CGPoint(x: 10.0, y: 0.0)
			teamScoreText.zPosition = 5
			teamScoreText.name = "teamScoreText"
			teamScoreText.text = "000"
			
			let teamTextNode = SKNode()
			teamTextNode.position = CGPoint(x: 200, y: 800 - (70 * i))
			teamTextNode.addChild(teamNameText)
			teamTextNode.addChild(teamScoreText)
			teamNodes.append(teamTextNode)
			self.addChild(teamTextNode)
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
	
	func sendIdleGrid() {
		let index = Int(arc4random_uniform(UInt32(idleGrids.count)))
		let grid = idleGrids[index]
		sendGrid(grid: grid)
	}
	
	func sendQuestionGrid(index: Int) {
		let grid = questionGrids[index]
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
			
			sendQuestionGrid(index: 0)
			
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
			let teamNode = teamNodes[i].childNode(withName: "teamScoreText") as! SKLabelNode?
			teamNode?.text = String(teamScores[i])
		}
	}
}
