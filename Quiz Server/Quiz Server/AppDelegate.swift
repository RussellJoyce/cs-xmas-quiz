//
//  AppDelegate.swift
//  Quiz Server
//
//  Created by Russell Joyce on 16/11/2014.
//  Copyright (c) 2014 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import DDHidLib
import Starscream

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!
    
    let controllerWindow = ControllerWindowController(windowNibName: NSNib.Name(rawValue: "ControllerWindow"))
	
	let webSocket = WebSocket(url: URL(string: "ws://localhost:8091/")!)

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
	
	
    
    
	func startQuiz(screen: NSScreen?, buzzers: DDHidJoystick?, serial: ORSSerialPort?, testMode: Bool, numberOfTeams: Int) {
        window.close()
		
		controllerWindow.numTeams = numberOfTeams
        controllerWindow.testMode = testMode
        controllerWindow.quizScreen = screen
        controllerWindow.quizBuzzers = buzzers
        if let serial = serial {
            controllerWindow.quizLeds = QuizLeds(serialPort: serial, webSocket: webSocket)
        }
		
		controllerWindow.socket = webSocket;
        controllerWindow.showWindow(self)
    }

}
