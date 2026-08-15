//
//  QuizScene.swift
//  Quiz Server
//
//  Created by Ian Gray on 2026-08-10.
//  Copyright © 2026 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import SpriteKit

/// Geometry for the two-column grid of team boxes used by the guessing rounds.
struct TeamGridLayout {
	/// Height of each box, reduced when there are enough teams to need it.
	let boxHeight: Int
	/// Matching label size: text shrinks along with the boxes rather than against them.
	let fontSize: CGFloat
	/// One position per team, indexed by zero-based team number.
	let positions: [CGPoint]
}


/// Common base class for the quiz round scenes.
/// Every round is a `QuizScene`, held by a `SpriteKitViewController`
class QuizScene: SKScene {

	/// True once `setUpScene(size:)` has run.
	private(set) var isSetUp = false

	/// The effect node wrapping the background, if `addPulsableBackground` was used.
	/// Pass this to `Utils.createFilterPulse(...)` to build a flash action.
	private(set) var backgroundEffect: SKEffectNode?

	/// Sizes the scene and builds it, at most once.
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

	/// Returns the round to its starting state. Called by `SpriteKitViewController` on every round change
	func reset() {
	}

	/// Called when this round is switched away from
	func teardown() {
	}

	/// A team has buzzed while this round is live.
	func buzzerPressed(team: Int, type: BuzzerType, options: BuzzerOptions) {
	}

	/// Which teams are playing, indexed by zero-based team number
	func setParticipating(_ teams: [Bool]) {
	}

	override func willMove(from view: SKView) {
		super.willMove(from: view)
		teardown()
	}

	
	/// Adds a full-screen background image at the centre of the scene.
	/// - Returns: the sprite, so scenes that parent content to it can keep a reference.
	@discardableResult
	func addBackground(imageNamed name: String, zPosition: CGFloat = 0) -> SKSpriteNode {
		return addBackground(SKSpriteNode(imageNamed: name), zPosition: zPosition)
	}

	/// As `addBackground(imageNamed:)`, but for a background drawn rather than loaded
	/// (Idle2Scene renders a gradient).
	@discardableResult
	func addBackground(texture: SKTexture, zPosition: CGFloat = 0) -> SKSpriteNode {
		return addBackground(SKSpriteNode(texture: texture), zPosition: zPosition)
	}

	@discardableResult
	private func addBackground(_ sprite: SKSpriteNode, zPosition: CGFloat) -> SKSpriteNode {
		sprite.zPosition = zPosition
		sprite.position = self.centrePoint
		sprite.size = self.size
		self.addChild(sprite)
		return sprite
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

		backgroundEffect = effect
		return effect
	}


	/// Works out where the team boxes go for the rounds that show every team at once:
	/// two columns either side of the centre line, filling the left column from the top
	/// down and then the right. Boxes shrink once there are more than ten teams.
	/// - Parameter xOffset: distance of each column from the centre line.
	func teamGridLayout(xOffset: CGFloat = 500) -> TeamGridLayout {
		let numTeams = Settings.shared.numTeams
		let halfway = Int((Double(numTeams) / 2).rounded(.up))
		let boxHeight = numTeams > 10 ? 100 : 150
		let spacing = Int(Double(boxHeight) * 1.3)

		var positions = [CGPoint]()
		for team in 0..<numTeams {
			//Row down from the top of whichever column this team sits in
			let row = (team < halfway) ? team : (team - halfway)
			let yOffset = ((halfway - 1) - row) * spacing
			positions.append(CGPoint(
				x: (team < halfway) ? self.centrePoint.x - xOffset : self.centrePoint.x + xOffset,
				y: CGFloat(boxHeight + 10 + yOffset)
			))
		}

		return TeamGridLayout(boxHeight: boxHeight, fontSize: boxHeight >= 150 ? 60 : 40, positions: positions)
	}


	/// Adds a wide emitter along the top edge of the scene, pre-simulated so that it is
	/// already falling across the screen the moment the round appears.
	///
	/// Scenes re-create these on every `didMove(to:)`, so pass the previous emitter as
	/// `replacing` and assign the result back to the same property — otherwise a new
	/// emitter is added on each visit and the old ones are never torn down:
	///
	///     snow = addSnow(replacing: snow, emitterNamed: "Snow", zPosition: 20)
	///
	/// - Returns: the new emitter, or nil if the .sks file could not be loaded.
	@discardableResult
	func addSnow(replacing existing: SKEmitterNode?,
				 emitterNamed name: String,
				 zPosition: CGFloat,
				 xOffset: CGFloat = 0,
				 preSimulate: TimeInterval = 8,
				 configure: ((SKEmitterNode) -> Void)? = nil) -> SKEmitterNode? {
		existing?.removeFromParent()

		guard let snow = SKEmitterNode(fileNamed: name) else {
			return nil
		}
		snow.position = CGPoint(x: (self.size.width / 2) + xOffset, y: self.size.height + 16)
		snow.zPosition = zPosition
		configure?(snow)
		snow.advanceSimulationTime(preSimulate)
		self.addChild(snow)
		return snow
	}
}
