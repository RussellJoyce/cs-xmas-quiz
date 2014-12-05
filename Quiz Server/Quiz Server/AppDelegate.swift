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
        
        // Code to test quiz screen layout, with no controller view
        /*
        let quizScreen = NSScreen.screens()![0] as NSScreen
        let quizView = QuizViewController(nibName: "QuizView", bundle: nil) as QuizViewController!
        quizView.view.addConstraint(NSLayoutConstraint(item: quizView.view,
            attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal,
            toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute,
            multiplier: 1, constant: quizScreen.frame.width))
        quizView.view.addConstraint(NSLayoutConstraint(item: quizView.view,
            attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal,
            toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute,
            multiplier: 1, constant: quizScreen.frame.height))
        quizView.view.enterFullScreenMode(quizScreen, withOptions: [NSFullScreenModeAllScreens: 0])
        */
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }
    
    func applicationDidChangeScreenParameters(notification: NSNotification) {
        // Screens changed - figure out how the changes affect us
        println("Screens changed!")
    }
    
    
    func startQuiz(screen: NSScreen?, controller: DDHidJoystick?, serial: ORSSerialPort?, testMode: Bool) {
        window.close()
        
        controllerWindow.quizScreen = screen
        controllerWindow.quizController = controller
        if let optSerial = serial {
            controllerWindow.quizLeds = QuizLeds(serialPort: optSerial)
        }
        
        controllerWindow.showWindow(self)
    }

}

