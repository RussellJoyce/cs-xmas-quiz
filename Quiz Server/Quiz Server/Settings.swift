//
//  Settings.swift
//  Quiz Server
//
//  Created by Ian Gray on 2025-10-24.
//  Copyright © 2025 Russell Joyce & Ian Gray. All rights reserved.
//

import SpriteKit

final class Settings {
	static let shared = Settings()
	private init() {}

	var debug: Bool = false
	
	var geographyImagesPath: String = ""
	var musicPath: String = ""
	var uniquePath: String = ""
	var pointlessPath: String = ""
	
	var numTeams: Int = 14
}



final class Utils {
	
	static func createFilterPulse(upTime : TimeInterval, downTime : TimeInterval, filterNode : SKEffectNode, extraAction : SKAction? = nil, filterKey : String = "inputEV") -> SKAction {
		
		let exAc : SKAction = (extraAction == nil ? SKAction() : extraAction!)
		
		let pulseupaction = SKAction.customAction(withDuration: upTime, actionBlock: {(node, time) -> Void in
			(node as! SKEffectNode).filter!.setValue(1 + (time*3), forKey: filterKey)
		})
		let pulsednaction = SKAction.customAction(withDuration: downTime, actionBlock: {(node, time) -> Void in
			(node as! SKEffectNode).filter!.setValue(1 + (downTime - time)*3, forKey: filterKey)
		})
		pulseupaction.timingMode = .easeInEaseOut
		pulsednaction.timingMode = .easeInEaseOut
		let pulseAction = SKAction.sequence([
			SKAction.run({ () -> Void in filterNode.shouldRasterize = false }),
			pulseupaction,
			exAc,
			pulsednaction,
			SKAction.run({ () -> Void in filterNode.shouldRasterize = true })
		])
		
		return pulseAction
	}
	

	static func sanitiseString(_ input : String) -> String {
		var str = input.lowercased()
		str = str.trimmingCharacters(in: .whitespacesAndNewlines)
		str = str.trimmingCharacters(in: .punctuationCharacters)
		str = str.trimmingCharacters(in: .symbols)
		str = str.replacingOccurrences(of: "\"", with: "")
		str = str.replacingOccurrences(of: "\'", with: "")
		str = str.replacingOccurrences(of: "-", with: " ")
		str = str.replacingOccurrences(of: "&", with: " ")
		str = str.replacingOccurrences(of: "(", with: "")
		str = str.replacingOccurrences(of: ")", with: "")
		return str
	}
	
	
	static func numberAsEmoji(_ n: Int) -> String {
		func conv(_ n: Int) -> String {
			switch n {
			case 0: return "0️⃣"
			case 1: return "1️⃣"
			case 2: return "2️⃣"
			case 3: return "3️⃣"
			case 4: return "4️⃣"
			case 5: return "5️⃣"
			case 6: return "6️⃣"
			case 7: return "7️⃣"
			case 8: return "8️⃣"
			case 9: return "9️⃣"
			default: return ""
			}
		}
		if n > 10 {
			return conv(n/10) + conv(n%10)
		} else {
			return conv(n)
		}
	}
	
}


// Extension to safely reload NSTableView data on main thread
extension NSTableView {
	func safeReloadData() {
		DispatchQueue.main.async {
			self.reloadData()
		}
	}
}



