import Foundation

enum GestaltTweakCategory: String, CaseIterable, Identifiable {
    case region, display, hardware, ipad, internalFeatures

    var id: String { rawValue }

    var label: String {
        switch self {
        case .region: L10n.shared.tr("tweak.category.region")
        case .display: L10n.shared.tr("tweak.category.display")
        case .hardware: L10n.shared.tr("tweak.category.hardware")
        case .ipad: L10n.shared.tr("tweak.category.ipad")
        case .internalFeatures: L10n.shared.tr("tweak.category.internal")
        }
    }
}

enum GestaltTweakID: String, CaseIterable, Identifiable {
    case supportsDynamicIsland, alwaysOnDisplay, alwaysOnDisplayVibrancy
    case aiRegionUS
    // siriMode removed: duplicate of the Siri AI tab's SiriModeApplier path,
    // which is the only variant that can actually revert (remove the key).
    // disableDynamicIsland removed too: the capability key alone proved
    // enable-only on native island devices, so a Gestalt-only off toggle was
    // a silent no-op - the Hide/Restore pair below carries BOTH the proven
    // SpringBoard suppression flag and the capability=0 staging.
    case hideDynamicIslandOn, hideDynamicIslandOff
    case disableParallax, enableLiquidGlassLowPerformance, disableLiquidGlassLowPerformance
    case pwm
    case bootChime, chargeLimit, tapToWake, cameraButton
    case pencil, actionButton, collisionSOS
    case stageManager, iPadOS, iPadApps
    case iosMode
    case internalInstall, internalStorage, securityResearchDevice
    case internalFeatures
    case rdarCanvasGestalt

    var id: String { rawValue }
}

enum GestaltDeviceGate {
    /// Marketing iPhone 13 series and newer (machine family >= 14).
    case iphone13OrLater
    /// Marketing iPhone 13 series and older (machine family <= 14).
    case iphone13OrBelow
    /// Devices below the iPhone 15 series (12MP-era cameras).
    case belowIPhone15
    /// Exactly the marketing iPhone 11 and 12 series
    /// (machineIdentifier iPhone12,* / iPhone13,*).
    case iphone11Or12Only
    /// Devices with a native Dynamic Island: iPhone 14 Pro series
    /// (machine family >= 15) and everything newer.
    case iphone14ProOrLater
    /// Devices WITHOUT a native Dynamic Island (notch era,
    /// machine family <= 14) - audience for the fake-pill cleanup.
    case belowIPhone14Pro
}

struct GestaltTweakDefinition: Identifiable {
    let id: GestaltTweakID
    let category: GestaltTweakCategory
    let title: String
    let detail: String
    let values: [String: Any]
    var isRisky = false
    var isExperimental = false
    var deviceGate: GestaltDeviceGate? = nil

    var isSupportedOnThisDevice: Bool {
        DeviceCapability.supports(deviceGate)
    }
}

enum GestaltTweakCatalog {
    static let definitions: [GestaltTweakDefinition] = [
        .init(id: .aiRegionUS, category: .region, title: L10n.shared.tr("tweak.airegion.title"), detail: L10n.shared.tr("tweak.airegion.detail"), values: [:], isRisky: true),

        .init(id: .supportsDynamicIsland, category: .display, title: L10n.shared.tr("tweak.dynamicisland.title"), detail: L10n.shared.tr("tweak.dynamicisland.detail"), values: ["YlEtTtHlNesRBMal1CqRaA": 1]),
        // Single proven off-switch pair: hideDynamicIslandOn drives
        // Nugget >=7.2's SpringBoard suppression flag AND stages
        // capability=0 below as belt-and-suspenders; Restore removes both.
        // The SpringBoard write itself is handled specially in
        // GestaltPresetManagerView.applySelected().
        .init(id: .hideDynamicIslandOn, category: .display, title: L10n.shared.tr("tweak.hideisland.title"), detail: L10n.shared.tr("tweak.hideisland.detail"), values: ["YlEtTtHlNesRBMal1CqRaA": 0], isExperimental: true),
        .init(id: .hideDynamicIslandOff, category: .display, title: L10n.shared.tr("tweak.showisland.title"), detail: L10n.shared.tr("tweak.showisland.detail"), values: [:]),
        .init(id: .alwaysOnDisplay, category: .display, title: L10n.shared.tr("tweak.aod.title"), detail: L10n.shared.tr("tweak.aod.detail"), values: ["2OOJf1VhaM7NxfRok3HbWQ": 1, "j8/Omm6s1lsmTDFsXjsBfA": 1], isRisky: true),
        .init(id: .alwaysOnDisplayVibrancy, category: .display, title: L10n.shared.tr("tweak.aodvibrancy.title"), detail: L10n.shared.tr("tweak.aodvibrancy.detail"), values: ["ykpu7qyhqFweVMKtxNylWA": 1]),
        .init(id: .disableParallax, category: .display, title: L10n.shared.tr("tweak.parallax.title"), detail: L10n.shared.tr("tweak.parallax.detail"), values: ["UIParallaxCapability": 0]),
        .init(id: .enableLiquidGlassLowPerformance, category: .display, title: L10n.shared.tr("tweak.lglowon.title"), detail: L10n.shared.tr("tweak.lglowon.detail"), values: ["SAGvsp6O6kAQ4fEfDJpC4Q": 1]),
        .init(id: .disableLiquidGlassLowPerformance, category: .display, title: L10n.shared.tr("tweak.lglowoff.title"), detail: L10n.shared.tr("tweak.lglowoff.detail"), values: ["SAGvsp6O6kAQ4fEfDJpC4Q": 0]),
        .init(id: .pwm, category: .display, title: L10n.shared.tr("tweak.pwm.title"), detail: L10n.shared.tr("tweak.pwm.detail"), values: ["6IejgN+1Fmu5/QrZFOIeNw": 1]),

        .init(id: .bootChime, category: .hardware, title: L10n.shared.tr("tweak.bootchime.title"), detail: L10n.shared.tr("tweak.bootchime.detail"), values: ["QHxt+hGLaBPbQJbXiUJX3w": 1]),
        .init(id: .chargeLimit, category: .hardware, title: L10n.shared.tr("tweak.chargelimit.title"), detail: L10n.shared.tr("tweak.chargelimit.detail"), values: ["37NVydb//GP/GrhuTN+exg": 1]),
        .init(id: .tapToWake, category: .hardware, title: L10n.shared.tr("tweak.taptowake.title"), detail: L10n.shared.tr("tweak.taptowake.detail"), values: ["yZf3GTRMGTuwSV/lD7Cagw": 1]),
        .init(id: .cameraButton, category: .hardware, title: L10n.shared.tr("tweak.cameracontrol.title"), detail: L10n.shared.tr("tweak.cameracontrol.detail"), values: ["CwvKxM2cEogD3p+HYgaW0Q": 1, "oOV1jhJbdV3AddkcCg0AEA": 1]),
        .init(id: .pencil, category: .hardware, title: L10n.shared.tr("tweak.pencil.title"), detail: L10n.shared.tr("tweak.pencil.detail"), values: ["yhHcB0iH0d1XzPO/CFd3ow": 1]),
        .init(id: .actionButton, category: .hardware, title: L10n.shared.tr("tweak.actionbutton.title"), detail: L10n.shared.tr("tweak.actionbutton.detail"), values: ["cT44WE1EohiwRzhsZ8xEsw": 1]),
        .init(id: .collisionSOS, category: .hardware, title: L10n.shared.tr("tweak.collisionsos.title"), detail: L10n.shared.tr("tweak.collisionsos.detail"), values: ["HCzWusHQwZDea6nNhaKndw": 1]),

        .init(id: .stageManager, category: .ipad, title: L10n.shared.tr("tweak.stagemanager.title"), detail: L10n.shared.tr("tweak.stagemanager.detail"), values: ["qeaj75wk3HF4DwQ8qbIi7g": 1]),
        .init(id: .iPadApps, category: .ipad, title: L10n.shared.tr("tweak.ipadapps.title"), detail: L10n.shared.tr("tweak.ipadapps.detail"), values: ["9MZ5AdH43csAUajl/dU+IQ": [1, 2]]),
        .init(id: .iosMode, category: .ipad, title: L10n.shared.tr("tweak.iosmode.title"), detail: L10n.shared.tr("tweak.iosmode.detail"), values: ["mG0AnH/Vy1veoqoLRAIgTA": 0, "UCG5MkVahJxG1YULbbd5Bg": 0, "ZYqko/XM5zD3XBfN5RmaXA": 0, "nVh/gwNpy7Jv1NOk00CMrw": 0, "uKc7FPnEO++lVhHWHFlGbQ": 0]),
        .init(id: .iPadOS, category: .ipad, title: L10n.shared.tr("tweak.ipados.title"), detail: L10n.shared.tr("tweak.ipados.detail"), values: ["mG0AnH/Vy1veoqoLRAIgTA": 1, "UCG5MkVahJxG1YULbbd5Bg": 1, "ZYqko/XM5zD3XBfN5RmaXA": 1, "nVh/gwNpy7Jv1NOk00CMrw": 1, "uKc7FPnEO++lVhHWHFlGbQ": 1], isRisky: true),

        .init(id: .internalInstall, category: .internalFeatures, title: L10n.shared.tr("tweak.internalinstall.title"), detail: L10n.shared.tr("tweak.internalinstall.detail"), values: ["EqrsVvjcYDdxHBiQmGhAWw": 1], isRisky: true),
        .init(id: .internalStorage, category: .internalFeatures, title: L10n.shared.tr("tweak.internalstorage.title"), detail: L10n.shared.tr("tweak.internalstorage.detail"), values: ["LBJfwOEzExRxzlAnSuI7eg": 1], isRisky: true),
        .init(id: .securityResearchDevice, category: .internalFeatures, title: L10n.shared.tr("tweak.securityresearch.title"), detail: L10n.shared.tr("tweak.securityresearch.detail"), values: ["XYlJKKkj2hztRP1NWWnhlw": 1], isRisky: true),
        .init(id: .internalFeatures, category: .internalFeatures, title: L10n.shared.tr("tweak.internalfeatures.title"), detail: L10n.shared.tr("tweak.internalfeatures.detail"), values: ["EqrsVvjcYDdxHBiQmGhAWw": 1, "Oji6HRoPi7rH7HPdWVakuw": 1, "LBJfwOEzExRxzlAnSuI7eg": 1], isRisky: true),

        // Canvas dimensions are ALSO read from MobileGestalt (MGKeys:
        // MainScreenCanvasSizes), not only from the graphics plist that
        // bad_query cannot reach. Values are injected per-device at apply
        // time by RDARFix.applyCanvasSizesGestalt (native screen bounds).
        .init(id: .rdarCanvasGestalt, category: .display, title: L10n.shared.tr("tweak.rdargestalt.title"), detail: L10n.shared.tr("tweak.rdargestalt.detail"), values: [:], isExperimental: true),
    ]

    static func definition(for id: GestaltTweakID) -> GestaltTweakDefinition? {
        definitions.first { $0.id == id }
    }
}

enum GestaltCacheDataPatchError: LocalizedError {
    case cacheDataMissing, cacheDataTooShort, patternNotFound, invalidOffset

    var errorDescription: String? {
        switch self {
        case .cacheDataMissing: L10n.shared.tr("ipadosp.error.missing")
        case .cacheDataTooShort: L10n.shared.tr("ipadosp.error.tooshort")
        case .patternNotFound: L10n.shared.tr("ipadosp.error.notfound")
        case .invalidOffset: L10n.shared.tr("ipadosp.error.invalidoffset")
        }
    }
}

enum GestaltCacheDataPatch {
    /// Binary patch of the top-level `CacheData` blob following Nugget's
    /// iPadOS-mode marker search: find the capability nibble and flip it to 3.
    static func applyiPadOSMode(to plist: inout [String: Any]) throws {
        guard let cacheData = plist["CacheData"] as? Data else {
            throw GestaltCacheDataPatchError.cacheDataMissing
        }

        var hex = Array(cacheData.map { String(format: "%02x", $0) }.joined())
        let sliceStart = 1616
        let sliceLength = 200
        guard hex.count > sliceStart else { throw GestaltCacheDataPatchError.cacheDataTooShort }

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
        guard let offset = matchedOffset else { throw GestaltCacheDataPatchError.patternNotFound }

        let rightOffset = offset + 13
        let leftOffset = offset - 67
        guard leftOffset > 0, rightOffset < hex.count - 1 else {
            throw GestaltCacheDataPatchError.invalidOffset
        }
        for position in [leftOffset, rightOffset] {
            guard ["1", "3"].contains(String(hex[position])),
                  hex[position - 1] == "0", hex[position + 1] == "0" else {
                throw GestaltCacheDataPatchError.invalidOffset
            }
        }

        hex[leftOffset] = "3"
        let updatedHex = String(hex)
        var updatedData = Data(capacity: updatedHex.count / 2)
        var index = updatedHex.startIndex
        while index < updatedHex.endIndex {
            let next = updatedHex.index(index, offsetBy: 2)
            guard let byte = UInt8(updatedHex[index..<next], radix: 16) else {
                throw GestaltCacheDataPatchError.invalidOffset
            }
            updatedData.append(byte)
            index = next
        }
        plist["CacheData"] = updatedData
    }
}
