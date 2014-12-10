//
//  PointlessGameController.swift
//  Quiz Server
//
//  Created by Ian Gray on 08/12/2014.
//  Copyright (c) 2014 Russell Joyce. All rights reserved.
//

import Cocoa

class PointlessGameController: NSViewController {

	@IBOutlet weak var labelstack: NSStackView!
	@IBOutlet weak var pv: PointlessView!
	
	var labels = [PGLabelView]()
	var lastTeam = 10
	var canShow💩 = false
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		for i in 1...8 {
			let v = PGLabelView(teamno: i)
			labels.append(v)
			labelstack.addView(v, inGravity: NSStackViewGravity.Center)
		}
		
		pv.layer!.borderWidth = 4
		pv.layer!.borderColor = NSColor(red: 0, green: 0, blue: 0, alpha: 1).CGColor
    }
	
	
	func setCurrentTeam(team: Int) {
		labels[team].setActive()
		if(lastTeam < labels.count && lastTeam != team)	{
			labels[lastTeam].setInactive()
		}
		lastTeam = team
		pv.reset()
	}
	
	func setScore(score: Int) {
		pv.setScore(score, {
			if(self.lastTeam < self.labels.count)	{
				self.labels[self.lastTeam].setText(String(score))
			}
		})
	}
	
	func wrong() {
		pv.wrong()
		if(lastTeam < labels.count)	{
			switch(arc4random_uniform(6)) {
			case 0: labels[lastTeam].setText("❌")
			case 1: labels[lastTeam].setText("❌")
			case 2:
				if canShow💩 { //Lol
					labels[lastTeam].setText("💩")
				} else {
					labels[lastTeam].setText("❌")
				}
			case 3: labels[lastTeam].setText("😩")
			case 4: labels[lastTeam].setText("😟")
			case 5: labels[lastTeam].setText("👎")
			default: labels[lastTeam].setText("❌")
			}
			canShow💩 = true
		}
	}
	
	func resetTeam() {
		pv.reset()
		if(lastTeam < labels.count)	{
			labels[lastTeam].setText("")
		}
	}
	
	func reset() {
		pv.reset()
		for i in 0...7 {
			labels[i].setText("")
		}
		if(lastTeam < labels.count) {
			labels[lastTeam].setInactive()
		}
	}
	
	
}

class PGLabelView : NSView {
	let teamno : Int
	let label = NSTextField()
	
	let bgCol = NSColor(red: 1, green: 1, blue: 1, alpha: 0.3).CGColor
	let bgColHighlight = NSColor(red: 1, green: 1, blue: 1, alpha: 0.9).CGColor
	
	let textCol = NSColor(red: 1, green: 1, blue: 1, alpha: 1)
	let textColHighlight = NSColor(red: 0, green: 0, blue: 0, alpha: 1)
	
	init(teamno : Int) {
		self.teamno = teamno
		super.init()
		self.teamno = teamno //This is required. teamno gets reset to 100 by the required constructors below and don't have time to fix it properly. 😩
		self.translatesAutoresizingMaskIntoConstraints = false
		self.wantsLayer = true
		self.layerUsesCoreImageFilters = true
		self.layer!.backgroundColor = bgCol
		
		label.editable = false
		label.drawsBackground = false
		label.bezeled = false
		label.font = NSFont(name: "DIN Alternate Bold", size: 52)
		label.stringValue = "Team " + String(teamno) + ":"
		label.translatesAutoresizingMaskIntoConstraints = false
		label.textColor = textCol
		label.alphaValue = 0.7

		self.addSubview(label)

		
		self.addConstraint(NSLayoutConstraint(item: self,
			attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal,
			toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute,
			multiplier: 1, constant: CGFloat(600)))
		
		self.addConstraint(NSLayoutConstraint(item: self,
			attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.Equal,
			toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute,
			multiplier: 1, constant: CGFloat(80)))
		
		
		self.addConstraint(NSLayoutConstraint(item: label,
			attribute: NSLayoutAttribute.CenterY, relatedBy: NSLayoutRelation.Equal,
			toItem: self, attribute: NSLayoutAttribute.CenterY,
			multiplier: 1, constant: -5))
		
		self.addConstraint(NSLayoutConstraint(item: label,
			attribute: NSLayoutAttribute.Leading, relatedBy: NSLayoutRelation.Equal,
			toItem: self, attribute: NSLayoutAttribute.Leading,
			multiplier: 1, constant: 50))
		
		
		label.addConstraint(NSLayoutConstraint(item: label,
			attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal,
			toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute,
			multiplier: 1, constant: CGFloat(280)))
		
		label.addConstraint(NSLayoutConstraint(item: label,
			attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.GreaterThanOrEqual,
			toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute,
			multiplier: 1, constant: CGFloat(60)))

	}
	
	func setActive() {
		label.textColor = textColHighlight
		let sweep = CABasicAnimation()
		sweep.keyPath = "backgroundColor"
		sweep.fromValue = bgCol
		sweep.toValue = bgColHighlight
		sweep.duration = 0.5
		self.layer?.addAnimation(sweep, forKey: "sweep")
		self.layer!.backgroundColor = bgColHighlight
	}
	
	func setInactive() {
		label.textColor = textCol
		let sweep = CABasicAnimation()
		sweep.keyPath = "backgroundColor"
		sweep.fromValue = bgColHighlight
		sweep.toValue = bgCol
		sweep.duration = 0.5
		self.layer?.addAnimation(sweep, forKey: "sweep")
		self.layer!.backgroundColor = bgCol
	}
	
	func setText(text : String) {
		label.stringValue = "Team " + String(teamno) + ": " + text
	}
	
	required init?(coder: NSCoder) {
		self.teamno = 100
		super.init(coder: coder)
	}
	
	override init(frame frameRect: NSRect) {
		self.teamno = 100
		super.init(frame: frameRect)
	}
}


class PGMainView: NSView {
	let bgImage = NSImage(named: "purple-texture")
	override func drawRect(dirtyRect: NSRect) {
		bgImage?.drawInRect(dirtyRect)
	}
}

