//
//  Settings.swift
//  Quiz Server
//
//  Created by Ian Gray on 2025-10-24.
//  Copyright © 2025 Russell Joyce & Ian Gray. All rights reserved.
//

import SpriteKit


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

	/// The screen the quiz display is shown on, and whether it runs windowed rather than
	/// taking that screen exclusively fullscreen
	var quizScreen: NSScreen?
	var windowedMode = true
}

// MARK: - Global enums
enum BuzzerType {
	case test
	case button
	case websocket
	case disabled
}

/// The controller's buzzer-related toggles, gathered up so that every round shares one `buzzerPressed` signature.
struct BuzzerOptions {
	var buzzcocksMode = false
	var buzzerQueueMode = false
	var quietMode = false
	var buzzerSounds = false
	var blankVideo = false
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
	case wavelength
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
	

	/// Hue identifying a team
	static func teamHue(_ team: Int) -> CGFloat {
		return CGFloat(team % 10) / 10.0
	}

	/// A team's identifying colour. Saturation and brightness vary with the use
	static func teamColour(_ team: Int, saturation: CGFloat = 1.0, brightness: CGFloat = 1.0, alpha: CGFloat = 1.0) -> NSColor {
		return NSColor(calibratedHue: teamHue(team), saturation: saturation, brightness: brightness, alpha: alpha)
	}


	/// Reads one of the question files off disk. Use UTF-8 if possible, warn if fallback is required
	/// - Returns: the file's contents, or nil if it could not be read at all.
	static func readQuestionFile(_ path: String) -> String? {
		if let utf8 = try? String(contentsOfFile: path, encoding: .utf8) {
			return utf8
		}
		if let latin1 = try? String(contentsOfFile: path, encoding: .isoLatin1) {
			print("Question file '\(path)' is not valid UTF-8, read as Latin-1 instead")
			return latin1
		}
		print("Could not read question file '\(path)'")
		return nil
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

	/// Loads an emitter from the named .sks file, positions it, and attaches it as a child.
	/// - Parameters:
	///   - configure: applied before the node is attached, for textures, colours,
	///     `numParticlesToEmit` and so on.
	///   - autoRemove: call `removeWhenDone()` once configured, so that finite bursts
	///     tidy themselves up. Pass false for continuous emitters whose lifetime the
	///     caller manages (by holding a reference and setting `particleBirthRate`).
	@discardableResult
	func addEmitter(named name: String,
					at position: CGPoint,
					zPosition: CGFloat,
					autoRemove: Bool = true,
					configure: ((SKEmitterNode) -> Void)? = nil) -> SKEmitterNode {
		let emitter = SKEmitterNode(fileNamed: name)!
		emitter.position = position
		emitter.zPosition = zPosition
		configure?(emitter)
		if autoRemove {
			emitter.removeWhenDone()
		}
		self.addChild(emitter)
		return emitter
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
