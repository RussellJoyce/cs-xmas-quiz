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

    @IBOutlet weak var team1: NSTextField!
    @IBOutlet weak var team2: NSTextField!
    @IBOutlet weak var team3: NSTextField!
    @IBOutlet weak var team4: NSTextField!
    @IBOutlet weak var team5: NSTextField!
    @IBOutlet weak var team6: NSTextField!
    @IBOutlet weak var team7: NSTextField!
    @IBOutlet weak var team8: NSTextField!
    @IBOutlet weak var sparksView: SKView!
    
    var numbers = [NSTextField]()
    var leds: QuizLeds?
    var eightCount = 0
    
    let eightSound = try! AVAudioPlayer(contentsOfURL: NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource("eight", ofType: "wav")!))
    
    let scene = SKScene()
    let sparksUp = [SKEmitterNode(fileNamed: "SparksUp")!,
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
        SKEmitterNode(fileNamed: "SparksDown")!]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        numbers.appendContentsOf([team1, team2, team3, team4, team5, team6, team7, team8])
        
        // Set up SpriteKit sparks
        sparksView.allowsTransparency = true
        scene.size = sparksView.bounds.size
        scene.backgroundColor = NSColor.clearColor()
        sparksView.presentScene(scene)
        for (index, node) in sparksUp.enumerate() {
            node.position = CGPoint(x: (index * 204) + 247, y: 653)
            scene.addChild(node)
        }
        for (index, node) in sparksDown.enumerate() {
            node.position = CGPoint(x: (index * 204) + 247, y: 433)
            scene.addChild(node)
        }
        
        reset()
    }
    
    func reset() {
        leds?.stringOff()
        leds?.buzzersOff()
        for (_, team) in numbers.enumerate() {
            team.textColor = NSColor.whiteColor()
            leds?.stringOff()
        }
        
        for node in sparksUp {
            node.particleBirthRate = 0
        }
        for node in sparksDown {
            node.particleBirthRate = 0
        }
        
        eightCount = 0
		eightSound.prepareToPlay()
    }
    
    func buzzerPressed(team: Int) {
        numbers[team].textColor = NSColor(calibratedHue: CGFloat(team) / 8.0, saturation: 1.0, brightness: 1.0, alpha: 1.0)
        leds?.stringTeamWhite(team)
        leds?.buzzerOn(team)
        sparksUp[team].particleBirthRate = 600
        sparksDown[team].particleBirthRate = 600
        
        if team == 7 {
            if eightCount == 0 {
                eightCount = 7
				eightSound.currentTime = 0
				eightSound.play()
            }
            else {
                eightCount--
            }
        }
    }
    
    func buzzerReleased(team: Int) {
        numbers[team].textColor = NSColor.whiteColor()
        leds?.stringTeamOff(team)
        leds?.buzzerOff(team)
        sparksUp[team].particleBirthRate = 0
        sparksDown[team].particleBirthRate = 0
    }
    
}
