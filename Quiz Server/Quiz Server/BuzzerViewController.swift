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
    var firstBuzzTime: Date?
    var leds: QuizLeds?
    var teams = [NSView]()
    var teamNames = [NSTextField]()
    var teamTimes = [NSTextField?]()
    var teamEnabled = [true, true, true, true, true, true, true, true]
    var buzzes = [Int]()
    var nextTeamNumber = 0
	let buzzNoise = try! AVAudioPlayer(
		contentsOf: URL(fileURLWithPath: Bundle.main.path(forResource: "buzzer", ofType: "wav")!))
	
    override func viewDidLoad() {
        super.viewDidLoad()
        teams += [team1, team2, team3, team4, team5, team6, team7, team8]
        teamNames += [teamName1, teamName2, teamName3, teamName4, teamName5, teamName6, teamName7, teamName8]
        teamTimes += [nil, teamTime2, teamTime3, teamTime4, teamTime5, teamTime6, teamTime7, teamTime8] as [NSTextField?]
        buzzNoise.prepareToPlay()
		
		
		for team in teams {
			let scaleFilter = CIFilter(name: "CILanczosScaleTransform")
			scaleFilter?.setDefaults()
			scaleFilter?.setValue(1, forKey: "inputScale")
			scaleFilter?.name = "scale"
			team.layerUsesCoreImageFilters = true
			team.layer?.filters = [scaleFilter!]
		}
    }
    
    func reset() {
        leds?.buzzersOn()
        teamEnabled = [true, true, true, true, true, true, true, true]
        for team in teams {
            team.isHidden = true
            team.layer?.opacity = 1.0
        }
        buzzNumber = 0
        buzzes.removeAll()
        nextTeamNumber = 0
    }
    
    func buzzerPressed(_ team: Int) {
        if teamEnabled[team] {
            teamEnabled[team] = false
            leds?.buzzerOff(team: team)
            teamNames[buzzNumber].stringValue = "Team \(team + 1)"
            let teamHue = CGFloat(team) / 8.0
            teams[buzzNumber].layer?.backgroundColor = NSColor(calibratedHue: teamHue, saturation: 1.0, brightness: 0.7, alpha: 1.0).cgColor
			buzzes.append(team)
			
			let movey = CABasicAnimation()
			movey.keyPath = "position.y"
			movey.fromValue = 500
			movey.toValue = teams[buzzNumber].frame.origin.y
			movey.duration = 0.3
			movey.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
			teams[buzzNumber].layer!.add(movey, forKey: "movey")
			
			let movex = CABasicAnimation()
			movex.keyPath = "position.x"
			movex.fromValue = teams[buzzNumber].frame.origin.x - (teams[buzzNumber].frame.width)
			movex.toValue = teams[buzzNumber].frame.origin.x
			movex.duration = 0.3
			movex.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
			teams[buzzNumber].layer!.add(movex, forKey: "movex")
			
			let scale = CABasicAnimation()
			scale.keyPath = "filters.scale.inputScale"
			scale.fromValue = 3
			scale.toValue = 1
			scale.duration = 0.3
			scale.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
			teams[buzzNumber].layer!.add(scale, forKey: "scale")
			
            teams[buzzNumber].isHidden = false
			
            if buzzNumber == 0 {
                firstBuzzTime = Date()
                buzzNoise.currentTime = 0
                buzzNoise.play()
                leds?.stringTeamAnimate(team: team)
                nextTeamNumber = 1
            }
            else if let firstBuzzTimeOpt = firstBuzzTime {
                let time = -firstBuzzTimeOpt.timeIntervalSinceNow
                teamTimes[buzzNumber]?.stringValue = NSString(format: "+ %0.04f seconds", time) as String
            }
            
            buzzNumber += 1
        }
    }
    
    func nextTeam() {
        if nextTeamNumber < buzzes.count {
            let team = buzzes[nextTeamNumber]
            teams[nextTeamNumber - 1].layer?.opacity = 0.5
            leds?.stringTeamColour(team: team)
            nextTeamNumber += 1
        }
    }
}

class PlaceholderView: NSView {
    let color = NSColor(deviceWhite: 1.0, alpha: 0.4)
    
    override func draw(_ dirtyRect: NSRect) {
        color.setFill()
        NSRectFill(dirtyRect)
        super.draw(dirtyRect)
    }
}

class BuzzerBackgroundView: NSView {
    let bgImage = NSImage(named: "2")
    override func draw(_ dirtyRect: NSRect) {
        bgImage?.draw(in: dirtyRect, from: dirtyRect, operation: NSCompositingOperation.copy, fraction: 1.0)
    }
}
