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
	private var intentionalDisconnect = false

	var isConnected: Bool { state == .connected }

	init(url: URL) {
		self.url = url
		super.init()
		self.session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
	}

	func connect() {
		guard state == .disconnected else { return }
		state = .connecting
		intentionalDisconnect = false
		task = session.webSocketTask(with: url)
		task?.resume()
	}

	func disconnect() {
		intentionalDisconnect = true
		stopPing()
		task?.cancel(with: .goingAway, reason: nil)
		task = nil
		state = .disconnected
	}

	/// Send a text message, silently dropping it if not connected.
	func send(_ text: String) {
		guard state == .connected else { return }
		task?.send(.string(text)) { [weak self] error in
			guard let self = self, let error = error else { return }
			print("WebSocket send error: \(error.localizedDescription)")
			self.handleConnectionLost()
		}
	}

	// MARK: - URLSessionWebSocketDelegate

	func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
		state = .connected
		reconnectScheduled = false
		print("websocket is connected")
		delegate?.webSocketDidConnect()
		listenForMessages()
		startPing()
	}

	func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
		let reasonStr = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "unknown"
		print("websocket is disconnected: \(reasonStr) with code: \(closeCode.rawValue)")
		handleConnectionLost()
	}

	func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
		if let error = error {
			print("websocket encountered an error: \(error.localizedDescription)")
			handleConnectionLost()
		}
	}

	// MARK: - Private

	private func handleConnectionLost() {
		guard state != .disconnected else { return }
		stopPing()
		state = .disconnected
		task = nil
		delegate?.webSocketDidDisconnect()
		if !intentionalDisconnect {
			scheduleReconnect()
		}
	}

	private func listenForMessages() {
		task?.receive { [weak self] result in
			guard let self = self else { return }
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
			guard let self = self, self.state == .connected else { return }
			self.task?.sendPing { [weak self] error in
				guard let self = self, let error = error else { return }
				print("WebSocket ping failed: \(error.localizedDescription)")
				self.handleConnectionLost()
			}
		}
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
