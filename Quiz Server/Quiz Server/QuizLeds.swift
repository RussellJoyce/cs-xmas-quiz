//
//  QuizLeds.swift
//  Quiz Server
//
//  Created by Russell Joyce on 04/12/2014.
//  Copyright (c) 2014 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa

let LEDS_ANIM    = 0x10 as UInt8
let LEDS_TEAM    = 0x20 as UInt8
let LEDS_TEAMC   = 0x30 as UInt8
let LEDS_COL     = 0x40 as UInt8
let LEDS_TESTON  = 0x50 as UInt8
let LEDS_TESTOFF = 0x60 as UInt8
let LEDS_POINTW  = 0x80 as UInt8
let LEDS_POINTC  = 0x90 as UInt8

let LED_ON     = 0xA0 as UInt8
let LED_OFF    = 0xB0 as UInt8
let LED_ALLON  = 0xC0 as UInt8
let LED_ALLOFF = 0xD0 as UInt8
let LED_POINT_STATE = 0xE0 as UInt8

/// Controller for the quiz buzzer system LEDs (both buzzer LEDs and LED string)
class QuizLeds: NSObject {
    let serial: ORSSerialPort
    
    /// Initialise LEDs connected via serial port
    ///
    /// - parameter serialPort: Serial port of the buzzer system
    init(serialPort: ORSSerialPort) {
        serial = serialPort
    }
    
    /// Open associated serial port (required once before use)
    func openSerial() {
        serial.open()
    }
    
    /// Close associated serial port (call when finished using LEDs)
    ///
    /// - returns: true if port was closed successfully, false otherwise
    func closeSerial() -> Bool {
        return serial.close()
    }
    
    /// Turn all buzzer LEDs off
    ///
    /// - returns: true if data sent successfully, false otherwise
    func buzzersOff() -> Bool {
        return serial.sendData(NSData(bytes: [LED_ALLOFF], length: 1));
    }
    
    /// Turn all buzzer LEDs on
    ///
    /// - returns: true if data sent successfully, false otherwise
    func buzzersOn() -> Bool {
        return serial.sendData(NSData(bytes: [LED_ALLON], length: 1));
    }
    
    /// Turn a specific buzzer LED off
    ///
    /// - parameter team: The team's LED to to turn on (0-9)
    /// - returns: true if data sent successfully, false otherwise
    func buzzerOff(team: Int) -> Bool {
        return serial.sendData(NSData(bytes: [LED_OFF + UInt8(team)], length: 1));
    }
    
    /// Turn a specific buzzer LED on
    ///
    /// - parameter team: The team's LED to to turn on (0-9)
    /// - returns: true if data sent successfully, false otherwise
    func buzzerOn(team: Int) -> Bool {
        return serial.sendData(NSData(bytes: [LED_ON + UInt8(team)], length: 1));
    }
    
    /// Set animation on LED string
    ///
    /// - parameter animation: The animation number (0-15)
    /// - returns: true if data sent successfully, false otherwise
    func stringAnimation(animation: Int) -> Bool {
        return serial.sendData(NSData(bytes: [LEDS_ANIM + UInt8(animation)], length: 1));
    }
    
    /// Turn LED string off (set to animation 0)
    ///
    /// - returns: true if data sent successfully, false otherwise
    func stringOff() -> Bool {
        return stringAnimation(0)
    }
    
    /// Set LED string to focus on team with animation
    ///
    /// - parameter team: The team number (0-9)
    /// - returns: true if data sent successfully, false otherwise
    func stringTeamAnimate(team: Int) -> Bool {
        return serial.sendData(NSData(bytes: [LEDS_TEAM + UInt8(team)], length: 1));
    }

	/// Set LED string to team colour
	///
	/// - parameter team: The team number (0-9)
	/// - returns: true if data sent successfully, false otherwise
	func stringTeamColour(team: Int) -> Bool {
		NSThread.sleepForTimeInterval(0.01)
		return serial.sendData(NSData(bytes: [LEDS_TEAMC + UInt8(team)], length: 1));
	}

	/// Set LED string to a given fixed colour
	///
	/// - parameter colour: The colour (red, green, blue, cyan, magenta, yellow, white, black)
	/// - returns: true if data sent successfully, false otherwise
	func stringFixedColour(colour: Int) -> Bool {
		NSThread.sleepForTimeInterval(0.01)
		return serial.sendData(NSData(bytes: [LEDS_COL + UInt8(colour)], length: 1));
	}
	
	/// Turn on test LEDs for team
	///
	/// - parameter team: The team number (0-9)
	/// - returns: true if data sent successfully, false otherwise
	func stringTestOn(team: Int) -> Bool {
		NSThread.sleepForTimeInterval(0.01)
		return serial.sendData(NSData(bytes: [LEDS_TESTON + UInt8(team)], length: 1));
	}
	
	/// Turn off test LEDs for team
	///
	/// - parameter team: The team number (0-9)
	/// - returns: true if data sent successfully, false otherwise
	func stringTestOff(team: Int) -> Bool {
		NSThread.sleepForTimeInterval(0.01)
		return serial.sendData(NSData(bytes: [LEDS_TESTOFF + UInt8(team)], length: 1));
	}
	
	/// Reset the Pointless LEDs
	///
	/// - returns: true if data sent successfully, false otherwise
	func stringPointlessReset() -> Bool {
		return serial.sendData(NSData(bytes: [LED_POINT_STATE + UInt8(0)], length: 1));
	}
	
	/// Decrement the Pointless LEDs
	///
	/// - returns: true if data sent successfully, false otherwise
	func stringPointlessDec() -> Bool {
		return serial.sendData(NSData(bytes: [LED_POINT_STATE + UInt8(1)], length: 1));
	}

	
    /// Play Pointless wrong animation on LED string
    ///
    /// - returns: true if data sent successfully, false otherwise
    func stringPointlessWrong() -> Bool {
        return serial.sendData(NSData(bytes: [LEDS_POINTW], length: 1));
    }
    
    /// Play Pointless correct animation on LED string
    ///
    /// - returns: true if data sent successfully, false otherwise
    func stringPointlessCorrect() -> Bool {
        return serial.sendData(NSData(bytes: [LEDS_POINTC], length: 1));
    }
}
