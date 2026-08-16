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

class MusicScene: QuizScene {
	
	var useLEDs : NSButton?
	
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
			
			if useLEDs?.state == .on {
				let peakL = normalisePower(power: music?.peakPower(forChannel: 0) ?? -160.0)
				let peakR = normalisePower(power: music?.peakPower(forChannel: 1) ?? -160.0)
				let avgL = normalisePower(power: music?.averagePower(forChannel: 0) ?? -160.0)
				let avgR = normalisePower(power: music?.averagePower(forChannel: 1) ?? -160.0)
				QuizWebSocket.shared?.setMusicLevels(leftAvg: Int(avgL*100), leftPeak: Int(peakL*100), rightAvg: Int(avgR*100), rightPeak: Int(peakR*100))
			}
        }
    }
    
	override func buildScene() {
        buzzNoises.append(SKAction.playSoundFileNamed("scratch1", waitForCompletion: false))
        buzzNoises.append(SKAction.playSoundFileNamed("scratch2", waitForCompletion: false))
        buzzNoises.append(SKAction.playSoundFileNamed("scratch3", waitForCompletion: false))
		
		addBackground(imageNamed: "music2")

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
	
	override func reset() {
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
	
	/// Where a team's box goes and how it looks
	private struct BuzzerBoxLayout {
		var width : Int
		var height : Int
		var fontSize : CGFloat
		var position : CGPoint
		var addGlow = false
		var altText : String? = nil
	}

	override func buzzerPressed(team: Int, type: BuzzerType, options: BuzzerOptions) {
		guard teamEnabled[team], buzzes.count < 5 || options.buzzcocksMode else { return }
		teamEnabled[team] = false
		buzzes.append(team)

		let isFirstBuzz = buzzNumber == 0
		if isFirstBuzz {
			nextTeamNumber = 1
		}

		if video != nil {
			//We are playing a video
			if isFirstBuzz {
				buzzSound()
				video?.pause()
				QuizWebSocket.shared?.buzz(team: team)
			}
			if options.blankVideo {
				videoEffect.filter?.setValue(40, forKey: "inputRadius")
			}
		} else if isFirstBuzz && !options.buzzcocksMode {
			//We are playing music, and stop dead on the first buzz rather than
			//letting every team queue up behind it
			firstBuzzTime = Date()
			buzzSound()
			pauseMusic()
			QuizWebSocket.shared?.buzz(team: team)
		}

		let layout = buzzerBoxLayout(team: team, isFirstBuzz: isFirstBuzz, options: options)
		let box = BuzzerTeamNode(team: team,
								 width: layout.width,
								 height: layout.height,
								 fontSize: layout.fontSize,
								 addGlow: layout.addGlow,
								 entranceShimmer: true,
								 altText: layout.altText)
		box.position = layout.position
		box.zPosition = 1
		teamBoxes.append(box)
		self.addChild(box)

		buzzNumber += 1
	}

	/// The layout varies with the medium, whether this is the first buzz, and whether
	/// buzzcocks mode is queueing every team with their time rather than showing one.
	private func buzzerBoxLayout(team: Int, isFirstBuzz: Bool, options: BuzzerOptions) -> BuzzerBoxLayout {
		let centreX = self.centrePoint.x
		let top = self.size.height

		if video != nil {
			return BuzzerBoxLayout(width: 350, height: 90, fontSize: 50,
								   position: CGPoint(x: 250, y: (top - 230) - CGFloat(buzzNumber * 120)), addGlow: isFirstBuzz)
		}

		if !options.buzzcocksMode {
			return isFirstBuzz
				? BuzzerBoxLayout(width: 1000, height: 200, fontSize: 150,
								  position: CGPoint(x: centreX, y: top - 160),
								  addGlow: true)
				: BuzzerBoxLayout(width: 800, height: 130, fontSize: 100,
								  position: CGPoint(x: centreX, y: (top - 230) - CGFloat(buzzNumber * 175)))
		}

		//Buzzcocks mode: every team gets a row showing how long they took
		let altText = "Team \(team + 1) \(timeSinceFirstBuzz())"
		if isFirstBuzz {
			return BuzzerBoxLayout(width: 1000, height: 90, fontSize: 80,
								   position: CGPoint(x: centreX, y: top - 100),
								   altText: altText)
		}
		//We have a few layouts for larger team numbers
		if Settings.shared.numTeams <= 10 {
			return BuzzerBoxLayout(width: 1000, height: 90, fontSize: 80,
								   position: CGPoint(x: centreX, y: (top - 100) - CGFloat(buzzNumber * 100)),
								   altText: altText)
		}
		return BuzzerBoxLayout(width: 1000, height: 60, fontSize: 50, //This will work up to about 15
							   position: CGPoint(x: centreX, y: (top - 120) - CGFloat(buzzNumber * 65)),
							   altText: altText)
	}

	/// Time since the first team buzzed, as "(1.4 sec)".
	private func timeSinceFirstBuzz() -> String {
		guard let startTime = firstBuzzTime else { return "()" }
		let elapsed = Date().timeIntervalSince(startTime)
		let wholeSeconds = Int(elapsed)
		let tenthsOfSecond = Int((elapsed - Double(wholeSeconds)) * 10)
		return "(\(String(format: "%d.%d", wholeSeconds, tenthsOfSecond)) sec)"
	}
	
	override func teardown() {
		//This will allow play from where we left off. Reselect the track to reset it.
		pauseMusic()
		video?.pause()
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

