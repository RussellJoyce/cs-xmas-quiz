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
import Starscream

class MusicScene: SKScene {
	
	fileprivate var setUp = false

	var buzzNumber = 0
	var firstBuzzTime: Date?
	var teamEnabled = [Bool](repeating: true, count: 15)
	var buzzes = [Int]()
	var nextTeamNumber = 0
	var buzzNoises = [SKAction]()
	var teamBoxes = [BuzzerTeamNode]()
    var music: AVAudioPlayer?
	var webSocket : WebSocket?
	var video: SKVideoNode?
	var videoEffect = SKEffectNode()

	
	var lastAltBuzzIndex = 0
	
    func normalisePower(power: Float) -> Float {
        return pow(10.0, min(power, 0.0)/20.0)
    }
    
    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        
        if music?.isPlaying ?? false {
            music?.updateMeters()
            let peakL = normalisePower(power: music?.peakPower(forChannel: 0) ?? -160.0)
            let peakR = normalisePower(power: music?.peakPower(forChannel: 1) ?? -160.0)
            let avgL = normalisePower(power: music?.averagePower(forChannel: 0) ?? -160.0)
            let avgR = normalisePower(power: music?.averagePower(forChannel: 1) ?? -160.0)
            
			webSocket?.setMusicLevels(leftAvg: Int(avgL*100), leftPeak: Int(peakL*100), rightAvg: Int(avgR*100), rightPeak: Int(peakR*100))
        }
    }
    
	func setUpScene(size: CGSize, webSocket: WebSocket?) {
		if setUp {
			return
		}
		setUp = true
		
		self.size = size
		self.webSocket = webSocket

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
		webSocket?.ledsOff()
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
						webSocket?.buzz(team: team)
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
					webSocket?.buzz(team: team)
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
			webSocket?.setTeamColour(team: team)
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
		webSocket?.ledsOff()
    }
    
    func stopMusic() {
        music?.stop()
        music?.currentTime = 0
        music?.prepareToPlay()
		webSocket?.ledsOff()
		video?.pause()
		video?.removeFromParent()
		video = nil
	}
}
