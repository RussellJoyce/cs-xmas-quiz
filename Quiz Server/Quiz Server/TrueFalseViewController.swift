//
//  TrueFalseViewController.swift
//  Quiz Server
//
//  Created by Ian Gray on 09/12/2014.
//  Copyright (c) 2014 Russell Joyce. All rights reserved.
//

import Cocoa
import AVFoundation

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
	var teamEnabled = [true, true, true, true, true, true, true, true]
	
	var teams = [TrueFalseTeamView]()
	
	let 🔊 = AVAudioPlayer(
		contentsOfURL: NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource("timer", ofType: "wav")!),
		error: nil)
	let 🔊end = AVAudioPlayer(
		contentsOfURL: NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource("timerend", ofType: "wav")!),
		error: nil)
	
    override func viewDidLoad() {
        super.viewDidLoad()
		topView.topLabel = topLabel
		teams.extend([team1, team2, team3, team4, team5, team6, team7, team8])
		for i in 0..<teams.count {
			teams[i].setTeam(i)
		}
		🔊.prepareToPlay()
		🔊end.prepareToPlay()
    }
	
	func reset() {
		counting = false
		teamEnabled = [true, true, true, true, true, true, true, true]
		pressed = [Int]()
		for i in 0...7 {
			teams[i].setNeutral()
		}
	}
	
	func start() {
		objc_sync_enter(🔒)
		counting = true
		pressed = [Int]()
		objc_sync_exit(🔒)
		
		dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), {
			for(var i = 5; i >= 0; i--) {
				if(i != 5) {
					NSThread.sleepForTimeInterval(1.0)
				}
				dispatch_sync(dispatch_get_main_queue(), {
					self.topView.setVal(i)
					self.🔊.currentTime = 0
					self.🔊.play()
				})
			}
			
			dispatch_sync(dispatch_get_main_queue(), {
				objc_sync_enter(self.🔒)
				self.counting = false
				self.🔊end.currentTime = 0
				self.🔊end.play()
				objc_sync_exit(self.🔒)
				//Now set the team colours based on who pressed what
				for i in 0...7 {
					if(self.teamEnabled[i]) {
						if contains(self.pressed, i) {
							self.teams[i].setPressedTrue()
						} else {
							self.teams[i].setPressedFalse()
						}
					}
				}
			})
		})
	}
	
	func answer(ans : Bool) {
		for i in 0...7 {
			if(self.teamEnabled[i]) {
				if(contains(self.pressed, i) == ans) {
					self.teams[i].setNeutral()
				} else {
					teamEnabled[i] = false
					self.teams[i].setTeamOut()
				}
			}
		}
	}
	
	func buzzerPressed(team: Int) {
		objc_sync_enter(🔒)
		if(counting && teamEnabled[team]) {
			if !contains(pressed, team) {
				pressed.append(team)
			}
		}
		objc_sync_exit(🔒)
	}
}

class TFMainView: NSView {
	let bgImage = NSImage(named: "dark-purple-background")
	override func drawRect(dirtyRect: NSRect) {
		bgImage?.drawInRect(dirtyRect)
	}
}


class TrueFalseTeamView : NSView {

	var teamno : Int = 0
	let label = NSTextField()
	
	let textColStd = NSColor(red: 1, green: 1, blue: 1, alpha: 1)
	let bgColStd = NSColor(red: 1, green: 1, blue: 1, alpha: 0.3).CGColor
	let textColOut = NSColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1)
	let bgColOut = NSColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.3).CGColor
	
	let textColTrue = NSColor(red: 0.5, green: 1, blue: 0.5, alpha: 1)
	let bgColTrue = NSColor(red: 0.7, green: 1, blue: 0.7, alpha: 0.3).CGColor
	let textColFalse = NSColor(red: 1, green: 0.5, blue: 0.5, alpha: 1)
	let bgColFalse = NSColor(red: 1, green: 0.7, blue: 0.7, alpha: 0.3).CGColor
	
	func setTeam(team : Int) {
		teamno = team
		
		label.editable = false
		label.drawsBackground = false
		label.bezeled = false
		label.font = NSFont(name: "DIN Alternate Bold", size: 70)
		label.stringValue = "Team " + String(teamno + 1)
		label.translatesAutoresizingMaskIntoConstraints = false
		label.textColor = textColStd
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
	
	func setPressedTrue() {
		label.textColor = textColTrue
		self.layer!.backgroundColor = bgColTrue
	}
	
	func setPressedFalse() {
		label.textColor = textColFalse
		self.layer!.backgroundColor = bgColFalse
	}
	
	func setNeutral() {
		label.textColor = textColStd
		self.layer!.backgroundColor = bgColStd
		label.stringValue = "Team " + String(teamno + 1)
	}
	
	func setTeamOut() {
		label.textColor = textColOut
		self.layer!.backgroundColor = bgColOut
		label.stringValue = "Team " + String(teamno + 1) + " OUT"
	}
	
	required init?(coder: NSCoder) {super.init(coder: coder)}
	
	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		
		self.wantsLayer = true
		self.layerUsesCoreImageFilters = true
		self.layer!.backgroundColor = bgColStd
		
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
		
		let fade = CABasicAnimation()
		fade.keyPath = "opacity"
		fade.fromValue = 1
		fade.toValue = 0
		fade.duration = 1.3

		let unblur = CABasicAnimation()
		unblur.keyPath = "backgroundFilters.gauss.inputRadius"
		unblur.fromValue = 5
		unblur.toValue = 0
		unblur.duration = 1.3

		self.layer?.addAnimation(fade, forKey: "fade")
		self.layer?.addAnimation(unblur, forKey: "unblur")
	}
	
	required init?(coder: NSCoder) {super.init(coder: coder)}
	
	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		
		self.wantsLayer = true
		self.layerUsesCoreImageFilters = true
		self.layer!.backgroundColor = NSColor(red: 1, green: 1, blue: 1, alpha: 0.8).CGColor
		
		self.alphaValue = 0
		
		let gauss = CIFilter(name: "CIGaussianBlur")
		gauss.setDefaults()
		gauss.setValue(0, forKey: "inputRadius")
		gauss.name = "gauss"
		self.layer?.backgroundFilters = [gauss]
	}
}

