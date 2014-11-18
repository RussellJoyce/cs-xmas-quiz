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
    
    var controllerWindow : ControllerWindowController?


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
    
    
    func startQuiz(quizScreen: NSScreen, quizController: DDHidJoystick) {
        window.close()
        controllerWindow = ControllerWindowController(windowNibName: "ControllerWindowController")
        controllerWindow!.showWindow(self)
        
        let screenRect = quizScreen.frame
        let view = ColorView(frame: screenRect, color: NSColor.greenColor())
        let label = NSTextField(frame: CGRectMake(20, 20, screenRect.width - 40, screenRect.height - 40))
        label.editable = false
        label.stringValue = "Quiz screen!"
        view.subviews.append(label)
        let fullScreenOptions = [NSFullScreenModeAllScreens: 0]
        view.enterFullScreenMode(quizScreen, withOptions: fullScreenOptions)
    }

}

