//
//  MusicScene.swift
//  Quiz Server
//
//  Created by Russell Joyce on 03/12/2019.
//  Copyright © 2019 Russell Joyce & Ian Gray. All rights reserved.
//

import Cocoa
import SpriteKit
import AVFoundation

class MusicScene: QuizScene {
	
	var useLEDs : NSButton?
	
	var buzzNumber = 0
	var firstBuzzTime: Date?
	var teamEnabled = [Bool](repeating: true, count: 15)
	var buzzes = [Int]() { didSet { onQueueChanged?() } }
	var nextTeamNumber = 0 { didSet { onQueueChanged?() } }

	/// Called whenever a team joins the queue, the highlight moves on, or it is cleared
	var onQueueChanged: (() -> Void)?
	var buzzNoises = [SKAction]()
	var teamBoxes = [BuzzerTeamNode]()
	/// What is loaded. Only one thing at a time, so a buzz can never be handled as video
	/// while music is playing, or the other way round.
	enum Track {
		case none
		case audio(AVAudioPlayer)
		case video(SKVideoNode, AVPlayer)
	}
	private(set) var track: Track = .none
	var videoEffect = SKEffectNode()

	var isVideo: Bool {
		if case .video = track { return true }
		return false
	}

	private var audioPlayer: AVAudioPlayer? {
		if case .audio(let player) = track { return player }
		return nil
	}
	
	private var lastMusicUpdateTime: TimeInterval = 0
	private let musicUpdateFPS: Double = 30.0

	private var avgPowerBarLeft: SKShapeNode?
	private var avgPowerBarRight: SKShapeNode?
	private var peakMarkerLeft: SKShapeNode?
	private var peakMarkerRight: SKShapeNode?
	
	var lastAltBuzzIndex = 0
	
    func normalisePower(power: Float) -> Float {
        return pow(10.0, min(power, 0.0)/20.0)
    }
    
	func boostPower(power: Float) -> Float {
		let new = power * 1.3
		return new > 1.0 ? 1.0 : new
	}
	
    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        
        let dt = currentTime - lastMusicUpdateTime
        if dt < (1.0 / musicUpdateFPS) {
            return
        }
        lastMusicUpdateTime = currentTime
        
        if let music = audioPlayer, music.isPlaying {
			music.updateMeters()
			
			if useLEDs?.state == .on {
				let peakL = normalisePower(power: music.peakPower(forChannel: 0))
				let peakR = normalisePower(power: music.peakPower(forChannel: 1))
				let avgL = normalisePower(power: music.averagePower(forChannel: 0))
				let avgR = normalisePower(power: music.averagePower(forChannel: 1))
				QuizWebSocket.shared?.setMusicLevels(leftAvg: Int(avgL*100), leftPeak: Int(peakL*100), rightAvg: Int(avgR*100), rightPeak: Int(peakR*100))
			}
        }
    }
    
	override func buildScene() {
        buzzNoises.append(Sound.effect("scratch1"))
        buzzNoises.append(Sound.effect("scratch2"))
        buzzNoises.append(Sound.effect("scratch3"))
		
		addBackground(imageNamed: "music2")

		videoEffect.name = "videoEffect"
		videoEffect.filter = CIFilter(name: "CIGaussianBlur")
		videoEffect.filter?.setDefaults()
		videoEffect.filter?.setValue(0, forKey: "inputRadius")
		videoEffect.shouldEnableEffects = true
		videoEffect.zPosition = 1000
		self.addChild(videoEffect)
	}
	
	func buzzSound() {
        // Play random buzzer sound
        if let buzzNoise = buzzNoises.randomElement() {
            self.run(buzzNoise)
        }
    }
	
	/// Stops (back to the start) and clears the buzzes, leaving the track loaded.
	/// Also called on entering the round, so it always starts from the top.
	override func reset() {
		stop()
		clearBuzzes()
	}

	/// Clears the buzzes and shuts the buzzers, without touching the playhead
	private func clearBuzzes() {
		teamEnabled = [Bool](repeating: false, count: Settings.shared.numTeams)
		buzzNumber = 0
		buzzes.removeAll()
		nextTeamNumber = 0
		
		for teamBox in teamBoxes {
			teamBox.removeFromParent()
		}
		teamBoxes.removeAll()
		
		videoEffect.filter?.setValue(0, forKey: "inputRadius")
	}
	
	/// Where a team's box goes and how it looks
	private struct BuzzerBoxLayout {
		var width : Int
		var height : Int
		var fontSize : CGFloat
		var position : CGPoint
		var addGlow = false
		var altText : String? = nil
	}

	override func buzzerPressed(team: Int, type: BuzzerType, options: BuzzerOptions) {
		guard teamEnabled[team], buzzes.count < 5 || options.buzzcocksMode else { return }
		teamEnabled[team] = false
		buzzes.append(team)

		let isFirstBuzz = buzzNumber == 0
		if isFirstBuzz {
			nextTeamNumber = 1
		}

		if isVideo {
			if isFirstBuzz {
				buzzSound()
				pause()
				QuizWebSocket.shared?.buzz(team: team)
			}
			if options.blankVideo {
				videoEffect.filter?.setValue(40, forKey: "inputRadius")
			}
		} else if isFirstBuzz && !options.buzzcocksMode {
			//We are playing music, and stop dead on the first buzz rather than
			//letting every team queue up behind it
			firstBuzzTime = Date()
			buzzSound()
			pause()
			QuizWebSocket.shared?.buzz(team: team)
		}

		let layout = buzzerBoxLayout(team: team, isFirstBuzz: isFirstBuzz, options: options)
		let box = BuzzerTeamNode(team: team,
								 width: layout.width,
								 height: layout.height,
								 fontSize: layout.fontSize,
								 addGlow: layout.addGlow,
								 entranceShimmer: true,
								 altText: layout.altText,
								 style: .glossy)
		box.position = layout.position
		box.zPosition = 1
		teamBoxes.append(box)
		self.addChild(box)

		buzzNumber += 1
	}

	/// The layout varies with the medium, whether this is the first buzz, and whether
	/// buzzcocks mode is queueing every team with their time rather than showing one.
	private func buzzerBoxLayout(team: Int, isFirstBuzz: Bool, options: BuzzerOptions) -> BuzzerBoxLayout {
		let centreX = self.centrePoint.x
		let top = self.size.height

		if isVideo {
			return BuzzerBoxLayout(width: 350, height: 90, fontSize: 50,
								   position: CGPoint(x: 250, y: (top - 230) - CGFloat(buzzNumber * 120)), addGlow: isFirstBuzz)
		}

		if !options.buzzcocksMode {
			return isFirstBuzz
				? BuzzerBoxLayout(width: 1000, height: 200, fontSize: 150,
								  position: CGPoint(x: centreX, y: top - 160),
								  addGlow: true)
				: BuzzerBoxLayout(width: 800, height: 130, fontSize: 100,
								  position: CGPoint(x: centreX, y: (top - 230) - CGFloat(buzzNumber * 175)))
		}

		//Buzzcocks mode: every team gets a row showing how long they took
		let altText = "Team \(team + 1) \(timeSinceFirstBuzz())"
		if isFirstBuzz {
			return BuzzerBoxLayout(width: 1000, height: 90, fontSize: 80,
								   position: CGPoint(x: centreX, y: top - 100),
								   altText: altText)
		}
		//We have a few layouts for larger team numbers
		if Settings.shared.numTeams <= 10 {
			return BuzzerBoxLayout(width: 1000, height: 90, fontSize: 80,
								   position: CGPoint(x: centreX, y: (top - 100) - CGFloat(buzzNumber * 100)),
								   altText: altText)
		}
		return BuzzerBoxLayout(width: 1000, height: 60, fontSize: 50, //This will work up to about 15
							   position: CGPoint(x: centreX, y: (top - 120) - CGFloat(buzzNumber * 65)),
							   altText: altText)
	}

	/// Time since the first team buzzed, as "(1.4 sec)".
	private func timeSinceFirstBuzz() -> String {
		guard let startTime = firstBuzzTime else { return "()" }
		let elapsed = Date().timeIntervalSince(startTime)
		let wholeSeconds = Int(elapsed)
		let tenthsOfSecond = Int((elapsed - Double(wholeSeconds)) * 10)
		return "(\(String(format: "%d.%d", wholeSeconds, tenthsOfSecond)) sec)"
	}
	
	override func teardown() {
		//Coming back to the round resets it, which goes back to the start. The LEDs are
		//left alone: this runs once the transition has finished, by which time the
		//incoming round has already set them.
		pausePlayer()
	}

	/// Whether a team has buzzed behind the one currently highlighted
	var hasNextTeam: Bool { nextTeamNumber < buzzes.count }

	func nextTeam() {
		if hasNextTeam {
			teamBoxes[nextTeamNumber-1].run(SKAction.fadeAlpha(to: 0.3, duration: 0.5))
			teamBoxes[nextTeamNumber-1].stopGlow()
			teamBoxes[nextTeamNumber].startGlow()
			let team = buzzes[nextTeamNumber]
			QuizWebSocket.shared?.setTeamColour(team)
			nextTeamNumber += 1
		}
	}
    
	static let audioExtensions: Set<String> = ["mp3", "wav"]
	static let videoExtensions: Set<String> = ["mov", "mp4", "mpeg", "avi"]

	/// Replaces whatever was loaded, clearing the buzzes. Returns false if the file could
	/// not be opened, which leaves nothing loaded.
	@discardableResult
	func load(file: String) -> Bool {
		reset()
		unload()

		let url = URL(fileURLWithPath: file)
		let ext = url.pathExtension.lowercased()
		if MusicScene.videoExtensions.contains(ext) {
			let player = AVPlayer(url: url)
			player.isMuted = Settings.shared.muted
			let node = SKVideoNode(avPlayer: player)
			node.position = CGPoint(x: self.frame.midX + 200, y: self.frame.midY)
			node.size = CGSize(width: 1400, height: 840)
			node.zPosition = 1000
			videoEffect.addChild(node)
			track = .video(node, player)
		} else if let player = Sound.player(contentsOf: url) {
			player.isMeteringEnabled = true
			player.prepareToPlay()
			track = .audio(player)
		}
		return isLoaded
	}

	var isLoaded: Bool {
		if case .none = track { return false }
		return true
	}

	/// Starts or resumes, clearing the buzzes and letting every team buzz again
	func play() {
		clearBuzzes()
		firstBuzzTime = Date()
		teamEnabled = [Bool](repeating: true, count: Settings.shared.numTeams)
		switch track {
		case .none:
			break
		case .audio(let player):
			player.play()
			player.updateMeters()
		case .video(_, let player):
			//A video left at its end would otherwise just sit there
			if let duration = duration, playhead >= duration - 0.1 {
				player.seek(to: .zero)
			}
			player.play()
		}
	}

	func pause() {
		pausePlayer()
		QuizWebSocket.shared?.ledsOff()
	}

	private func pausePlayer() {
		switch track {
		case .none: break
		case .audio(let player): player.pause()
		case .video(let node, _): node.pause()
		}
	}

	/// A pause that also goes back to the start. The buzzes stay on screen.
	func stop() {
		pause()
		switch track {
		case .none: break
		case .audio(let player):
			player.currentTime = 0
			player.prepareToPlay()
		case .video(_, let player):
			player.seek(to: .zero)
		}
	}

	var isPlaying: Bool {
		switch track {
		case .none: return false
		case .audio(let player): return player.isPlaying
		case .video(_, let player): return player.rate != 0
		}
	}

	/// Seconds into the track
	var playhead: TimeInterval {
		switch track {
		case .none: return 0
		case .audio(let player): return player.currentTime
		case .video(_, let player): return player.currentTime().seconds.finiteOrZero
		}
	}

	/// Length of the track in seconds, or nil while a video is still working it out
	var duration: TimeInterval? {
		switch track {
		case .none: return nil
		case .audio(let player): return player.duration
		case .video(_, let player):
			let seconds = player.currentItem?.duration.seconds ?? .nan
			return seconds.isFinite ? seconds : nil
		}
	}

	private func unload() {
		if case .video(let node, _) = track {
			node.pause()
			node.removeFromParent()
		}
		track = .none
	}

	func addMonitorBars() {
		let barWidth: CGFloat = 30
		let barYOffset: CGFloat = size.height * 0.1
		// Left channel avg bar
		let avgBarLeftRect = CGRect(x: 20, y: barYOffset, width: barWidth, height: 10)
		let avgBarLeft = SKShapeNode(rect: avgBarLeftRect, cornerRadius: 8)
		avgBarLeft.fillColor = .green
		avgBarLeft.strokeColor = .clear
		avgBarLeft.zPosition = 10
		self.avgPowerBarLeft = avgBarLeft
		self.addChild(avgBarLeft)
		// Left channel peak marker
		let peakMarkerLeftRect = CGRect(x: 15, y: barYOffset, width: barWidth + 10, height: 4)
		let peakMarkerLeft = SKShapeNode(rect: peakMarkerLeftRect, cornerRadius: 2)
		peakMarkerLeft.fillColor = .white
		peakMarkerLeft.strokeColor = .clear
		peakMarkerLeft.zPosition = 11
		self.peakMarkerLeft = peakMarkerLeft
		self.addChild(peakMarkerLeft)
		// Right channel avg bar
		let avgBarRightRect = CGRect(x: 70, y: barYOffset, width: barWidth, height: 10)
		let avgBarRight = SKShapeNode(rect: avgBarRightRect, cornerRadius: 8)
		avgBarRight.fillColor = .green
		avgBarRight.strokeColor = .clear
		avgBarRight.zPosition = 10
		self.avgPowerBarRight = avgBarRight
		self.addChild(avgBarRight)
		// Right channel peak marker
		let peakMarkerRightRect = CGRect(x: 65, y: barYOffset, width: barWidth + 10, height: 4)
		let peakMarkerRight = SKShapeNode(rect: peakMarkerRightRect, cornerRadius: 2)
		peakMarkerRight.fillColor = .white
		peakMarkerRight.strokeColor = .clear
		peakMarkerRight.zPosition = 11
		self.peakMarkerRight = peakMarkerRight
		self.addChild(peakMarkerRight)
	}
	
	
	func updateMonitors() {
		let music = audioPlayer
		music?.updateMeters()
		let peakL = normalisePower(power: music?.peakPower(forChannel: 0) ?? -160.0)
		let peakR = normalisePower(power: music?.peakPower(forChannel: 1) ?? -160.0)
		let avgL = normalisePower(power: music?.averagePower(forChannel: 0) ?? -160.0)
		let avgR = normalisePower(power: music?.averagePower(forChannel: 1) ?? -160.0)
		
		let maxBarHeight = self.size.height * 0.8
		let barYOffset = self.size.height * 0.1
	
		let peakLBoosted = boostPower(power: peakL)
		let peakRBoosted = boostPower(power: peakR)
		let avgLBoosted = boostPower(power: avgL)
		let avgRBoosted = boostPower(power: avgR)
		
		// Left channel avg bar and marker
		if let avgBar = avgPowerBarLeft {
			let h = CGFloat(avgLBoosted) * maxBarHeight
			avgBar.path = CGPath(roundedRect: CGRect(x: 20, y: barYOffset, width: 30, height: max(10, h)), cornerWidth: 8, cornerHeight: 8, transform: nil)
			avgBar.fillColor = NSColor(calibratedRed: CGFloat(avgLBoosted), green: 1.0 - CGFloat(avgL), blue: 0.0, alpha: 1.0)
		}
		if let marker = peakMarkerLeft {
			let y = barYOffset + CGFloat(peakLBoosted) * maxBarHeight
			marker.path = CGPath(roundedRect: CGRect(x: 15, y: y, width: 40, height: 4), cornerWidth: 2, cornerHeight: 2, transform: nil)
		}
		// Right channel avg bar and marker
		if let avgBar = avgPowerBarRight {
			let h = CGFloat(avgRBoosted) * maxBarHeight
			avgBar.path = CGPath(roundedRect: CGRect(x: 70, y: barYOffset, width: 30, height: max(10, h)), cornerWidth: 8, cornerHeight: 8, transform: nil)
			avgBar.fillColor = NSColor(calibratedRed: CGFloat(avgRBoosted), green: 1.0 - CGFloat(avgR), blue: 0.0, alpha: 1.0)
		}
		if let marker = peakMarkerRight {
			let y = barYOffset + CGFloat(peakRBoosted) * maxBarHeight
			marker.path = CGPath(roundedRect: CGRect(x: 65, y: y, width: 40, height: 4), cornerWidth: 2, cornerHeight: 2, transform: nil)
		}
	}
	
}



// MARK: - Controller window

class MusicPanel: NSObject, RoundPanel {

	let round = RoundType.music
	weak var host: ControllerWindowController!

	@IBOutlet weak var trackList: NSPopUpButton!
	@IBOutlet weak var nextTrackButton: NSButton!
	@IBOutlet weak var nextTeamButton: NSButton!
	@IBOutlet weak var playPauseButton: NSButton!
	@IBOutlet weak var trackStatus: NSTextField!
	@IBOutlet weak var trackProgress: NSProgressIndicator!
	@IBOutlet weak var useLEDs: NSButton!

	private var scene: MusicScene { host.quizDisplay.musicScene }
	private var statusTimer: Timer?

	func connectControls() {
		scene.useLEDs = useLEDs
	}

	func setUp() {
		scene.onQueueChanged = { [weak self] in
			guard let self else { return }
			self.nextTeamButton.isEnabled = self.scene.hasNextTeam
		}
		scene.onQueueChanged?()

		trackList.removeAllItems()
		let extensions = MusicScene.audioExtensions.union(MusicScene.videoExtensions)
		for file in Utils.questionFiles(in: Settings.shared.musicPath, extensions: extensions) {
			trackList.addItem(withTitle: file)
			let isVideo = MusicScene.videoExtensions.contains((file as NSString).pathExtension.lowercased())
			trackList.lastItem?.image = NSImage(systemSymbolName: isVideo ? "film" : "music.note",
												accessibilityDescription: isVideo ? "Video" : "Audio")
		}
		if trackList.numberOfItems > 0 {
			chooseTrack(trackList)
		} else {
			refreshStatus()
		}

		let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in self?.refreshStatus() }
		RunLoop.main.add(timer, forMode: .common)
		statusTimer = timer
	}

	func tearDown() {
		statusTimer?.invalidate()
	}

	@IBAction func nextTeam(_ sender: AnyObject) {
		scene.nextTeam()
	}

	/// Pauses if playing, otherwise plays, which also clears the buzzes
	@IBAction func playPause(_ sender: AnyObject) {
		if scene.isPlaying {
			scene.pause()
		} else {
			scene.play()
		}
		refreshStatus()
	}

	@IBAction func stop(_ sender: AnyObject) {
		scene.stop()
		refreshStatus()
	}

	@IBAction func chooseTrack(_ sender: NSPopUpButton) {
		guard let file = trackList.selectedItem?.title else { return }
		scene.load(file: Settings.shared.musicPath + "/" + file)

		//The options that only make sense for the other kind of track are greyed out
		host.buzzcocksMode.isEnabled = !scene.isVideo
		useLEDs.isEnabled = !scene.isVideo
		host.blankVideo.isEnabled = scene.isVideo
		refreshStatus()
	}

	@IBAction func nextTrack(_ sender: AnyObject) {
		let next = trackList.indexOfSelectedItem + 1
		guard next < trackList.numberOfItems else { return }
		trackList.selectItem(at: next)
		chooseTrack(trackList)
	}

	private func refreshStatus() {
		nextTrackButton.isEnabled = trackList.indexOfSelectedItem + 1 < trackList.numberOfItems
		//A buzz pauses without going through here, so the timer catches the label up
		playPauseButton.title = scene.isPlaying ? "Pause" : "Play"
		playPauseButton.isEnabled = scene.isLoaded

		guard scene.isLoaded else {
			trackStatus.stringValue = trackList.numberOfItems == 0
				? "No music or video in \(Settings.shared.musicPath)"
				: "Could not open \(trackList.selectedItem?.title ?? "that file")"
			trackProgress.doubleValue = 0
			return
		}

		let playhead = scene.playhead
		let state = scene.isPlaying ? "▶ Playing" : (playhead == 0 ? "■ At start" : "❚❚ Paused")
		let kind = scene.isVideo ? "video" : "audio"
		let length = scene.duration.map(Self.format) ?? "–:––"
		trackStatus.stringValue = "\(state) · \(kind) · \(Self.format(playhead)) / \(length)"

		if let duration = scene.duration, duration > 0 {
			trackProgress.doubleValue = 100 * playhead / duration
		} else {
			trackProgress.doubleValue = 0
		}
	}

	private static func format(_ seconds: TimeInterval) -> String {
		let whole = Int(seconds)
		return String(format: "%d:%02d", whole / 60, whole % 60)
	}
}

private extension Double {
	var finiteOrZero: Double { isFinite ? self : 0 }
}
