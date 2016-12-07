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
	let target: Int
	let bonus: Int
}

class BoggleScene: SKScene {
	
	var leds: QuizLeds?
	var webSocket: WebSocket?
	fileprivate var setUp = false
	var numTeams = 10
	
	private var teamScores = [Int]()
	private var teamScoreLabels = [SKNode]()
	private var teamBars = [SKNode]()
	private var targetLabel = SKNode()
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
			let target = gridItem.value(forKey: "target") as! Int
			let grid = gridItem.value(forKey: "grid") as! String
			let question = BoggleQuestion(grid: grid, target: target, bonus: Int(ceil(Double(target) * 1.25)))
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
		timerText.zPosition = 50
		timerText.position = CGPoint.zero
		timerShadowText.fontSize = 300
		timerShadowText.fontColor = NSColor.black
		timerShadowText.horizontalAlignmentMode = .left
		timerShadowText.verticalAlignmentMode = .baseline
		timerShadowText.zPosition = 49
		timerShadowText.position = CGPoint.zero
		let textShadow = SKEffectNode()
		textShadow.shouldEnableEffects = true
		textShadow.shouldRasterize = true
		textShadow.zPosition = 49
		let filter = CIFilter(name: "CIGaussianBlur")
		filter?.setDefaults()
		filter?.setValue(20, forKey: "inputRadius")
		textShadow.filter = filter;
		textShadow.addChild(timerShadowText)
		timerTextNode.addChild(timerText)
		timerTextNode.addChild(textShadow)
		self.addChild(timerTextNode)
		
		let lineShadowFilter = CIFilter(name: "CIGaussianBlur")
		lineShadowFilter?.setDefaults()
		lineShadowFilter?.setValue(30, forKey: "inputRadius")
		
		let bonusPath = CGMutablePath()
		bonusPath.move(to: CGPoint(x: 120.0, y: 755.0))
		bonusPath.addLine(to: CGPoint(x: 1800.0, y: 755.0))
		let bonusLine = SKShapeNode(path:bonusPath)
		bonusLine.strokeColor = .yellow
		bonusLine.lineWidth = 8.0
		bonusLine.zPosition = 10
		self.addChild(bonusLine)
		let bonusLineShadow = SKShapeNode(path:bonusPath)
		bonusLineShadow.strokeColor = .black
		bonusLineShadow.lineWidth = 8.0
		bonusLineShadow.zPosition = 9
		let bonusLineShadowEffect = SKEffectNode()
		bonusLineShadowEffect.shouldEnableEffects = true
		bonusLineShadowEffect.shouldRasterize = true
		bonusLineShadowEffect.zPosition = 9
		bonusLineShadowEffect.filter = lineShadowFilter;
		bonusLineShadowEffect.addChild(bonusLineShadow)
		bonusLineShadowEffect.position = .zero
		self.addChild(bonusLineShadowEffect)
		
		let scorePath = CGMutablePath()
		scorePath.move(to: CGPoint(x: 120.0, y: 630.0))
		scorePath.addLine(to: CGPoint(x: 1800.0, y: 630.0))
		let scoreLine = SKShapeNode(path:scorePath)
		scoreLine.strokeColor = .green
		scoreLine.lineWidth = 8.0
		scoreLine.zPosition = 10
		self.addChild(scoreLine)
		let scoreLineShadow = SKShapeNode(path:scorePath)
		scoreLineShadow.strokeColor = .black
		scoreLineShadow.lineWidth = 8.0
		scoreLineShadow.zPosition = 9
		let scoreLineShadowEffect = SKEffectNode()
		scoreLineShadowEffect.shouldEnableEffects = true
		scoreLineShadowEffect.shouldRasterize = true
		scoreLineShadowEffect.zPosition = 9
		scoreLineShadowEffect.filter = lineShadowFilter;
		scoreLineShadowEffect.addChild(scoreLineShadow)
		scoreLineShadowEffect.position = .zero
		self.addChild(scoreLineShadowEffect)
		
		let basePath = CGMutablePath()
		basePath.move(to: CGPoint(x: 120.0, y: 130.0))
		basePath.addLine(to: CGPoint(x: 1800.0, y: 130.0))
		let baseLine = SKShapeNode(path:basePath)
		baseLine.strokeColor = .white
		baseLine.lineWidth = 8.0
		baseLine.zPosition = 40
		self.addChild(baseLine)
		let baseLineShadow = SKShapeNode(path:basePath)
		baseLineShadow.strokeColor = .black
		baseLineShadow.lineWidth = 8.0
		baseLineShadow.zPosition = 1
		let baseLineShadowEffect = SKEffectNode()
		baseLineShadowEffect.shouldEnableEffects = true
		baseLineShadowEffect.shouldRasterize = true
		baseLineShadowEffect.zPosition = 1
		baseLineShadowEffect.filter = lineShadowFilter;
		baseLineShadowEffect.addChild(baseLineShadow)
		baseLineShadowEffect.position = .zero
		self.addChild(baseLineShadowEffect)
		
		let targetLabelText = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		targetLabelText.fontSize = 70
		targetLabelText.horizontalAlignmentMode = .right
		targetLabelText.verticalAlignmentMode = .center
		targetLabelText.position = CGPoint(x: 105, y: 630)
		targetLabelText.zPosition = 22
		targetLabelText.text = "👑"
		let targetShadowText = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		targetShadowText.fontSize = 70
		targetShadowText.fontColor = NSColor.black
		targetShadowText.horizontalAlignmentMode = .right
		targetShadowText.verticalAlignmentMode = .center
		targetShadowText.position = CGPoint(x: 105, y: 630)
		targetShadowText.zPosition = 21
		targetShadowText.text = ""
		let targetShadow = SKEffectNode()
		targetShadow.shouldEnableEffects = true
		targetShadow.shouldRasterize = true
		targetShadow.zPosition = 21
		targetShadow.filter = filter;
		targetShadow.addChild(targetShadowText)
		let targetLabelText2 = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		targetLabelText2.fontSize = 70
		targetLabelText2.horizontalAlignmentMode = .left
		targetLabelText2.verticalAlignmentMode = .center
		targetLabelText2.position = CGPoint(x: 1815, y: 630)
		targetLabelText2.zPosition = 22
		targetLabelText2.text = "👑"
		let targetShadowText2 = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		targetShadowText2.fontSize = 70
		targetShadowText2.fontColor = NSColor.black
		targetShadowText2.horizontalAlignmentMode = .left
		targetShadowText2.verticalAlignmentMode = .center
		targetShadowText2.position = CGPoint(x: 1815, y: 630)
		targetShadowText2.zPosition = 21
		targetShadowText2.text = ""
		let targetShadow2 = SKEffectNode()
		targetShadow2.shouldEnableEffects = true
		targetShadow2.shouldRasterize = true
		targetShadow2.zPosition = 21
		targetShadow2.filter = filter;
		targetShadow2.addChild(targetShadowText2)
		targetLabel.zPosition = 22
		targetLabel.addChild(targetLabelText)
		targetLabel.addChild(targetShadow)
		targetLabel.addChild(targetLabelText2)
		targetLabel.addChild(targetShadow2)
		self.addChild(targetLabel)
		
		let bonusLabelText = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		bonusLabelText.fontSize = 70
		bonusLabelText.horizontalAlignmentMode = .right
		bonusLabelText.verticalAlignmentMode = .center
		bonusLabelText.position = CGPoint(x: 105, y: 755)
		bonusLabelText.zPosition = 22
		bonusLabelText.text = "🚀"
		self.addChild(bonusLabelText)
		
		let bonusLabelText2 = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
		bonusLabelText2.fontSize = 70
		bonusLabelText2.horizontalAlignmentMode = .left
		bonusLabelText2.verticalAlignmentMode = .center
		bonusLabelText2.position = CGPoint(x: 1815, y: 755)
		bonusLabelText2.zPosition = 22
		bonusLabelText2.text = "🚀"
		self.addChild(bonusLabelText2)
		
		for i in 0..<numTeams {
			let width = 1680.0 / Double(numTeams)
			let barWidth = width * 0.8
			let x = 120.0 + (width * (Double(i) + 0.5))
			
			let teamScoreText = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
			teamScoreText.fontSize = 72
			teamScoreText.horizontalAlignmentMode = .center
			teamScoreText.verticalAlignmentMode = .baseline
			teamScoreText.position = CGPoint.zero
			teamScoreText.zPosition = 15
			teamScoreText.text = "000"
			
			let teamScoreShadowText = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
			teamScoreShadowText.fontSize = 72
			teamScoreShadowText.fontColor = NSColor.black
			teamScoreShadowText.horizontalAlignmentMode = .center
			teamScoreShadowText.verticalAlignmentMode = .baseline
			teamScoreShadowText.position = CGPoint.zero
			teamScoreShadowText.zPosition = 14
			teamScoreShadowText.text = "000"
			let teamScoreShadow = SKEffectNode()
			teamScoreShadow.shouldEnableEffects = true
			teamScoreShadow.shouldRasterize = true
			teamScoreShadow.zPosition = 14
			let filter = CIFilter(name: "CIGaussianBlur")
			filter?.setDefaults()
			filter?.setValue(18, forKey: "inputRadius")
			teamScoreShadow.filter = filter;
			teamScoreShadow.addChild(teamScoreShadowText)
			
			let teamScoreLabel = SKNode()
			teamScoreLabel.position = CGPoint(x: x, y: 150)
			teamScoreLabel.zPosition = 15
			teamScoreLabel.addChild(teamScoreText)
			teamScoreLabel.addChild(teamScoreShadow)
			teamScoreLabels.append(teamScoreLabel)
			self.addChild(teamScoreLabel)
			
			let teamNameText = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
			teamNameText.fontSize = 48
			teamNameText.horizontalAlignmentMode = .center
			teamNameText.verticalAlignmentMode = .baseline
			teamNameText.position = CGPoint(x: x, y: 70)
			teamNameText.zPosition = 15
			teamNameText.text = "Team \(i + 1)"
			self.addChild(teamNameText)
			
			let teamNameShadowText = SKLabelNode(fontNamed: ".AppleSystemUIFontBold")
			teamNameShadowText.fontSize = 48
			teamNameShadowText.fontColor = NSColor.black
			teamNameShadowText.horizontalAlignmentMode = .center
			teamNameShadowText.verticalAlignmentMode = .baseline
			teamNameShadowText.position = CGPoint.zero
			teamNameShadowText.zPosition = 14
			teamNameShadowText.text = "Team \(i + 1)"
			let teamNameShadow = SKEffectNode()
			teamNameShadow.shouldEnableEffects = true
			teamNameShadow.shouldRasterize = true
			teamNameShadow.zPosition = 14
			teamNameShadow.filter = filter;
			teamNameShadow.addChild(teamNameShadowText)
			teamNameShadow.position = CGPoint(x: x, y: 70)
			self.addChild(teamNameShadow)
			
			var teamHue = CGFloat(i) / 8.0
			if teamHue > 1.0 {
				teamHue -= 1.0
			}
			let barColour = NSColor(calibratedHue: teamHue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
			
			let bar = SKSpriteNode(texture: nil, color: barColour, size: CGSize(width: barWidth, height: 0.0))
			bar.anchorPoint = .zero
			bar.zPosition = 13
			bar.name = "bar"
			
			let barBorder = SKSpriteNode(texture: nil, color: .white, size: CGSize(width: barWidth + 6, height: 0.0))
			barBorder.position = CGPoint(x: -3.0, y: 3.0)
			barBorder.anchorPoint = .zero
			barBorder.zPosition = 12
			
			let barShadow = SKSpriteNode(texture: nil, color: .black, size: CGSize(width: barWidth + 6, height: 0.0))
			barShadow.position = CGPoint(x: -3.0, y: 3.0)
			barShadow.anchorPoint = .zero
			barShadow.zPosition = 1
			let barShadowEffect = SKEffectNode()
			barShadowEffect.shouldEnableEffects = true
			barShadowEffect.shouldRasterize = true
			barShadowEffect.zPosition = 1
			let barShadowFilter = CIFilter(name: "CIGaussianBlur")
			barShadowFilter?.setDefaults()
			barShadowFilter?.setValue(40, forKey: "inputRadius")
			barShadowEffect.filter = barShadowFilter;
			barShadowEffect.addChild(barShadow)
			barShadowEffect.position = .zero
			
			let barContainer = SKNode()
			barContainer.position = CGPoint(x: x - barWidth/2, y: 130.0)
			barContainer.addChild(bar)
			barContainer.addChild(barBorder)
			barContainer.addChild(barShadowEffect)
			
			teamBars.append(barContainer)
			self.addChild(barContainer)
		}
	}
	
	func reset(setGrid: Bool = true) {
		clearTeamScores()
		stopTimer()
		updateTime(seconds: 120)
		updateTargetString(target: "👑", shadow: false)
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
			updateTargetString(target: String(questions[currentQuestion].target), shadow: true)
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
	
	func updateTargetString(target: String, shadow: Bool) {
		for node in targetLabel.children {
			if let label = node as? SKLabelNode {
				label.text = target
			}
			else if let effect = node as? SKEffectNode {
				for node2 in effect.children {
					if let label = node2 as? SKLabelNode {
						if (shadow) {
							label.text = target
						}
						else {
							label.text = ""
						}
					}
				}
			}
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
			let question = questions[currentQuestion]
			let score = teamScores[i]
			let scoreString = String(score)
			let progress = Double(teamScores[i]) / Double(question.target)
			let barHeight = CGFloat(progress * 500.0)
			var colour = SKColor.darkGray
			if score >= question.bonus {
				colour = .yellow
			}
			else if score >= question.target {
				colour = .green
			}
			let growBar = SKAction.resize(toHeight: barHeight, duration: 0.4)
			growBar.timingMode = .easeOut
			
			for node in teamScoreLabels[i].children {
				if let label = node as? SKLabelNode {
					label.text = scoreString
				}
				else if let effect = node as? SKEffectNode {
					for node2 in effect.children {
						if let label = node2 as? SKLabelNode {
							label.text = scoreString
						}
					}
				}
			}
			for node in teamBars[i].children {
				if let bar = node as? SKSpriteNode {
					if bar.size.height != barHeight {
						bar.run(growBar)
						if bar.name == "bar" {
							bar.color = colour
						}
					}
				}
				else if let effect = node as? SKEffectNode {
					for node2 in effect.children {
						if let bar = node2 as? SKSpriteNode {
							if bar.size.height != barHeight {
								bar.run(growBar)
							}
						}
					}
				}
			}
		}
	}
}
