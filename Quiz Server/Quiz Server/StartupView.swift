//
//  StartupView.swift
//  Quiz Server
//
//  Created by Russell Joyce on 17/11/2014.
//  Copyright (c) 2014 Russell Joyce. All rights reserved.
//

import Cocoa
import DDHidLib

class StartupView: NSViewController {
    
    @IBOutlet weak var screenSelector: NSPopUpButton!
    @IBOutlet weak var controllerSelector: NSPopUpButton!
    @IBOutlet weak var serialSelector: NSPopUpButton!
    @IBOutlet weak var startButton: NSButton!
    
    var tempViews = [(NSScreen, NSView)]()
    var allControllers: [DDHidJoystick]?
    var allPorts: [ORSSerialPort]?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let allScreens = NSScreen.screens() as [NSScreen]?
        
        if let screens = allScreens {
            let numScreens = screens.count
            println("Found \(numScreens) screen(s):")

            for (index, screen) in enumerate(screens) {
                println("  \(screen.frame)")
                if index > 0 {
                    let screenRect = screen.frame
                    let view = ColorView(frame: screenRect, color: NSColor.redColor())
                    let label = NSTextField(frame: CGRectMake(20, 20, screenRect.width - 40, screenRect.height - 40))
                    label.editable = false
                    label.stringValue = "Screen \(index)"
                    view.subviews.append(label)
                    let fullScreenOptions = [NSFullScreenModeAllScreens: 0]
                    view.enterFullScreenMode(screen, withOptions: fullScreenOptions)
                    tempViews.append((screen, view))
                }
            }
            
            if numScreens > 1 {
                screenSelector.removeAllItems()
                for i in 1...numScreens-1 {
                    screenSelector.addItemWithTitle("Screen \(i)")
                }
                
                screenSelector.enabled = true
            }
        }
        else {
            println("Error enumerating screens");
        }
        
        
        allControllers = DDHidJoystick.allJoysticks() as? [DDHidJoystick]
        
        if let controllers = allControllers {
            println("Found \(controllers.count) game controller(s):")
            
            if controllers.count > 0 {
                controllerSelector.removeAllItems()
                
                for controller in controllers {
                    println("  \(controller.manufacturer()) - \(controller.productName())")
                    controllerSelector.addItemWithTitle(controller.productName())
                }
                
                controllerSelector.enabled = true
            }
        }
        
        
        let serialPortManager = ORSSerialPortManager.sharedSerialPortManager()
        allPorts = serialPortManager.availablePorts as? [ORSSerialPort]
        
        if let ports = allPorts {
            println("Found \(ports.count) serial port(s):")
            
            if ports.count > 0 {
                serialSelector.removeAllItems()
                
                for port in ports {
                    println("  \(port.name)")
                    serialSelector.addItemWithTitle(port.name)
                }
                
                serialSelector.enabled = true
            }
        }
        
        
        startButton.enabled = screenSelector.enabled && controllerSelector.enabled // || true
    }
    
    
    @IBAction func startQuiz(sender: AnyObject) {
        for (screen, view) in tempViews {
            let fullScreenOptions = [NSFullScreenModeAllScreens: 0]
            view.exitFullScreenModeWithOptions(fullScreenOptions)
        }

        let screen = tempViews[screenSelector.indexOfSelectedItem].0
        
        tempViews = []
        
        let delegate = NSApplication.sharedApplication().delegate as AppDelegate
        delegate.startQuiz(screen, controller: allControllers![controllerSelector.indexOfSelectedItem], serial: allPorts![serialSelector.indexOfSelectedItem])
    }
}
