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
/// `version` catch the case where it drifts anyway. The mapping itself, and the header
/// fields both simulators share, are in `SharedFrameFile`.
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
		static let seq       = 8
		static let count     = 12
		static let frames    = 24
		static let lookup    = 32
		static let rgb       = 544
	}
	private static let maxLEDs = 512
	private static let size = 2080

	static let defaultPath = "/tmp/quizledsim.frame"

	//MARK: - State

	private let file: SharedFrameFile

	/// `ledlookup`, published by ledsim so this side never needs its own copy of the table.
	private(set) var lookup: [UInt8] = []

	private var fpsFrames: UInt64 = 0
	private var fpsSampled: Date = .distantPast
	private(set) var framesPerSecond: Double?

	init(path: String = LEDFrameReader.defaultPath) {
		file = SharedFrameFile(path: path, size: LEDFrameReader.size,
		                       magic: 0x4C45_4431,   //"LED1"
		                       version: 1)
	}

	//MARK: - Reading

	/// Samples the current frame. Returns `.absent` with the last frame still attached when
	/// the simulator has gone away, so the caller can grey out what was last shown.
	func poll() -> (state: State, frame: Frame?) {
		guard file.claimed != nil else { return (.absent, nil) }

		let frame = readFrame()
		let state: State = file.isLive ? .live : .absent

		if lookup.isEmpty {
			lookup = file.bytes(Off.lookup, LEDFrameReader.maxLEDs)
		}
		updateRate(frame, state)
		return (state, frame)
	}

	/// Seqlock read: `seq` is odd while ledsim is mid-write, and changes across the copy if
	/// a frame landed while we were reading. This could tear but...mneh
	private func readFrame() -> Frame? {
		for _ in 0..<8 {
			let seq = file.load(UInt32.self, Off.seq)
			if seq & 1 == 1 { continue }

			let count = Int(file.load(UInt32.self, Off.count))
			guard count > 0, count <= LEDFrameReader.maxLEDs else { return nil }
			let frames = file.load(UInt64.self, Off.frames)
			let pixels = file.bytes(Off.rgb, count * 3)

			if file.load(UInt32.self, Off.seq) == seq {
				return Frame(pixels: pixels, count: count, seq: seq, frames: frames)
			}
		}
		return nil
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
}
