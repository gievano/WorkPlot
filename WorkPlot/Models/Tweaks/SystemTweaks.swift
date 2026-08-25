import Foundation

/// System category tweaks.
enum SystemTweaks {
    static let all: [Tweak] = [
        Tweak(
            id: "boot-chime",
            title: "Boot Chime",
            subtitle: "Enable the macOS-style boot chime on startup.",
            category: .system,
            symbol: "music.note",
            isRisky: false,
            notes: nil,
            modifications: [
                GestaltModification(key: "QHxt+hGLaBPbQJbXiUJX3w",
                                    subkey: nil, value: .int(1))
            ]
        ),
        Tweak(
            id: "charge-limit",
            title: "Charge Limit",
            subtitle: "Enable the 80% charge limit setting.",
            category: .system,
            symbol: "battery.75percent",
            isRisky: false,
            notes: nil,
            modifications: [
                GestaltModification(key: "37NVydb//GP/GrhuTN+exg",
                                    subkey: nil, value: .int(1))
            ]
        ),
        Tweak(
            id: "collision-sos",
            title: "Collision SOS",
            subtitle: "Enable the Crash Detection menu.",
            category: .system,
            symbol: "car.side.fill",
            isRisky: false,
            notes: nil,
            modifications: [
                GestaltModification(key: "HCzWusHQwZDea6nNhaKndw",
                                    subkey: nil, value: .int(1))
            ]
        ),
        Tweak(
            id: "tap-to-wake",
            title: "Tap to Wake",
            subtitle: "Enable Tap to Wake (useful on iPhone SE).",
            category: .system,
            symbol: "hand.tap.fill",
            isRisky: false,
            notes: nil,
            modifications: [
                GestaltModification(key: "yZf3GTRMGTuwSV/lD7Cagw",
                                    subkey: nil, value: .int(1))
            ]
        ),
        Tweak(
            id: "iphone-16-settings",
            title: "iPhone 16 Settings",
            subtitle: "Reveal the Camera Control settings panes.",
            category: .system,
            symbol: "button.programmable",
            isRisky: false,
            notes: nil,
            modifications: [
                GestaltModification(key: "CwvKxM2cEogD3p+HYgaW0Q",
                                    subkey: nil, value: .int(1)),
                GestaltModification(key: "oOV1jhJbdV3AddkcCg0AEA",
                                    subkey: nil, value: .int(1)),
            ]
        ),
        Tweak(
            id: "parallax",
            title: "Disable Wallpaper Parallax",
            subtitle: "Turn off the wallpaper depth/parallax effect.",
            category: .system,
            symbol: "square.3.layers.3d.slash",
            isRisky: false,
            notes: nil,
            modifications: [
                GestaltModification(key: "UIParallaxCapability",
                                    subkey: nil, value: .int(0))
            ]
        ),
        Tweak(
            id: "stage-manager",
            title: "Stage Manager",
            subtitle: "Advertise Stage Manager support.",
            category: .system,
            symbol: "macwindow",
            isRisky: false,
            notes: nil,
            modifications: [
                GestaltModification(key: "qeaj75wk3HF4DwQ8qbIi7g",
                                    subkey: nil, value: .int(1))
            ]
        ),
        Tweak(
            id: "shutter",
            title: "Region Restrictions",
            subtitle: "Spoof region to lift shutter-sound restrictions.",
            category: .system,
            symbol: "camera.aperture",
            isRisky: false,
            notes: nil,
            modifications: [
                GestaltModification(key: "h63QSdBCiT/z0WU6rdQv6Q",
                                    subkey: nil, value: .string("US")),
                GestaltModification(key: "zHeENZu+wbg7PUprwNwBWg",
                                    subkey: nil, value: .string("LL/A")),
            ]
        ),
        Tweak(
            id: "pencil",
            title: "Apple Pencil Settings",
            subtitle: "Reveal the Apple Pencil settings tab.",
            category: .system,
            symbol: "pencil.tip",
            isRisky: false,
            notes: nil,
            modifications: [
                GestaltModification(key: "yhHcB0iH0d1XzPO/CFd3ow",
                                    subkey: nil, value: .int(1))
            ]
        ),
        Tweak(
            id: "action-button",
            title: "Action Button Settings",
            subtitle: "Reveal the Action Button settings tab.",
            category: .system,
            symbol: "button.horizontal.top.press.fill",
            isRisky: false,
            notes: nil,
            modifications: [
                GestaltModification(key: "cT44WE1EohiwRzhsZ8xEsw",
                                    subkey: nil, value: .int(1))
            ]
        ),
        Tweak(
            id: "internal-storage",
            title: "Internal Storage",
            subtitle: "Expose internal storage capacity.",
            category: .system,
            symbol: "internaldrive.fill",
            isRisky: true,
            notes: "Risky on some devices, mainly iPads.",
            modifications: [
                GestaltModification(key: "LBJfwOEzExRxzlAnSuI7eg",
                                    subkey: nil, value: .int(1))
            ]
        ),
        Tweak(
            id: "internal-install",
            title: "Internal Install",
            subtitle: "Mark the build as internal (Metal HUD anywhere).",
            category: .system,
            symbol: "wrench.and.screwdriver.fill",
            isRisky: false,
            notes: nil,
            modifications: [
                GestaltModification(key: "EqrsVvjcYDdxHBiQmGhAWw",
                                    subkey: nil, value: .int(1))
            ]
        ),
        Tweak(
            id: "internal-features",
            title: "Internal Features",
            subtitle: "Expose internal settings and build flags via CacheData.",
            category: .system,
            symbol: "ant",
            isRisky: true,
            notes: "Writes the internal-build, internal-settings-bundle and internal-install flags directly into CacheData.",
            modifications: [
                GestaltModification(key: "EqrsVvjcYDdxHBiQmGhAWw",
                                    subkey: nil, value: .int(1),
                                    cacheDataKey: "EqrsVvjcYDdxHBiQmGhAWw",
                                    cacheDataDisabledValue: 0),
                GestaltModification(key: "Oji6HRoPi7rH7HPdWVakuw",
                                    subkey: nil, value: .int(1),
                                    cacheDataKey: "Oji6HRoPi7rH7HPdWVakuw",
                                    cacheDataDisabledValue: 0),
                GestaltModification(key: "LBJfwOEzExRxzlAnSuI7eg",
                                    subkey: nil, value: .int(1),
                                    cacheDataKey: "LBJfwOEzExRxzlAnSuI7eg",
                                    cacheDataDisabledValue: 0),
            ]
        ),
        Tweak(
            id: "srd",
            title: "Security Research Device",
            subtitle: "Enable Security Research Device mode.",
            category: .system,
            symbol: "lock.shield.fill",
            isRisky: true,
            notes: "Intended for security research devices.",
            modifications: [
                GestaltModification(key: "XYlJKKkj2hztRP1NWWnhlw",
                                    subkey: nil, value: .int(1))
            ]
        ),
    ]
}
