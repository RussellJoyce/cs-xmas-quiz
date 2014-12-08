//
//  QuizLeds.swift
//  Quiz Server
//
//  Created by Russell Joyce on 04/12/2014.
//  Copyright (c) 2014 Russell Joyce. All rights reserved.
//

import Cocoa

let LEDS_ANIM  = 0x10 as Byte
let LEDS_TEAM  = 0x20 as Byte
let LEDS_TEAMR = 0x30 as Byte
let LEDS_TEAMG = 0x40 as Byte

let LED_ON  = 0xA0 as Byte
let LED_OFF = 0xB0 as Byte
let LED_SET = 0xC0 as Byte

/// Controller for the quiz buzzer system LEDs (both buzzer LEDs and LED string)
class QuizLeds: NSObject {
    let serial: ORSSerialPort
    
    /// Initialise LEDs connected via serial port
    ///
    /// :param: serialPort Serial port of the buzzer system
    init(serialPort: ORSSerialPort) {
        serial = serialPort
    }
    
    /// Open associated serial port (required once before use)
    func openSerial() {
        serial.open()
    }
    
    /// Close associated serial port (call when finished using LEDs)
    ///
    /// :returns: true if port was closed successfully, false otherwise
    func closeSerial() -> Bool {
        return serial.close()
    }
    
    /// Turn all buzzer LEDs off
    ///
    /// :returns: true if data sent successfully, false otherwise
    func allOff() -> Bool {
        return serial.sendData(NSData(bytes: [LED_SET, 0x00] as [Byte], length: 2));
    }
    
    /// Turn all buzzer LEDs on
    ///
    /// :returns: true if data sent successfully, false otherwise
    func allOn() -> Bool {
        return serial.sendData(NSData(bytes: [LED_SET, 0xFF] as [Byte], length: 2));
    }
    
    /// Turn a specific buzzer LED off
    ///
    /// :param: led The LED to to turn off (0-7)
    /// :returns: true if data sent successfully, false otherwise
    func ledOff(led: Int) -> Bool {
        return serial.sendData(NSData(bytes: [LED_OFF + led] as [Byte], length: 1));
    }
    
    /// Turn a specific buzzer LED on
    ///
    /// :param: led The LED to to turn on (0-7)
    /// :returns: true if data sent successfully, false otherwise
    func ledOn(led: Int) -> Bool {
        return serial.sendData(NSData(bytes: [LED_ON + led] as [Byte], length: 1));
    }
    
    /// Set animation on LED string
    ///
    /// :param: animation The animation number (0-7)
    /// :returns: true if data sent successfully, false otherwise
    func setAnimation(animation: Int) -> Bool {
        return serial.sendData(NSData(bytes: [LEDS_ANIM + animation] as [Byte], length: 1));
    }
}
