//
//  TestView.swift
//  Quiz Server
//
//  Created by Russell Joyce on 08/12/2014.
//  Copyright (c) 2014 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import AVFoundation
import SpriteKit

class TestViewController: NSViewController {

    @IBOutlet weak var skView: SKView!
    
    var leds: QuizLeds?
    
	let eightSound = SKAction.playSoundFileNamed("eight", waitForCompletion: false)
    
    let scene = SKScene()
	let numbers = [SKLabelNode(fontNamed: ".AppleSystemUIFontBold"),
		SKLabelNode(fontNamed: ".AppleSystemUIFontBold"),
		SKLabelNode(fontNamed: ".AppleSystemUIFontBold"),
		SKLabelNode(fontNamed: ".AppleSystemUIFontBold"),
		SKLabelNode(fontNamed: ".AppleSystemUIFontBold"),
		SKLabelNode(fontNamed: ".AppleSystemUIFontBold"),
		SKLabelNode(fontNamed: ".AppleSystemUIFontBold"),
		SKLabelNode(fontNamed: ".AppleSystemUIFontBold"),
		SKLabelNode(fontNamed: ".AppleSystemUIFontBold"),
		SKLabelNode(fontNamed: ".AppleSystemUIFontBold")]
	let sparksUp = [SKEmitterNode(fileNamed: "SparksUp")!,
		SKEmitterNode(fileNamed: "SparksUp")!,
		SKEmitterNode(fileNamed: "SparksUp")!,
		SKEmitterNode(fileNamed: "SparksUp")!,
		SKEmitterNode(fileNamed: "SparksUp")!,
		SKEmitterNode(fileNamed: "SparksUp")!,
		SKEmitterNode(fileNamed: "SparksUp")!,
		SKEmitterNode(fileNamed: "SparksUp")!,
		SKEmitterNode(fileNamed: "SparksUp")!,
		SKEmitterNode(fileNamed: "SparksUp")!]
	let sparksDown = [SKEmitterNode(fileNamed: "SparksDown")!,
		SKEmitterNode(fileNamed: "SparksDown")!,
		SKEmitterNode(fileNamed: "SparksDown")!,
		SKEmitterNode(fileNamed: "SparksDown")!,
		SKEmitterNode(fileNamed: "SparksDown")!,
		SKEmitterNode(fileNamed: "SparksDown")!,
		SKEmitterNode(fileNamed: "SparksDown")!,
		SKEmitterNode(fileNamed: "SparksDown")!,
		SKEmitterNode(fileNamed: "SparksDown")!,
		SKEmitterNode(fileNamed: "SparksDown")!]
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
        // Set up SpriteKit sparks and numbers
        scene.size = skView.bounds.size
        scene.backgroundColor = NSColor.blackColor()
		for (index, node) in numbers.enumerate() {
			node.fontColor = NSColor.blueColor()
			node.fontSize = 170.0
			node.horizontalAlignmentMode = .Center
			node.verticalAlignmentMode = .Center
			node.text = String(index + 1)
			node.position = CGPoint(x: (index * 190) + 105, y: 540)
			scene.addChild(node)
		}
        for (index, node) in sparksUp.enumerate() {
            node.position = CGPoint(x: (index * 190) + 105, y: 655)
            scene.addChild(node)
        }
        for (index, node) in sparksDown.enumerate() {
            node.position = CGPoint(x: (index * 190) + 105, y: 425)
            scene.addChild(node)
        }
		skView.presentScene(scene)
        
        reset()
    }
    
    func reset() {
        leds?.stringOff()
        leds?.buzzersOff()
        for (_, team) in numbers.enumerate() {
            team.fontColor = NSColor.whiteColor()
            leds?.stringOff()
        }
        
        for node in sparksUp {
            node.particleBirthRate = 0
        }
        for node in sparksDown {
            node.particleBirthRate = 0
        }
    }
    
    func buzzerPressed(team: Int) {
        numbers[team].fontColor = NSColor(calibratedHue: CGFloat(team) / 10.0, saturation: 1.0, brightness: 1.0, alpha: 1.0)
        leds?.stringTeamWhite(team)
        leds?.buzzerOn(team)
        sparksUp[team].particleBirthRate = 600
        sparksDown[team].particleBirthRate = 600
        
        if team == 7 {
			scene.runAction(eightSound)
        }
    }
    
    func buzzerReleased(team: Int) {
        numbers[team].fontColor = NSColor.whiteColor()
        leds?.stringTeamOff(team)
        leds?.buzzerOff(team)
        sparksUp[team].particleBirthRate = 0
        sparksDown[team].particleBirthRate = 0
    }
    
}
