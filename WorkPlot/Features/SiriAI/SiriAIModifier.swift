//
//  SiriAIModifier.swift
//  WorkPlot
//
//  Automates Step 1 of Toto's manual method (FilzaSlop + text editor):
//  flip the capability flag inside the base64 CacheData blob of the XML
//  serialization. The actual patch logic lives in CacheDataPatcher so the
//  Siri AI toggle and the dual-cache tweaks share one verified code path.
//

import Foundation

enum SiriAIModifier {
    typealias State = CacheDataPatcher.State

    static let originalBase64 = CacheDataPatcher.originalMarker
    static let patchedBase64 = CacheDataPatcher.replacementMarker

    static func state(of plist: [String: Any]) -> State {
        CacheDataPatcher.state(of: plist)
    }

    static func setEnabled(_ enabled: Bool, in plist: inout [String: Any]) throws {
        try CacheDataPatcher.setEnabled(enabled, to: &plist)
    }
}
