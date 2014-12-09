//
//  TrueFalseViewController.swift
//  Quiz Server
//
//  Created by Ian Gray on 09/12/2014.
//  Copyright (c) 2014 Russell Joyce. All rights reserved.
//

import Cocoa

class TrueFalseViewController: NSViewController {


	@IBOutlet weak var topView: TFTopView!
	@IBOutlet weak var topLabel: NSTextField!
	@IBOutlet weak var team1: TrueFalseTeamView!
	@IBOutlet weak var team2: TrueFalseTeamView!
	@IBOutlet weak var team3: TrueFalseTeamView!
	@IBOutlet weak var team4: TrueFalseTeamView!
	@IBOutlet weak var team5: TrueFalseTeamView!
	@IBOutlet weak var team6: TrueFalseTeamView!
	@IBOutlet weak var team7: TrueFalseTeamView!
	@IBOutlet weak var team8: TrueFalseTeamView!
	@IBOutlet var mainView: TFMainView!
	
	let 🔒 = Int()
	var counting = false
	var pressed = [Int]()
	
	var teams = [TrueFalseTeamView]()
	
    override func viewDidLoad() {
        super.viewDidLoad()
		topView.topLabel = topLabel
		teams.extend([team1, team2, team3, team4, team5, team6, team7, team8])
		for i in 0..<teams.count {
			teams[i].setTeam(i)
		}
    }
	
	func reset() {
		
	}
	
	func start() {
		objc_sync_enter(🔒)
		counting = true
		pressed = [Int]()
		objc_sync_exit(🔒)
		
		dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), {
			for(var i = 5; i > 0; i--) {
				NSThread.sleepForTimeInterval(1.0)
				dispatch_async(dispatch_get_main_queue(), {
					self.topView.setVal(i)
					
					objc_sync_enter(self.🔒)
					self.counting = false
					objc_sync_exit(self.🔒)
				})
			}
		})
	}
	
	func answer(ans : Bool) {
		
	}
	
	func buzzerPressed(team: Int) {
		objc_sync_enter(🔒)
		if(counting) {
			//pressed.
		}
		objc_sync_exit(🔒)
	}
}

class TFMainView: NSView {
	let bgImage = NSImage(named: "3")
	override func drawRect(dirtyRect: NSRect) {
		bgImage?.drawInRect(dirtyRect)
	}
}


class TrueFalseTeamView : NSView {

	var teamno : Int = 0
	let label = NSTextField()
	let textCol = NSColor(red: 1, green: 1, blue: 1, alpha: 1)
	let bgCol = NSColor(red: 1, green: 1, blue: 1, alpha: 0.3).CGColor

	func setTeam(team : Int) {
		teamno = team
		
		label.editable = false
		label.drawsBackground = false
		label.bezeled = false
		label.font = NSFont(name: "DIN Alternate Bold", size: 45)
		label.stringValue = "Team " + String(teamno + 1)
		label.translatesAutoresizingMaskIntoConstraints = false
		label.textColor = textCol
		label.alignment = NSTextAlignment.CenterTextAlignment
		
		self.addSubview(label)
		
		label.addConstraint(NSLayoutConstraint(item: label,
			attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal,
			toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute,
			multiplier: 1, constant: CGFloat(280)))
		
		label.addConstraint(NSLayoutConstraint(item: label,
			attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.GreaterThanOrEqual,
			toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute,
			multiplier: 1, constant: CGFloat(60)))
		
		self.addConstraint(NSLayoutConstraint(item: label,
			attribute: NSLayoutAttribute.CenterY, relatedBy: NSLayoutRelation.Equal,
			toItem: self, attribute: NSLayoutAttribute.CenterY,
			multiplier: 1, constant: -5))
		
		self.addConstraint(NSLayoutConstraint(item: label,
			attribute: NSLayoutAttribute.CenterX, relatedBy: NSLayoutRelation.Equal,
			toItem: self, attribute: NSLayoutAttribute.CenterX,
			multiplier: 1, constant: 0))
		
	}
	
	required init?(coder: NSCoder) {super.init(coder: coder)}
	
	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		
		self.wantsLayer = true
		self.layerUsesCoreImageFilters = true
		self.layer!.backgroundColor = bgCol
		
		let blurFilter = CIFilter(name: "CIGaussianBlur")
		blurFilter.setDefaults()
		blurFilter.setValue(5, forKey: "inputRadius")
		blurFilter.name = "gauss"
		self.layer?.backgroundFilters = [blurFilter]
	}
}

class TFTopView : NSView {
	
	var topLabel : NSTextField!
	
	
	func setVal(val : Int) {
		topLabel.stringValue = String(val)
	}
	
	required init?(coder: NSCoder) {super.init(coder: coder)}
	
	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		
		self.wantsLayer = true
		self.layerUsesCoreImageFilters = true
		self.layer!.backgroundColor = NSColor(red: 1, green: 1, blue: 1, alpha: 0.3).CGColor
		
		let blurFilter = CIFilter(name: "CIGaussianBlur")
		blurFilter.setDefaults()
		blurFilter.setValue(5, forKey: "inputRadius")
		blurFilter.name = "gauss"
		self.layer?.backgroundFilters = [blurFilter]
	}
}

