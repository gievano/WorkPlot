import Foundation

/// Liquid Glass category tweaks.
enum LiquidGlassTweaks {
    static let all: [Tweak] = [
        Tweak(
            id: "lg-lpm-enable",
            title: "Liquid Glass Low Power",
            subtitle: "Force low-power mode for Liquid Glass.",
            category: .liquidGlass,
            symbol: "drop.fill",
            isRisky: false,
            notes: nil,
            modifications: [
                GestaltModification(key: "SAGvsp6O6kAQ4fEfDJpC4Q",
                                    subkey: nil, value: .int(1))
            ]
        ),
        Tweak(
            id: "lg-lpm-disable",
            title: "Liquid Glass Full Fidelity",
            subtitle: "Disable Liquid Glass low-power mode.",
            category: .liquidGlass,
            symbol: "drop.halffull",
            isRisky: false,
            notes: nil,
            modifications: [
                GestaltModification(key: "SAGvsp6O6kAQ4fEfDJpC4Q",
                                    subkey: nil, value: .int(0))
            ]
        ),
    ]
}
