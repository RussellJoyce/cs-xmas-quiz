//
//  AppDelegate.swift
//  Quiz Server
//
//  Created by Russell Joyce on 16/11/2014.
//  Copyright (c) 2014 Russell Joyce & Ian Gray. All rights reserved.
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
        print("Screens changed!")
    }
    
    
    func startQuiz(screen: NSScreen?, buzzers: DDHidJoystick?, serial: ORSSerialPort?, testMode: Bool) {
        window.close()
        
        controllerWindow.testMode = testMode
        controllerWindow.quizScreen = screen
        controllerWindow.quizBuzzers = buzzers
        if let optSerial = serial {
            controllerWindow.quizLeds = QuizLeds(serialPort: optSerial)
        }
        
        controllerWindow.showWindow(self)
    }

}

