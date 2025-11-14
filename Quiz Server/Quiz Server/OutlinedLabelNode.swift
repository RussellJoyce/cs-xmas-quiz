//
//  OutlinedLabelNode.swift
//  Quiz Server
//
//  Created by Ian Gray on 2025-10-25.
//  Copyright © 2025 Russell Joyce & Ian Gray. All rights reserved.
//
import Foundation
import Cocoa
import SpriteKit

class OutlinedLabelNode: SKNode {
    private let mainLabel: SKLabelNode
    private var outlineLabels: [SKLabelNode] = []
    private let outlineColor: NSColor
    private let outlineWidth: CGFloat
    
    var text: String? {
        get { mainLabel.text }
        set {
            mainLabel.text = newValue
            outlineLabels.forEach { $0.text = newValue }
        }
    }
    
    var fontSize: CGFloat {
        get { mainLabel.fontSize }
        set {
            mainLabel.fontSize = newValue
            outlineLabels.forEach { $0.fontSize = newValue }
        }
    }
    
    var fontColor: NSColor? {
        get { mainLabel.fontColor }
        set { mainLabel.fontColor = newValue }
    }
    
    var positionInParent: CGPoint {
        get { self.position }
        set { self.position = newValue }
    }
    
    init(text: String?, fontNamed: String?, fontSize: CGFloat, fontColor: NSColor, outlineColor: NSColor, outlineWidth: CGFloat) {
        self.mainLabel = SKLabelNode(fontNamed: fontNamed)
        self.outlineColor = outlineColor
        self.outlineWidth = outlineWidth
        super.init()
        mainLabel.text = text
        mainLabel.fontSize = fontSize
        mainLabel.fontColor = fontColor
        mainLabel.horizontalAlignmentMode = .center
        mainLabel.verticalAlignmentMode = .center
        mainLabel.zPosition = 1
        self.addOutlineLabels(base: mainLabel)
        self.addChild(mainLabel)
    }
    
    private func addOutlineLabels(base: SKLabelNode) {
        let offsets: [CGPoint] = [
            CGPoint(x: -outlineWidth, y: 0), CGPoint(x: outlineWidth, y: 0),
            CGPoint(x: 0, y: -outlineWidth), CGPoint(x: 0, y: outlineWidth),
            CGPoint(x: -outlineWidth, y: -outlineWidth), CGPoint(x: outlineWidth, y: outlineWidth),
            CGPoint(x: -outlineWidth, y: outlineWidth), CGPoint(x: outlineWidth, y: -outlineWidth)
        ]
        for offset in offsets {
            let outline = SKLabelNode(fontNamed: base.fontName)
            outline.text = base.text
            outline.fontSize = base.fontSize
            outline.fontColor = outlineColor
            outline.position = offset
            outline.zPosition = 0
            outline.horizontalAlignmentMode = base.horizontalAlignmentMode
            outline.verticalAlignmentMode = base.verticalAlignmentMode
            self.addChild(outline)
            outlineLabels.append(outline)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
