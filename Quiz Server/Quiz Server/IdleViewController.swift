//
//  IdleViewController.swift
//  Quiz Server
//
//  Created by Russell Joyce on 09/12/2014.
//  Copyright (c) 2014 Russell Joyce. All rights reserved.
//

import Cocoa

class IdleViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }
    
}


class IdleBackgroundView: NSView {
    let bgImage = NSImage(named: "1")
    override func drawRect(dirtyRect: NSRect) {
        bgImage?.drawInRect(dirtyRect)
    }
}