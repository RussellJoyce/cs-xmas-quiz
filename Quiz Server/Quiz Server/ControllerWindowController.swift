//
//  ControllerWindowController.swift
//  Quiz Server
//
//  Created by Russell Joyce on 18/11/2014.
//  Copyright (c) 2014 Russell Joyce. All rights reserved.
//

import Cocoa
import DDHidLib

class ControllerWindowController: NSWindowController, NSWindowDelegate {
    
    var quizScreen: NSScreen?
    var quizController: DDHidJoystick?
    var quizLeds: QuizLeds?
    
    let quizView = QuizViewController(nibName: "QuizView", bundle: nil) as QuizViewController!
    
    var led1 = false
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        // Open serial port
        quizLeds?.openSerial()
        
        // Open game controller
        quizController?.setDelegate(self)
        quizController?.startListening()
        
        // Show quiz view on selected screen
        quizView.view.enterFullScreenMode(quizScreen!, withOptions: [NSFullScreenModeAllScreens: 0])
    }
    
    func windowWillClose(notification: NSNotification) {
        // Turn off all buzzer and animation LEDs
        quizLeds?.allOff()
        quizLeds?.setAnimation(0)
        
        // Cleanly close serial port and game controller
        quizLeds?.closeSerial()
        quizController?.stopListening()
    }
    
    @IBAction func pressed1(sender: NSButton) {
        if led1 {
            quizLeds?.ledOff(0)
            usleep(100000)
            quizLeds?.ledOff(1)
            usleep(100000)
            quizLeds?.ledOff(2)
            usleep(100000)
            quizLeds?.ledOff(3)
            usleep(100000)
            quizLeds?.ledOff(4)
            usleep(100000)
            quizLeds?.ledOff(5)
            usleep(100000)
            quizLeds?.ledOff(6)
            usleep(100000)
            quizLeds?.ledOff(7)
            led1 = false
        }
        else {
            quizLeds?.ledOn(0)
            usleep(100000)
            quizLeds?.ledOn(1)
            usleep(100000)
            quizLeds?.ledOn(2)
            usleep(100000)
            quizLeds?.ledOn(3)
            usleep(100000)
            quizLeds?.ledOn(4)
            usleep(100000)
            quizLeds?.ledOn(5)
            usleep(100000)
            quizLeds?.ledOn(6)
            usleep(100000)
            quizLeds?.ledOn(7)
            led1 = true
        }
    }
    
    
    override func ddhidJoystick(joystick: DDHidJoystick!, buttonDown buttonNumber: UInt32) {
        println("Button \(buttonNumber) down")
        quizLeds?.ledOn(Byte(buttonNumber))
        quizView.titleLabel.stringValue = "Button \(buttonNumber + 1) buzzed"
    }
    
    override func ddhidJoystick(joystick: DDHidJoystick!, buttonUp buttonNumber: UInt32) {
        println("Button \(buttonNumber) up")
        quizLeds?.ledOff(Byte(buttonNumber))
    }

    
}
