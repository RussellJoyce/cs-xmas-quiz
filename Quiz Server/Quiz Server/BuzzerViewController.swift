//
//  BuzzerViewController.swift
//  Quiz Server
//
//  Created by Russell Joyce on 09/12/2014.
//  Copyright (c) 2014 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import AVFoundation
import SpriteKit

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
		
		
		for team in teams {
			let scaleFilter = CIFilter(name: "CILanczosScaleTransform")
			scaleFilter.setDefaults()
			scaleFilter.setValue(1, forKey: "inputScale")
			scaleFilter.name = "scale"
			team.layerUsesCoreImageFilters = true
			team.layer?.filters = [scaleFilter]
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
            let teamHue = CGFloat(team) / 8.0
            teams[buzzNumber].layer?.backgroundColor = NSColor(calibratedHue: teamHue, saturation: 1.0, brightness: 0.7, alpha: 1.0).CGColor
			
			
			let movey = CABasicAnimation()
			movey.keyPath = "position.y"
			movey.fromValue = 500
			movey.toValue = teams[buzzNumber].frame.origin.y
			movey.duration = 0.3
			movey.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
			teams[buzzNumber].layer!.addAnimation(movey, forKey: "movey")
			
			let movex = CABasicAnimation()
			movex.keyPath = "position.x"
			movex.fromValue = teams[buzzNumber].frame.origin.x - (teams[buzzNumber].frame.width)
			movex.toValue = teams[buzzNumber].frame.origin.x
			movex.duration = 0.3
			movex.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
			teams[buzzNumber].layer!.addAnimation(movex, forKey: "movex")
			
			let scale = CABasicAnimation()
			scale.keyPath = "filters.scale.inputScale"
			scale.fromValue = 3
			scale.toValue = 1
			scale.duration = 0.3
			scale.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
			teams[buzzNumber].layer!.addAnimation(scale, forKey: "scale")
			
			
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

class PlaceholderView: NSView {
    let color = NSColor(deviceWhite: 1.0, alpha: 0.4)
    
    override func drawRect(dirtyRect: NSRect) {
        color.setFill()
        NSRectFill(dirtyRect)
        super.drawRect(dirtyRect)
    }
}

class BuzzerBackgroundView: NSView {
    let bgImage = NSImage(named: "2")
    override func drawRect(dirtyRect: NSRect) {
        bgImage?.drawInRect(dirtyRect, fromRect: dirtyRect, operation: NSCompositingOperation.CompositeCopy, fraction: 1.0)
    }
}



// A nice dispatch function from http://stackoverflow.com/questions/24034544/dispatch-after-gcd-in-swift/24318861#24318861

func delay(delay:Double, closure:()->()) {
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            Int64(delay * Double(NSEC_PER_SEC))
        ),
        dispatch_get_main_queue(), closure)
}

