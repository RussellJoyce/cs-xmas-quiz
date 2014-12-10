//
//  IdleViewController.swift
//  Quiz Server
//
//  Created by Russell Joyce on 09/12/2014.
//  Copyright (c) 2014 Russell Joyce. All rights reserved.
//

import Cocoa

class IdleViewController: NSViewController {

    var leds: QuizLeds?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    
    func reset() {
        leds?.stringAnimation(2)
    }
    
}
