//
//  QuizWebSocket.swift
//  Quiz Server
//
//  Replaces Starscream WebSocket + LEDWebSocket extension with native URLSessionWebSocketTask.
//

import Foundation

protocol QuizWebSocketDelegate: AnyObject {
	func webSocketDidConnect()
	func webSocketDidDisconnect()
	func webSocketDidReceiveMessage(_ text: String)
}

class QuizWebSocket: NSObject, URLSessionWebSocketDelegate {

	static var shared: QuizWebSocket?

	weak var delegate: QuizWebSocketDelegate?

	private enum ConnectionState {
		case disconnected
		case connecting
		case connected
	}

	private let url: URL
	private var session: URLSession!
	private var task: URLSessionWebSocketTask?
	private var state: ConnectionState = .disconnected
	private var reconnectScheduled = false
	private var pingTimer: Timer?
	private var connectWatchdog: Timer? //Add a watchdog so that connecting can be aborted and retried
	private var intentionalDisconnect = false
	private let connectTimeout: TimeInterval = 10.0

	var isConnected: Bool { state == .connected && task != nil }

	init(url: URL) {
		self.url = url
		super.init()
		self.session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
	}

	/// True only for the task we are currently using.
	/// Deals with callbacks from old connections
	private func isCurrent(_ candidate: URLSessionTask?) -> Bool {
		guard let candidate = candidate, let current = task else { return false }
		return candidate === current
	}

	func connect() {
		guard state == .disconnected else { return }
		state = .connecting
		intentionalDisconnect = false
		task = session.webSocketTask(with: url)
		startConnectWatchdog()
		task?.resume()
	}

	func disconnect() {
		intentionalDisconnect = true
		stopPing()
		stopConnectWatchdog()
		task?.cancel(with: .goingAway, reason: nil)
		task = nil
		state = .disconnected
	}

	/// Send a text message, silently dropping it if not connected.
	func send(_ text: String) {
		guard state == .connected, let current = task else { return }
		current.send(.string(text)) { [weak self] error in
			guard let self = self, let error = error else { return }
			print("WebSocket send error: \(error.localizedDescription)")
			guard self.isCurrent(current) else { return }
			self.handleConnectionLost()
		}
	}

	// MARK: - URLSessionWebSocketDelegate

	func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
		guard isCurrent(webSocketTask) else {
			print("websocket ignoring open from a stale task")
			webSocketTask.cancel(with: .abnormalClosure, reason: nil)
			return
		}
		state = .connected
		reconnectScheduled = false
		stopConnectWatchdog()
		print("websocket is connected")
		delegate?.webSocketDidConnect()
		listenForMessages()
		startPing()
	}

	func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
		let reasonStr = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "unknown"
		print("websocket is disconnected: \(reasonStr) with code: \(closeCode.rawValue)")
		guard isCurrent(webSocketTask) else { return }
		handleConnectionLost()
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
		// `task` here is the parameter, not the property.
		if let error = error {
			print("websocket encountered an error: \(error.localizedDescription)")
		}
		guard isCurrent(task) else { return }
		handleConnectionLost()
	}

	// MARK: - Private

	private func handleConnectionLost() {
		guard state != .disconnected else { return }
		stopPing()
		stopConnectWatchdog()
		state = .disconnected
		task = nil
		delegate?.webSocketDidDisconnect()
		if !intentionalDisconnect {
			scheduleReconnect()
		}
	}

	/// Unconditional return to a known state
	private func forceReset(_ why: String) {
		print("WebSocket forcing a reset: \(why)")
		stopPing()
		stopConnectWatchdog()
		task?.cancel(with: .abnormalClosure, reason: nil)
		task = nil
		let wasConnected = (state == .connected)
		state = .disconnected
		if wasConnected {
			delegate?.webSocketDidDisconnect()
		}
		if !intentionalDisconnect {
			scheduleReconnect()
		}
	}

	private func listenForMessages() {
		guard let current = task else { return }
		current.receive { [weak self] result in
			// Once this task is no longer ours, stop reading from it and stop reporting it
			guard let self = self, self.isCurrent(current) else { return }
			switch result {
			case .success(.string(let text)):
				self.delegate?.webSocketDidReceiveMessage(text)
				self.listenForMessages()
			case .success(.data(_)):
				self.listenForMessages()
			case .failure(let error):
				print("WebSocket receive error: \(error.localizedDescription)")
				self.handleConnectionLost()
			@unknown default:
				self.listenForMessages()
			}
		}
	}

	private func scheduleReconnect() {
		guard !reconnectScheduled else { return }
		reconnectScheduled = true
		DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
			guard let self = self else { return }
			self.reconnectScheduled = false
			self.connect()
		}
	}

	private func startPing() {
		stopPing()
		pingTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
			guard let self = self else { return }

			if self.state == .connected && self.task == nil {
				self.forceReset("connected with no task")
				return
			}

			guard self.state == .connected, let current = self.task else { return }
			current.sendPing { [weak self] error in
				guard let self = self, let error = error else { return }
				print("WebSocket ping failed: \(error.localizedDescription)")
				guard self.isCurrent(current) else { return }
				self.handleConnectionLost()
			}
		}
	}

	/// Gives up on a connection attempt that never finished
	private func startConnectWatchdog() {
		stopConnectWatchdog()
		connectWatchdog = Timer.scheduledTimer(withTimeInterval: connectTimeout, repeats: false) { [weak self] _ in
			guard let self = self, self.state == .connecting else { return }
			self.forceReset("connect timed out after \(self.connectTimeout)s")
		}
	}

	private func stopConnectWatchdog() {
		connectWatchdog?.invalidate()
		connectWatchdog = nil
	}

	private func stopPing() {
		pingTimer?.invalidate()
		pingTimer = nil
	}

	// MARK: - LED Commands

	func ledsOff() {
		send("lea00")
	}

	func megamas() {
		send("lea01")
	}

	func timertwinkle() {
		send("lea02")
	}

	/// Trigger a random buzzer animation for team (0-based)
	func buzz(team: Int) {
		if team >= 0 && team < 50 {
			send("leb" + String(format: "%02d", team))
		}
	}

	/// Set leds to an R G B colour (0-255)
	func setColour(r: UInt8, g: UInt8, b: UInt8) {
		send("lec" + String(format: "%03d", r) + String(format: "%03d", g) + String(format: "%03d", b))
	}

	/// Set leds to the colour of a specified team (0-based)
	func setTeamColour(_ team: Int) {
		if team >= 0 && team < 50 {
			send("let" + String(format: "%02d", team))
		}
	}

	func setTargetTeam(_ team: Int) {
		if team >= 0 && team < 50 {
			send("lee" + String(format: "%02d", team))
		}
	}

	func pulseWhite() {
		send("lep00")
	}

	func pulseRed() {
		send("lep01")
	}

	func pulseGreen() {
		send("lep02")
	}

	/// Pulse leds the colour of a specified team (0-based)
	func pulseTeamColour(_ team: Int) {
		if team >= 0 && team < 50 {
			send("leq" + String(format: "%02d", team))
		}
	}

	/// Pulse leds the colour of a specified team (0-based) quickly
	func pulseTeamColourQuick(_ team: Int) {
		if team >= 0 && team < 50 {
			send("leq" + String(format: "%02d", team + 50))
		}
	}

	/// Set music levels on LEDs
	func setMusicLevels(leftAvg: Int, leftPeak: Int, rightAvg: Int, rightPeak: Int) {
		send("lem" + String(format: "%03d", leftAvg) + String(format: "%03d", leftPeak) + String(format: "%03d", rightAvg) + String(format: "%03d", rightPeak))
	}

	/// Set the leds to a value from 0 to NUM_LEDS.
	func setCounterValue(_ val: Int) {
		send("ler" + String(format: "%03d", val))
	}
}
