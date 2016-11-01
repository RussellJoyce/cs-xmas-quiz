//
//  TrueFalseViewController.swift
//  Quiz Server
//
//  Created by Ian Gray on 09/12/2014.
//  Copyright (c) 2014 Russell Joyce & Ian Gray. All rights reserved.
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
	@IBOutlet weak var team9: TrueFalseTeamView!
	@IBOutlet weak var team10: TrueFalseTeamView!
	
	let 🔒 = Int()
	var counting = false
	var counted = false
	var pressed = [Int]()
	var teamEnabled = [Bool](repeating: true, count: 10)
	var leds: QuizLeds?
	
	var teams = [TrueFalseTeamView]()
	
	let 🔊 = try! AVAudioPlayer(
		contentsOf: URL(fileURLWithPath: Bundle.main.path(forResource: "timer", ofType: "wav")!))
	let 🔊end = try! AVAudioPlayer(
		contentsOf: URL(fileURLWithPath: Bundle.main.path(forResource: "timerend", ofType: "wav")!))
	
    override func viewDidLoad() {
        super.viewDidLoad()
		topView.topLabel = topLabel
		teams.append(contentsOf: [team1, team2, team3, team4, team5, team6, team7, team8, team9, team10])
		for i in 0..<teams.count {
			teams[i].setTeam(team: i)
		}
    }
	
	func reset() {
		objc_sync_enter(🔒)
		counting = false
		pressed = [Int]()
		objc_sync_exit(🔒)
		teamEnabled = [Bool](repeating: true, count: 10)
		for team in teams {
			team.setNeutral()
		}
		leds?.buzzersOff()
		counted = false
		
		🔊.prepareToPlay()
		🔊end.prepareToPlay()
	}
	
	func start() {
		if (counting) {
			return
		}
		
		for i in 0..<teams.count {
			if(teamEnabled[i]) {
				leds?.buzzerOn(team: i)
			}
		}
		
		objc_sync_enter(🔒)
		counting = true
		pressed = [Int]()
		leds?.stringPointlessReset()
		objc_sync_exit(🔒)
		
		DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async(execute: {
			for i in (0...5).reversed() {
				if(i != 5) {
					Thread.sleep(forTimeInterval: 1.0)
					for _ in 0...19 {
						self.leds?.stringPointlessDec()
					}
					if (!self.counting) {
						return
					}
				}
				DispatchQueue.main.sync(execute: {
					self.topView.setVal(val: i)
					self.🔊.currentTime = 0
					self.🔊.play()
				})
			}
			
			DispatchQueue.main.sync(execute: {
				objc_sync_enter(self.🔒)
				self.counting = false
				self.🔊end.currentTime = 0
				self.🔊end.play()
				objc_sync_exit(self.🔒)
				
				self.leds?.buzzersOff()
				
				//Now set the team colours based on who pressed what
				for (i, team) in self.teams.enumerated() {
					if(self.teamEnabled[i]) {
						if self.pressed.contains(i) {
							team.setPressedTrue()
						} else {
							team.setPressedFalse()
						}
					}
				}
				self.counted = true
			})
		})
	}
	
	func answer(ans : Bool) {
		if (!counted) {
			return
		}
		
		if(ans) {
			leds?.stringFixedColour(colour: 1);
		} else {
			leds?.stringFixedColour(colour: 0);
		}
		
		for (i, team) in teams.enumerated() {
			if(self.teamEnabled[i]) {
				if(self.pressed.contains(i) == ans) {
					team.setNeutral()
				} else {
					teamEnabled[i] = false
					team.setTeamOut()
				}
			}
		}
		
		counted = false
	}
	
	func buzzerPressed(team: Int) {
		objc_sync_enter(🔒)
		if(counting && teamEnabled[team]) {
			if !pressed.contains(team) {
				pressed.append(team)
			}
		}
		objc_sync_exit(🔒)
	}
}

class TFMainView: NSView {
	let bgImage = NSImage(named: "dark-purple-background-blurred")
	override func draw(_ dirtyRect: NSRect) {
		bgImage?.draw(in: dirtyRect)
	}
}


class TrueFalseTeamView : NSView {

	var teamno : Int = 0
	let label = NSTextField()
	var leds: QuizLeds?
	
	let textColStd = NSColor(red: 1, green: 1, blue: 1, alpha: 1)
	let bgColStd = NSColor(red: 1, green: 1, blue: 1, alpha: 0.3).cgColor
	let textColOut = NSColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1)
	let bgColOut = NSColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.3).cgColor
	
	let textColTrue = NSColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 1)
	let bgColTrue = NSColor(red: 0.5, green: 1, blue: 0.5, alpha: 0.3).cgColor
	let textColFalse = NSColor(red: 0.7, green: 0.3, blue: 0.3, alpha: 1)
	let bgColFalse = NSColor(red: 1, green: 0.5, blue: 0.5, alpha: 0.3).cgColor
	
	func setTeam(team : Int) {
		teamno = team
		
		label.isEditable = false
		label.drawsBackground = false
		label.isBezeled = false
		label.font = NSFont(name: "DIN Alternate Bold", size: 70)
		label.stringValue = "Team " + String(teamno + 1)
		label.translatesAutoresizingMaskIntoConstraints = false
		label.textColor = textColStd
		label.alignment = NSTextAlignment.center
		
		self.addSubview(label)
		
		label.addConstraint(NSLayoutConstraint(item: label,
			attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.greaterThanOrEqual,
			toItem: nil, attribute: NSLayoutAttribute.notAnAttribute,
			multiplier: 1, constant: CGFloat(280)))
		
		label.addConstraint(NSLayoutConstraint(item: label,
			attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.greaterThanOrEqual,
			toItem: nil, attribute: NSLayoutAttribute.notAnAttribute,
			multiplier: 1, constant: CGFloat(60)))
		
		self.addConstraint(NSLayoutConstraint(item: label,
			attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal,
			toItem: self, attribute: NSLayoutAttribute.centerY,
			multiplier: 1, constant: -5))
		
		self.addConstraint(NSLayoutConstraint(item: label,
			attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal,
			toItem: self, attribute: NSLayoutAttribute.centerX,
			multiplier: 1, constant: 0))
		
	}
	
	func setPressedTrue() {
		label.textColor = textColTrue
		self.layer?.backgroundColor = bgColTrue
		label.stringValue = "Team \(teamno + 1): ✅"
	}
	
	func setPressedFalse() {
		label.textColor = textColFalse
		self.layer?.backgroundColor = bgColFalse
		label.stringValue = "Team \(teamno + 1): ❌"
	}
	
	func setNeutral() {
		label.textColor = textColStd
		self.layer?.backgroundColor = bgColStd
		label.stringValue = "Team \(teamno + 1)"
	}
	
	func setTeamOut() {
		label.textColor = textColOut
		self.layer?.backgroundColor = bgColOut
		label.stringValue = "Team \(teamno + 1) OUT"
	}
	
	required init?(coder: NSCoder) {super.init(coder: coder)}
	
	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		
		self.wantsLayer = true
		self.layerUsesCoreImageFilters = true
		self.layer?.backgroundColor = bgColStd
		
		let blurFilter = CIFilter(name: "CIGaussianBlur")!
		blurFilter.setDefaults()
		blurFilter.setValue(5, forKey: "inputRadius")
		blurFilter.name = "gauss"
		self.layer?.backgroundFilters = [blurFilter]
	}
}





class TFTopView : NSView {
	
	var topLabel : NSTextField?
	
	func setVal(val : Int) {
		topLabel?.stringValue = String(val)
		
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

		self.layer?.add(fade, forKey: "fade")
		self.layer?.add(unblur, forKey: "unblur")
	}
	
	required init?(coder: NSCoder) {super.init(coder: coder)}
	
	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		
		self.wantsLayer = true
		self.layerUsesCoreImageFilters = true
		self.layer?.backgroundColor = NSColor(red: 1, green: 1, blue: 1, alpha: 0.8).cgColor
		
		self.alphaValue = 0
		
		let gauss = CIFilter(name: "CIGaussianBlur")!
		gauss.setDefaults()
		gauss.setValue(0, forKey: "inputRadius")
		gauss.name = "gauss"
		self.layer?.backgroundFilters = [gauss]
	}
}

