//
//  TestView.swift
//  Quiz Server
//
//  Created by Russell Joyce on 08/12/2014.
//  Copyright (c) 2014 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import AVFoundation
import SpriteKit

class TestViewController: NSViewController {

    @IBOutlet weak var team1: NSTextField!
    @IBOutlet weak var team2: NSTextField!
    @IBOutlet weak var team3: NSTextField!
    @IBOutlet weak var team4: NSTextField!
    @IBOutlet weak var team5: NSTextField!
    @IBOutlet weak var team6: NSTextField!
    @IBOutlet weak var team7: NSTextField!
    @IBOutlet weak var team8: NSTextField!
	
    var numbers = [NSTextField]()
    var leds: QuizLeds?
	
    override func viewDidLoad() {
        super.viewDidLoad()
        numbers.append(contentsOf: [team1, team2, team3, team4, team5, team6, team7, team8])
		
        reset()
    }
    
    func reset() {
        leds?.stringOff()
        leds?.buzzersOff()
        for (_, team) in numbers.enumerated() {
            team.textColor = NSColor.white
            leds?.stringOff()
        }
	}
    
    func buzzerPressed(_ team: Int) {
        numbers[team].textColor = NSColor(calibratedHue: CGFloat(team) / 8.0, saturation: 1.0, brightness: 1.0, alpha: 1.0)
        leds?.buzzerOn(team: team)
    }
    
    func buzzerReleased(_ team: Int) {
        numbers[team].textColor = NSColor.white
        leds?.buzzerOff(team: team)
    }
    
}
