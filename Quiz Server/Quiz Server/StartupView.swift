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

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let allScreens = NSScreen.screens()
        
        if let screens = allScreens {
            let numScreens = screens.count
            println("Found \(numScreens) screens:")
            for screen in screens {
                println("  \(screen.frame)")
            }
            
            screensLabel.stringValue = "\(numScreens) screens available"
        }
        else {
            println("Error enumerating screens");
        }
        
    }
    
}
