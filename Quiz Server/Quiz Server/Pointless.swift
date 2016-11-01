//
//  Pointless.swift
//  Test
//
//  Created by Ian Gray on 01/12/2014.
//  Copyright (c) 2014 Ian Gray. All rights reserved.
//

import Cocoa
import AVFoundation

let numBars = 100
let sleepTimeInterval = 0.002
let barAnimationTime = 1.5
let barAlphaStart = 1
let moveRandomAmount = 8


///The top-level view for creating a Pointless score display
//Creates and places an instance of PointlessStackViewController as a subview
class PointlessView: NSView {
    
    var leds: QuizLeds?
	
	let imgView = PointlessBackgroundImage()
	let pvc = PointlessStackViewController(nibName: "PointlessStackView", bundle: nil)
	
	let counterSound = try! AVAudioPlayer(
		contentsOf: URL(fileURLWithPath: Bundle.main.path(forResource: "counter_soft_end", ofType: "wav")!))
	let endStingSound = try! AVAudioPlayer(
		contentsOf: URL(fileURLWithPath: Bundle.main.path(forResource: "counter_score100", ofType: "wav")!))
	let endPointlessSound = try! AVAudioPlayer(
		contentsOf: URL(fileURLWithPath: Bundle.main.path(forResource: "counter_sting", ofType: "wav")!))
	let wrongSound = try! AVAudioPlayer(
		contentsOf: URL(fileURLWithPath: Bundle.main.path(forResource: "counter_wrong", ofType: "wav")!))
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		self.initialise()
	}
	
	init() {
		super.init(frame: NSRect())
		self.initialise()
	}
	
	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		self.initialise()
	}
	
	func initialise() {
		self.addSubview(imgView)
		constrainToSizeOfContainer(target: imgView, container: self)
		
		//On top of the background image, add an instance of the stackview
		imgView.addSubview(pvc!.view)
		constrainToSizeOfContainer(target: pvc!.view, container: imgView)
	}
	
	func setScore(score: Int, callback: (()->Void)! = nil) {
		if score <= 100 {
			leds?.stringPointlessReset()
			counterSound.currentTime = 0
			counterSound.play()
			self.pvc!.resetBars()
			DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async(execute: {
				if(score < 100) {
					for i in 0...(99-score) {
						Thread.sleep(forTimeInterval: sleepTimeInterval)
						DispatchQueue.main.async(execute: {
							self.pvc!.disappearBar(num: i, delay: 0)
							self.pvc!.mainLabel.stringValue = String(99-i)
							self.leds?.stringPointlessDec()
						})
					}
				}
				DispatchQueue.main.async(execute: {
					self.counterSound.stop()
					
					if(score == 0) {
						self.endPointlessSound.currentTime = 0
						self.endPointlessSound.play()
					} else {
						self.endStingSound.currentTime = 0.3
						self.endStingSound.play()
					}
					
					self.imgView.pulse(score: score)
					if(callback != nil) {
						callback()
					}
                    
                    self.leds?.stringPointlessCorrect()
				})
			})
		}
	}
	
	func wrong() {
		wrongSound.stop()
		wrongSound.currentTime = 0
		wrongSound.play()
		self.imgView.wrongpulse()
	}
	
	func reset() {
		self.pvc!.resetBars()
		self.pvc!.mainLabel.stringValue = String(100)
		
		//Preload sound buffers
		counterSound.prepareToPlay()
		endStingSound.prepareToPlay()
		endPointlessSound.prepareToPlay()
		wrongSound.prepareToPlay()
	}
}


///The PointlessStackViewController is primarily responsible for maintaining its 'bars' and the animations thereon
class PointlessStackViewController: NSViewController {
	
	@IBOutlet weak var stack: NSStackView!
	@IBOutlet weak var mainLabel: NSTextField!
	
	var bars = [PointlessBar]()
	var barContainers = [PointlessBarContainer]()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		//Add the bars
		for _ in 0..<numBars {
			let container = PointlessBarContainer()
			stack.addView(container, in: NSStackViewGravity.bottom)
			
			let bar = PointlessBar()
			container.addSubview(bar)
			
			//Set the container to the same width as the stack
			stack.addConstraint(NSLayoutConstraint(item: container, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal, toItem: stack, attribute: NSLayoutAttribute.width, multiplier: 1, constant: 0))
			
			//Set container's height to be at least the size of the bar it contains
			container.addConstraint(NSLayoutConstraint(item: container, attribute: NSLayoutAttribute.height, relatedBy: NSLayoutRelation.greaterThanOrEqual, toItem: bar, attribute: NSLayoutAttribute.height, multiplier: 1, constant: 0))
			
			//Centre align bar in container
			container.addConstraint(NSLayoutConstraint(item: bar, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: container, attribute: NSLayoutAttribute.centerX, multiplier: 1, constant: 0))
			
			//Centre align container in stack
			stack.addConstraint(NSLayoutConstraint(item: container, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal, toItem: stack, attribute: NSLayoutAttribute.centerX, multiplier: 1, constant: 0))
			
			bars.append(bar)
			barContainers.append(container)
		}
	}
	
	
	func disappearBar(num: Int, delay : CFTimeInterval) {
		let blur = CABasicAnimation()
		blur.keyPath = "filters.motion.inputRadius"
		blur.fromValue = 0
		blur.toValue = 80
		blur.duration = barAnimationTime
		blur.beginTime = CACurrentMediaTime() + delay
		
		let fade = CABasicAnimation()
		fade.keyPath = "opacity"
		fade.fromValue = 1
		fade.toValue = 0
		fade.duration = barAnimationTime
		fade.beginTime = CACurrentMediaTime() + delay
		fade.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseIn)
		
		let move = CABasicAnimation()
		move.keyPath = "position.y"
		move.fromValue = barContainers[num].frame.origin.y
		move.toValue = barContainers[num].frame.origin.y + CGFloat(10 + arc4random_uniform(UInt32(moveRandomAmount)))
		move.duration = barAnimationTime
		move.beginTime = CACurrentMediaTime() + delay
		move.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
		
		barContainers[num].layer?.add(blur, forKey: "blur")
		barContainers[num].layer?.add(fade, forKey: "fade")
		barContainers[num].layer?.add(move, forKey: "move")
		
		barContainers[num].alphaValue = 0
	}
	
	func resetBars() {
		for bc in barContainers {
			bc.alphaValue = CGFloat(barAlphaStart)
		}
	}
}


///The individual bars inside the Pointless stack, instantiated by PointlessStackViewController
class PointlessBar: NSImageView {
	let bgImage = NSImage(named: "bar3")
	
	init() {
		super.init(frame: NSRect())
		self.translatesAutoresizingMaskIntoConstraints = false
		setMinSize(view: self, width: 300, height: 6)
	}
	
	override func draw(_ dirtyRect: NSRect) {
		bgImage?.draw(in: dirtyRect)
	}
	
	override init(frame frameRect: NSRect) {super.init(frame: frameRect)}
	required init?(coder: NSCoder) {super.init(coder: coder)}
}

///Containers are needed because if we applied the filters to the PointlessBars themselves the
///results could not render outside of the bounds of the bar
class PointlessBarContainer: NSView {
	init() {
		super.init(frame: NSRect())
		self.translatesAutoresizingMaskIntoConstraints = false
		self.wantsLayer = true
		self.layerUsesCoreImageFilters = true
		self.alphaValue = CGFloat(barAlphaStart)
		
		let blurFilter = CIFilter(name: "CIMotionBlur")!
		blurFilter.setDefaults()
		blurFilter.setValue(0, forKey: "inputRadius")
		blurFilter.setValue(0, forKey: "inputAngle")
		blurFilter.name = "motion"
		self.layer?.filters = [blurFilter]
	}
	
	override init(frame frameRect: NSRect) {super.init(frame: frameRect)}
	required init?(coder: NSCoder) {super.init(coder: coder)}
}



class PointlessBackgroundImage: NSImageView {
	let bgImage = NSImage(named: "purple-texture")
	
	init() {
		super.init(frame: NSRect())
		self.wantsLayer = true
		self.layerUsesCoreImageFilters = true
		self.layer?.backgroundColor = NSColor(red: 0, green: 0, blue: 0, alpha: 1).cgColor
		
		let pulse = CIFilter(name: "CIExposureAdjust")!
		pulse.setDefaults()
		pulse.setValue(1, forKey: "inputEV")
		pulse.name = "pulse"
		
		let wp = CIFilter(name: "CIWhitePointAdjust")!
		wp.setDefaults()
		wp.setValue(CIColor(red: 1, green: 1, blue: 1), forKey: "inputColor")
		wp.name = "wp"
		
		self.layer?.filters = [pulse, wp]
	}
	
	override func draw(_ dirtyRect: NSRect) {
		bgImage?.draw(in: dirtyRect)
	}
	
	func pulse(score: Int) {
		let rampUpTime = 0.1
		var ev: Float
		var fadeTime: CFTimeInterval
		
		switch(score) {
		case 0:
			ev = 7
			fadeTime = 3.5
		case 1...20:
			ev = 5.5
			fadeTime = 3.0
		case 21...50:
			ev = 4
			fadeTime = 3.0
		default:
			ev = 3
			fadeTime = 2.0
		}
		
		let pulseup = CABasicAnimation()
		pulseup.keyPath = "filters.pulse.inputEV"
		pulseup.fromValue = 1
		pulseup.toValue = ev
		pulseup.duration = rampUpTime
		pulseup.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
		
		let pulsedn = CABasicAnimation()
		pulsedn.keyPath = "filters.pulse.inputEV"
		pulsedn.fromValue = ev
		pulsedn.toValue = 1
		pulsedn.duration = fadeTime
		pulsedn.beginTime = CACurrentMediaTime() + rampUpTime
		pulsedn.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
		
		self.layer?.add(pulseup, forKey: "pulseup")
		self.layer?.add(pulsedn, forKey: "pulsedn")
	}
	
	func wrongpulse() {
		let rampUpTime = 0.1
		let ev: Float = 0.2
		let fadeTime: CFTimeInterval = 2.5
		let col = CIColor(red: 1, green: 0, blue: 0)
		
		let pulseup = CABasicAnimation()
		pulseup.keyPath = "filters.pulse.inputEV"
		pulseup.fromValue = 1
		pulseup.toValue = ev
		pulseup.duration = rampUpTime
		pulseup.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
		
		let pulsedn = CABasicAnimation()
		pulsedn.keyPath = "filters.pulse.inputEV"
		pulsedn.fromValue = ev
		pulsedn.toValue = 1
		pulsedn.duration = fadeTime
		pulsedn.beginTime = CACurrentMediaTime() + rampUpTime
		pulsedn.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
		
		
		let wpup = CABasicAnimation()
		wpup.keyPath = "filters.wp.inputColor"
		wpup.fromValue = CIColor(red: 1, green: 1, blue: 1)
		wpup.toValue = col
		wpup.duration = rampUpTime * 2
		wpup.beginTime = CACurrentMediaTime()
		wpup.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
		
		let wpdn = CABasicAnimation()
		wpdn.keyPath = "filters.wp.inputColor"
		wpdn.fromValue = col
		wpdn.toValue = CIColor(red: 1, green: 1, blue: 1)
		wpdn.duration = fadeTime
		wpdn.beginTime = CACurrentMediaTime() + rampUpTime * 2
		wpdn.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
		
		self.layer?.add(pulseup, forKey: "pulseup")
		self.layer?.add(pulsedn, forKey: "pulsedn")
		self.layer?.add(wpup, forKey: "wpup")
		self.layer?.add(wpdn, forKey: "wpdn")
	}
	
	override init(frame frameRect: NSRect) {super.init(frame: frameRect)}
	required init?(coder: NSCoder) {super.init(coder: coder)}
}




// And now follows a pile of useful functions for placing constraints
// I assume that such things MUST exist somewhere in the libs right?
//----------------------------------------------------------------------------------------------------------------

/// Constrain the view target to be the size of container.
/// target must be a subview of container!
///- parameter target: The view to have constraints applied to it
///- parameter container: The view into which constraints are added. Must contain target as a subview
func constrainToSizeOfContainer(target: NSView, container: NSView) {
	target.frame = container.bounds
	target.translatesAutoresizingMaskIntoConstraints = false
	
	container.addConstraint(NSLayoutConstraint(
		item: target, attribute: NSLayoutAttribute.top,
		relatedBy: NSLayoutRelation.equal,
		toItem: container, attribute: NSLayoutAttribute.top,
		multiplier: 1, constant: 0))
	
	container.addConstraint(NSLayoutConstraint(
		item: target, attribute: NSLayoutAttribute.leading,
		relatedBy: NSLayoutRelation.equal,
		toItem: container, attribute: NSLayoutAttribute.leading,
		multiplier: 1, constant: 0))
	
	container.addConstraint(NSLayoutConstraint(
		item: target, attribute: NSLayoutAttribute.bottom,
		relatedBy: NSLayoutRelation.equal,
		toItem: container, attribute: NSLayoutAttribute.bottom,
		multiplier: 1, constant: 0))
	
	container.addConstraint(NSLayoutConstraint(
		item: target, attribute: NSLayoutAttribute.trailing,
		relatedBy: NSLayoutRelation.equal,
		toItem: container, attribute: NSLayoutAttribute.trailing,
		multiplier: 1, constant: 0))
}


func setMinSize(view: NSView, width: Int, height: Int) {
	view.translatesAutoresizingMaskIntoConstraints = false
	
	view.addConstraint(NSLayoutConstraint(item: view,
		attribute: .width, relatedBy: .greaterThanOrEqual,
		toItem: nil, attribute: .notAnAttribute,
		multiplier: 1, constant: CGFloat(width)))
	view.addConstraint(NSLayoutConstraint(item: view,
		attribute: .height, relatedBy: .greaterThanOrEqual,
		toItem: nil, attribute: .notAnAttribute,
		multiplier: 1, constant: CGFloat(height)))
}


func setMaxSize(view: NSView, width: Int, height: Int) {
	view.translatesAutoresizingMaskIntoConstraints = false
	
	view.addConstraint(NSLayoutConstraint(item: view,
		attribute: .width, relatedBy: .lessThanOrEqual,
		toItem: nil, attribute: .notAnAttribute,
		multiplier: 1, constant: CGFloat(width)))
	view.addConstraint(NSLayoutConstraint(item: view,
		attribute: .height, relatedBy: .lessThanOrEqual,
		toItem: nil, attribute: .notAnAttribute,
		multiplier: 1, constant: CGFloat(height)))
}
