//
//  LEDWebSocket.swift
//  Quiz Server
//
//  Created by Ian Gray on 25/11/2023.
//  Copyright © 2023 Russell Joyce & Ian Gray. All rights reserved.
//

import Foundation
import Starscream

extension WebSocket {
	
	func sendIfConnected(_ s : String) {
		if isConnected {
			write(string: s)
		}
	}
	
	func ledsOff() {
		sendIfConnected("lea00")
	}
	
	func megamas() {
		sendIfConnected("lea01")
	}
	
	/// Trigger a random buzzer animation for team (0-based)
	func buzz(team : Int) {
		if team >= 0 && team < 100 {
			sendIfConnected("leb" + String(format: "%02d", team))
		}
	}
	
	/// Set leds to an R G B colour (0-255)
	func setColour(r : UInt8, g : UInt8, b : UInt8) {
		sendIfConnected("lec" + String(format: "%03d", r) + String(format: "%03d", g) + String(format: "%03d", b))
	}
	
	/// Set leds to the colour of a specified team (0-based)
	func setTeamColour(team : Int) {
		if team >= 0 && team < 100 {
			sendIfConnected("let" + String(format: "%02d", team))
		}
	}
	
	func pulseWhite() {
		sendIfConnected("lep00")
	}
	
	func pulseRed() {
		sendIfConnected("lep01")
	}
	
	func pulseGreen() {
		sendIfConnected("lep02")
	}
	
	/// Pulse leds the colour of a specified team (0-based)
	func pulseTeamColour(team : Int) {
		if team >= 0 && team < 100 {
			sendIfConnected("leq" + String(format: "%02d", team))
		}
	}
	
	/// Set music levels on LEDs
	/// - parameter leftAvg: Left average power
	/// - parameter leftPeak: Left peak power
	/// - parameter rightAvg: Right average power
	/// - parameter rightPeak: Right peak power
	func setMusicLevels(leftAvg: Int, leftPeak: Int, rightAvg: Int, rightPeak: Int) {
		sendIfConnected("lem" + String(format: "%03d", leftAvg) + String(format: "%03d", leftPeak) + String(format: "%03d", rightAvg) + String(format: "%03d", rightPeak))
	}
}

