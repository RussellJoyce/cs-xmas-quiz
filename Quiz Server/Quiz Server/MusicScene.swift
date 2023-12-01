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
	
	var leds: QuizLeds?
	fileprivate var setUp = false
	var numTeams = 15
	
	var buzzNumber = 0
	var firstBuzzTime: Date?
	var teamEnabled = [Bool](repeating: true, count: 15)
	var buzzes = [Int]()
	var nextTeamNumber = 0
	var buzzNoises = [SKAction]()
	var teamBoxes = [BuzzerTeamNode]()
    var music: AVAudioPlayer?
	var webSocket : WebSocket?
	
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
            
            leds?.stringMusic(leftAvg: Int(avgL*100), leftPeak: Int(peakL*100), rightAvg: Int(avgR*100), rightPeak: Int(peakR*100))
			webSocket?.setMusicLevels(leftAvg: Int(avgL*100), leftPeak: Int(peakL*100), rightAvg: Int(avgR*100), rightPeak: Int(peakR*100))
        }
    }
    
	func setUpScene(size: CGSize, leds: QuizLeds?, numTeams: Int, webSocket: WebSocket?) {
		if setUp {
			return
		}
		setUp = true
		
		self.size = size
		self.leds = leds
		self.webSocket = webSocket
		self.numTeams = numTeams
        
        buzzNoises.append(SKAction.playSoundFileNamed("scratch1", waitForCompletion: false))
        buzzNoises.append(SKAction.playSoundFileNamed("scratch2", waitForCompletion: false))
        buzzNoises.append(SKAction.playSoundFileNamed("scratch3", waitForCompletion: false))
		
		let bgImage = SKSpriteNode(imageNamed: "music2")
		bgImage.zPosition = 0
		bgImage.position = CGPoint(x:self.frame.midX, y:self.frame.midY)
		bgImage.size = self.size
        
		self.addChild(bgImage)
	}
	
	func buzzSound() {
        // Play random buzzer sound
        if let buzzNoise = buzzNoises.randomElement() {
            self.run(buzzNoise)
        }
    }
	
	func reset() {
        leds?.stringOff()
		webSocket?.ledsOff()
        pauseMusic()
		teamEnabled = [Bool](repeating: false, count: numTeams)
		buzzNumber = 0
		buzzes.removeAll()
		nextTeamNumber = 0
		
		for teamBox in teamBoxes {
			teamBox.removeFromParent()
		}
		teamBoxes.removeAll()
	}
	
	func buzzerPressed(team: Int, type: BuzzerType, buzzcocksMode: Bool) {
		if teamEnabled[team] && (buzzes.count < 5 || buzzcocksMode == true) {
			teamEnabled[team] = false
			
			buzzes.append(team)
			
			if buzzNumber == 0 {
				nextTeamNumber = 1
				
				var box : BuzzerTeamNode;
				if buzzcocksMode == false {
					firstBuzzTime = Date()
					buzzSound()
					pauseMusic()
					leds?.stringTeamAnimate(team: team)
					webSocket?.buzz(team: team)
					box = BuzzerTeamNode(team: team, width: 1000, height: 200, fontSize: 150, addGlow: true)
					box.position = CGPoint(x: self.centrePoint.x, y: self.size.height - 160)
				} else {
					var timeString : String;
					if let stTime = firstBuzzTime {
						let timeDifference = Date().timeIntervalSince(stTime)
						let wholeSeconds = Int(timeDifference)
						let tenthsOfSecond = Int((timeDifference - Double(wholeSeconds)) * 10)
						timeString = "(\(String(format: "%d.%d", wholeSeconds, tenthsOfSecond)) sec)"
						//let diffComponents = Calendar.current.dateComponents([.second, .nanosecond], from: stTime, to: Date())
						//let nanostring = "\(diffComponents.nanosecond ?? 0 / 100000000)".prefix(1)
						//timeString = "(\(diffComponents.second ?? 0).\(nanostring) sec)"
					} else {
						timeString = "()"
					}
					box = BuzzerTeamNode(team: team, width: 1000, height: 90, fontSize: 80, addGlow: false, altText: "Team \(team + 1) \(timeString)")
					box.position = CGPoint(x: self.centrePoint.x, y: self.size.height - 100)
				}
				box.zPosition = 1
				teamBoxes.append(box)
				self.addChild(box)
				
			} else {
				var box : BuzzerTeamNode;
				if buzzcocksMode == false {
					box = BuzzerTeamNode(team: team, width: 800, height: 130, fontSize: 100, addGlow: false)
					box.position = CGPoint(x: self.centrePoint.x, y: (self.size.height - 230) - CGFloat(buzzNumber * 175))
				} else {
					var timeString : String;
					if let stTime = firstBuzzTime {
						let timeDifference = Date().timeIntervalSince(stTime)
						let wholeSeconds = Int(timeDifference)
						let tenthsOfSecond = Int((timeDifference - Double(wholeSeconds)) * 10)
						timeString = "(\(String(format: "%d.%d", wholeSeconds, tenthsOfSecond)) sec)"
						//let diffComponents = Calendar.current.dateComponents([.second, .nanosecond], from: stTime, to: Date())
						//let nanostring = "\(diffComponents.nanosecond ?? 0 / 100000000)".prefix(1)
						//timeString = "(\(diffComponents.second ?? 0).\(nanostring) sec)"
					} else {
						timeString = "()"
					}
					//We have a few layouts for larger team numbers
					if numTeams <= 10 {
						box = BuzzerTeamNode(team: team, width: 1000, height: 90, fontSize: 80, addGlow: false, altText: "Team \(team + 1) \(timeString)")
						box.position = CGPoint(x: self.centrePoint.x, y: (self.size.height - 100) - CGFloat(buzzNumber * 100))
					} else { //This will work up to about 15
						box = BuzzerTeamNode(team: team, width: 1000, height: 60, fontSize: 50, addGlow: false, altText: "Team \(team + 1) \(timeString)")
						box.position = CGPoint(x: self.centrePoint.x, y: (self.size.height - 120) - CGFloat(buzzNumber * 65))
					}
				}
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
			leds?.stringTeamColour(team: team)
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
    
    func resumeMusic() {
        reset()
		firstBuzzTime = Date()
		teamEnabled = [Bool](repeating: true, count: numTeams)
		music?.play()
        music?.updateMeters()
    }
    
    func pauseMusic() {
        music?.pause()
        leds?.stringOff()
		webSocket?.ledsOff()
    }
    
    func stopMusic() {
        music?.stop()
        music?.currentTime = 0
        music?.prepareToPlay()
        leds?.stringOff()
		webSocket?.ledsOff()
    }
}
