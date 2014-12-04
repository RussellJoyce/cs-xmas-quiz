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

class QuizLeds: NSObject {
    let serial: ORSSerialPort
    
    init(serialPort: ORSSerialPort) {
        serial = serialPort
    }
    
    func openSerial() {
        serial.open()
    }
    
    func closeSerial() -> Bool {
        return serial.close()
    }
    
    func allOff() -> Bool {
        return serial.sendData(NSData(bytes: [LED_SET, 0x00] as [Byte], length: 2));
    }
    
    func allOn() -> Bool {
        return serial.sendData(NSData(bytes: [LED_SET, 0xFF] as [Byte], length: 2));
    }
    
    func ledOff(led: Byte) -> Bool {
        return serial.sendData(NSData(bytes: [LED_OFF + led] as [Byte], length: 1));
    }
    
    func ledOn(led: Byte) -> Bool {
        return serial.sendData(NSData(bytes: [LED_ON + led] as [Byte], length: 1));
    }
    
    func setAnimation(animation: Byte) -> Bool {
        return serial.sendData(NSData(bytes: [LEDS_ANIM + animation] as [Byte], length: 1));
    }
}
