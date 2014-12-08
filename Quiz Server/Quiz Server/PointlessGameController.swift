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
	
}




class PGLabelView : NSView {
	let teamno : Int
	let label = NSTextField()
	
	init(teamno : Int) {
		self.teamno = teamno
		super.init()
		self.translatesAutoresizingMaskIntoConstraints = false
		setMinSize(self, 300, 30)
		self.wantsLayer = true
		//self.layer!.backgroundColor = NSColor(red: 1, green: 0, blue: 0, alpha: 1).CGColor
		
		label.editable = false
		label.drawsBackground = false
		label.bezeled = false
		
		label.font = NSFont(name: "Oriya MN Bold", size: 48)
		
		label.stringValue = "Team " + String(teamno)
		label.translatesAutoresizingMaskIntoConstraints = false
		self.addSubview(label)
		constrainToSizeOfContainer(label, self)
	}
	
	required init?(coder: NSCoder) {
		self.teamno = 0
		super.init(coder: coder)
	}
	
	override init(frame frameRect: NSRect) {
		self.teamno = 0
		super.init(frame: frameRect)
	}
}


class PGMainView: NSView {
	let bgImage = NSImage(named: "purple-texture")
	override func drawRect(dirtyRect: NSRect) {
		bgImage?.drawInRect(dirtyRect)
		self.wantsUpdateLayer
	}
}

