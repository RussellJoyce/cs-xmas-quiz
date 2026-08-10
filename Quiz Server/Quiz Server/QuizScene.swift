//
//  QuizScene.swift
//  Quiz Server
//
//  Created by Ian Gray on 2026-08-10.
//  Copyright © 2026 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import SpriteKit

/// Common base class for the quiz round scenes.
///
/// Handles the setup ceremony that every scene was repeating: the run-once guard,
/// sizing the scene, and building a full-screen background layer.
///
/// Every round is a `QuizScene`, and `SpriteKitViewController` holds them as such.
class QuizScene: SKScene {

	/// True once `setUpScene(size:)` has run. Setup is deliberately once-only:
	/// the view controller builds every scene up front and reuses them.
	private(set) var isSetUp = false

	/// The full-screen background sprite, if one was added.
	private(set) var backgroundImage: SKSpriteNode?

	/// The effect node wrapping the background, if `addPulsableBackground` was used.
	/// Pass this to `Utils.createFilterPulse(...)` to build a flash action.
	private(set) var backgroundEffect: SKEffectNode?


	/// Sizes the scene and builds it, at most once. Not overridable: put per-scene
	/// setup in `buildScene()`, which is called with `self.size` already valid.
	final func setUpScene(size: CGSize) {
		if isSetUp {
			return
		}
		isSetUp = true

		self.size = size
		buildScene()
	}

	/// Override point for per-scene setup. Called exactly once, after `size` is set.
	func buildScene() {
	}

	/// Returns the round to its starting state. Called by `SpriteKitViewController`
	/// on every round change, so every round should override this — the empty default
	/// exists only so that `QuizScene` is usable on its own.
	func reset() {
	}


	/// Adds a full-screen background image at the centre of the scene.
	/// - Returns: the sprite, so scenes that parent content to it can keep a reference.
	@discardableResult
	func addBackground(imageNamed name: String, zPosition: CGFloat = 0) -> SKSpriteNode {
		let bgImage = SKSpriteNode(imageNamed: name)
		bgImage.zPosition = zPosition
		bgImage.position = self.centrePoint
		bgImage.size = self.size
		self.addChild(bgImage)

		backgroundImage = bgImage
		return bgImage
	}


	/// Adds a full-screen background image wrapped in an `SKEffectNode` carrying a
	/// `CIExposureAdjust` filter, so the background can be flashed by animating
	/// `inputEV` (see `Utils.createFilterPulse`).
	/// - Parameters:
	///   - initialEV: starting exposure. 0 leaves the image as-is; TimerScene uses 1
	///     to brighten its background permanently.
	///   - shouldRasterize: rasterise the effect node up front. `createFilterPulse`
	///     toggles this around each pulse regardless.
	/// - Returns: the effect node, which is what scenes run the pulse action on.
	@discardableResult
	func addPulsableBackground(imageNamed name: String,
							   initialEV: Double = 0,
							   shouldRasterize: Bool = false,
							   zPosition: CGFloat = 0) -> SKEffectNode {
		let bgImage = SKSpriteNode(imageNamed: name)
		bgImage.zPosition = zPosition
		bgImage.position = self.centrePoint
		bgImage.size = self.size

		let effect = SKEffectNode()
		let exfilter = CIFilter(name: "CIExposureAdjust")
		exfilter?.setDefaults()
		exfilter?.setValue(initialEV, forKey: "inputEV")
		effect.filter = exfilter
		effect.shouldRasterize = shouldRasterize
		effect.addChild(bgImage)
		self.addChild(effect)

		backgroundImage = bgImage
		backgroundEffect = effect
		return effect
	}
}
