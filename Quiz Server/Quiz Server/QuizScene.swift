//
//  QuizScene.swift
//  Quiz Server
//
//  Created by Ian Gray on 2026-08-10.
//  Copyright © 2026 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import SpriteKit

/// Geometry for a grid of team boxes, one box per team.
struct TeamGridLayout {
	/// Width of each box.
	let boxWidth: Int
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

		return TeamGridLayout(boxWidth: 600, boxHeight: boxHeight, fontSize: boxHeight >= 150 ? 60 : 40, positions: positions)
	}


	/// Works out where the team boxes go for the rounds that give each team a small box
	/// rather than a wide one: a centred grid of near-square cells, filled left to right
	/// and top to bottom, sized to whatever space the caller has left over.
	///
	/// Unlike `teamGridLayout`, the number of columns follows the number of teams, so
	/// fourteen teams get 5x3 rather than a pair of long columns.
	/// - Parameters:
	///   - top: y of the top edge of the grid.
	///   - bottom: y of the bottom edge, leaving room for whatever sits below it.
	///   - sideMargin: space kept clear at each side of the scene.
	func teamSquareGridLayout(top: CGFloat, bottom: CGFloat, sideMargin: CGFloat = 120) -> TeamGridLayout {
		let numTeams = max(1, Settings.shared.numTeams)

		//Enough columns to keep the cells from growing long and thin, but few enough that
		//a small quiz still gets big boxes.
		let columns: Int
		switch numTeams {
		case 1...4:   columns = 2
		case 5...6:   columns = 3
		case 7...10:  columns = 4
		default:      columns = 5
		}
		let rows = Int((Double(numTeams) / Double(columns)).rounded(.up))

		let cellWidth = (self.size.width - (2 * sideMargin)) / CGFloat(columns)
		let cellHeight = (top - bottom) / CGFloat(rows)
		//The gap between boxes is taken out of the cell, so the grid as a whole still
		//fills the space it was given.
		let boxWidth = Int(cellWidth * 0.9)
		let boxHeight = Int(cellHeight * 0.88)

		var positions = [CGPoint]()
		for team in 0..<numTeams {
			let row = team / columns
			let column = team % columns
			//A short last row is centred under the ones above rather than left-aligned.
			let inThisRow = min(columns, numTeams - (row * columns))
			let rowWidth = CGFloat(inThisRow) * cellWidth
			let rowLeft = (self.size.width - rowWidth) / 2
			positions.append(CGPoint(
				x: rowLeft + (CGFloat(column) + 0.5) * cellWidth,
				y: top - (CGFloat(row) + 0.5) * cellHeight
			))
		}

		//Roughly a third of the box height reads well for a couple of characters, and is
		//held back from growing silly when there are only a few teams.
		let fontSize = min(CGFloat(boxHeight) * 0.42, 110)

		return TeamGridLayout(boxWidth: boxWidth, boxHeight: boxHeight,
							  fontSize: fontSize, positions: positions)
	}


	/// Adds a wide emitter along the top edge of the scene, pre-simulated so that it is
	/// already falling across the screen the moment the round appears.
	///
	/// Scenes re-create these on every `didMove(to:)`, so pass the previous emitter as
	/// `replacing` and assign the result back to the same property
	///
	///     snow = addSnow(replacing: snow, emitterNamed: "Snow", zPosition: 20)
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
	
	
	@discardableResult
	func addBokehBackground(replacing existing: SKEmitterNode?,
							textureName: String,
							zPosition: CGFloat,
							preSimulate: TimeInterval = 8) -> SKEmitterNode?
	{
		existing?.removeFromParent()
		
		let bok = SKEmitterNode()
		bok.particleTexture = SKTexture(imageNamed: textureName)
		bok.position = self.centrePoint
		bok.zPosition = zPosition
		bok.particlePositionRange = CGVector(dx: self.size.width, dy: self.size.height)
		bok.particleBirthRate = 20
		bok.particleLifetime = 10
		bok.particleLifetimeRange = 0
		bok.particleScale = 1.5
		bok.particleScaleRange = 2
		bok.particleScaleSpeed = 0.03
		bok.particleRotationRange = 2 * .pi
		bok.particleSpeed = 0
		bok.particleSpeedRange = 10
		bok.emissionAngleRange = 2 * .pi
		
		let fade = SKKeyframeSequence(keyframeValues: [0.0, 0.3, 0.0], times: [0.0, 0.5, 1.0])
		fade.interpolationMode = .spline
		bok.particleAlphaSequence = fade
		
		bok.advanceSimulationTime(preSimulate)
		self.addChild(bok)
		return bok
	}
}

