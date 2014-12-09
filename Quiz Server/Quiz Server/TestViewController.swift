//
//  TestView.swift
//  Quiz Server
//
//  Created by Russell Joyce on 08/12/2014.
//  Copyright (c) 2014 Russell Joyce. All rights reserved.
//

import Cocoa
import AVFoundation

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
    
    let 👽 = AVAudioPlayer(contentsOfURL: NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource("eight", ofType: "wav")!), error: nil) // EXTRATERRESTRIAL ALIEN
    
    override func viewDidLoad() {
        super.viewDidLoad()
        numbers.extend([team1, team2, team3, team4, team5, team6, team7, team8])
        
        👽.prepareToPlay()
        
        reset()
    }
    
    func reset() {
        for team in numbers {
            team.textColor = NSColor.whiteColor()
        }
    }
    
    func buzzerPressed(team: Int) {
        numbers[team].textColor = NSColor.redColor()
        
        if (team == 7) {
            👽.currentTime = 0
            👽.play()
        }
    }
    
    func buzzerReleased(team: Int) {
        numbers[team].textColor = NSColor.whiteColor()
    }
    
}
