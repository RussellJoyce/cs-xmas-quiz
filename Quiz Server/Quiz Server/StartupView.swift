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
		allScreens!.sort(by: {$0.frame.width > $1.frame.width})
		
        if let screens = allScreens {
            let numScreens = screens.count
            print("Found \(numScreens) screen(s):")
            
            if numScreens > 0 {
                screenSelector.removeAllItems()
                screenSelector.isEnabled = true

                for (index, screen) in screens.enumerated() {
                    print("  \(screen.frame)")
                    screenSelector.addItem(withTitle: "Screen \(index) - \(Int(screen.frame.width))x\(Int(screen.frame.height)) \(screen.frame.origin)")
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
                    controllerSelector.addItem(withTitle: controller.productName())
                }
                
                controllerSelector.isEnabled = true
            }
        }
        
        
        let serialPortManager = ORSSerialPortManager.shared()
        allPorts = serialPortManager.availablePorts as [ORSSerialPort]
        
        if let ports = allPorts {
            print("Found \(ports.count) serial port(s):")
            
            if ports.count > 0 {
                serialSelector.removeAllItems()
                
                for port in ports {
                    print("  \(port.name)")
                    serialSelector.addItem(withTitle: port.name)
                }
                
                serialSelector.isEnabled = true
            }
        }

        
        startButton.isEnabled = true
    }
    
    
    @IBAction func startQuiz(_ sender: AnyObject) {
		let screen = (allScreens != nil && (allScreens?.count)! > 0) ? allScreens?[screenSelector.indexOfSelectedItem] : nil
        let controller = (allControllers != nil && (allControllers?.count)! > 0) ? allControllers?[controllerSelector.indexOfSelectedItem] : nil
        let serial = (allPorts != nil && (allPorts?.count)! > 0) ? allPorts?[serialSelector.indexOfSelectedItem] : nil
        let test = testMode.state == NSOnState;
		
        let delegate = NSApplication.shared().delegate as! AppDelegate
        delegate.startQuiz(screen: screen, buzzers: controller, serial: serial, testMode: test)
    }
}
