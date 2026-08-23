//
//  AppleIntelligenceController.swift
//  WorkPlot
//
//  Legacy Apple Intelligence path (Toto method step 3): writes ONLY the
//  CacheExtra eligibility key. The Siri mode flag belongs to the new Siri AI
//  toggle (SiriAIModifier + SiriModeApplier), never to this controller.
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
