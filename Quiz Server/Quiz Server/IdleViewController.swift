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
    var leds: QuizLeds?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up SpriteKit scene/view
        skView.allowsTransparency = true
        scene.size = skView.bounds.size
        scene.backgroundColor = NSColor.clearColor()
        skView.presentScene(scene)
        let node = SKEmitterNode(fileNamed: "Snow")
        node.position = CGPoint(x: scene.size.width / 2, y: scene.size.height + 5)
        scene.addChild(node)
    }
    
    
    func reset() {
        leds?.stringAnimation(2)
    }
    
}
