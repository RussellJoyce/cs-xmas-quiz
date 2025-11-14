//
//  Settings.swift
//  Quiz Server
//
//  Created by Ian Gray on 2025-10-24.
//  Copyright © 2025 Russell Joyce & Ian Gray. All rights reserved.
//

final class Settings {
	static let shared = Settings()
	private init() {}

	var debug: Bool = false
	
	var geographyImagesPath: String = ""
	var musicPath: String = ""
	var uniquePath: String = ""
	var pointlessPath: String = ""
	
	var numTeams: Int = 14
}
