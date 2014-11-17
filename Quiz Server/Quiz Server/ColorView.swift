//
//  ColorView.swift
//  Quiz Server
//
//  Created by Russell Joyce on 17/11/2014.
//  Copyright (c) 2014 Russell Joyce. All rights reserved.
//

import Cocoa

class ColorView: NSView {
    var color = NSColor.blackColor()
    
    init(frame frameRect: NSRect, color: NSColor) {
        super.init(frame: frameRect)
        self.color = color
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func drawRect(dirtyRect: NSRect) {
        self.color.setFill()
        NSRectFill(dirtyRect)
        super.drawRect(dirtyRect)
    }
}