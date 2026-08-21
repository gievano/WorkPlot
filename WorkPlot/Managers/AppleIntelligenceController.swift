//
//  AppleIntelligenceController.swift
//  WorkPlot
//
//  Simple CacheExtra eligibility toggle (Step 3 of Toto's method).
//

import Foundation

enum AppleIntelligenceController {
    static let eligibilityKey = "A62OafQ85EJAiiqKn4agtg"

    static func isEnabled(in plist: [String: Any]) -> Bool {
        let cacheExtra = plist["CacheExtra"] as? [String: Any] ?? [:]
        return (cacheExtra[eligibilityKey] as? Int) == 1
    }

    static func setEnabled(_ enabled: Bool, in plist: inout [String: Any]) {
        var cacheExtra = plist["CacheExtra"] as? [String: Any] ?? [:]
        if enabled {
            cacheExtra[eligibilityKey] = 1
        } else {
            cacheExtra.removeValue(forKey: eligibilityKey)
        }
        plist["CacheExtra"] = cacheExtra
    }
}
