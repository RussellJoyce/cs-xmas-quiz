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
    
    var quizScreen : NSScreen?
    var quizController : DDHidJoystick?
    var quizSerial : ORSSerialPort?
    
    var led1 = false
    
    override func windowDidLoad() {
        super.windowDidLoad()
        println("test")
        
        // Open serial port
        quizSerial?.open()
        
        // Open game controller
        quizController?.setDelegate(self)
        quizController?.startListening()
        
        // Show quiz view on selected screen
        let screenRect = quizScreen!.frame
        let view = ColorView(frame: screenRect, color: NSColor.greenColor())
        let label = NSTextField(frame: CGRectMake(20, 20, screenRect.width - 40, screenRect.height - 40))
        label.editable = false
        label.stringValue = "Quiz screen!"
        view.subviews.append(label)
        let fullScreenOptions = [NSFullScreenModeAllScreens: 0]
        view.enterFullScreenMode(quizScreen!, withOptions: fullScreenOptions)
    }
    
    func windowWillClose(notification: NSNotification) {
        // Turn off all buzzer and animation LEDs
        quizSerial?.sendData(NSData(bytes: [0x10, 0xC0, 0x00] as [Byte], length: 3));
        
        // Cleanly close serial port and game controller
        quizSerial?.close()
        quizController?.stopListening()
    }
    
    @IBAction func pressed1(sender: NSButton) {
        if led1 {
            quizSerial?.sendData(NSData(bytes: [0xB0] as [Byte], length: 1));
            sleep(1)
            quizSerial?.sendData(NSData(bytes: [0xB1] as [Byte], length: 1));
            sleep(1)
            quizSerial?.sendData(NSData(bytes: [0xB2] as [Byte], length: 1));
            sleep(1)
            quizSerial?.sendData(NSData(bytes: [0xB3] as [Byte], length: 1));
            sleep(1)
            quizSerial?.sendData(NSData(bytes: [0xB4] as [Byte], length: 1));
            sleep(1)
            quizSerial?.sendData(NSData(bytes: [0xB5] as [Byte], length: 1));
            sleep(1)
            quizSerial?.sendData(NSData(bytes: [0xB6] as [Byte], length: 1));
            sleep(1)
            quizSerial?.sendData(NSData(bytes: [0xB7] as [Byte], length: 1));
            led1 = false
        }
        else {
            quizSerial?.sendData(NSData(bytes: [0xA0] as [Byte], length: 1));
            sleep(1)
            quizSerial?.sendData(NSData(bytes: [0xA1] as [Byte], length: 1));
            sleep(1)
            quizSerial?.sendData(NSData(bytes: [0xA2] as [Byte], length: 1));
            sleep(1)
            quizSerial?.sendData(NSData(bytes: [0xA3] as [Byte], length: 1));
            sleep(1)
            quizSerial?.sendData(NSData(bytes: [0xA4] as [Byte], length: 1));
            sleep(1)
            quizSerial?.sendData(NSData(bytes: [0xA5] as [Byte], length: 1));
            sleep(1)
            quizSerial?.sendData(NSData(bytes: [0xA6] as [Byte], length: 1));
            sleep(1)
            quizSerial?.sendData(NSData(bytes: [0xA7] as [Byte], length: 1));
            led1 = true
        }
    }
    
    
    override func ddhidJoystick(joystick: DDHidJoystick!, buttonDown buttonNumber: UInt32) {
        println("Button \(buttonNumber) down")
        quizSerial?.sendData(NSData(bytes: [0xA0 + Byte(buttonNumber)] as [Byte], length: 1));
    }
    
    override func ddhidJoystick(joystick: DDHidJoystick!, buttonUp buttonNumber: UInt32) {
        println("Button \(buttonNumber) up")
        quizSerial?.sendData(NSData(bytes: [0xB0 + Byte(buttonNumber)] as [Byte], length: 1));
    }

    
}
