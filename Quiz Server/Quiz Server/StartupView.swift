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
    @IBOutlet weak var testMode: NSButton!
    
    var allScreens: [NSScreen]?
    var allControllers: [DDHidJoystick]?
    var allPorts: [ORSSerialPort]?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        allScreens = NSScreen.screens() as [NSScreen]?
        
        if let screens = allScreens {
            let numScreens = screens.count
            println("Found \(numScreens) screen(s):")
            
            if numScreens > 0 {
                screenSelector.removeAllItems()
                screenSelector.enabled = true

                for (index, screen) in enumerate(screens) {
                    println("  \(screen.frame)")
                    screenSelector.addItemWithTitle("Screen \(index) - \(screen.frame)")
                }
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

        
        startButton.enabled = (screenSelector.enabled && controllerSelector.enabled && serialSelector.enabled) || (testMode.state == NSOnState)
    }
    
    
    @IBAction func testModeChanged(sender: AnyObject) {
        startButton.enabled = (screenSelector.enabled && controllerSelector.enabled && serialSelector.enabled) || (testMode.state == NSOnState)
    }
    
    
    @IBAction func startQuiz(sender: AnyObject) {
        let screen = (allScreens?.count > 0) ? allScreens?[screenSelector.indexOfSelectedItem] : nil
        let controller = (allControllers?.count > 0) ? allControllers?[controllerSelector.indexOfSelectedItem] : nil
        let serial = (allPorts?.count > 0) ? allPorts?[serialSelector.indexOfSelectedItem] : nil
        let test = testMode.state == NSOnState;
        
        let delegate = NSApplication.sharedApplication().delegate as AppDelegate
        delegate.startQuiz(screen, controller: controller, serial: serial, testMode: test)
    }
}
