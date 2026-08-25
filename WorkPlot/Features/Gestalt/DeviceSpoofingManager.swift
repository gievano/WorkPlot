//
//  DeviceSpoofingManager.swift
//  WorkPlot
//
//  Full-device spoofing over MobileGestalt CacheExtra. One target maps to
//  EVERY model-identity key at once: all ProductType variants, all
//  HWModel/board variants, HardwarePlatform (CPU), RegulatoryModelNumber,
//  marketing-name keys, and the ArtworkDevice dictionary entries.
//
//  Key-to-value mapping verified against The Apple Wiki "List of MobileGestalt
//  keys" plus Nugget's AI-enabler spoof set (leminlimez/Nugget, MIT).
//

import Foundation

struct SpoofTarget: Identifiable, Hashable {
    let marketingName: String
    let productType: String
    let hwModel: String
    let cpuName: String
    let regulatoryModel: String

    var id: String { productType }
}

enum DeviceSpoofingError: LocalizedError {
    case missingCacheExtra

    var errorDescription: String? {
        switch self {
        case .missingCacheExtra:
            "CacheExtra is missing from the MobileGestalt plist."
        }
    }
}

enum DeviceSpoofingManager {

    /// Confirmed identifier/board/CPU/regulatory mapping per device.
    /// Board configs & CPU platforms cross-checked against IPSW metadata:
    /// iPhone16,1=D83AP/t8130, iPhone16,2=D84AP/t8130,
    /// iPhone17,1=D93AP/t8140, iPhone17,2=D94AP/t8140,
    /// iPhone18,1=V53AP/t8150, iPhone18,2=V54AP/t8150.
    static let targets: [SpoofTarget] = [
        SpoofTarget(marketingName: "iPhone 15 Pro", productType: "iPhone16,1", hwModel: "D83AP", cpuName: "t8130", regulatoryModel: "A2848"),
        SpoofTarget(marketingName: "iPhone 15 Pro Max", productType: "iPhone16,2", hwModel: "D84AP", cpuName: "t8130", regulatoryModel: "A2849"),
        SpoofTarget(marketingName: "iPhone 16 Pro", productType: "iPhone17,1", hwModel: "D93AP", cpuName: "t8140", regulatoryModel: "A3083"),
        SpoofTarget(marketingName: "iPhone 16 Pro Max", productType: "iPhone17,2", hwModel: "D94AP", cpuName: "t8140", regulatoryModel: "A3084"),
        SpoofTarget(marketingName: "iPhone 17 Pro", productType: "iPhone18,1", hwModel: "V53AP", cpuName: "t8150", regulatoryModel: "A3256"),
        SpoofTarget(marketingName: "iPhone 17 Pro Max", productType: "iPhone18,2", hwModel: "V54AP", cpuName: "t8150", regulatoryModel: "A3257")
    ]

    // MARK: Key groups (all values written per target in one pass)

    /// Every ProductType-string key in CacheExtra.
    /// `h9jDsbgj7xIVeIQ8S3/X3Q` is the primary one read by most services;
    /// the rest are the iOS 26 ProductTypeDescFor* variants plus
    /// SubProductType and ThinningProductType.
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

    /// Every HWModel-string key in CacheExtra: HWModelStr,
    /// HWModelUniqueStr, and the six HWModelDescriptionFor* variants.
    /// Nugget also writes the board config into TargetSubType
    /// (`oYicEKzVTz4/CxxE05pEgQ`), so it belongs here too.
    static let hwModelKeys = [
        "/YYygAofPDbhrwToVsXdeA",
        "GGIIDN/ANr8X2WrgS6nBYQ",
        "uCIk6n9Am5fsV2cTjhqFQw",
        "dW5fpt/6HhaTbnK/UqL6cA",
        "oQNDePXjSD1z7W0ddqt9tg",
        "yAfB6E2v0++rHtdW7SDg8w",
        "b4e7mEbjqfewD6oXmo9U5g",
        "ZGraRMW0TsxCvONeeJ5C2w",
        "oYicEKzVTz4/CxxE05pEgQ"
    ]

    /// HardwarePlatform stores the CPU platform string (t8130 = A17 Pro,
    /// t8140 = A18 Pro, t8150 = A19 Pro) - Nugget's third spoof axis.
    /// ponytail: NOT written by the picker spoof anymore (full blast broke
    /// mobilegestalt trust on iOS 27); kept because the built-in presets
    /// stage these keys explicitly.
    static let cpuKeys = ["5pYKlGnYYBzGvAlIU8RjEQ"]

    /// RegulatoryModelNumber is the "A" model number of the hardware.
    /// ponytail: presets-only, same reason as cpuKeys above.
    static let regulatoryModelKeys = ["97JDvERpVwO+GHtthIh7hA"]

    /// Region-code keys REMOVED from the spoof write-set: overwriting the
    /// device's real region (US/US-A) alongside a full identity blast was
    /// part of the regression. AI-region forcing still writes LL/LL/A via
    /// AIRegionApplier, which is the proven route.

    /// Marketing-name keys. Only overwritten when already present so we
    /// never invent keys on devices that do not cache them.
    static let deviceNameKeys = [
        "Z/dqyWS6OZTRy10UcmUAhw",
        "bbtR9jQx50Fv5Af/affNtA",
        "vme9Buk6XiWFCXoHApxNFA",
        "j9Th5smJpdztHwc+i39zIg"
    ]

    /// Rewrites every model-related key to the target device at once.
    /// Owner rule (enforced by Support/check-feature.ps1): the ArtworkDevice
    /// dictionary must already exist - a device without it cannot render the
    /// spoofed identity, so apply refuses loudly instead of inventing keys.
    static func apply(_ target: SpoofTarget, to plist: inout [String: Any]) throws {
        guard var cacheExtra = plist["CacheExtra"] as? [String: Any] else {
            throw DeviceSpoofingError.missingCacheExtra
        }
        guard var artwork = cacheExtra[GestaltArtwork.artworkKey] as? [String: Any] else {
            throw GestaltArtworkError.artworkDictionaryMissing
        }

        // Write-set = the PROVEN minimal blast from the release where device
        // spoofing verifiably worked on iOS 27 (old IPA forensics + git
        // history): ProductType x9, HW/board x9, marketing names when already
        // cached, CompatibleDeviceFallback inside ArtworkDevice. Writing CPU
        // platform, RegulatoryModelNumber, and US region codes on top made
        // mobilegestaltd distrust the whole CacheExtra and ignore every key
        // - that was the "spoofing ga jalan walau restart" regression.
        for key in productTypeKeys {
            cacheExtra[key] = target.productType
        }
        for key in hwModelKeys {
            cacheExtra[key] = target.hwModel
        }

        // Only overwrite names that already exist so we never invent keys.
        for key in deviceNameKeys where cacheExtra[key] != nil {
            cacheExtra[key] = target.marketingName
        }

        // ArtworkDevice dictionary entry rides along with the same pass.
        artwork["CompatibleDeviceFallback"] = target.productType
        cacheExtra[GestaltArtwork.artworkKey] = artwork

        plist["CacheExtra"] = cacheExtra
    }
}
