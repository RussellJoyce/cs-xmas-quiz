//
//  TeletextNode.swift
//  Quiz Server
//
//  Created by Ian Gray on 2026-09-17.
//  Copyright © 2026 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import SpriteKit


/// A teletext screen: a header row, a page under it, and an optional strip overlaid on
/// top of the page (used for newsflashes).
///
/// The node's own origin is the top left corner of the screen, because pages are laid out
/// from the top down.
///
/// Rendering a grid costs a bitmap and a texture upload, so each layer is only redrawn
/// when its grid has actually changed. Call `refresh()` once a frame to let that happen.
final class TeletextNode: SKNode {

	/// One thing drawn on screen: the solid part, plus a second sprite holding just the
	/// flashing cells, which blinks over the top.
	private final class Layer {
		let solid = SKSpriteNode()
		let flash = SKSpriteNode()
		var grid: TeletextGrid?
		var dirty = false

		init(zPosition: CGFloat) {
			for sprite in [solid, flash] {
				sprite.anchorPoint = CGPoint(x: 0, y: 1)
				sprite.zPosition = zPosition
			}
			flash.zPosition = zPosition + 0.1
			flash.run(SKAction.repeatForever(SKAction.sequence([
				SKAction.fadeAlpha(to: 1, duration: 0),
				SKAction.wait(forDuration: 0.64),
				SKAction.fadeAlpha(to: 0, duration: 0),
				SKAction.wait(forDuration: 0.36)
			])))
		}
	}

	let cellSize: CGSize
	let columns: Int

	/// Width and height of the whole screen, header included.
	var screenSize: CGSize {
		CGSize(width: cellSize.width * CGFloat(columns),
			   height: cellSize.height * CGFloat(TeletextGrid.bodyRows + 1))
	}

	private let headerLayer = Layer(zPosition: 2)
	private let bodyLayer = Layer(zPosition: 1)
	private let overlayLayer = Layer(zPosition: 3)
	private var overlayRow = 0


	init(cellSize: CGSize, columns: Int = TeletextGrid.standardColumns) {
		self.cellSize = cellSize
		self.columns = columns
		super.init()

		for layer in [headerLayer, bodyLayer, overlayLayer] {
			addChild(layer.solid)
			addChild(layer.flash)
		}
		positionLayer(headerLayer, atRow: 0)
		positionLayer(bodyLayer, atRow: 1)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}


	// MARK: - Contents

	/// The header row, which changes every second as the clock ticks.
	var header: TeletextGrid? {
		didSet { headerLayer.grid = header; headerLayer.dirty = true }
	}

	/// The page itself, occupying the 24 rows below the header.
	var page: TeletextGrid? {
		didSet { bodyLayer.grid = page; bodyLayer.dirty = true }
	}

	/// A strip drawn over the page, starting at screen row `row` (so row 1 is the first
	/// row under the header). Setting nil takes it away again.
	func setOverlay(_ grid: TeletextGrid?, atRow row: Int) {
		overlayRow = row
		overlayLayer.grid = grid
		overlayLayer.dirty = true
		positionLayer(overlayLayer, atRow: row)
	}


	/// Redraws whichever layers have changed. Cheap when nothing has.
	func refresh() {
		for layer in [headerLayer, bodyLayer, overlayLayer] where layer.dirty {
			layer.dirty = false
			apply(layer.grid, to: layer.solid, flashingOnly: false)
			apply(layer.grid, to: layer.flash, flashingOnly: true)
		}
	}


	// MARK: - Drawing

	private func apply(_ grid: TeletextGrid?, to sprite: SKSpriteNode, flashingOnly: Bool) {
		guard let grid, let image = TeletextRenderer.render(grid, cellSize: cellSize, flashingOnly: flashingOnly) else {
			sprite.texture = nil
			sprite.isHidden = true
			return
		}
		sprite.texture = SKTexture(cgImage: image)
		sprite.size = CGSize(width: cellSize.width * CGFloat(grid.columns),
							 height: cellSize.height * CGFloat(grid.rowCount))
		sprite.isHidden = false
	}

	private func positionLayer(_ layer: Layer, atRow row: Int) {
		let y = -CGFloat(row) * cellSize.height
		layer.solid.position = CGPoint(x: 0, y: y)
		layer.flash.position = CGPoint(x: 0, y: y)
	}
}
