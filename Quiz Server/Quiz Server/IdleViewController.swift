//
//  IdleViewController.swift
//  Quiz Server
//
//  Created by Russell Joyce on 09/12/2014.
//  Copyright (c) 2014 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import SpriteKit

class IdleViewController: NSViewController {

    @IBOutlet weak var skView: SKView!
    
    let scene = SKScene()
    let snow = SKEmitterNode(fileNamed: "Snow")
    let poo = SKEmitterNode(fileNamed: "Poo")
    var leds: QuizLeds?
    var snowAmount = CGFloat(40.0)
    var buzzerStates = [Bool](count: 8, repeatedValue: false)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up SpriteKit scene/view
        skView.allowsTransparency = true
        scene.size = skView.bounds.size
        scene.backgroundColor = NSColor.clearColor()
        skView.presentScene(scene)
        snow.position = CGPoint(x: scene.size.width / 2, y: scene.size.height + 16)
        poo.position = CGPoint(x: scene.size.width / 2, y: scene.size.height + 32)
        scene.addChild(poo)
        scene.addChild(snow)
    }
    
    func reset() {
        leds?.stringAnimation(2)
        snowAmount = 40
        snow.particleBirthRate = snowAmount
        poo.particleBirthRate = 0
        
        buzzerStates = [Bool](count: 8, repeatedValue: false)
    }
    
    func buzzerPressed(team: Int) {
        if !buzzerStates[team] {
            snowAmount += 50
            snow.particleBirthRate = snowAmount
            buzzerStates[team] = true
            
            if buzzerStates == [true, true, true, true, true, true, true, true] {
                poo.particleBirthRate = 20
            }
        }
    }
    
    func buzzerReleased(team: Int) {
        if buzzerStates[team] {
            snowAmount -= 50
            snow.particleBirthRate = snowAmount
            buzzerStates[team] = false
            poo.particleBirthRate = 0
        }
    }
    
}
