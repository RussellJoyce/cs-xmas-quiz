//
//  StartupView.swift
//  Quiz Server
//
//  Created by Russell Joyce on 17/11/2014.
//  Copyright (c) 2014 Russell Joyce. All rights reserved.
//

import Cocoa

class StartupView: NSViewController {
    
    @IBOutlet weak var screensLabel: NSTextField!
    @IBOutlet weak var captureButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let allScreens = NSScreen.screens()
        
        if let screens = allScreens as? [NSScreen] {
            let numScreens = screens.count
            println("Found \(numScreens) screens:")
            for screen in screens {
                println("  \(screen.frame)")
            }
            
            screensLabel.stringValue = "\(numScreens - 1) screens available"
            
            if numScreens > 1 {
                captureButton.enabled = true
            }
        }
        else {
            println("Error enumerating screens");
        }
        
    }
    
    @IBAction func captureScreens(sender: AnyObject) {
        let allScreens = NSScreen.screens()
        
        if let screens = allScreens as? [NSScreen] {
            for (index, screen) in enumerate(screens) {
                if index > 0 {
                    let screenRect = screen.frame
                    let view = ColourView(frame: screenRect, color: NSColor.greenColor())
                    let label = NSTextField(frame: CGRectMake(20, 20, screenRect.width - 40, screenRect.height - 40))
                    label.editable = false
                    label.stringValue = "Screen \(index)"
                    view.subviews.append(label)
                    let fullScreenOptions = [NSFullScreenModeAllScreens: 0]
                    view.enterFullScreenMode(screen, withOptions: fullScreenOptions)
                }
            }
        }
        else {
            println("Error capturing screens");
        }
    }
}

class ColourView: NSView {
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
