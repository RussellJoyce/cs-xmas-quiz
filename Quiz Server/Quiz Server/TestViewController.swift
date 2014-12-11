//
//  TestView.swift
//  Quiz Server
//
//  Created by Russell Joyce on 08/12/2014.
//  Copyright (c) 2014 Russell Joyce. All rights reserved.
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
    
    let 👽 = AVAudioPlayer(contentsOfURL: NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource("eight", ofType: "wav")!), error: nil) // EXTRATERRESTRIAL ALIEN
    
    let scene = SKScene()
    let sparksUp = [SKEmitterNode(fileNamed: "SparksUp"),
        SKEmitterNode(fileNamed: "SparksUp"),
        SKEmitterNode(fileNamed: "SparksUp"),
        SKEmitterNode(fileNamed: "SparksUp"),
        SKEmitterNode(fileNamed: "SparksUp"),
        SKEmitterNode(fileNamed: "SparksUp"),
        SKEmitterNode(fileNamed: "SparksUp"),
        SKEmitterNode(fileNamed: "SparksUp")]
    let sparksDown = [SKEmitterNode(fileNamed: "SparksDown"),
        SKEmitterNode(fileNamed: "SparksDown"),
        SKEmitterNode(fileNamed: "SparksDown"),
        SKEmitterNode(fileNamed: "SparksDown"),
        SKEmitterNode(fileNamed: "SparksDown"),
        SKEmitterNode(fileNamed: "SparksDown"),
        SKEmitterNode(fileNamed: "SparksDown"),
        SKEmitterNode(fileNamed: "SparksDown")]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        numbers.extend([team1, team2, team3, team4, team5, team6, team7, team8])
        👽.prepareToPlay()
        
        
        // Set up SpriteKit sparks
        sparksView.allowsTransparency = true
        scene.size = sparksView.bounds.size
        scene.backgroundColor = NSColor.clearColor()
        sparksView.presentScene(scene)
        for (index, node) in enumerate(sparksUp) {
            node.position = CGPoint(x: (index * 204) + 247, y: 653)
            scene.addChild(node)
        }
        for (index, node) in enumerate(sparksDown) {
            node.position = CGPoint(x: (index * 204) + 247, y: 433)
            scene.addChild(node)
        }
        
        reset()
    }
    
    func reset() {
        leds?.stringOff()
        leds?.buzzersOff()
        for (index, team) in enumerate(numbers) {
            team.textColor = NSColor.whiteColor()
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
        numbers[team].textColor = NSColor.redColor()
        leds?.stringTeamWhite(team)
        leds?.buzzerOn(team)
        sparksUp[team].particleBirthRate = 600
        sparksDown[team].particleBirthRate = 600
        
        if (team == 7) {
            👽.currentTime = 0
            👽.play()
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
