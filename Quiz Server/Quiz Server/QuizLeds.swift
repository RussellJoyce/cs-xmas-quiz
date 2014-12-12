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
let LEDS_TEAMW = 0x50 as Byte
let LEDS_TEAMO = 0x60 as Byte

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
    func buzzersOff() -> Bool {
        return serial.sendData(NSData(bytes: [LED_SET, 0x00] as [Byte], length: 2));
    }
    
    /// Turn all buzzer LEDs on
    ///
    /// :returns: true if data sent successfully, false otherwise
    func buzzersOn() -> Bool {
        return serial.sendData(NSData(bytes: [LED_SET, 0xFF] as [Byte], length: 2));
    }
    
    /// Turn a specific buzzer LED off
    ///
    /// :param: team The team's LED to to turn on (0-7)
    /// :returns: true if data sent successfully, false otherwise
    func buzzerOff(team: Int) -> Bool {
        return serial.sendData(NSData(bytes: [LED_OFF + team] as [Byte], length: 1));
    }
    
    /// Turn a specific buzzer LED on
    ///
    /// :param: team The team's LED to to turn on (0-7)
    /// :returns: true if data sent successfully, false otherwise
    func buzzerOn(team: Int) -> Bool {
        return serial.sendData(NSData(bytes: [LED_ON + team] as [Byte], length: 1));
    }
    
    /// Set animation on LED string
    ///
    /// :param: animation The animation number (0-7)
    /// :returns: true if data sent successfully, false otherwise
    func stringAnimation(animation: Int) -> Bool {
        return serial.sendData(NSData(bytes: [LEDS_ANIM + animation] as [Byte], length: 1));
    }
    
    /// Turn LED string off (set to animation 0)
    ///
    /// :returns: true if data sent successfully, false otherwise
    func stringOff() -> Bool {
        return stringAnimation(0)
    }
    
    /// Set LED string to focus on team with animation
    ///
    /// :param: team The team number (0-7)
    /// :returns: true if data sent successfully, false otherwise
    func stringTeamAnimate(team: Int) -> Bool {
        return serial.sendData(NSData(bytes: [LEDS_TEAM + team] as [Byte], length: 1));
    }
    
    /// Set LED string team LEDs to red
    ///
    /// :param: team The team number (0-7)
    /// :returns: true if data sent successfully, false otherwise
    func stringTeamRed(team: Int) -> Bool {
		NSThread.sleepForTimeInterval(0.01)
        return serial.sendData(NSData(bytes: [LEDS_TEAMR + team] as [Byte], length: 1));
    }
    
    /// Set LED string team LEDs to green
    ///
    /// :param: team The team number (0-7)
    /// :returns: true if data sent successfully, false otherwise
    func stringTeamGreen(team: Int) -> Bool {
		NSThread.sleepForTimeInterval(0.01)
        return serial.sendData(NSData(bytes: [LEDS_TEAMG + team] as [Byte], length: 1));
    }
    
    /// Set LED string team LEDs to white
    ///
    /// :param: team The team number (0-7)
    /// :returns: true if data sent successfully, false otherwise
    func stringTeamWhite(team: Int) -> Bool {
		NSThread.sleepForTimeInterval(0.01)
        return serial.sendData(NSData(bytes: [LEDS_TEAMW + team] as [Byte], length: 1));
    }
    
    /// Set LED string team LEDs to off
    ///
    /// :param: team The team number (0-7)
    /// :returns: true if data sent successfully, false otherwise
    func stringTeamOff(team: Int) -> Bool {
		NSThread.sleepForTimeInterval(0.01)
        return serial.sendData(NSData(bytes: [LEDS_TEAMO + team] as [Byte], length: 1));
    }
}
