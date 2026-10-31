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
	@IBOutlet weak var quizRootPath: NSTextField!
	@IBOutlet weak var numTeamsInput: NSTextField!
	@IBOutlet weak var debugMode: NSButton!
	
	var allScreens: [NSScreen]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        allScreens = NSScreen.screens as [NSScreen]?
		allScreens?.sort(by: {$0.frame.width > $1.frame.width})
		
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

		quizRootPath.stringValue = "\(NSHomeDirectory())/Documents/cs-xmas-quiz"
		
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
		Settings.shared.quizRoot = quizRootPath.stringValue
		var isDir: ObjCBool = false
		if !FileManager.default.fileExists(atPath: Settings.shared.questionsPath, isDirectory: &isDir) || !isDir.boolValue {
			print("No Questions folder in quiz repository '\(Settings.shared.quizRoot)', so the question rounds will be empty")
		}
		let requestedTeams = Int(numTeamsInput.intValue)
		Settings.shared.numTeams = max(1, min(Settings.maxTeams, requestedTeams))
		if requestedTeams != Settings.shared.numTeams {
			print("Number of teams \(requestedTeams) is out of range, using \(Settings.shared.numTeams)")
		}
		Settings.shared.debug = debugMode.state == NSControl.StateValue.on

		//indexOfSelectedItem is -1 when nothing is selected
		if let screens = allScreens, !screens.isEmpty {
			let selected = screenSelector.indexOfSelectedItem
			Settings.shared.quizScreen = screens.indices.contains(selected) ? screens[selected] : screens[0]
		} else {
			Settings.shared.quizScreen = nil
		}
		Settings.shared.windowedMode = windowedMode.state == NSControl.StateValue.on

		view.window?.close()
		ControllerWindowController.shared.showWindow(self)
    }

	@IBAction func quizRootBrowse(_ sender: Any) {
		createDialog(title: "cs-xmas-quiz repository folder", textField: quizRootPath)
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

