//
//  SiriModeApplier.swift
//  WorkPlot
//
//  Toggles the iOS 27 Siri AI mode via the CacheExtra key
//  `a3n5T9sFtyQ74NEp9ESxg` (value 2 = enabled). Disabling removes the key
//  so the system falls back to its natural state.
//

import Foundation

struct SiriModeApplier {
    static let cacheExtraKey = "a3n5T9sFtyQ74NEp9ESxg"
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
