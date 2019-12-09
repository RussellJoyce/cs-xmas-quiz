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

class MusicScene: SKScene {
	
	var leds: QuizLeds?
	fileprivate var setUp = false
	var numTeams = 10
	
	var buzzNumber = 0
	var firstBuzzTime: Date?
	var teamEnabled = [Bool](repeating: true, count: 10)
	var buzzes = [Int]()
	var nextTeamNumber = 0
	var buzzNoises = [SKAction]()
	var teamBoxes = [BuzzerTeamNode]()
    var music: AVAudioPlayer?
	
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
        }
    }
    
	func setUpScene(size: CGSize, leds: QuizLeds?, numTeams: Int) {
		if setUp {
			return
		}
		setUp = true
		
		self.size = size
		self.leds = leds
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
        pauseMusic()
		teamEnabled = [Bool](repeating: false, count: 10)
		buzzNumber = 0
		buzzes.removeAll()
		nextTeamNumber = 0
		
		for teamBox in teamBoxes {
			teamBox.removeFromParent()
		}
		teamBoxes.removeAll()
	}
	
	func buzzerPressed(team: Int, type: BuzzerType) {
		if teamEnabled[team] && buzzes.count < 5 {
			teamEnabled[team] = false
			
			buzzes.append(team)
			
			if buzzNumber == 0 {
				firstBuzzTime = Date()
                buzzSound()
                pauseMusic()
				leds?.stringTeamAnimate(team: team)
				nextTeamNumber = 1
				
				let box = BuzzerTeamNode(team: team, width: 1000, height: 200, fontSize: 150, addGlow: true)
				box.position = CGPoint(x: self.centrePoint.x, y: self.size.height - 160)
				box.zPosition = 1
				teamBoxes.append(box)
				self.addChild(box)
				
			} else {
				let box = BuzzerTeamNode(team: team, width: 800, height: 130, fontSize: 100, addGlow: false)
				box.position = CGPoint(x: self.centrePoint.x, y: (self.size.height - 230) - CGFloat(buzzNumber * 175))
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
		teamEnabled = [Bool](repeating: true, count: 10)
		music?.play()
        music?.updateMeters()
    }
    
    func pauseMusic() {
        music?.pause()
        leds?.stringOff()
    }
    
    func stopMusic() {
        music?.stop()
        music?.currentTime = 0
        music?.prepareToPlay()
        leds?.stringOff()
    }
}
