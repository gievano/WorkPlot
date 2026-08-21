import Foundation

enum GestaltTweakCategory: String, CaseIterable, Identifiable {
    case display, hardware, ipad, internalFeatures

    var id: String { rawValue }

    var label: String {
        switch self {
        case .display: "Display & Appearance"
        case .hardware: "Hardware Capabilities"
        case .ipad: "iPad Capabilities"
        case .internalFeatures: "Internal & Research"
        }
    }
}

enum GestaltTweakID: String, CaseIterable, Identifiable {
    case supportsDynamicIsland, alwaysOnDisplay, alwaysOnDisplayVibrancy
    case disableParallax, enableLiquidGlassLowPerformance, disableLiquidGlassLowPerformance
    case bootChime, chargeLimit, tapToWake, cameraButton
    case pencil, actionButton, collisionSOS
    case stageManager, iPadApps
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

        .init(id: .internalInstall, category: .internalFeatures, title: "Apple Internal Install", detail: "Enables internal capabilities like Metal HUD; some services may misbehave.", values: ["EqrsVvjcYDdxHBiQmGhAWw": 1], isRisky: true),
        .init(id: .internalStorage, category: .internalFeatures, title: "Internal Storage View", detail: "Shows internal files in Storage settings; high risk on some iPads.", values: ["LBJfwOEzExRxzlAnSuI7eg": 1], isRisky: true),
        .init(id: .securityResearchDevice, category: .internalFeatures, title: "Security Research Device Mode", detail: "Marks device as a Security Research Device.", values: ["XYlJKKkj2hztRP1NWWnhlw": 1], isRisky: true),
    ]

    static func definition(for id: GestaltTweakID) -> GestaltTweakDefinition? {
        definitions.first { $0.id == id }
    }
}
