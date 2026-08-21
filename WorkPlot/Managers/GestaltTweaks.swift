import Foundation

enum GestaltTweakCategory: String, CaseIterable, Identifiable {
    case region, display, hardware, ipad, internalFeatures

    var id: String { rawValue }

    var label: String {
        switch self {
        case .region: "Region"
        case .display: "Display & Appearance"
        case .hardware: "Hardware Capabilities"
        case .ipad: "iPad Capabilities"
        case .internalFeatures: "Internal & Research"
        }
    }
}

enum GestaltTweakID: String, CaseIterable, Identifiable {
    case supportsDynamicIsland, alwaysOnDisplay, alwaysOnDisplayVibrancy
    case aiRegionUS
    case disableParallax, enableLiquidGlassLowPerformance, disableLiquidGlassLowPerformance
    case bootChime, chargeLimit, tapToWake, cameraButton
    case pencil, actionButton, collisionSOS
    case stageManager, iPadOS, iPadApps
    case internalInstall, internalStorage, securityResearchDevice

    var id: String { rawValue }
}

struct GestaltTweakDefinition: Identifiable {
    let id: GestaltTweakID
    let category: GestaltTweakCategory
    let title: String
    let detail: String
    let values: [String: Any]
    var isRisky = false
}

enum GestaltTweakCatalog {
    static let definitions: [GestaltTweakDefinition] = [
        .init(id: .aiRegionUS, category: .region, title: "AI Region: US (LL/A)", detail: "Spoofs US region untuk Apple Intelligence; bisa spoof model device.", values: [:], isRisky: true),

        .init(id: .supportsDynamicIsland, category: .display, title: "Dynamic Island", detail: "Enable Dynamic Island capability.", values: ["YlEtTtHlNesRBMal1CqRaA": 1]),
        .init(id: .alwaysOnDisplay, category: .display, title: "Always-On Display", detail: "May increase burn-in risk on unsupported devices.", values: ["2OOJf1VhaM7NxfRok3HbWQ": 1, "j8/Omm6s1lsmTDFsXjsBfA": 1], isRisky: true),
        .init(id: .alwaysOnDisplayVibrancy, category: .display, title: "AOD Vibrancy", detail: "Use when AOD rendering looks incorrect.", values: ["ykpu7qyhqFweVMKtxNylWA": 1]),
        .init(id: .disableParallax, category: .display, title: "Disable Wallpaper Parallax", detail: "Stops wallpaper motion based on device movement.", values: ["UIParallaxCapability": 0]),
        .init(id: .enableLiquidGlassLowPerformance, category: .display, title: "Liquid Glass Low-Performance ON", detail: "For iOS 26 and later.", values: ["SAGvsp6O6kAQ4fEfDJpC4Q": 1]),
        .init(id: .disableLiquidGlassLowPerformance, category: .display, title: "Liquid Glass Low-Performance OFF", detail: "Mutually exclusive with the option above.", values: ["SAGvsp6O6kAQ4fEfDJpC4Q": 0]),

        .init(id: .bootChime, category: .hardware, title: "Boot & Shutdown Chime", detail: "Enables boot/shutdown chime capability.", values: ["QHxt+hGLaBPbQJbXiUJX3w": 1]),
        .init(id: .chargeLimit, category: .hardware, title: "Charge Limit Menu", detail: "Shows Settings menu; actual limiting depends on hardware.", values: ["37NVydb//GP/GrhuTN+exg": 1]),
        .init(id: .tapToWake, category: .hardware, title: "Tap to Wake", detail: "Primarily for iPhone SE where unavailable.", values: ["yZf3GTRMGTuwSV/lD7Cagw": 1]),
        .init(id: .cameraButton, category: .hardware, title: "Camera Control Settings", detail: "Shows Camera Control settings and capabilities.", values: ["CwvKxM2cEogD3p+HYgaW0Q": 1, "oOV1jhJbdV3AddkcCg0AEA": 1]),
        .init(id: .pencil, category: .hardware, title: "Apple Pencil Settings", detail: "Shows Apple Pencil settings page.", values: ["yhHcB0iH0d1XzPO/CFd3ow": 1]),
        .init(id: .actionButton, category: .hardware, title: "Action Button Settings", detail: "Shows Action Button settings page.", values: ["cT44WE1EohiwRzhsZ8xEsw": 1]),
        .init(id: .collisionSOS, category: .hardware, title: "Collision SOS", detail: "Shows collision detection in SOS settings.", values: ["HCzWusHQwZDea6nNhaKndw": 1]),

        .init(id: .stageManager, category: .ipad, title: "Stage Manager Support", detail: "Marks device as supporting Stage Manager.", values: ["qeaj75wk3HF4DwQ8qbIi7g": 1]),
        .init(id: .iPadApps, category: .ipad, title: "Allow iPad Apps", detail: "Enables iPad app compatibility types on iPhone.", values: ["9MZ5AdH43csAUajl/dU+IQ": [1, 2]]),
        .init(id: .iPadOS, category: .ipad, title: "Enable iPadOS Mode", detail: "Mengubah 5 capabilities + CacheData; eksperimental dan berisiko tinggi.", values: ["mG0AnH/Vy1veoqoLRAIgTA": 1, "UCG5MkVahJxG1YULbbd5Bg": 1, "ZYqko/XM5zD3XBfN5RmaXA": 1, "nVh/gwNpy7Jv1NOk00CMrw": 1, "uKc7FPnEO++lVhHWHFlGbQ": 1], isRisky: true),

        .init(id: .internalInstall, category: .internalFeatures, title: "Apple Internal Install", detail: "Enables internal capabilities like Metal HUD; some services may misbehave.", values: ["EqrsVvjcYDdxHBiQmGhAWw": 1], isRisky: true),
        .init(id: .internalStorage, category: .internalFeatures, title: "Internal Storage View", detail: "Shows internal files in Storage settings; high risk on some iPads.", values: ["LBJfwOEzExRxzlAnSuI7eg": 1], isRisky: true),
        .init(id: .securityResearchDevice, category: .internalFeatures, title: "Security Research Device Mode", detail: "Marks device as a Security Research Device.", values: ["XYlJKKkj2hztRP1NWWnhlw": 1], isRisky: true),
    ]

    static func definition(for id: GestaltTweakID) -> GestaltTweakDefinition? {
        definitions.first { $0.id == id }
    }
}

enum GestaltCacheDataPatchError: LocalizedError {
    case cacheDataMissing, cacheDataTooShort, patternNotFound, invalidOffset

    var errorDescription: String? {
        switch self {
        case .cacheDataMissing: "MobileGestalt tidak punya CacheData, jadi iPadOS mode tidak bisa diaktifkan."
        case .cacheDataTooShort: "CacheData terlalu pendek untuk dipatch dengan aman."
        case .patternNotFound: "Marker iPadOS dari Nugget tidak ditemukan di CacheData."
        case .invalidOffset: "Validasi offset CacheData gagal. Tidak ada perubahan."
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
