//
//  BuzzerViewController.swift
//  Quiz Server
//
//  Created by Russell Joyce on 09/12/2014.
//  Copyright (c) 2014 Russell Joyce. All rights reserved.
//

import Cocoa
import AVFoundation

class BuzzerViewController: NSViewController {
    
    @IBOutlet weak var team1: NSView!
    @IBOutlet weak var team2: NSView!
    @IBOutlet weak var team3: NSView!
    @IBOutlet weak var team4: NSView!
    @IBOutlet weak var team5: NSView!
    @IBOutlet weak var team6: NSView!
    @IBOutlet weak var team7: NSView!
    @IBOutlet weak var team8: NSView!
    
    @IBOutlet weak var teamName1: NSTextField!
    @IBOutlet weak var teamName2: NSTextField!
    @IBOutlet weak var teamName3: NSTextField!
    @IBOutlet weak var teamName4: NSTextField!
    @IBOutlet weak var teamName5: NSTextField!
    @IBOutlet weak var teamName6: NSTextField!
    @IBOutlet weak var teamName7: NSTextField!
    @IBOutlet weak var teamName8: NSTextField!
    
    @IBOutlet weak var teamTime2: NSTextField!
    @IBOutlet weak var teamTime3: NSTextField!
    @IBOutlet weak var teamTime4: NSTextField!
    @IBOutlet weak var teamTime5: NSTextField!
    @IBOutlet weak var teamTime6: NSTextField!
    @IBOutlet weak var teamTime7: NSTextField!
    @IBOutlet weak var teamTime8: NSTextField!
    
    
    var buzzNumber = 0
    var firstBuzzTime: NSDate?
    var leds: QuizLeds?
    var teams = [NSView]()
    var teamNames = [NSTextField]()
    var teamTimes = [NSTextField?]()
    var teamEnabled = [true, true, true, true, true, true, true, true]
    let buzzNoise = AVAudioPlayer(contentsOfURL: NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource("buzzer", ofType: "wav")!), error: nil)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        teams += [team1, team2, team3, team4, team5, team6, team7, team8]
        teamNames += [teamName1, teamName2, teamName3, teamName4, teamName5, teamName6, teamName7, teamName8]
        teamTimes += [nil, teamTime2, teamTime3, teamTime4, teamTime5, teamTime6, teamTime7, teamTime8] as [NSTextField?]
        buzzNoise.prepareToPlay()
        
        for (team, teamView) in enumerate(teams) {
            //teamView.wantsLayer = true
            //teamView.layerUsesCoreImageFilters = true
        }
    }
    
    func reset() {
        leds?.buzzersOn()
        teamEnabled = [true, true, true, true, true, true, true, true]
        for team in teams {
            team.hidden = true
        }
        buzzNumber = 0
    }
    
    func buzzerPressed(team: Int) {
        if teamEnabled[team] {
            teamEnabled[team] = false
            leds?.buzzerOff(team)
            teamNames[buzzNumber].stringValue = "Team \(team + 1)"
            teams[buzzNumber].layer?.backgroundColor = NSColor(calibratedHue: CGFloat(team) / 8.0, saturation: 1.0, brightness: 0.7, alpha: 1.0).CGColor
            
            if buzzNumber == 0 {
                firstBuzzTime = NSDate()
                buzzNoise.currentTime = 0
                buzzNoise.play()
                leds?.stringTeamAnimate(team)
            }
            else if let firstBuzzTimeOpt = firstBuzzTime {
                let time = -firstBuzzTimeOpt.timeIntervalSinceNow
                teamTimes[buzzNumber]?.stringValue = NSString(format: "+ %0.04f seconds", time)
            }
            teams[buzzNumber].hidden = false
            buzzNumber++
        }
    }
}

class BuzzerBackgroundView: NSView {
    let bgImage = NSImage(named: "2")
    override func drawRect(dirtyRect: NSRect) {
        bgImage?.drawInRect(dirtyRect, fromRect: dirtyRect, operation: NSCompositingOperation.CompositeCopy, fraction: 1.0)
    }
}
