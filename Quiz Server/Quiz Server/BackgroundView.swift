//
//  BackgroundView.swift
//  Quiz Server
//
//  Created by Russell Joyce on 08/12/2014.
//  Copyright (c) 2014 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa

class BackgroundView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        NSRectFill(dirtyRect)
        super.draw(dirtyRect)
    }
}
