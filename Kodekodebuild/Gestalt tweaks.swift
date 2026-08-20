//
//  GestaltTweaks.swift
//  GestaltTweak
//
//  Licensed under the MIT License. Tweak keys and approaches from
//  leminlimez/Nugget and frs0n/GestaltEdit.
//

import Foundation

enum GestaltTweakCategory: String, CaseIterable, Identifiable {
    case region
    case display
    case hardware
    case ipad
    case internalFeatures

    var id: String { rawValue }

    var label: String {
        switch self {
        case .display: "Display & Appearance"
        case .hardware: "Hardware Capabilities"
        case .ipad: "iPad Capabilities"
        case .region: "Region"
        case .internalFeatures: "Internal & Research"
        }
    }
}

enum GestaltTweakID: String, CaseIterable, Identifiable {
    case supportsDynamicIsland
    case bootChime
    case chargeLimit
    case tapToWake
    case cameraButton
    case disableParallax
    case enableLiquidGlassLowPerformance
    case disableLiquidGlassLowPerformance
    case stageManager
    case iPadOS
    case iPadApps
    case pencil
    case actionButton
    case internalInstall
    case internalStorage
    case securityResearchDevice
    case collisionSOS
    case alwaysOnDisplay
    case alwaysOnDisplayVibrancy
    case pulseWidthModulation
    case highLuminanceAOD
    case hdrPhotoDisplay
    case twilight
    case grayDimming
    case contextualVolume
    case faceID
    case usbC
    case mtpFileTransfer
    case alwaysOnCompass
    case secureMicrophone
    case audioMix
    case thunderbolt
    case usbCDisplayOutput
    case wirelessSplitting
    case independentSpeakerOutput
    case ultraLowPowerNetworking
    case aodFlipbook
    case heartRateVariability
    case spatialFaceTimeAudio
    case hypertensivePatternMeasurements
    case frameSynchronousBrightness
    case p3VideoRecording
    case autoLowLightVideo

    var id: String { rawValue }
}

struct GestaltTweakDefinition: Identifiable {
    let id: GestaltTweakID
    let category: GestaltTweakCategory
    let title: String
    let detail: String
    let values: [String: Any]
    var isRisky = false
    var isLocked = false
    /// True when the tweak's keys never ship on stock devices, so a baseline
    /// captured from an already-tweaked device can safely remove them.
    var isTweakOnly = false

    func isApplied(in cacheExtra: [String: Any]) -> Bool {
        for (key, expected) in values {
            guard let stored = cacheExtra[key],
                  Self.valueEquals(stored, expected) else {
                continue
            }
            return true
        }
        return false
    }

    private static func valueEquals(_ lhs: Any, _ rhs: Any) -> Bool {
        if let l = lhs as? NSNumber, let r = rhs as? NSNumber {
            return l == r
        }
        if let l = lhs as? String, let r = rhs as? String {
            return l == r
        }
        if let l = lhs as? NSArray, let r = rhs as? NSArray {
            return l == r
        }
        return false
    }
}

enum GestaltTweakCatalog {
    static let definitions: [GestaltTweakDefinition] = [
        .init(id: .supportsDynamicIsland, category: .display, title: "Enable Dynamic Island Capability", detail: "Nugget's alternate enable method.", values: ["YlEtTtHlNesRBMal1CqRaA": 1]),
        .init(id: .alwaysOnDisplay, category: .display, title: "Always-On Display", detail: "May increase burn-in risk on unsupported devices.", values: ["2OOJf1VhaM7NxfRok3HbWQ": 1, "j8/Omm6s1lsmTDFsXjsBfA": 1], isRisky: true),
        .init(id: .alwaysOnDisplayVibrancy, category: .display, title: "AOD Vibrancy", detail: "Use this when AOD rendering looks incorrect.", values: ["ykpu7qyhqFweVMKtxNylWA": 1]),
        .init(id: .disableParallax, category: .display, title: "Disable Wallpaper Parallax", detail: "Stops wallpaper motion based on device movement.", values: ["UIParallaxCapability": 0]),
        .init(id: .enableLiquidGlassLowPerformance, category: .display, title: "Enable Liquid Glass Low-Performance Mode", detail: "Lowers Liquid Glass graphics performance.", values: ["SAGvsp6O6kAQ4fEfDJpC4Q": 1]),
        .init(id: .disableLiquidGlassLowPerformance, category: .display, title: "Disable Liquid Glass Low-Performance Mode", detail: "Mutually exclusive with the option above.", values: ["SAGvsp6O6kAQ4fEfDJpC4Q": 0]),
        .init(id: .pulseWidthModulation, category: .display, title: "Pulse Width Modulation", detail: "Exposes the display PWM capability.", values: ["6IejgN+1Fmu5/QrZFOIeNw": 1]),
        .init(id: .highLuminanceAOD, category: .display, title: "High-Luminance Always-On Display", detail: "Allows Always-On Display to reach a higher brightness level.", values: ["7brdL5xrEUWnlF9C0kdg5A": 1]),
        .init(id: .hdrPhotoDisplay, category: .display, title: "HDR Photo Display", detail: "Enables true HDR rendering for photos.", values: ["a1r7npIrhXsZ7SmKRKC1eA": 1]),
        .init(id: .twilight, category: .display, title: "Twilight", detail: "Enables the Twilight screen mode capability.", values: ["1Bk5Dr0hTb0bYXl04068MQ": 1]),
        .init(id: .grayDimming, category: .display, title: "Gray Dimming", detail: "Enables gray-scale screen dimming.", values: ["1cPL2NOPt23mHxhn0J4xPA": 1]),
        .init(id: .contextualVolume, category: .display, title: "Contextual Volume", detail: "Enables the contextual volume UI.", values: ["7AqG7ADB9UZgLLYKd9ZhrQ": 1]),
        .init(id: .aodFlipbook, category: .display, title: "Always-On Display Flipbook", detail: "Enables AOD flipbook widgets on the Lock Screen.", values: ["aoJSd/MXk7M40NgXTM6x+g": 1]),
        .init(id: .frameSynchronousBrightness, category: .display, title: "Frame-Synchronous Brightness", detail: "Enables frame-synchronous display brightness.", values: ["/oWN4fE81uA9pCW4FmD7Ug": 1]),

        .init(id: .bootChime, category: .hardware, title: "Boot & Shutdown Chime", detail: "Enables the device boot and shutdown chime capability.", values: ["QHxt+hGLaBPbQJbXiUJX3w": 1]),
        .init(id: .chargeLimit, category: .hardware, title: "Charge Limit Menu", detail: "Shows the Settings menu; actual limiting depends on hardware.", values: ["37NVydb//GP/GrhuTN+exg": 1]),
        .init(id: .tapToWake, category: .hardware, title: "Tap to Wake", detail: "Primarily for models such as iPhone SE where it is unavailable.", values: ["yZf3GTRMGTuwSV/lD7Cagw": 1]),
        .init(id: .cameraButton, category: .hardware, title: "iPhone 16 Camera Control Settings", detail: "Shows Camera Control settings and related capabilities.", values: ["CwvKxM2cEogD3p+HYgaW0Q": 1, "oOV1jhJbdV3AddkcCg0AEA": 1]),
        .init(id: .pencil, category: .hardware, title: "Apple Pencil Settings", detail: "Shows the Apple Pencil settings page.", values: ["yhHcB0iH0d1XzPO/CFd3ow": 1]),
        .init(id: .actionButton, category: .hardware, title: "Action Button Settings", detail: "Shows the Action Button settings page.", values: ["cT44WE1EohiwRzhsZ8xEsw": 1]),
        .init(id: .collisionSOS, category: .hardware, title: "Collision SOS", detail: "Shows collision detection in SOS settings.", values: ["HCzWusHQwZDea6nNhaKndw": 1]),
        .init(id: .faceID, category: .hardware, title: "Face ID", detail: "Marks the device as Face ID capable. Risky without TrueDepth hardware.", values: ["8olRm6C1xqr7AJGpLRnpSw": 1], isRisky: true),
        .init(id: .usbC, category: .hardware, title: "USB-C Support", detail: "Marks the device as USB-C capable.", values: ["BWoQXWXYITrPRpFyc9xTLw": 1]),
        .init(id: .mtpFileTransfer, category: .hardware, title: "USB File Transfer (MTP)", detail: "Enables MTP file transfer over USB.", values: ["68eiAurB2LJ96Vz/CzaAcA": 1]),
        .init(id: .alwaysOnCompass, category: .hardware, title: "Always-On Compass", detail: "Enables the always-on compass capability.", values: ["aCQx2Qq/TChnNAq1rr6Egw": 1]),
        .init(id: .secureMicrophone, category: .hardware, title: "Secure Microphone", detail: "Enables secure microphone handling.", values: ["7UhDrmrZozgwO+3AgUbHxw": 1]),
        .init(id: .thunderbolt, category: .hardware, title: "Thunderbolt Support", detail: "Marks the device as Thunderbolt capable.", values: ["4ec+Q3FdQ1N0HeNpOPsmfA": 1]),
        .init(id: .usbCDisplayOutput, category: .hardware, title: "USB-C Display Output", detail: "Enables display output over USB-C.", values: ["khE304sL66yzf7K+2e+0cw": 1]),
        .init(id: .wirelessSplitting, category: .hardware, title: "Wireless Screen Splitting", detail: "Enables wireless display splitting.", values: ["2zyzecwSf2ZYRpB3tuQhOQ": 1]),
        .init(id: .independentSpeakerOutput, category: .hardware, title: "Independent Speaker Output", detail: "Enables independent audio output on the speaker.", values: ["6VRApe6L2vc1r2s+xts9/w": 1]),
        .init(id: .ultraLowPowerNetworking, category: .hardware, title: "Ultra-Low-Power Networking", detail: "Enables ultra-low-power networking.", values: ["a1eUrgG+tlRzm4B5fqIdeg": 1]),
        .init(id: .heartRateVariability, category: .hardware, title: "Heart Rate Variability", detail: "Enables heart rate variability tracking.", values: ["/Oajtq8qODrC4XBBOULF3A": 1]),
        .init(id: .spatialFaceTimeAudio, category: .hardware, title: "Spatial FaceTime Audio Playback", detail: "Enables spatial audio playback for FaceTime.", values: ["/EVOCjM/Nmb2roP5ebtEFA": 1]),
        .init(id: .hypertensivePatternMeasurements, category: .hardware, title: "Hypertensive Pattern Measurements", detail: "Enables hypertensive pattern measurements.", values: ["4fh9efw4o1yaFqkXNCXoeA": 1]),
        .init(id: .p3VideoRecording, category: .hardware, title: "P3 Video Recording", detail: "Enables P3 color space video recording.", values: ["1eBwtCIwbIDdC80wiyzfow": 1]),
        .init(id: .autoLowLightVideo, category: .hardware, title: "Auto Low-Light Video", detail: "Enables automatic low-light video recording.", values: ["AX/UKxSHwm+OuFRIdvNAfg": 1]),

        .init(id: .stageManager, category: .ipad, title: "Stage Manager Support", detail: "Marks the device as supporting Stage Manager.", values: ["qeaj75wk3HF4DwQ8qbIi7g": 1]),
        .init(id: .iPadApps, category: .ipad, title: "Allow iPad Apps", detail: "Enables iPad app compatibility types on iPhone.", values: ["9MZ5AdH43csAUajl/dU+IQ": [1, 2]]),
        .init(id: .iPadOS, category: .ipad, title: "Enable iPadOS Mode", detail: "Changes five capabilities and CacheData; experimental and high risk.", values: ["mG0AnH/Vy1veoqoLRAIgTA": 1, "UCG5MkVahJxG1YULbbd5Bg": 1, "ZYqko/XM5zD3XBfN5RmaXA": 1, "nVh/gwNpy7Jv1NOk00CMrw": 1, "uKc7FPnEO++lVhHWHFlGbQ": 1], isRisky: true, isTweakOnly: true),

        .init(id: .internalInstall, category: .internalFeatures, title: "Apple Internal Install", detail: "Enables internal capabilities such as Metal HUD; some services may misbehave.", values: ["EqrsVvjcYDdxHBiQmGhAWw": 1], isRisky: true, isTweakOnly: true),
        .init(id: .internalStorage, category: .internalFeatures, title: "Internal Storage View", detail: "Shows internal files in Storage settings; high risk on some iPads.", values: ["LBJfwOEzExRxzlAnSuI7eg": 1], isRisky: true, isTweakOnly: true),
        .init(id: .securityResearchDevice, category: .internalFeatures, title: "Security Research Device Mode", detail: "Marks the device as a Security Research Device.", values: ["XYlJKKkj2hztRP1NWWnhlw": 1], isRisky: true, isTweakOnly: true),
        .init(id: .audioMix, category: .internalFeatures, title: "Audio Mix", detail: "Enables the audio mix capability.", values: ["aVL5GE3tx0LSCI/ErfrJGA": 1])
    ]

    static func definition(for id: GestaltTweakID) -> GestaltTweakDefinition? {
        definitions.first { $0.id == id }
    }
}

struct DynamicIslandOption: Identifiable, Hashable {
    let subtype: Int
    let title: String
    var id: Int { subtype }

    static let all: [DynamicIslandOption] = [
        .init(subtype: 2436, title: "iPhone X Gestures (SE)"),
        .init(subtype: 2556, title: "iPhone 14 Pro"),
        .init(subtype: 2796, title: "iPhone 14 Pro Max"),
        .init(subtype: 2976, title: "iPhone 15 Pro Max"),
        .init(subtype: 2622, title: "iPhone 16 Pro"),
        .init(subtype: 2868, title: "iPhone 16 Pro Max"),
        .init(subtype: 2736, title: "iPhone Air")
    ]
}

enum GestaltTweakError: LocalizedError {
    case artworkDictionaryMissing
    case cacheDataMissing
    case cacheDataTooShort
    case cacheDataPatternNotFound
    case invalidCacheDataOffset

    var errorDescription: String? {
        switch self {
        case .artworkDictionaryMissing: "MobileGestalt is missing the ArtworkDevice dictionary, so Dynamic Island or model name cannot be changed."
        case .cacheDataMissing: "MobileGestalt is missing CacheData, so iPadOS mode cannot be enabled."
        case .cacheDataTooShort: "CacheData is too short to apply iPadOS mode safely."
        case .cacheDataPatternNotFound: "The iPadOS marker required by Nugget was not found in CacheData."
        case .invalidCacheDataOffset: "CacheData marker validation failed. No changes were made."
        }
    }
}

extension GestaltPlist {
    mutating func apply(definition: GestaltTweakDefinition) throws {
        for (key, value) in definition.values {
            setCacheExtra(value, forKey: key)
        }
        if definition.id == .iPadOS {
            try enableIPadOSCacheData()
        }
    }

    mutating func setDynamicIslandSubtype(_ subtype: Int) throws {
        let key = "oPeik/9e8lQWMszEjbPzng"
        guard var artwork = cacheExtra[key] as? [String: Any] else {
            throw GestaltTweakError.artworkDictionaryMissing
        }
        artwork["ArtworkDeviceSubType"] = subtype
        setCacheExtra(artwork, forKey: key)
        setCacheExtra(1, forKey: "YlEtTtHlNesRBMal1CqRaA")
    }

    mutating func setModelName(_ name: String) throws {
        let key = "oPeik/9e8lQWMszEjbPzng"
        guard var artwork = cacheExtra[key] as? [String: Any] else {
            throw GestaltTweakError.artworkDictionaryMissing
        }
        artwork["ArtworkDeviceProductDescription"] = name
        setCacheExtra(artwork, forKey: key)
    }

    /// Restores just the Dynamic Island subtype and support flag to stock.
    mutating func restoreDynamicIsland(from baselineCacheExtra: [String: Any]?) {
        let artworkKey = "oPeik/9e8lQWMszEjbPzng"
        let diKey = "YlEtTtHlNesRBMal1CqRaA"
        if var artwork = cacheExtra[artworkKey] as? [String: Any] {
            if let stockSubtype = (baselineCacheExtra?[artworkKey] as? [String: Any])?["ArtworkDeviceSubType"] {
                artwork["ArtworkDeviceSubType"] = stockSubtype
            } else {
                artwork.removeValue(forKey: "ArtworkDeviceSubType")
            }
            setCacheExtra(artwork, forKey: artworkKey)
        }
        if let pristineDI = baselineCacheExtra?[diKey] {
            setCacheExtra(pristineDI, forKey: diKey)
        } else {
            removeCacheExtraValue(forKey: diKey)
        }
    }

    private mutating func enableIPadOSCacheData() throws {
        guard let cacheData = dict["CacheData"] as? Data else {
            throw GestaltTweakError.cacheDataMissing
        }
        var hex = Array(cacheData.map { String(format: "%02x", $0) }.joined())
        let sliceStart = 1616
        let sliceLength = 200
        guard hex.count > sliceStart else { throw GestaltTweakError.cacheDataTooShort }

        let end = min(hex.count, sliceStart + sliceLength)
        let slice = String(hex[sliceStart..<end])
        let regex = try NSRegularExpression(pattern: "0+(?:5555)*([0-9a-f]{4})")
        let nsRange = NSRange(slice.startIndex..<slice.endIndex, in: slice)
        var matchedOffset: Int?
        regex.enumerateMatches(in: slice, range: nsRange) { match, _, stop in
            guard let range = match.flatMap({ Range($0.range(at: 1), in: slice) }) else { return }
            let value = slice[range]
            if value.filter({ $0 != "0" }).count >= 3 {
                matchedOffset = sliceStart + slice.distance(from: slice.startIndex, to: range.lowerBound)
                stop.pointee = true
            }
        }
        guard let offset = matchedOffset else { throw GestaltTweakError.cacheDataPatternNotFound }

        let rightOffset = offset + 13
        let leftOffset = offset - 67
        guard leftOffset > 0, rightOffset < hex.count - 1 else {
            throw GestaltTweakError.invalidCacheDataOffset
        }
        for position in [leftOffset, rightOffset] {
            guard ["1", "3"].contains(String(hex[position])),
                  hex[position - 1] == "0", hex[position + 1] == "0" else {
                throw GestaltTweakError.invalidCacheDataOffset
            }
        }
        hex[leftOffset] = "3"
        let updatedHex = String(hex)
        var updatedData = Data(capacity: updatedHex.count / 2)
        var index = updatedHex.startIndex
        while index < updatedHex.endIndex {
            let next = updatedHex.index(index, offsetBy: 2)
            guard let byte = UInt8(updatedHex[index..<next], radix: 16) else {
                throw GestaltTweakError.invalidCacheDataOffset
            }
            updatedData.append(byte)
            index = next
        }
        dict["CacheData"] = updatedData
    }
}
