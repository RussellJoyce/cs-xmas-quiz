//
//  GameScene.swift
//  SpriteKitTest
//
//  Created by Russell Joyce on 15/11/2015.
//  Copyright (c) 2015 Russell Joyce. All rights reserved.
//

import SpriteKit

class GameScene: SKScene {
	
	var team = 0
	var teamBox: BuzzerTeamNode?
	
    override func didMoveToView(view: SKView) {
		
		let bgImage = SKSpriteNode(imageNamed: "background")
		bgImage.zPosition = -1.0
		bgImage.position = CGPoint(x:CGRectGetMidX(self.frame), y:CGRectGetMidY(self.frame))
		bgImage.size = self.size
		
		self.addChild(bgImage)
    }
    
    override func mouseDown(theEvent: NSEvent) {
        /* Called when a mouse click occurs */
		
		if teamBox != nil {
			teamBox?.removeFromParent()
			teamBox = nil
			team++
		}
		else {
			teamBox = BuzzerTeamNode(team: team)
			teamBox?.position = self.centrePoint
			teamBox?.zPosition = 10
			self.addChild(teamBox!)
		}
    }
    
    override func update(currentTime: CFTimeInterval) {
        /* Called before each frame is rendered */
    }
}

extension SKNode {
	var centrePoint: CGPoint {
		return CGPoint(x:CGRectGetMidX(self.frame), y:CGRectGetMidY(self.frame))
	}
}
