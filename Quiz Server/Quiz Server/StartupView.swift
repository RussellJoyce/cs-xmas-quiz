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
    @IBOutlet weak var testMode: NSButton!
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
    
    
    @IBAction func startQuiz(_ sender: AnyObject) {
		let screen = (allScreens != nil && (allScreens?.count)! > 0) ? allScreens?[screenSelector.indexOfSelectedItem] : nil
        let test = testMode.state == NSControl.StateValue.on;
		let numTeams = Int(numTeamsInput.intValue)
		
        let delegate = NSApplication.shared.delegate as! AppDelegate

		delegate.startQuiz(screen: screen, testMode: test, numberOfTeams: numTeams, geographyImagesPath: geographyImagesPath.stringValue, musicPath: musicPath.stringValue, uniquePath: uniquePath.stringValue, debugMode: debugMode.state == .on)
    }
	
	@IBAction func geographyPathBrowse(_ sender: Any) {
		let dialog = NSOpenPanel();
		dialog.title = "Geography round images folder"
		dialog.showsHiddenFiles = false
		dialog.canChooseDirectories = true
		dialog.canChooseFiles = false
		dialog.canCreateDirectories = false
		dialog.allowsMultipleSelection = false
		dialog.directoryURL = URL(fileURLWithPath: geographyImagesPath.stringValue, isDirectory: true)
		if (dialog.runModal() == NSApplication.ModalResponse.OK) {
			let result = dialog.url // Pathname of the file
			if (result != nil) {
				let path = result!.path
				geographyImagesPath.stringValue = path
			}
		}
	}
    
    @IBAction func musicPathBrowse(_ sender: Any) {
        let dialog = NSOpenPanel();
        dialog.title = "Music round music folder"
        dialog.showsHiddenFiles = false
        dialog.canChooseDirectories = true
        dialog.canChooseFiles = false
        dialog.canCreateDirectories = false
        dialog.allowsMultipleSelection = false
        dialog.directoryURL = URL(fileURLWithPath: musicPath.stringValue, isDirectory: true)
        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            let result = dialog.url
            if (result != nil) {
                let path = result!.path
                musicPath.stringValue = path
            }
        }
    }
	
	
	@IBAction func uniquePathBrowse(_ sender: NSButton) {
		let dialog = NSOpenPanel();
		dialog.title = "Folder of unique lists"
		dialog.showsHiddenFiles = false
		dialog.canChooseDirectories = true
		dialog.canChooseFiles = false
		dialog.canCreateDirectories = false
		dialog.allowsMultipleSelection = false
		dialog.directoryURL = URL(fileURLWithPath: uniquePath.stringValue, isDirectory: true)
		if (dialog.runModal() == NSApplication.ModalResponse.OK) {
			let result = dialog.url
			if (result != nil) {
				let path = result!.path
				uniquePath.stringValue = path
			}
		}
	}
	
}
