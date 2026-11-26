//
//  TreeLink.swift
//  Quiz Server
//
//  The desk trees over USB serial. Each tree is an ESP32 whose built-in USB serial port shows
//  up as /dev/cu.usbmodem*. The app finds them with IOKit, takes each one over from WiFi with a
//  hello, and then sends every tree command to it directly, so the trees do not depend on the
//  node server or the WiFi. The serial protocol is described at the top of
//  quizleds/src/tree/tree_main.cpp.
//
//  For USB trees this does what nodeserver/trees.js and sendTreeState() do for WiFi ones: tells
//  each tree its place among them (iNNCC, ordered by tree id, so by MAC address), and replays
//  the animation, team count and brightness to a tree that has just been claimed.
//
//  The ports are opened for exclusive use, so nothing else (a serial monitor, a firmware
//  upload) can open a tree while the app is running. Quit the app to flash a tree.
//
//  Everything runs on the main queue.
//

import Foundation
import IOKit
import IOKit.serial

final class TreeLink {

	/// Espressif's built-in USB serial/JTAG controller, on the ESP32-C3 and -C6
	static let espressifVendor = 0x303A
	static let usbSerialJTAG = 0x1001

	private final class Port {
		let path: String
		let fd: Int32
		let source: DispatchSourceRead
		var buffer = Data()
		/// From the tree's answer to the hello; nil until then
		var id: String?
		var chip = ""
		var build = ""
		/// The tree printed "Serial host": it has just been taken over from WiFi, so has
		/// none of the state and needs it all
		var fresh = false

		init(path: String, fd: Int32, source: DispatchSourceRead) {
			self.path = path
			self.fd = fd
			self.source = source
		}
	}

	/// The ids of the trees claimed, in order. Stored, not computed, so the test probe can
	/// read it (Mirror only sees stored properties).
	private(set) var claimed: [String] = []

	/// Device paths that have been found and are open, claimed or not
	private var ports: [String: Port] = [:]
	/// Device paths that have been found but could not be opened yet (e.g. busy); retried
	private var waiting: Set<String> = []

	/// What a freshly claimed tree is sent, as the node server does for WiFi trees. Seeded
	/// from the settings in `start()`, so the trees are right even if the node server never
	/// connects, then kept up to date by `send(_:)`.
	private var lastAnimation = "a01"
	private var lastTeamCount = "n14"
	private var lastBrightness = "g128"

	private var notifyPort: IONotificationPortRef?
	private var addedIterator: io_iterator_t = 0
	private var removedIterator: io_iterator_t = 0
	private var timer: Timer?

	/// How often each tree is sent the hello: until it answers, and after that as a check
	/// that it is still there and has not restarted (see `fresh`)
	private let helloInterval: TimeInterval = 2

	/// Starts looking for trees. In the end-to-end tests (QUIZ_TEST_PROBE set) the real USB
	/// ports are left alone, so a test run never takes over trees on the desk; the tests list
	/// their simulated trees' ports in QUIZ_TREE_PORTS instead, separated by commas.
	func start() {
		let settings = Settings.shared
		lastAnimation = "a" + String(format: "%02d", settings.idleTreeAnimation.rawValue)
		lastTeamCount = "n" + String(format: "%02d", max(1, min(99, settings.numTeams)))
		lastBrightness = "g" + String(format: "%03d", max(0, min(255, settings.treeBrightness)))

		let env = ProcessInfo.processInfo.environment
		if let list = env["QUIZ_TREE_PORTS"] {
			list.split(separator: ",").map(String.init).filter { !$0.isEmpty }.forEach(found)
		}
		if env["QUIZ_TEST_PROBE"] == nil {
			startDiscovery()
		}
		timer = Timer.scheduledTimer(withTimeInterval: helloInterval, repeats: true) { [weak self] _ in
			self?.tick()
		}
	}

	// MARK: - Commands

	/// Sends a tree command, as the protocol has it without the "lt" (e.g. "b03"), to every
	/// claimed tree, and remembers it if a newly claimed tree will need it
	func send(_ command: String) {
		guard let kind = command.first else { return }
		switch kind {
			case "a": lastAnimation = command
			case "g": lastBrightness = command
			case "n": lastTeamCount = command
			default: break
		}
		for port in ports.values where port.id != nil {
			write(command, to: port)
		}
	}

	/// One command line. The newline in front ends any line left half written by an earlier
	/// write that did not fit; the tree ignores newlines outside a line.
	private func write(_ command: String, to port: Port) {
		let bytes = Array(("\n>" + command + "\n").utf8)
		let written = bytes.withUnsafeBufferPointer { Darwin.write(port.fd, $0.baseAddress, $0.count) }
		if written != bytes.count {
			//Never wait for a tree: the port is non-blocking, so a tree that is not reading
			//loses the command instead of stalling the app
			print("Tree \(name(of: port)): could not send '\(command)'" +
			      (written < 0 ? ": \(String(cString: strerror(errno)))" : ", buffer full"))
		}
	}

	private func name(of port: Port) -> String {
		port.id ?? port.path
	}

	// MARK: - Finding trees

	private func startDiscovery() {
		guard let notifyPort = IONotificationPortCreate(kIOMainPortDefault) else {
			print("Trees: cannot watch for USB devices")
			return
		}
		self.notifyPort = notifyPort
		IONotificationPortSetDispatchQueue(notifyPort, .main)
		let context = Unmanaged.passUnretained(self).toOpaque()

		//Each registration consumes its matching dictionary, so each gets its own
		IOServiceAddMatchingNotification(notifyPort, kIOFirstMatchNotification,
		                                 IOServiceMatching(kIOSerialBSDServiceValue), { context, iterator in
			Unmanaged<TreeLink>.fromOpaque(context!).takeUnretainedValue().devicesAdded(iterator)
		}, context, &addedIterator)
		IOServiceAddMatchingNotification(notifyPort, kIOTerminatedNotification,
		                                 IOServiceMatching(kIOSerialBSDServiceValue), { context, iterator in
			Unmanaged<TreeLink>.fromOpaque(context!).takeUnretainedValue().devicesRemoved(iterator)
		}, context, &removedIterator)

		//Draining the iterators arms them, and the first one also lists the devices already
		//plugged in
		devicesAdded(addedIterator)
		devicesRemoved(removedIterator)
	}

	private func devicesAdded(_ iterator: io_iterator_t) {
		while case let service = IOIteratorNext(iterator), service != 0 {
			defer { IOObjectRelease(service) }
			guard let path = TreeLink.calloutPath(service), TreeLink.isTree(service) else { continue }
			found(path)
		}
	}

	private func devicesRemoved(_ iterator: io_iterator_t) {
		while case let service = IOIteratorNext(iterator), service != 0 {
			defer { IOObjectRelease(service) }
			guard let path = TreeLink.calloutPath(service) else { continue }
			waiting.remove(path)
			if ports[path] != nil { drop(path, reason: "unplugged") }
		}
	}

	/// The /dev/cu.* path of a serial device
	private static func calloutPath(_ service: io_object_t) -> String? {
		IORegistryEntryCreateCFProperty(service, kIOCalloutDeviceKey as CFString,
		                                kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
	}

	/// Whether a serial device belongs to an ESP32's built-in USB serial port. The ids are on
	/// the USB device, a few levels up the registry from the serial device.
	private static func isTree(_ service: io_object_t) -> Bool {
		func number(_ key: String) -> Int? {
			IORegistryEntrySearchCFProperty(service, kIOServicePlane, key as CFString, kCFAllocatorDefault,
			                                IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)) as? Int
		}
		return number("idVendor") == espressifVendor && number("idProduct") == usbSerialJTAG
	}

	// MARK: - Ports

	private func found(_ path: String) {
		guard ports[path] == nil else { return }
		if !open(path) { waiting.insert(path) }
	}

	/// Opens a tree's port for this app alone and sends the hello. False if it cannot be
	/// opened now, for example because a serial monitor has it.
	private func open(_ path: String) -> Bool {
		let fd = Darwin.open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
		guard fd >= 0 else {
			if !waiting.contains(path) {
				print("Trees: cannot open \(path) (\(String(cString: strerror(errno)))); will keep trying")
			}
			return false
		}
		//Exclusive: any further open fails with EBUSY until this one is closed
		if ioctl(fd, TIOCEXCL) != 0 {
			print("Trees: \(path) could not be made exclusive: \(String(cString: strerror(errno)))")
		}
		//Raw bytes. The baud rate means nothing over USB. Opening one doesn't reset the tree,
		//so DTR and RTS are left as they are. Not CLOCAL: with it set, a C6 opened as soon as it
		//had been plugged in took the hello but never sent anything back until it was reset.
		//The same open without it, opened just as soon, never did that.
		var settings = termios()
		if tcgetattr(fd, &settings) == 0 {
			cfmakeraw(&settings)
			tcsetattr(fd, TCSANOW, &settings)
		}

		let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
		let port = Port(path: path, fd: fd, source: source)
		source.setEventHandler { [weak self] in self?.readable(path) }
		source.setCancelHandler { Darwin.close(fd) }
		ports[path] = port
		waiting.remove(path)
		source.resume()

		print("Trees: opened \(path)")
		hello(port)
		return true
	}

	private func hello(_ port: Port) {
		let bytes = Array("\n>h\n".utf8)
		_ = bytes.withUnsafeBufferPointer { Darwin.write(port.fd, $0.baseAddress, $0.count) }
	}

	private func drop(_ path: String, reason: String) {
		guard let port = ports.removeValue(forKey: path) else { return }
		port.source.cancel()
		print("Trees: \(name(of: port)) gone (\(reason))")
		if port.id != nil { membershipChanged() }
	}

	/// Every few seconds: retry ports that could not be opened, and hello every open one,
	/// which claims those that have not answered yet and finds any that restarted
	private func tick() {
		for path in waiting { _ = open(path) }
		ports.values.forEach(hello)
	}

	// MARK: - Reading

	private func readable(_ path: String) {
		guard let port = ports[path] else { return }
		var chunk = [UInt8](repeating: 0, count: 1024)
		let n = chunk.withUnsafeMutableBufferPointer { Darwin.read(port.fd, $0.baseAddress, $0.count) }
		if n == 0 || (n < 0 && errno != EAGAIN && errno != EINTR) {
			//A pty or a device that has gone without IOKit saying so
			drop(path, reason: n == 0 ? "closed" : String(cString: strerror(errno)))
			return
		}
		guard n > 0 else { return }
		port.buffer.append(contentsOf: chunk[0..<n])
		while let newline = port.buffer.firstIndex(of: UInt8(ascii: "\n")) {
			let bytes = port.buffer[port.buffer.startIndex..<newline]
			port.buffer.removeSubrange(port.buffer.startIndex...newline)
			let line = String(decoding: bytes, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
			if !line.isEmpty { received(line, from: port) }
		}
		//A tree that never sends a newline should not grow this for ever
		if port.buffer.count > 4096 { port.buffer.removeAll() }
	}

	private func received(_ line: String, from port: Port) {
		if line == "Serial host" {
			port.fresh = true
			return
		}
		//"<tree <id> <chip> <build date and time>"
		guard line.hasPrefix("<tree ") else {
			print("Tree \(name(of: port)): \(line)")
			return
		}
		let fields = line.split(separator: " ", maxSplits: 3).map(String.init)
		guard fields.count >= 3 else { return }
		let wasClaimed = port.id != nil
		port.id = fields[1]
		port.chip = fields[2]
		port.build = fields.count > 3 ? fields[3] : ""
		if !wasClaimed {
			print("Trees: claimed \(fields[1]) (\(port.chip), built \(port.build)) on \(port.path)")
			membershipChanged()
			sendState(to: port)
		} else if port.fresh {
			//It has restarted since it was claimed and lost everything
			print("Trees: \(fields[1]) restarted")
			identities()
			sendState(to: port)
		}
		port.fresh = false
	}

	// MARK: - State

	private func sendState(to port: Port) {
		write(lastAnimation, to: port)
		write(lastTeamCount, to: port)
		write(lastBrightness, to: port)
	}

	private func membershipChanged() {
		claimed = ports.values.compactMap { $0.id }.sorted()
		identities()
	}

	/// Tells every claimed tree its place, iNNCC, in tree id order. A tree that is somehow
	/// on two ports takes one place, as in trees.js.
	private func identities() {
		let order = Array(Set(claimed)).sorted()
		let count = min(order.count, 99)
		for port in ports.values {
			guard let id = port.id, let index = order.firstIndex(of: id) else { continue }
			write("i" + String(format: "%02d", min(index, 98)) + String(format: "%02d", count), to: port)
		}
	}
}
