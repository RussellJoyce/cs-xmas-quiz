//
//  Settings.swift
//  Quiz Server
//
//  Created by Ian Gray on 2025-10-24.
//  Copyright © 2025 Russell Joyce & Ian Gray. All rights reserved.
//

import SpriteKit


protocol QuizRound : SKScene {
	func setUpScene(size: CGSize)
	func reset()
}


// MARK: - Settings

final class Settings {
	static let shared = Settings()
	private init() {}

	var debug: Bool = false
	
	/// The very first time the websocket connects, this is set to true and left true
	var websocketHasPreviouslyConnected = false
	
	/// Paths for locating questions in different places
	var geographyImagesPath: String = ""
	var musicPath: String = ""
	var uniquePath: String = ""
	var pointlessPath: String = ""
	
	var numTeams: Int = 14
}

// MARK: - Global enums
enum BuzzerType {
	case test
	case button
	case websocket
	case disabled
}

enum RoundType {
	case none
	case idle
	case test
	case buzzers
	case music
	case trueFalse
	case timer
	case geography
	case text
	case numbers
	case scores
	case pointless
}


// MARK: - Utils
final class Utils {
	
	static func createFilterPulse(upTime : TimeInterval, downTime : TimeInterval, filterNode : SKEffectNode, extraAction : SKAction? = nil, filterKey : String = "inputEV") -> SKAction {
		
		let exAc : SKAction = (extraAction == nil ? SKAction() : extraAction!)
		
		let pulseupaction = SKAction.customAction(withDuration: upTime, actionBlock: {(node, time) -> Void in
			(node as! SKEffectNode).filter!.setValue((time*3), forKey: filterKey)
		})
		let pulsednaction = SKAction.customAction(withDuration: downTime, actionBlock: {(node, time) -> Void in
			(node as! SKEffectNode).filter!.setValue((downTime - time)*3, forKey: filterKey)
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
		if n >= 10 {
			return conv(n/10) + conv(n%10)
		} else {
			return conv(n)
		}
	}
	
}

// MARK: - Extensions

// Extension to safely reload NSTableView data on main thread
extension NSTableView {
	func safeReloadData() {
		DispatchQueue.main.async {
			self.reloadData()
		}
	}
}

// Add a centrePoint convenience method
extension SKNode {
	var centrePoint: CGPoint {
		return CGPoint(x:self.frame.midX, y:self.frame.midY)
	}
}

// Convenience to remove emitters when they are done
extension SKEmitterNode {
	func removeWhenDone() {
		if (self.numParticlesToEmit != 0) {
			let ttl = TimeInterval((CGFloat(self.numParticlesToEmit) / self.particleBirthRate) + (self.particleLifetime + (self.particleLifetimeRange / 2.0)))
			let removeAction = SKAction.sequence([SKAction.wait(forDuration: ttl), SKAction.removeFromParent()])
			self.run(removeAction)
		}
	}
}

// Linear interpolate colour
func lerp(a : CGFloat, b : CGFloat, fraction : CGFloat) -> CGFloat {
	return (b-a) * fraction + a
}

struct ColorComponents {
	var red = CGFloat(0)
	var green = CGFloat(0)
	var blue = CGFloat(0)
	var alpha = CGFloat(0)
}

// NSColour extension to use the ColorComponents struct
extension NSColor {
	func toComponents() -> ColorComponents {
		var components = ColorComponents()
		getRed(&components.red, green: &components.green, blue: &components.blue, alpha: &components.alpha)
		return components
	}
}

// SKAction to transition colours
extension SKAction {
	static func colorTransitionAction(fromColor : NSColor, toColor : NSColor, duration : Double = 0.4) -> SKAction {
		return SKAction.customAction(withDuration: duration, actionBlock: { (node : SKNode!, elapsedTime : CGFloat) -> Void in
			let fraction = CGFloat(elapsedTime / CGFloat(duration))
			let startColorComponents = fromColor.toComponents()
			let endColorComponents = toColor.toComponents()
			let transColor = NSColor(red: lerp(a: startColorComponents.red, b: endColorComponents.red, fraction: fraction),
									 green: lerp(a: startColorComponents.green, b: endColorComponents.green, fraction: fraction),
									 blue: lerp(a: startColorComponents.blue, b: endColorComponents.blue, fraction: fraction),
									 alpha: lerp(a: startColorComponents.alpha, b: endColorComponents.alpha, fraction: fraction))
			(node as? SKShapeNode)?.fillColor = transColor
		}
		)
	}
}
