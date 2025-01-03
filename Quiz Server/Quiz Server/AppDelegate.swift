//
//  AppDelegate.swift
//  Quiz Server
//
//  Created by Russell Joyce on 16/11/2014.
//  Copyright (c) 2014 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import Starscream

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    
    let controllerWindow = ControllerWindowController(windowNibName: "ControllerWindow")
	
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationDidChangeScreenParameters(_ notification: Notification) {
        // Screens changed - figure out how the changes affect us
        print("Screens changed!")
    }
	
	func startQuiz(screen: NSScreen?, testMode: Bool, numberOfTeams: Int, geographyImagesPath: String, musicPath: String, uniquePath: String, debugMode: Bool) {
        window.close()
		
		controllerWindow.numTeams = numberOfTeams
        controllerWindow.testMode = testMode
        controllerWindow.quizScreen = screen
		controllerWindow.geographyImagesPath = geographyImagesPath
        controllerWindow.musicPath = musicPath
		controllerWindow.uniquePath = uniquePath
		controllerWindow.debugMode = debugMode
		
        controllerWindow.showWindow(self)
    }
}
