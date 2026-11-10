//
//  SharedFrameFile.swift
//  Quiz Server
//
//  A read-only mapping of one of the files the LED simulators publish into: ledsim's strip
//  (quizleds/sim/frameshm.h) and treesim's trees (quizleds/sim/treeshm.h).
//

import Foundation

/// Both formats start with the same header fields: a magic number at 0, a version at 4 and a
/// CLOCK_REALTIME heartbeat, as a Double, at 16. The rest is up to the reader.
final class SharedFrameFile {

	static let magicOffset = 0
	static let versionOffset = 4
	static let heartbeatOffset = 16

	/// How long the heartbeat may go unwritten before the simulator counts as gone
	static let staleAfter: TimeInterval = 0.5

	private let path: String
	private let size: Int
	private let magic: UInt32
	private let version: UInt32
	private var fd: Int32 = -1
	private var base: UnsafeRawPointer?
	private var lastOpenAttempt: Date = .distantPast

	init(path: String, size: Int, magic: UInt32, version: UInt32) {
		self.path = path
		self.size = size
		self.magic = magic
		self.version = version
	}

	deinit {
		if let base = base { munmap(UnsafeMutableRawPointer(mutating: base), size) }
		if fd >= 0 { close(fd) }
	}

	/// The mapping, if the file is there and a simulator has claimed it with the expected
	/// magic and version. Says nothing about whether that simulator is still running: see `isLive`.
	var claimed: UnsafeRawPointer? {
		guard ensureMapped(), let base = base,
		      load(UInt32.self, SharedFrameFile.magicOffset) == magic,
		      load(UInt32.self, SharedFrameFile.versionOffset) == version else { return nil }
		return base
	}

	/// The heartbeat is recent. Only meaningful once `claimed` has returned a mapping.
	var isLive: Bool {
		let age = Date().timeIntervalSince1970 - load(Double.self, SharedFrameFile.heartbeatOffset)
		return age < SharedFrameFile.staleAfter
	}

	func load<T>(_ type: T.Type, _ offset: Int) -> T {
		base!.load(fromByteOffset: offset, as: T.self)
	}

	func bytes(_ offset: Int, _ count: Int) -> [UInt8] {
		[UInt8](UnsafeRawBufferPointer(start: base! + offset, count: count))
	}

	/// A NUL-terminated string of at most `count` bytes
	func string(_ offset: Int, _ count: Int) -> String {
		let raw = bytes(offset, count)
		let end = raw.firstIndex(of: 0) ?? raw.count
		return String(decoding: raw[..<end], as: UTF8.self)
	}

	/// Maps the file, creating it if it is not there yet. Whichever of the two processes
	/// starts first creates it; a fresh file is zero-filled, so `magic` reads as 0 and the
	/// region is correctly reported as unclaimed until the simulator initialises it.
	private func ensureMapped() -> Bool {
		if base != nil { return true }

		//Retry occasionally rather than on every frame, so a missing file is not 60 failed
		//open() calls a second.
		guard Date().timeIntervalSince(lastOpenAttempt) > 1.0 else { return false }
		lastOpenAttempt = Date()

		//O_RDWR is needed to create and size the file; the mapping itself is read-only.
		let handle = open(path, O_RDWR | O_CREAT, 0o600)
		guard handle >= 0 else { return false }

		var st = stat()
		if fstat(handle, &st) != 0 || st.st_size < off_t(size) {
			if ftruncate(handle, off_t(size)) != 0 {
				close(handle)
				return false
			}
		}

		let p = mmap(nil, size, PROT_READ, MAP_SHARED, handle, 0)
		guard let p = p, p != MAP_FAILED else {
			close(handle)
			return false
		}

		fd = handle
		base = UnsafeRawPointer(p)
		return true
	}
}
