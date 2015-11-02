//
//  StartupView.swift
//  Quiz Server
//
//  Created by Russell Joyce on 17/11/2014.
//  Copyright (c) 2014 Russell Joyce & Ian Gray. All rights reserved.
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
            print("Found \(numScreens) screen(s):")
            
            if numScreens > 0 {
                screenSelector.removeAllItems()
                screenSelector.enabled = true

                for (index, screen) in screens.enumerate() {
                    print("  \(screen.frame)")
                    screenSelector.addItemWithTitle("Screen \(index) - \(screen.frame)")
                }
            }
        }
        else {
            print("Error enumerating screens");
        }
        
        
        allControllers = DDHidJoystick.allJoysticks() as? [DDHidJoystick]
        
        if let controllers = allControllers {
            print("Found \(controllers.count) game controller(s):")
            
            if controllers.count > 0 {
                controllerSelector.removeAllItems()
                
                for controller in controllers {
                    print("  \(controller.manufacturer()) - \(controller.productName())")
                    controllerSelector.addItemWithTitle(controller.productName())
                }
                
                controllerSelector.enabled = true
            }
        }
        
        
        let serialPortManager = ORSSerialPortManager.sharedSerialPortManager()
        allPorts = serialPortManager.availablePorts as? [ORSSerialPort]
        
        if let ports = allPorts {
            print("Found \(ports.count) serial port(s):")
            
            if ports.count > 0 {
                serialSelector.removeAllItems()
                
                for port in ports {
                    print("  \(port.name)")
                    serialSelector.addItemWithTitle(port.name)
                }
                
                serialSelector.enabled = true
            }
        }

        
        startButton.enabled = true
    }
    
    
    @IBAction func startQuiz(sender: AnyObject) {
        let screen = (allScreens?.count > 0) ? allScreens?[screenSelector.indexOfSelectedItem] : nil
        let controller = (allControllers?.count > 0) ? allControllers?[controllerSelector.indexOfSelectedItem] : nil
        let serial = (allPorts?.count > 0) ? allPorts?[serialSelector.indexOfSelectedItem] : nil
        let test = testMode.state == NSOnState;
        
        let delegate = NSApplication.sharedApplication().delegate as! AppDelegate
        delegate.startQuiz(screen, buzzers: controller, serial: serial, testMode: test)
    }
}
