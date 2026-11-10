//
//  TreeFrameReader.swift
//  Quiz Server
//
//  Reads the desk trees that treesim publishes into a shared-memory file, so the controller
//  window can show what the real trees would be doing.
//

import Foundation

/// Reader for the file written by `quizleds/sim/treesim.cpp`.
///
/// As for `LEDFrameReader`, the offsets are written out by hand. `quizleds/sim/treeshm.h` is
/// the authority, and treesim.cpp pins every one of them with a `static_assert`.
final class TreeFrameReader {

	enum Process: UInt32 {
		case dead = 0, running = 1, frozen = 2
	}

	struct Tree: Equatable {
		let id: String
		let process: Process
		let connected: Bool
		/// The tree's place among those connected, from the server's last `iNNCC`, or nil before one
		let place: (index: Int, count: Int)?
		/// The bytes sent to the LEDs, LED 0 (the top of the ring) first, then clockwise
		let pixels: [UInt8]
		let seq: UInt32
		let frames: UInt64
		/// The last command the tree was sent
		let last: String

		static func == (a: Tree, b: Tree) -> Bool {
			a.id == b.id && a.process == b.process && a.connected == b.connected &&
			a.place?.index == b.place?.index && a.place?.count == b.place?.count &&
			a.seq == b.seq && a.last == b.last
		}
	}

	//MARK: - Layout. Mirrors struct TreeShm in quizleds/sim/treeshm.h.

	private enum Off {
		static let trees     = 8
		static let leds      = 12
		static let slots     = 32
	}
	private enum Slot {
		static let size      = 96
		static let seq       = 0
		static let process   = 4
		static let frames    = 8
		static let index     = 16
		static let count     = 20
		static let connected = 24
		static let id        = 32
		static let rgb       = 40
		static let last      = 64
	}
	private static let maxTrees = 32
	static let ledsPerTree = 8
	private static let size = 3104

	static let defaultPath = "/tmp/quiztreesim.frame"

	private let file: SharedFrameFile

	init(path: String = TreeFrameReader.defaultPath) {
		file = SharedFrameFile(path: path, size: TreeFrameReader.size,
		                       magic: 0x5452_4531,   //"TRE1"
		                       version: 1)
	}

	/// Whether treesim is running, and its trees in the order it runs them, which is also the
	/// order the server places them in
	func poll() -> (live: Bool, trees: [Tree]) {
		guard file.claimed != nil else { return (false, []) }
		guard file.load(UInt32.self, Off.leds) == UInt32(TreeFrameReader.ledsPerTree) else { return (false, []) }

		let count = min(Int(file.load(UInt32.self, Off.trees)), TreeFrameReader.maxTrees)
		let trees = (0..<count).map { readTree(Off.slots + $0 * Slot.size) }
		return (file.isLive, trees)
	}

	/// Seqlock read of the ring, as in `LEDFrameReader`. If every attempt overlaps a write the
	/// last copy is used anyway: a torn frame for one poll is better than the tree vanishing
	/// and its neighbours shuffling along. The other fields are each a single aligned word,
	/// and only shown as text, so they are read as they stand.
	private func readTree(_ at: Int) -> Tree {
		var seq: UInt32 = 0
		var pixels: [UInt8] = []
		var frames: UInt64 = 0
		for _ in 0..<8 {
			seq = file.load(UInt32.self, at + Slot.seq)
			if seq & 1 == 1 { continue }
			pixels = file.bytes(at + Slot.rgb, TreeFrameReader.ledsPerTree * 3)
			frames = file.load(UInt64.self, at + Slot.frames)
			if file.load(UInt32.self, at + Slot.seq) == seq { break }
		}

		let index = Int(file.load(Int32.self, at + Slot.index))
		let count = Int(file.load(Int32.self, at + Slot.count))
		return Tree(id: file.string(at + Slot.id, 8),
		            process: Process(rawValue: file.load(UInt32.self, at + Slot.process)) ?? .dead,
		            connected: file.load(UInt32.self, at + Slot.connected) != 0,
		            place: index >= 0 && count >= 0 ? (index, count) : nil,
		            pixels: pixels, seq: seq, frames: frames,
		            last: file.string(at + Slot.last, 32))
	}
}
