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
let moveRandomAmount = 10


///The top-level view for creating a Pointless score display
//Creates and places an instance of PointlessStackViewController as a subview
class PointlessView: NSView {
	
	let imgView = PointlessBackgroundImage()
	let pvc = PointlessStackViewController(nibName: "PointlessStackView", bundle: nil)

	let counterSound = AVAudioPlayer(
		contentsOfURL: NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource("counter_soft_end", ofType: "wav")!),
		error: nil)
	let endStingSound = AVAudioPlayer(
		contentsOfURL: NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource("counter_score100", ofType: "wav")!),
		error: nil)
	let endPointlessSound = AVAudioPlayer(
		contentsOfURL: NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource("counter_sting", ofType: "wav")!),
		error: nil)
	let wrongSound = AVAudioPlayer(
		contentsOfURL: NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource("counter_wrong", ofType: "wav")!),
		error: nil)
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		self.addSubview(imgView)
		constrainToSizeOfContainer(imgView, self)
		
		//On top of the background image, add an instance of the stackview
		imgView.addSubview(pvc!.view)
		constrainToSizeOfContainer(pvc!.view, imgView)
		
		//Preload sound buffers
		counterSound.prepareToPlay()
		endStingSound.prepareToPlay()
		endPointlessSound.prepareToPlay()
		wrongSound.prepareToPlay()
	}
	
	func setScore(score: Int) {
		if score < 100 {
			counterSound.currentTime = 0
			counterSound.play()
			self.pvc!.resetBars()
			dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), {
				for i in 0...(99-score) {
					NSThread.sleepForTimeInterval(sleepTimeInterval)
					dispatch_async(dispatch_get_main_queue(), {
						self.pvc!.disappearBar(i, delay: 0)
						self.pvc!.mainLabel.stringValue = String(99-i)
					})
				}
				
				dispatch_async(dispatch_get_main_queue(), {
					self.counterSound.stop()
					
					if(score == 0) {
						self.endPointlessSound.currentTime = 0
						self.endPointlessSound.play()
					} else {
						self.endStingSound.currentTime = 0.3
						self.endStingSound.play()
					}
					
					self.imgView.pulse(score)
				})
			})
		}
	}
	
	func reset() {
		self.pvc!.resetBars()
		self.pvc!.mainLabel.stringValue = String(100)
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
		for i in 0...numBars-1 {
			let container = PointlessBarContainer()
			stack.addView(container, inGravity: NSStackViewGravity.Bottom)
			
			let bar = PointlessBar()
			container.addSubview(bar)
			
			//Set the container to the same width as the stack
			stack.addConstraint(NSLayoutConstraint(item: container, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal, toItem: stack, attribute: NSLayoutAttribute.Width, multiplier: 1, constant: 0))
			
			//Set container's height to be at least the size of the bar it contains
			container.addConstraint(NSLayoutConstraint(item: container, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.GreaterThanOrEqual, toItem: bar, attribute: NSLayoutAttribute.Height, multiplier: 1, constant: 0))
			
			//Centre align bar in container
			container.addConstraint(NSLayoutConstraint(item: bar, attribute: NSLayoutAttribute.CenterX, relatedBy: NSLayoutRelation.Equal, toItem: container, attribute: NSLayoutAttribute.CenterX, multiplier: 1, constant: 0))
			
			//Centre align container in stack
			stack.addConstraint(NSLayoutConstraint(item: container, attribute: NSLayoutAttribute.CenterX, relatedBy: NSLayoutRelation.Equal, toItem: stack, attribute: NSLayoutAttribute.CenterX, multiplier: 1, constant: 0))
			
			bars.append(bar)
			barContainers.append(container)
		}
	}
	
	
	func disappearBar(num: Int, delay : CFTimeInterval) {
		let blur = CABasicAnimation()
		blur.keyPath = "filters.motion.inputRadius"
		blur.fromValue = 0
		blur.toValue = 40
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
		
		barContainers[num].layer?.addAnimation(blur, forKey: "blur")
		barContainers[num].layer?.addAnimation(fade, forKey: "fade")
		barContainers[num].layer?.addAnimation(move, forKey: "move")
		
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
	
	override init() {
		super.init()
		self.wantsLayer = true
		//self.layer?.backgroundColor = NSColor(red: 0, green: 1, blue: 1, alpha: 1).CGColor
		self.translatesAutoresizingMaskIntoConstraints = false
		setMinSize(self, 300, 3)
	}
	
	override func drawRect(dirtyRect: NSRect) {
		bgImage?.drawInRect(dirtyRect)
	}
	
	override init(frame frameRect: NSRect) {super.init(frame: frameRect)}
	required init?(coder: NSCoder) {super.init(coder: coder)}
}

///Containers are needed because if we applied the filters to the PointlessBars themselves the 
///results could not render outside of the bounds of the bar
class PointlessBarContainer: NSView {
	override init() {
		super.init()
		self.translatesAutoresizingMaskIntoConstraints = false
		self.wantsLayer = true
		self.layerUsesCoreImageFilters = true
		self.alphaValue = CGFloat(barAlphaStart)
		
		let blurFilter = CIFilter(name: "CIMotionBlur")
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
	
	override init() {
		super.init()
		self.wantsLayer = true
		self.layerUsesCoreImageFilters = true
		self.layer?.backgroundColor = NSColor(red: 0, green: 0, blue: 0, alpha: 1).CGColor
		
		let pulse = CIFilter(name: "CIExposureAdjust")
		pulse.setDefaults()
		pulse.setValue(1, forKey: "inputEV")
		pulse.name = "pulse"
		self.layer?.filters = [pulse]
	}
	
	override func drawRect(dirtyRect: NSRect) {
		bgImage?.drawInRect(dirtyRect)
	}
	
	func pulse(score: Int) {
		let rampUpTime = 0.1
		var ev: Float
		var fadeTime: CFTimeInterval
		
		if(score > 50) { // 99 - 51
			ev = 3
			fadeTime = 2.0
		} else if(score > 20) { // 50 - 21
			ev = 4
			fadeTime = 3.0
		} else if(score > 0) { // 20 - 1
			ev = 5.5
			fadeTime = 3.0
		} else { // Pointless
			ev = 7
			fadeTime = 3.5
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
		
		self.layer?.addAnimation(pulseup, forKey: "pulseup")
		self.layer?.addAnimation(pulsedn, forKey: "pulsedn")
	}
	
	override init(frame frameRect: NSRect) {super.init(frame: frameRect)}
	required init?(coder: NSCoder) {super.init(coder: coder)}
}




// And now follows a pile of useful functions for placing constraints
// I assume that such things MUST exist somewhere in the libs right?
//----------------------------------------------------------------------------------------------------------------

/// Constrain the view target to be the size of container.
/// target must be a subview of container!
///:param: target The view to have constraints applied to it
///:param: container The view into which constraints are added. Must contain target as a subview
func constrainToSizeOfContainer(target: NSView, container: NSView) {
	target.frame = container.bounds
	target.translatesAutoresizingMaskIntoConstraints = false
	
	container.addConstraint(NSLayoutConstraint(
		item: target, attribute: NSLayoutAttribute.Top,
		relatedBy: NSLayoutRelation.Equal,
		toItem: container, attribute: NSLayoutAttribute.Top,
		multiplier: 1, constant: 0))
	
	container.addConstraint(NSLayoutConstraint(
		item: target, attribute: NSLayoutAttribute.Leading,
		relatedBy: NSLayoutRelation.Equal,
		toItem: container, attribute: NSLayoutAttribute.Leading,
		multiplier: 1, constant: 0))
	
	container.addConstraint(NSLayoutConstraint(
		item: target, attribute: NSLayoutAttribute.Bottom,
		relatedBy: NSLayoutRelation.Equal,
		toItem: container, attribute: NSLayoutAttribute.Bottom,
		multiplier: 1, constant: 0))
	
	container.addConstraint(NSLayoutConstraint(
		item: target, attribute: NSLayoutAttribute.Trailing,
		relatedBy: NSLayoutRelation.Equal,
		toItem: container, attribute: NSLayoutAttribute.Trailing,
		multiplier: 1, constant: 0))
}


func setMinSize(view: NSView, width: Int, height: Int) {
	view.translatesAutoresizingMaskIntoConstraints = false
	
	view.addConstraint(NSLayoutConstraint(item: view,
		attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.GreaterThanOrEqual,
		toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute,
		multiplier: 1, constant: CGFloat(width)))
	view.addConstraint(NSLayoutConstraint(item: view,
		attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.GreaterThanOrEqual,
		toItem: nil, attribute: NSLayoutAttribute.NotAnAttribute,
		multiplier: 1, constant: CGFloat(height)))
}










