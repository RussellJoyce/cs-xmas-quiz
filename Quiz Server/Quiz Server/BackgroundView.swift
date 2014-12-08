//
//  BackgroundView.swift
//  Quiz Server
//
//  Created by Russell Joyce on 08/12/2014.
//  Copyright (c) 2014 Russell Joyce. All rights reserved.
//

import Cocoa

class BackgroundView: NSView {
    override func drawRect(dirtyRect: NSRect) {
        NSColor.blackColor().setFill()
        NSRectFill(dirtyRect)
        super.drawRect(dirtyRect)
    }
}