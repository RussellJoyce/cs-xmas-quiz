//
//  MusicScene.swift
//  Quiz Server
//
//  Created by Russell Joyce on 03/12/2019.
//  Copyright © 2019 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import SpriteKit
import AVFoundation

class MusicScene: SKScene, QuizRound {
	
	fileprivate var setUp = false

	var useLEDs : NSButton!
	
	var buzzNumber = 0
	var firstBuzzTime: Date?
	var teamEnabled = [Bool](repeating: true, count: 15)
	var buzzes = [Int]()
	var nextTeamNumber = 0
	var buzzNoises = [SKAction]()
	var teamBoxes = [BuzzerTeamNode]()
    var music: AVAudioPlayer?
	var video: SKVideoNode?
	var videoEffect = SKEffectNode()
	
	private var lastMusicUpdateTime: TimeInterval = 0
	private let musicUpdateFPS: Double = 30.0

	private var avgPowerBarLeft: SKShapeNode?
	private var avgPowerBarRight: SKShapeNode?
	private var peakMarkerLeft: SKShapeNode?
	private var peakMarkerRight: SKShapeNode?
	
	var lastAltBuzzIndex = 0
	
    func normalisePower(power: Float) -> Float {
        return pow(10.0, min(power, 0.0)/20.0)
    }
    
	func boostPower(power: Float) -> Float {
		let new = power * 1.3
		return new > 1.0 ? 1.0 : new
	}
	
    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        
        let dt = currentTime - lastMusicUpdateTime
        if dt < (1.0 / musicUpdateFPS) {
            return
        }
        lastMusicUpdateTime = currentTime
        
        if music?.isPlaying ?? false {
			music?.updateMeters()
			
			if useLEDs.state == .on {
				let peakL = normalisePower(power: music?.peakPower(forChannel: 0) ?? -160.0)
				let peakR = normalisePower(power: music?.peakPower(forChannel: 1) ?? -160.0)
				let avgL = normalisePower(power: music?.averagePower(forChannel: 0) ?? -160.0)
				let avgR = normalisePower(power: music?.averagePower(forChannel: 1) ?? -160.0)
				QuizWebSocket.shared?.setMusicLevels(leftAvg: Int(avgL*100), leftPeak: Int(peakL*100), rightAvg: Int(avgR*100), rightPeak: Int(peakR*100))
			}
        }
    }
    
	func setUpScene(size: CGSize) {
		if setUp {
			return
		}
		setUp = true

		self.size = size

        buzzNoises.append(SKAction.playSoundFileNamed("scratch1", waitForCompletion: false))
        buzzNoises.append(SKAction.playSoundFileNamed("scratch2", waitForCompletion: false))
        buzzNoises.append(SKAction.playSoundFileNamed("scratch3", waitForCompletion: false))
		
		let bgImage = SKSpriteNode(imageNamed: "music2")
		bgImage.zPosition = 0
		bgImage.position = CGPoint(x:self.frame.midX, y:self.frame.midY)
		bgImage.size = self.size
		self.addChild(bgImage)
		
		videoEffect.name = "videoEffect"
		videoEffect.filter = CIFilter(name: "CIGaussianBlur")
		videoEffect.filter?.setDefaults()
		videoEffect.filter?.setValue(0, forKey: "inputRadius")
		videoEffect.shouldEnableEffects = true
		videoEffect.zPosition = 1000
		self.addChild(videoEffect)
	}
	
	func buzzSound() {
        // Play random buzzer sound
        if let buzzNoise = buzzNoises.randomElement() {
            self.run(buzzNoise)
        }
    }
	
	func reset() {
		QuizWebSocket.shared?.ledsOff()
        pauseMusic()
		teamEnabled = [Bool](repeating: false, count: Settings.shared.numTeams)
		buzzNumber = 0
		buzzes.removeAll()
		nextTeamNumber = 0
		
		for teamBox in teamBoxes {
			teamBox.removeFromParent()
		}
		teamBoxes.removeAll()
		
		videoEffect.filter?.setValue(0, forKey: "inputRadius")
	}
	
	func buzzerPressed(team: Int, type: BuzzerType, buzzcocksMode: Bool, blankVideo : Bool) {
		if teamEnabled[team] && (buzzes.count < 5 || buzzcocksMode == true) {
			teamEnabled[team] = false
			
			buzzes.append(team)
			
			//Create a BuzzerTeamNode and put it somewhere in the scene
			//The layout varies based on audio or video, and whether we are pausing or not
			
			if video == nil {
				//We are playing music
				if buzzNumber == 0 {
					nextTeamNumber = 1
					var box : BuzzerTeamNode;
					if buzzcocksMode == false {
						firstBuzzTime = Date()
						buzzSound()
						pauseMusic()
						QuizWebSocket.shared?.buzz(team: team)
						box = BuzzerTeamNode(team: team, width: 1000, height: 200, fontSize: 150, addGlow: true, entranceShimmer: true)
						box.position = CGPoint(x: self.centrePoint.x, y: self.size.height - 160)
					} else {
						var timeString : String;
						if let stTime = firstBuzzTime {
							let timeDifference = Date().timeIntervalSince(stTime)
							let wholeSeconds = Int(timeDifference)
							let tenthsOfSecond = Int((timeDifference - Double(wholeSeconds)) * 10)
							timeString = "(\(String(format: "%d.%d", wholeSeconds, tenthsOfSecond)) sec)"
						} else {
							timeString = "()"
						}
						box = BuzzerTeamNode(team: team, width: 1000, height: 90, fontSize: 80, entranceShimmer: true, altText: "Team \(team + 1) \(timeString)")
						box.position = CGPoint(x: self.centrePoint.x, y: self.size.height - 100)
					}
					box.zPosition = 1
					teamBoxes.append(box)
					self.addChild(box)
					
				} else {
					var box : BuzzerTeamNode;
					if buzzcocksMode == false {
						box = BuzzerTeamNode(team: team, width: 800, height: 130, fontSize: 100, entranceShimmer: true)
						box.position = CGPoint(x: self.centrePoint.x, y: (self.size.height - 230) - CGFloat(buzzNumber * 175))
					} else {
						var timeString : String;
						if let stTime = firstBuzzTime {
							let timeDifference = Date().timeIntervalSince(stTime)
							let wholeSeconds = Int(timeDifference)
							let tenthsOfSecond = Int((timeDifference - Double(wholeSeconds)) * 10)
							timeString = "(\(String(format: "%d.%d", wholeSeconds, tenthsOfSecond)) sec)"
						} else {
							timeString = "()"
						}
						//We have a few layouts for larger team numbers
						if Settings.shared.numTeams <= 10 {
							box = BuzzerTeamNode(team: team, width: 1000, height: 90, fontSize: 80, entranceShimmer: true, altText: "Team \(team + 1) \(timeString)")
							box.position = CGPoint(x: self.centrePoint.x, y: (self.size.height - 100) - CGFloat(buzzNumber * 100))
						} else { //This will work up to about 15
							box = BuzzerTeamNode(team: team, width: 1000, height: 60, fontSize: 50, entranceShimmer: true, altText: "Team \(team + 1) \(timeString)")
							box.position = CGPoint(x: self.centrePoint.x, y: (self.size.height - 120) - CGFloat(buzzNumber * 65))
						}
					}
					box.zPosition = 1
					teamBoxes.append(box)
					self.addChild(box)
				}
			} else {
				//We are playing a video
				var box : BuzzerTeamNode;
				if buzzNumber == 0 {
					nextTeamNumber = 1
					buzzSound()
					video?.pause()
					QuizWebSocket.shared?.buzz(team: team)
				}

				if blankVideo {
					videoEffect.filter?.setValue(40, forKey: "inputRadius")
				}
				
				box = BuzzerTeamNode(team: team, width: 350, height: 90, fontSize: 50, addGlow: buzzNumber == 0, entranceShimmer: true)
				box.position = CGPoint(x: 250, y: (self.size.height - 230) - CGFloat(buzzNumber * 120))
				box.zPosition = 1
				teamBoxes.append(box)
				self.addChild(box)
			}
			
			buzzNumber += 1
		}
		
		if buzzes.count == 5 {
		}
	}
	
	func nextTeam() {
		if nextTeamNumber < buzzes.count {
			teamBoxes[nextTeamNumber-1].run(SKAction.fadeAlpha(to: 0.3, duration: 0.5))
			teamBoxes[nextTeamNumber-1].stopGlow()
			teamBoxes[nextTeamNumber].startGlow()
			let team = buzzes[nextTeamNumber]
			QuizWebSocket.shared?.setTeamColour(team)
			nextTeamNumber += 1
		}
	}
    
    func initMusic(file: String) {
        if music != nil {
            reset()
        }
        music = nil
        let musicUrl = URL(fileURLWithPath: file)
        do {
            try music = AVAudioPlayer(contentsOf: musicUrl)
        } catch let error {
            print(error.localizedDescription)
        }
        music?.isMeteringEnabled = true
        music?.prepareToPlay()
    }
    
	
	func prepareVideo(file: String) {
		if video != nil {
			reset()
		}
		video = nil
		
		let videoUrl = URL(fileURLWithPath: file)
		video = SKVideoNode(url: videoUrl)
		video!.position = CGPoint(x: self.frame.midX + 200, y: self.frame.midY)
		video!.size = CGSize(width: 1400, height: 840)
		video!.zPosition = 1000
		videoEffect.addChild(video!)

	}
	
	func resumeVideo() {
		reset()
		video?.play()
		videoEffect.filter?.setValue(0, forKey: "inputRadius")
		teamEnabled = [Bool](repeating: true, count: Settings.shared.numTeams)
	}
	
    func resumeMusic() {
        reset()
		firstBuzzTime = Date()
		teamEnabled = [Bool](repeating: true, count: Settings.shared.numTeams)
		music?.play()
        music?.updateMeters()
    }
    
    func pauseMusic() {
        music?.pause()
		QuizWebSocket.shared?.ledsOff()
    }
    
    func stopMusic() {
        music?.stop()
        music?.currentTime = 0
        music?.prepareToPlay()
		QuizWebSocket.shared?.ledsOff()
		video?.pause()
		video?.removeFromParent()
		video = nil
	}
	
	func addMonitorBars() {
		let barWidth: CGFloat = 30
		let barYOffset: CGFloat = size.height * 0.1
		// Left channel avg bar
		let avgBarLeftRect = CGRect(x: 20, y: barYOffset, width: barWidth, height: 10)
		let avgBarLeft = SKShapeNode(rect: avgBarLeftRect, cornerRadius: 8)
		avgBarLeft.fillColor = .green
		avgBarLeft.strokeColor = .clear
		avgBarLeft.zPosition = 10
		self.avgPowerBarLeft = avgBarLeft
		self.addChild(avgBarLeft)
		// Left channel peak marker
		let peakMarkerLeftRect = CGRect(x: 15, y: barYOffset, width: barWidth + 10, height: 4)
		let peakMarkerLeft = SKShapeNode(rect: peakMarkerLeftRect, cornerRadius: 2)
		peakMarkerLeft.fillColor = .white
		peakMarkerLeft.strokeColor = .clear
		peakMarkerLeft.zPosition = 11
		self.peakMarkerLeft = peakMarkerLeft
		self.addChild(peakMarkerLeft)
		// Right channel avg bar
		let avgBarRightRect = CGRect(x: 70, y: barYOffset, width: barWidth, height: 10)
		let avgBarRight = SKShapeNode(rect: avgBarRightRect, cornerRadius: 8)
		avgBarRight.fillColor = .green
		avgBarRight.strokeColor = .clear
		avgBarRight.zPosition = 10
		self.avgPowerBarRight = avgBarRight
		self.addChild(avgBarRight)
		// Right channel peak marker
		let peakMarkerRightRect = CGRect(x: 65, y: barYOffset, width: barWidth + 10, height: 4)
		let peakMarkerRight = SKShapeNode(rect: peakMarkerRightRect, cornerRadius: 2)
		peakMarkerRight.fillColor = .white
		peakMarkerRight.strokeColor = .clear
		peakMarkerRight.zPosition = 11
		self.peakMarkerRight = peakMarkerRight
		self.addChild(peakMarkerRight)
	}
	
	
	func updateMonitors() {
		music?.updateMeters()
		let peakL = normalisePower(power: music?.peakPower(forChannel: 0) ?? -160.0)
		let peakR = normalisePower(power: music?.peakPower(forChannel: 1) ?? -160.0)
		let avgL = normalisePower(power: music?.averagePower(forChannel: 0) ?? -160.0)
		let avgR = normalisePower(power: music?.averagePower(forChannel: 1) ?? -160.0)
		
		let maxBarHeight = self.size.height * 0.8
		let barYOffset = self.size.height * 0.1
	
		let peakLBoosted = boostPower(power: peakL)
		let peakRBoosted = boostPower(power: peakR)
		let avgLBoosted = boostPower(power: avgL)
		let avgRBoosted = boostPower(power: avgR)
		
		// Left channel avg bar and marker
		if let avgBar = avgPowerBarLeft {
			let h = CGFloat(avgLBoosted) * maxBarHeight
			avgBar.path = CGPath(roundedRect: CGRect(x: 20, y: barYOffset, width: 30, height: max(10, h)), cornerWidth: 8, cornerHeight: 8, transform: nil)
			avgBar.fillColor = NSColor(calibratedRed: CGFloat(avgLBoosted), green: 1.0 - CGFloat(avgL), blue: 0.0, alpha: 1.0)
		}
		if let marker = peakMarkerLeft {
			let y = barYOffset + CGFloat(peakLBoosted) * maxBarHeight
			marker.path = CGPath(roundedRect: CGRect(x: 15, y: y, width: 40, height: 4), cornerWidth: 2, cornerHeight: 2, transform: nil)
		}
		// Right channel avg bar and marker
		if let avgBar = avgPowerBarRight {
			let h = CGFloat(avgRBoosted) * maxBarHeight
			avgBar.path = CGPath(roundedRect: CGRect(x: 70, y: barYOffset, width: 30, height: max(10, h)), cornerWidth: 8, cornerHeight: 8, transform: nil)
			avgBar.fillColor = NSColor(calibratedRed: CGFloat(avgRBoosted), green: 1.0 - CGFloat(avgR), blue: 0.0, alpha: 1.0)
		}
		if let marker = peakMarkerRight {
			let y = barYOffset + CGFloat(peakRBoosted) * maxBarHeight
			marker.path = CGPath(roundedRect: CGRect(x: 65, y: y, width: 40, height: 4), cornerWidth: 2, cornerHeight: 2, transform: nil)
		}
	}
	
}

