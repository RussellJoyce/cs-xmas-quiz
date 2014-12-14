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
    
    @IBOutlet weak var sparksView: SKView!
    
    let scene = SKScene()
    let sparks = [SKEmitterNode(fileNamed: "BuzzSparks"),
        SKEmitterNode(fileNamed: "BuzzSparks"),
        SKEmitterNode(fileNamed: "BuzzSparks"),
        SKEmitterNode(fileNamed: "BuzzSparks"),
        SKEmitterNode(fileNamed: "BuzzSparks"),
        SKEmitterNode(fileNamed: "BuzzSparks"),
        SKEmitterNode(fileNamed: "BuzzSparks"),
        SKEmitterNode(fileNamed: "BuzzSparks")]
    
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
        
        // Set up SpriteKit sparks
        sparksView.allowsTransparency = true
        scene.size = sparksView.bounds.size
        scene.backgroundColor = NSColor.clearColor()
        sparksView.presentScene(scene)
        for (index, node) in enumerate(sparks) {
            if index == 0 {
                node.position = CGPoint(x: 960, y: 990)
            }
            else {
                node.particlePositionRange = CGVectorMake(734, 120)
                node.position = CGPoint(x: 960, y: 80 + ((7-index) * 128))
            }
            node.particleColorSequence = nil
            scene.addChild(node)
        }
    }
    
    func reset() {
        for node in sparks {
            node.particleBirthRate = 0
        }
        
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
            let spark = sparks[buzzNumber]
            spark.particleColor = NSColor(calibratedHue: teamHue, saturation: 0.7, brightness: 1.0, alpha: 1.0)
            spark.particleBirthRate = (buzzNumber == 0) ? 20000 : 10000
            delay(0.1) {
                spark.particleBirthRate = 0
            }
            
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



// Some nice NSTimer extensions from https://gist.github.com/radex/41a1e75bb1290fb5d559

func delay(delay:Double, closure:()->()) {
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            Int64(delay * Double(NSEC_PER_SEC))
        ),
        dispatch_get_main_queue(), closure)
}

