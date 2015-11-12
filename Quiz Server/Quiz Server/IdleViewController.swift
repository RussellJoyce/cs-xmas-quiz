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
    var snowmojis = [SKEmitterNode]()
    var leds: QuizLeds?
	
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up SpriteKit scene/view
        scene.size = skView.bounds.size
        scene.backgroundColor = NSColor.blackColor()
		let bgImage = SKSpriteNode(imageNamed: "1")
		bgImage.position = CGPoint(x: scene.size.width / 2, y: scene.size.height / 2)
		bgImage.size = scene.size
        snow.position = CGPoint(x: scene.size.width / 2, y: scene.size.height + 16)
		snow.particleBirthRate = 40
		
		for i in 0...9 {
			let snowmoji = SKEmitterNode(fileNamed: "Snowmoji")!
			snowmoji.particleTexture = SKTexture(imageNamed: "snowmoji\(i)")
			snowmoji.position = CGPoint(x: scene.size.width / 2, y: scene.size.height + 32)
			snowmojis.append(snowmoji)
		}
		
		scene.addChild(bgImage)
		for node in snowmojis {
			scene.addChild(node)
		}
        scene.addChild(snow)
		skView.presentScene(scene)
    }
    
    func reset() {
        leds?.stringAnimation(2)
		for node in snowmojis {
			node.particleBirthRate = 0
		}
		
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
		snowmojis[team].particleBirthRate = 20
    }
    
    func buzzerReleased(team: Int) {
        snowmojis[team].particleBirthRate = 0
    }
    
}
