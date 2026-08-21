//
//  DeviceSpoofingManager.swift
//  WorkPlot
//
//  Full-device spoofing over MobileGestalt CacheExtra. Selecting a target
//  updates all nine ProductType keys, the hardware/board model string, and
//  both device marketing-name keys simultaneously.
//

import Foundation

struct SpoofTarget: Identifiable, Hashable {
    let marketingName: String
    let productType: String
    let boardConfig: String

    var id: String { productType }
}

enum DeviceSpoofingError: LocalizedError {
    case missingCacheExtra

    var errorDescription: String? {
        switch self {
        case .missingCacheExtra:
            "MobileGestalt tidak punya CacheExtra; spoofing tidak dapat diterapkan."
        }
    }
}

enum DeviceSpoofingManager {

    /// Confirmed identifier/board mapping per device generation.
    static let targets: [SpoofTarget] = [
        SpoofTarget(marketingName: "iPhone 15 Pro", productType: "iPhone16,1", boardConfig: "D74AP"),
        SpoofTarget(marketingName: "iPhone 15 Pro Max", productType: "iPhone16,2", boardConfig: "D74AP"),
        SpoofTarget(marketingName: "iPhone 16 Pro", productType: "iPhone17,1", boardConfig: "D74AP"),
        SpoofTarget(marketingName: "iPhone 16 Pro Max", productType: "iPhone17,2", boardConfig: "D74AP"),
        SpoofTarget(marketingName: "iPhone 17 Pro", productType: "iPhone18,1", boardConfig: "D97AP"),
        SpoofTarget(marketingName: "iPhone 17 Pro Max", productType: "iPhone18,2", boardConfig: "D97AP")
    ]

    /// All nine keys in CacheExtra that store a ProductType string.
    /// `h9jDsbgj7xIVeIQ8S3/X3Q` is the primary one read by most services.
    static let productTypeKeys = [
        "xNN67KktpWp7syTT3S1BFA",
        "+1TeoctsaQC55zwHZ6MESg",
        "myx96YOqBSDzLwljSYWBiQ",
        "0+nc/Udy4WNG8S+Q7a/s1A",
        "GEsznZwAYGOa1a67QU1Uew",
        "GqAdWRLnC7oYQrNYF48VYA",
        "MKE8hwsOxxRCtwBk2aDBZA",
        "h9jDsbgj7xIVeIQ8S3/X3Q",
        "G91h5IuJvXISeyngNFqEpg"
    ]

    /// All nine keys in CacheExtra that store a board config string
    /// (D27AP on iPhone 14, D74AP, D97AP, ...).
    static let boardConfigKeys = [
        "oQNDePXjSD1z7W0ddqt9tg",
        "/YYygAofPDbhrwToVsXdeA",
        "b4e7mEbjqfewD6oXmo9U5g",
        "dW5fpt/6HhaTbnK/UqL6cA",
        "GGIIDN/ANr8X2WrgS6nBYQ",
        "ZGraRMW0TsxCvONeeJ5C2w",
        "uCIk6n9Am5fsV2cTjhqFQw",
        "oYicEKzVTz4/CxxE05pEgQ",
        "yAfB6E2v0++rHtdW7SDg8w"
    ]

    /// Both device marketing-name keys.
    static let deviceNameKeys = ["Z/dqyWS6OZTRy10UcmUAhw", "bbtR9jQx50Fv5Af/affNtA"]

    /// Returns the currently spoofed target by matching any ProductType key,
    /// or nil when no ProductType matches a known spoof entry.
    static func currentTarget(in plist: [String: Any]) -> SpoofTarget? {
        let cacheExtra = plist["CacheExtra"] as? [String: Any] ?? [:]
        let values = Set(
            productTypeKeys.compactMap { cacheExtra[$0] as? String }
        )
        return targets.first { values.contains($0.productType) }
    }

    /// Rewrites every model-related key to the target device at once.
    static func apply(_ target: SpoofTarget, to plist: inout [String: Any]) throws {
        guard var cacheExtra = plist["CacheExtra"] as? [String: Any] else {
            throw DeviceSpoofingError.missingCacheExtra
        }

        for key in productTypeKeys {
            cacheExtra[key] = target.productType
        }
        for key in boardConfigKeys {
            cacheExtra[key] = target.boardConfig
        }

        // Only overwrite names that already exist so we never invent keys.
        for key in deviceNameKeys where cacheExtra[key] != nil {
            cacheExtra[key] = target.marketingName
        }

        // CompatibleDeviceFallback lives inside the ArtworkDevice dictionary.
        if var artwork = cacheExtra[GestaltArtwork.artworkKey] as? [String: Any] {
            artwork["CompatibleDeviceFallback"] = target.productType
            cacheExtra[GestaltArtwork.artworkKey] = artwork
        }

        plist["CacheExtra"] = cacheExtra
    }

    /// Restores genuine identity is not possible from within the app — use a
    /// pre-spoof backup instead. This helper only clears the spoofed name
    /// overrides, leaving ProductType untouched.
    @discardableResult
    static func clearDeviceNames(in plist: inout [String: Any]) -> Bool {
        guard var cacheExtra = plist["CacheExtra"] as? [String: Any] else { return false }
        for key in deviceNameKeys { cacheExtra.removeValue(forKey: key) }
        plist["CacheExtra"] = cacheExtra
        return true
    }
}
