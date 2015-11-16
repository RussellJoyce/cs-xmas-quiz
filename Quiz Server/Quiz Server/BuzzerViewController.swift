//
//  BuzzerViewController.swift
//  Quiz Server
//
//  Created by Russell Joyce on 09/12/2014.
//  Copyright (c) 2014 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import AVFoundation
import SpriteKit

class BuzzerViewController: NSViewController {
	
    @IBOutlet weak var skView: SKView!
    
    var buzzNumber = 0
    var firstBuzzTime: NSDate?
    var leds: QuizLeds?
    var teamEnabled = [Bool](count: 10, repeatedValue: true)
    var buzzes = [Int]()
    var nextTeamNumber = 0
    let buzzNoise = SKAction.playSoundFileNamed("buzzer", waitForCompletion: false)
    let skScene = SKScene()
	var teamBox: BuzzerTeamNode?
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		skView.showsFPS = true
		skView.showsNodeCount = true
		skView.ignoresSiblingOrder = true
		
        skScene.size = skView.bounds.size
		skScene.backgroundColor = NSColor.blackColor()
		let bgImage = SKSpriteNode(imageNamed: "2")
		bgImage.zPosition = -1.0
		bgImage.position = CGPoint(x:CGRectGetMidX(skScene.frame), y:CGRectGetMidY(skScene.frame))
		bgImage.size = skScene.size
		
		skScene.addChild(bgImage)
		skView.presentScene(skScene)
    }
    
    func reset() {
        leds?.buzzersOn()
        teamEnabled = [Bool](count: 10, repeatedValue: true)
        buzzNumber = 0
        buzzes.removeAll()
        nextTeamNumber = 0
		
		teamBox?.removeFromParent()
		teamBox = nil
    }
    
    func buzzerPressed(team: Int) {
        if teamEnabled[team] && buzzes.count < 8 {
            teamEnabled[team] = false
            leds?.buzzerOff(team)
			
			buzzes.append(team)
			
            if buzzNumber == 0 {
                firstBuzzTime = NSDate()
                skScene.runAction(buzzNoise)
                leds?.stringTeamAnimate(team)
                nextTeamNumber = 1
				
				teamBox = BuzzerTeamNode(team: team)
				teamBox?.position = skScene.centrePoint
				teamBox?.zPosition = 10
				skScene.addChild(teamBox!)
            }
            else if let firstBuzzTimeOpt = firstBuzzTime {
                let time = -firstBuzzTimeOpt.timeIntervalSinceNow
            }
            
            buzzNumber++
        }
    }
    
    func nextTeam() {
        if nextTeamNumber < buzzes.count {
            let team = buzzes[nextTeamNumber]
            leds?.stringTeamColour(team)
            nextTeamNumber++
        }
    }
}


extension SKNode {
	var centrePoint: CGPoint {
		return CGPoint(x:CGRectGetMidX(self.frame), y:CGRectGetMidY(self.frame))
	}
}
