//: A SpriteKit based Playground

import PlaygroundSupport
import SpriteKit
import AVFoundation

class MusicScene: SKScene {
	
	var music: AVAudioPlayer?
	let barL = SKSpriteNode(color: .green, size: CGSize(width: 90.0, height: 400.0))
	let barR = SKSpriteNode(color: .green, size: CGSize(width: 90.0, height: 400.0))
	let peakBarL = SKSpriteNode(color: .red, size: CGSize(width: 90.0, height: 400.0))
	let peakBarR = SKSpriteNode(color: .red, size: CGSize(width: 90.0, height: 400.0))
	
	override func update(_ currentTime: TimeInterval) {
		super.update(currentTime)
		
		music?.updateMeters()
		let peakL = normalisePower(power: music?.peakPower(forChannel: 0) ?? -160.0)
		let peakR = normalisePower(power: music?.peakPower(forChannel: 1) ?? -160.0)
		let avgL = normalisePower(power: music?.averagePower(forChannel: 0) ?? -160.0)
		let avgR = normalisePower(power: music?.averagePower(forChannel: 1) ?? -160.0)
		
		barL.yScale = CGFloat(avgL)
		barR.yScale = CGFloat(avgR)
		peakBarL.yScale = CGFloat(peakL)
		peakBarR.yScale = CGFloat(peakR)
	}
	
	func setUpScene() {
		backgroundColor = .white
		
		peakBarL.position = CGPoint(x: 205, y: 100)
		peakBarR.position = CGPoint(x: 305, y: 100)
		barL.position = CGPoint(x: 205, y: 100)
		barR.position = CGPoint(x: 305, y: 100)
		
		peakBarL.anchorPoint = .zero
		peakBarR.anchorPoint = .zero
		barL.anchorPoint = .zero
		barR.anchorPoint = .zero
		
		let backgroundBoxL = SKSpriteNode(color: .gray, size: CGSize(width: 90.0, height: 400.0))
		backgroundBoxL.position = CGPoint(x: 205, y: 100)
		backgroundBoxL.anchorPoint = .zero
        let backgroundBoxR = SKSpriteNode(color: .gray, size: CGSize(width: 90.0, height: 400.0))
        backgroundBoxR.position = CGPoint(x: 305, y: 100)
        backgroundBoxR.anchorPoint = .zero
		
		addChild(backgroundBoxL)
        addChild(backgroundBoxR)
		addChild(peakBarL)
		addChild(peakBarR)
		addChild(barL)
		addChild(barR)
	}
	
	func normalisePower(power: Float) -> Float {
		return pow(10.0, min(power, 0.0)/20.0)
	}
	
	func initMusic(file: String) {
		music = nil
		let musicUrl = URL(fileURLWithPath: file)
		do {
			try music = AVAudioPlayer(contentsOf: musicUrl)
		} catch let error {
			print(error.localizedDescription)
		}
		music?.isMeteringEnabled = true
		music?.prepareToPlay()
	}

	func resumeMusic() {
		music?.play()
		music?.updateMeters()
	}

	func pauseMusic() {
		music?.pause()
	}

	func stopMusic() {
		music?.stop()
		music?.currentTime = 0
		music?.prepareToPlay()
	}
}


let sceneView = SKView(frame: CGRect(x:0 , y:0, width: 600, height: 600))
let scene = MusicScene(size: CGSize(width: 600, height: 600))
sceneView.showsFPS = true
scene.setUpScene()
sceneView.presentScene(scene)

PlaygroundSupport.PlaygroundPage.current.liveView = sceneView

scene.initMusic(file: "/Users/russell/Documents/cs-xmas-quiz/Music/Faster Than An Ambulance.m4a")
//scene.initMusic(file: "/Users/russell/Documents/cs-xmas-quiz/Music/Elephant Tusk.m4a")
//scene.initMusic(file: "/Users/russell/Documents/cs-xmas-quiz/Music/00 confusionmusic.wav")
//scene.initMusic(file: "/Users/russell/Music/iTunes/iTunes Media/Music/Elton John/Rocket Man [The Definitive Hits]/05 I Guess That's Why They Call It The Blues.m4a")
//scene.initMusic(file: "/Users/russell/Music/iTunes/iTunes Media/Music/Queen/Absolute Greatest (Collection)/09 One Vision.m4a")
//scene.initMusic(file: "/Users/russell/Music/iTunes/iTunes Media/Music/Tom Petty and the Heartbreakers/Greatest Hits/01 American Girl.m4a")
//scene.initMusic(file: "/Users/russell/Music/iTunes/iTunes Media/Music/Alanis Morissette/Jagged Little Pill (Collector's Edition)/1-10 Ironic.m4a")
//scene.initMusic(file: "/Users/russell/Music/iTunes/iTunes Media/Music/Foo Fighters/Sonic Highways/01 Something From Nothing.m4a")
scene.resumeMusic()

