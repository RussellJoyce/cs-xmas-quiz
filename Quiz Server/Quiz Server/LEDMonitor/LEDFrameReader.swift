//
//  LEDFrameReader.swift
//  Quiz Server
//
//  Reads the LED strip that ledsim publishes into a shared-memory file, so the controller
//  window can show what the real strip would be doing.
//

import Foundation

/// Reader for the frame region written by `quizleds/sim/frameshm.cpp`.
///
/// The field offsets below are written out by hand rather than shared through a bridging
/// header. `quizleds/sim/frameshm.h` is the authority: it pins every one of them with a
/// `static_assert`, so the C++ side cannot drift without failing to build. `magic` and
/// `version` catch the case where it drifts anyway.
///
final class LEDFrameReader {

	enum State {
		case absent
		case live
	}

	struct Frame {
		let pixels: [UInt8]     //count * 3, RGB
		let count: Int
		let seq: UInt32
		let frames: UInt64
	}

	//MARK: - Layout. Mirrors struct FrameShm in quizleds/sim/frameshm.h.

	private enum Off {
		static let magic     = 0
		static let version   = 4
		static let seq       = 8
		static let count     = 12
		static let heartbeat = 16
		static let frames    = 24
		static let lookup    = 32
		static let rgb       = 544
	}
	private static let magicValue: UInt32 = 0x4C45_4431   //"LED1"
	private static let version: UInt32 = 1
	private static let maxLEDs = 512
	private static let size = 2080

	/// How long the heartbeat may go unwritten before the simulator counts as gone
	private static let staleAfter: TimeInterval = 0.5

	static let defaultPath = "/tmp/quizledsim.frame"

	//MARK: - State

	private let path: String
	private var fd: Int32 = -1
	private var base: UnsafeRawPointer?
	private var lastOpenAttempt: Date = .distantPast

	/// `ledlookup`, published by ledsim so this side never needs its own copy of the table.
	private(set) var lookup: [UInt8] = []

	private var fpsFrames: UInt64 = 0
	private var fpsSampled: Date = .distantPast
	private(set) var framesPerSecond: Double?

	init(path: String = LEDFrameReader.defaultPath) {
		self.path = path
	}

	deinit {
		if let base = base { munmap(UnsafeMutableRawPointer(mutating: base), LEDFrameReader.size) }
		if fd >= 0 { close(fd) }
	}

	//MARK: - Reading

	/// Samples the current frame. Returns `.absent` with the last frame still attached when
	/// the simulator has gone away, so the caller can grey out what was last shown.
	func poll() -> (state: State, frame: Frame?) {
		guard ensureMapped(), let base = base else { return (.absent, nil) }

		guard load(UInt32.self, Off.magic) == LEDFrameReader.magicValue,
		      load(UInt32.self, Off.version) == LEDFrameReader.version else {
			return (.absent, nil)
		}

		let frame = readFrame(base)
		let age = Date().timeIntervalSince1970 - load(Double.self, Off.heartbeat)
		let state: State = age < LEDFrameReader.staleAfter ? .live : .absent

		if lookup.isEmpty {
			lookup = [UInt8](UnsafeRawBufferPointer(start: base + Off.lookup,
			                                        count: LEDFrameReader.maxLEDs))
		}
		updateRate(frame, state)
		return (state, frame)
	}

	/// Seqlock read: `seq` is odd while ledsim is mid-write, and changes across the copy if
	/// a frame landed while we were reading. This could tear but...mneh
	private func readFrame(_ base: UnsafeRawPointer) -> Frame? {
		for _ in 0..<8 {
			let seq = load(UInt32.self, Off.seq)
			if seq & 1 == 1 { continue }

			let count = Int(load(UInt32.self, Off.count))
			guard count > 0, count <= LEDFrameReader.maxLEDs else { return nil }
			let frames = load(UInt64.self, Off.frames)
			let pixels = [UInt8](UnsafeRawBufferPointer(start: base + Off.rgb, count: count * 3))

			if load(UInt32.self, Off.seq) == seq {
				return Frame(pixels: pixels, count: count, seq: seq, frames: frames)
			}
		}
		return nil
	}

	private func load<T>(_ type: T.Type, _ offset: Int) -> T {
		base!.load(fromByteOffset: offset, as: T.self)
	}

	private func updateRate(_ frame: Frame?, _ state: State) {
		guard state == .live, let frame = frame else {
			framesPerSecond = nil
			fpsSampled = .distantPast
			return
		}
		let now = Date()
		if fpsSampled == .distantPast {
			fpsFrames = frame.frames
			fpsSampled = now
			return
		}
		let elapsed = now.timeIntervalSince(fpsSampled)
		if elapsed >= 1.0 {
			framesPerSecond = Double(frame.frames &- fpsFrames) / elapsed
			fpsFrames = frame.frames
			fpsSampled = now
		}
	}

	//MARK: - Mapping

	/// Maps the file, creating it if it is not there yet. Whichever of the two processes
	/// starts first creates it; a fresh file is zero-filled, so `magic` reads as 0 and the
	/// region is correctly reported as unclaimed until ledsim initialises it.
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
		if fstat(handle, &st) != 0 || st.st_size < off_t(LEDFrameReader.size) {
			if ftruncate(handle, off_t(LEDFrameReader.size)) != 0 {
				close(handle)
				return false
			}
		}

		let p = mmap(nil, LEDFrameReader.size, PROT_READ, MAP_SHARED, handle, 0)
		guard let p = p, p != MAP_FAILED else {
			close(handle)
			return false
		}

		fd = handle
		base = UnsafeRawPointer(p)
		return true
	}
}
