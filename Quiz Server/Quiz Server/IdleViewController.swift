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
    @IBOutlet weak var lights: NSImageView!
    
    let scene = SKScene()
    let snow = SKEmitterNode(fileNamed: "Snow")!
    //let poo = SKEmitterNode(fileNamed: "Poo")!
    let santa = SKEmitterNode(fileNamed: "Santa")!
    let trees = SKEmitterNode(fileNamed: "Tree")!
    var leds: QuizLeds?
    var snowAmount = CGFloat(40.0)
    var buzzerStates = [Bool](count: 10, repeatedValue: false)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up SpriteKit scene/view
        scene.size = skView.bounds.size
        scene.backgroundColor = NSColor.blackColor()
		let bgImage = SKSpriteNode(imageNamed: "1")
		bgImage.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
		bgImage.size = scene.size
        snow.position = CGPoint(x: scene.size.width / 2, y: scene.size.height + 16)
        //poo.position = CGPoint(x: scene.size.width / 2, y: scene.size.height + 32)
        santa.position = CGPoint(x: scene.size.width / 2, y: scene.size.height + 32)
        trees.position = CGPoint(x: scene.size.width / 2, y: scene.size.height + 32)
        //scene.addChild(poo)
		scene.addChild(bgImage)
        scene.addChild(santa)
        scene.addChild(trees)
        scene.addChild(snow)
		skView.presentScene(scene)
    }
    
    func reset() {
        leds?.stringAnimation(2)
        snowAmount = 40
        snow.particleBirthRate = snowAmount
        //poo.particleBirthRate = 0
        santa.particleBirthRate = 0
        trees.particleBirthRate = 0
        
        buzzerStates = [Bool](count: 10, repeatedValue: false)
		
		// Add animated lights
		let images = [NSImage(named: "lights4")!, NSImage(named: "lights3")!, NSImage(named: "lights2")!, NSImage(named: "lights1")!, NSImage(named: "lights4")!]
		let animation = CAKeyframeAnimation(keyPath: "contents")
		animation.calculationMode = kCAAnimationCubic
		animation.duration = 6.0
		animation.repeatCount = Float.infinity
		animation.values = images
		lights.layer?.removeAllAnimations()
		lights.layer?.addAnimation(animation, forKey:"contents")
    }
    
    func buzzerPressed(team: Int) {
        if !buzzerStates[team] {
            snowAmount += 50
            snow.particleBirthRate = snowAmount
            buzzerStates[team] = true
            
            if buzzerStates == [true, true, true, true, true, true, true, true, true, true] {
                //poo.particleBirthRate = 20
                santa.particleBirthRate = 15
                trees.particleBirthRate = 15
            }
        }
    }
    
    func buzzerReleased(team: Int) {
        if buzzerStates[team] {
            snowAmount -= 50
            snow.particleBirthRate = snowAmount
            buzzerStates[team] = false
            //poo.particleBirthRate = 0
            santa.particleBirthRate = 0
            trees.particleBirthRate = 0
        }
    }
    
}
