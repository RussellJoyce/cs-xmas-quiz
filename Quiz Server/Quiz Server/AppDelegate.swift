//
//  AppDelegate.swift
//  Quiz Server
//
//  Created by Russell Joyce on 16/11/2014.
//  Copyright (c) 2014 Russell Joyce. All rights reserved.
//

import Cocoa
import DDHidLib

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    
    let controllerWindow = ControllerWindowController(windowNibName: "ControllerWindow")
    

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
    
    func applicationDidChangeScreenParameters(notification: NSNotification) {
        // Screens changed - figure out how the changes affect us
        println("Screens changed!")
    }
    
    
    func startQuiz(screen: NSScreen, controller: DDHidJoystick, serial: ORSSerialPort) {
        window.close()
        
        controllerWindow.quizScreen = screen
        controllerWindow.quizController = controller
        controllerWindow.quizLeds = QuizLeds(serialPort: serial)
        
        controllerWindow.showWindow(self)
    }

}

