//
//  SiriModeApplier.swift
//  WorkPlot
//
//  Toggles the Siri AI mode by bumping the Apple Intelligence eligibility key
//  `A62OafQ85EJAiiqKn4agtg` to 2. Disabling removes the key so the system
//  falls back to its natural state.
//

import Foundation

struct SiriModeApplier {
    static let cacheExtraKey = "A62OafQ85EJAiiqKn4agtg"
    static let enabledValue = 2

    static func setEnabled(_ enabled: Bool, in plist: inout [String: Any]) {
        var cacheExtra = plist["CacheExtra"] as? [String: Any] ?? [:]
        if enabled {
            cacheExtra[cacheExtraKey] = enabledValue
        } else {
            cacheExtra.removeValue(forKey: cacheExtraKey)
        }
        plist["CacheExtra"] = cacheExtra
    }
}
