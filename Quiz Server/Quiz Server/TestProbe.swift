//
//  TestProbe.swift
//  Quiz Server
//
//  Lets the end-to-end tests in nodeserver/test/e2e press the controller's real buttons and
//  read what the host and the audience would see. Does nothing at all unless QUIZ_TEST_PROBE
//  is set: the app then dials out to that URL and takes one JSON command per message.
//
//  Controls and state are found by name with Mirror, so a round needs no code here.
//    tabitemBuzzers                      a property of the controller
//    quizDisplay.buzzerScene.buzzes      a property of a property, private or not
//    buzzerPanel.nextTeam:               the control that sends this action to this object
//    pressedNumber:#3                    ...with this tag, for an action shared between controls
//
//  Everything runs on the main queue, as real clicks and socket messages do.
//

import Cocoa
import SpriteKit

final class TestProbe: NSObject, QuizWebSocketDelegate {

	private struct ProbeError: Error { let message: String }

	private static var shared: TestProbe?

	private let controller: ControllerWindowController
	private var task: URLSessionWebSocketTask?

	/// How many "co" messages have come from the node server. Nothing else uses "co", so a
	/// test can send one as a barrier: the socket is in order, so once it has been counted
	/// everything sent ahead of it has been handled. See `Host.settled` in rig.js.
	private var barriersReached = 0

	/// The experiment's stand-in for another app's window. See `windowAction`.
	private var coverWindow: NSWindow?

	static func startIfRequested(controller: ControllerWindowController) {
		guard let address = ProcessInfo.processInfo.environment["QUIZ_TEST_PROBE"],
			  let url = URL(string: address) else { return }
		let probe = TestProbe(controller: controller)
		shared = probe
		controller.socket.delegate = probe
		probe.connect(to: url)
	}

	private init(controller: ControllerWindowController) {
		self.controller = controller
	}

	// Sat in front of the controller, which still sees everything
	func webSocketDidConnect() { controller.webSocketDidConnect() }
	func webSocketDidDisconnect() { controller.webSocketDidDisconnect() }
	func webSocket(didReceive message: QuizMessage) {
		controller.webSocket(didReceive: message)
		if message == .connected { barriersReached += 1 }
	}

	private func connect(to url: URL) {
		let session = URLSession(configuration: .default, delegate: nil, delegateQueue: .main)
		task = session.webSocketTask(with: url)
		task?.resume()
		listen()
	}

	private func listen() {
		task?.receive { [weak self] result in
			guard let self else { return }
			switch result {
			case .success(.string(let text)):
				self.handle(text)
				self.listen()
			case .success:
				self.listen()
			case .failure(let error):
				//The test run is over or has died, so an app left behind would just be in the way
				print("Test probe connection ended: \(error.localizedDescription)")
				NSApp.terminate(nil)
			}
		}
	}

	private func reply(_ id: Any, result: Any? = nil, error: String? = nil) {
		var message: [String: Any] = ["id": id]
		if let error { message["error"] = error } else { message["result"] = result ?? NSNull() }

		guard JSONSerialization.isValidJSONObject(message),
			  let data = try? JSONSerialization.data(withJSONObject: message),
			  let text = String(data: data, encoding: .utf8) else {
			reply(id, error: "result could not be written as JSON")
			return
		}
		task?.send(.string(text)) { _ in }
	}

	private func handle(_ text: String) {
		guard let data = text.data(using: .utf8),
			  let command = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
			  let id = command["id"], let op = command["op"] as? String else {
			print("Test probe could not read: \(text)")
			return
		}
		let path = command["path"] as? String ?? ""

		do {
			switch op {
			case "click":
				try click(path)
				reply(id)
			case "set":
				try set(path, to: command["value"] as Any)
				reply(id)
			case "read":
				reply(id, result: encode(try resolve(path)))
			case "barriers":
				reply(id, result: barriersReached)
			case "scene":
				reply(id, result: sceneState())
			case "screenshot":
				try screenshot(to: path)
				reply(id)
			case "renderTick":
				renderTick(id)
			case "window":
				reply(id, result: try windowAction(path))
			default:
				reply(id, error: "unknown op '\(op)'")
			}
		} catch let error as ProbeError {
			reply(id, error: error.message)
		} catch {
			reply(id, error: "\(error)")
		}
	}


	// MARK: - Finding things

	private func children(of value: Any) -> [(String, Any)] {
		var found = [(String, Any)]()
		var mirror: Mirror? = Mirror(reflecting: value)
		while let current = mirror {
			for child in current.children {
				if let label = child.label { found.append((label, child.value)) }
			}
			mirror = current.superclassMirror
		}
		return found
	}

	/// Sees through an Optional, returning nil for an empty one
	private func unwrapped(_ value: Any) -> Any? {
		let mirror = Mirror(reflecting: value)
		guard mirror.displayStyle == .optional else { return value }
		return mirror.children.first.flatMap { unwrapped($0.value) }
	}

	private func resolve(_ path: String) throws -> Any {
		var current: Any = controller
		for segment in path.split(separator: ".") {
			let name = String(segment)
			if let index = Int(name), Mirror(reflecting: current).displayStyle == .collection {
				let items = Mirror(reflecting: current).children.map { $0.value }
				guard items.indices.contains(index) else {
					throw ProbeError(message: "'\(path)': no element \(index) of \(items.count)")
				}
				current = items[index]
			} else {
				let known = children(of: current)
				guard let match = known.first(where: { $0.0 == name }) else {
					throw ProbeError(message: "'\(path)': no '\(name)' on \(type(of: current)). It has: " +
									 known.map { $0.0 }.joined(separator: ", "))
				}
				current = match.1
			}
			guard let value = unwrapped(current) else {
				throw ProbeError(message: "'\(path)': '\(name)' is nil")
			}
			current = value
		}
		return current
	}

	/// Every control in the window, including those on tabs not showing
	private func allControls() -> [NSControl] {
		var found = [NSControl]()
		func walk(_ view: NSView) {
			if let control = view as? NSControl { found.append(control) }
			if let tabs = view as? NSTabView {
				tabs.tabViewItems.compactMap { $0.view }.forEach(walk)
			}
			view.subviews.forEach(walk)
		}
		if let root = controller.window?.contentView { walk(root) }
		return found
	}

	/// The control for "owner.action:" or "owner.action:#tag"
	private func control(forAction path: String) throws -> NSControl {
		let parts = path.components(separatedBy: "#")
		let tag = parts.count > 1 ? Int(parts[1]) : nil
		var segments = parts[0].components(separatedBy: ".")
		let action = segments.removeLast()
		let owner = try resolve(segments.joined(separator: ".")) as AnyObject

		let matches = allControls().filter { control in
			control.target === owner && control.action.map(NSStringFromSelector) == action &&
				(tag == nil || control.tag == tag)
		}
		guard let match = matches.first else {
			throw ProbeError(message: "'\(path)': no control sends that action to \(type(of: owner))")
		}
		guard matches.count == 1 else {
			throw ProbeError(message: "'\(path)': \(matches.count) controls send that action, so give a #tag")
		}
		return match
	}


	// MARK: - Acting

	private func click(_ path: String) throws {
		let target: Any = path.contains(":") ? try control(forAction: path) : try resolve(path)

		//The sidebar's own click comes down to this too.
		if let item = target as? NSTabViewItem {
			guard let tabs = item.tabView else {
				throw ProbeError(message: "'\(path)' is not in a tab view")
			}
			tabs.selectTabViewItem(item)
			return
		}

		guard let control = target as? NSControl else {
			throw ProbeError(message: "'\(path)' is a \(type(of: target)), which cannot be clicked")
		}
		//A host could not press any of these, so neither may a test. performClick would
		//quietly do nothing for a disabled one, and that would pass as success.
		guard control.isEnabled else {
			throw ProbeError(message: "'\(path)' is disabled")
		}
		guard control.window != nil, !control.isHiddenOrHasHiddenAncestor else {
			throw ProbeError(message: "'\(path)' is not showing. Is its tab selected?")
		}
		control.performClick(nil)
	}

	private func set(_ path: String, to value: Any) throws {
		let target: Any = path.contains(":") ? try control(forAction: path) : try resolve(path)
		guard let control = target as? NSControl else {
			throw ProbeError(message: "'\(path)' is a \(type(of: target)), which cannot be set")
		}
		switch value {
		case let text as String: control.stringValue = text
		case let number as NSNumber: control.doubleValue = number.doubleValue
		default: throw ProbeError(message: "'\(path)': cannot set to \(value)")
		}
		if let action = control.action {
			NSApp.sendAction(action, to: control.target, from: control)
		}
	}


	// MARK: - Reading

	private func encode(_ value: Any) -> Any {
		guard let value = unwrapped(value) else { return NSNull() }

		switch value {
		case let v as Bool: return v
		case let v as Int: return v
		case let v as String: return v
		case let v as CGFloat: return v.isFinite ? v : String(describing: v)
		case let v as Float: return v.isFinite ? v : String(describing: v)
		case let v as Double: return v.isFinite ? v : String(describing: v)
		case let v as NSButton:
			return ["title": v.title, "on": v.state == .on, "enabled": v.isEnabled, "hidden": v.isHidden]
		case let v as NSControl:
			return ["value": v.stringValue, "enabled": v.isEnabled, "hidden": v.isHidden]
		default: break
		}

		let mirror = Mirror(reflecting: value)
		switch mirror.displayStyle {
		case .collection, .set:
			return mirror.children.map { encode($0.value) }
		case .enum:
			return String(describing: value)
		default:
			return String(describing: type(of: value))
		}
	}

	private func sceneState() -> [String: Any] {
		let view = controller.quizDisplay.skView
		return [
			"round": String(describing: controller.quizDisplay.currentRound),
			"scene": view.scene.map { String(describing: type(of: $0)) } ?? NSNull(),
			"nodes": view.scene.map { describe($0) } ?? NSNull()
		]
	}

	private func describe(_ node: SKNode) -> [String: Any] {
		var out: [String: Any] = [
			"type": String(describing: type(of: node)),
			"alpha": node.alpha,
			"hidden": node.isHidden
		]
		if let name = node.name { out["name"] = name }
		if let label = node as? SKLabelNode, let text = label.text { out["text"] = text }
		if !node.children.isEmpty { out["children"] = node.children.map { describe($0) } }
		return out
	}

	private func screenshot(to file: String) throws {
		let view = controller.quizDisplay.skView
		guard let scene = view.scene, let texture = view.texture(from: scene) else {
			throw ProbeError(message: "the scene could not be rendered")
		}
		let bitmap = NSBitmapImageRep(cgImage: texture.cgImage())
		guard let png = bitmap.representation(using: .png, properties: [:]) else {
			throw ProbeError(message: "the scene could not be written as a PNG")
		}
		try png.write(to: URL(fileURLWithPath: file))
	}


	// MARK: - Spike experiment: does SpriteKit keep running when nobody can see it?
	// To be removed, or kept only as a health check, once that has been answered.

	/// Answers once a 0.2s SKAction has finished, with how long it really took. SKActions only
	/// advance when the view renders, so a stalled view never answers.
	private func renderTick(_ id: Any) {
		guard let scene = controller.quizDisplay.skView.scene else {
			reply(id, error: "no scene")
			return
		}
		let started = Date()
		scene.run(SKAction.wait(forDuration: 0.2)) { [weak self] in
			self?.reply(id, result: Date().timeIntervalSince(started))
		}
	}

	/// Puts the display window into a state that nobody can see
	private func windowAction(_ action: String) throws -> [String: Any] {
		guard let window = controller.quizDisplay.view.window else {
			throw ProbeError(message: "no display window")
		}
		switch action {
		case "cover":
			let cover = NSWindow(contentRect: window.frame.insetBy(dx: -40, dy: -40), styleMask: .borderless,
								 backing: .buffered, defer: false)
			cover.isReleasedWhenClosed = false
			cover.backgroundColor = .black
			cover.isOpaque = true
			cover.level = .floating
			cover.orderFrontRegardless()
			coverWindow = cover
		case "minimise":
			window.miniaturize(nil)
		case "hide":
			window.orderOut(nil)
		case "show":
			coverWindow?.close()
			coverWindow = nil
			window.deminiaturize(nil)
			window.orderFrontRegardless()
		case "status":
			break
		default:
			throw ProbeError(message: "unknown window action '\(action)'")
		}
		return ["visible": window.occlusionState.contains(.visible),
				"miniaturised": window.isMiniaturized,
				"appActive": NSApp.isActive]
	}
}
