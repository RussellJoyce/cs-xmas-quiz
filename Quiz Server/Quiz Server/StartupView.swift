//
//  StartupView.swift
//  Quiz Server
//
//  Created by Russell Joyce on 17/11/2014.
//  Copyright (c) 2014 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa

class StartupView: NSViewController {
    
    @IBOutlet weak var screenSelector: NSPopUpButton!
    @IBOutlet weak var startButton: NSButton!
    @IBOutlet weak var windowedMode: NSButton!
	@IBOutlet weak var geographyImagesPath: NSTextField!
    @IBOutlet weak var musicPath: NSTextField!
	@IBOutlet weak var uniquePath: NSTextField!
	@IBOutlet weak var numTeamsInput: NSTextField!
	@IBOutlet weak var debugMode: NSButton!
	
	var allScreens: [NSScreen]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        allScreens = NSScreen.screens as [NSScreen]?
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

		geographyImagesPath.stringValue = "\(NSHomeDirectory())/Documents/cs-xmas-quiz/nodeserver/static/geography"
        musicPath.stringValue = "\(NSHomeDirectory())/Documents/cs-xmas-quiz/Music"
		uniquePath.stringValue = "\(NSHomeDirectory())/Documents/cs-xmas-quiz/Unique"
		
        startButton.isEnabled = true
    }
	
	override func viewDidAppear() {
		//If we are not holding cmd, then just start the quiz immediately
		super.viewDidAppear()
		if !NSEvent.modifierFlags.contains(.command) {
			startQuiz(self)
		}
	}
    
    @IBAction func startQuiz(_ sender: AnyObject) {
		let screen = (allScreens != nil && (allScreens?.count)! > 0) ? allScreens?[screenSelector.indexOfSelectedItem] : nil
        let windowed = windowedMode.state == NSControl.StateValue.on;
        let delegate = NSApplication.shared.delegate as! AppDelegate

		Settings.shared.geographyImagesPath = geographyImagesPath.stringValue
		Settings.shared.musicPath = musicPath.stringValue
		Settings.shared.uniquePath = uniquePath.stringValue
		Settings.shared.numTeams = Int(numTeamsInput.intValue)
		Settings.shared.debug = debugMode.state == NSControl.StateValue.on
		
		delegate.startQuiz(screen: screen, windowedMode: windowed)
    }

	@IBAction func geographyPathBrowse(_ sender: Any) {
		createDialog(title: "Geography round images folder", textField: geographyImagesPath)
	}
    
    @IBAction func musicPathBrowse(_ sender: Any) {
		createDialog(title: "Music round music folder", textField: musicPath)
    }
	
	@IBAction func uniquePathBrowse(_ sender: NSButton) {
		createDialog(title: "Folder of unique lists", textField: uniquePath)
	}
	
	func createDialog(title : String, textField : NSTextField) {
		let dialog = NSOpenPanel();
		dialog.title = title
		dialog.showsHiddenFiles = false
		dialog.canChooseDirectories = true
		dialog.canChooseFiles = false
		dialog.canCreateDirectories = false
		dialog.allowsMultipleSelection = false
		dialog.directoryURL = URL(fileURLWithPath: textField.stringValue, isDirectory: true)
		
		if (dialog.runModal() == NSApplication.ModalResponse.OK) {
			let result = dialog.url
			if (result != nil) {
				textField.stringValue = result!.path
			}
		}
	}
	
}

