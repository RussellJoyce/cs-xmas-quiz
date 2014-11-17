//
//  AppDelegate.swift
//  Quiz Server
//
//  Created by Russell Joyce on 16/11/2014.
//  Copyright (c) 2014 Russell Joyce. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!


    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
    
    func applicationDidChangeScreenParameters(notification: NSNotification) {
        // Screens changed - figure out how the changes affect us
        NSLog("Screens changed!")
    }

}

