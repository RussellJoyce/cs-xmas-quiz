//
//  BuzzerViewController.swift
//  Quiz Server
//
//  Created by Russell Joyce on 09/12/2014.
//  Copyright (c) 2014 Russell Joyce. All rights reserved.
//

import Cocoa

class BuzzerViewController: NSViewController {
    
    struct Buzz {
        let team: Int
        let time: Double
    }
    
    
    var buzzes = [Buzz?](count: 8, repeatedValue: nil)
    
    var quizLeds: QuizLeds?

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    
    func reset() {
        
    }
    
    func buzzerPressed(team: Int) {
        
    }
    
}

class BuzzerBackgroundView: NSView {
    let bgImage = NSImage(named: "2")
    override func drawRect(dirtyRect: NSRect) {
        bgImage?.drawInRect(dirtyRect)
    }
}