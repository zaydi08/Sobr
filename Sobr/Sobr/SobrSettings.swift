//
//  SobrSettings.swift
//  Sobr
//
//  Created by Zayd Ibrahim on 10/25/26.
//

import Foundation

/// How the lockout works during a drinking session.
enum LockMode: String, Codable, CaseIterable {
    case blockAllExcept   // everything is locked except the apps you choose
    case allowAllExcept   // only the apps you choose are locked
}

/// The user's saved setup, created once and reused every night.
struct SobrSettings: Codable {
    var mode: LockMode = .allowAllExcept
    var chosenApps: [String] = []        // placeholder names until we hook up Screen Time
    var soberUpMinutes: Int = 240        // how long locks stay on after you start
}
