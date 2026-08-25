import Foundation

/// Display category tweaks.
enum DisplayTweaks {
    static let all: [Tweak] = [
        Tweak(
            id: "dynamic-island",
            title: "Dynamic Island",
            subtitle: "Force the Dynamic Island capability bit directly.",
            category: .display,
            symbol: "rectangle.inset.filled",
            isRisky: false,
            notes: nil,
            modifications: [
                GestaltModification(key: "YlEtTtHlNesRBMal1CqRaA",
                                    subkey: nil, value: .int(1))
            ]
        ),
        Tweak(
            id: "aod",
            title: "Always-On Display",
            subtitle: "Enable Always-On Display support.",
            category: .display,
            symbol: "sun.max.fill",
            isRisky: false,
            notes: nil,
            modifications: [
                GestaltModification(key: "2OOJf1VhaM7NxfRok3HbWQ",
                                    subkey: nil, value: .int(1)),
                GestaltModification(key: "j8/Omm6s1lsmTDFsXjsBfA",
                                    subkey: nil, value: .int(1)),
            ]
        ),
        Tweak(
            id: "aod-vibrancy",
            title: "AOD Vibrancy",
            subtitle: "Enable the Always-On Display vibrancy effect.",
            category: .display,
            symbol: "sparkles",
            isRisky: false,
            notes: nil,
            modifications: [
                GestaltModification(key: "ykpu7qyhqFweVMKtxNylWA",
                                    subkey: nil, value: .int(1))
            ]
        ),
        Tweak(
            id: "pwm",
            title: "Pulse Width Modulation",
            subtitle: "Advertise PWM display support.",
            category: .display,
            symbol: "waveform",
            isRisky: false,
            notes: nil,
            modifications: [
                GestaltModification(key: "6IejgN+1Fmu5/QrZFOIeNw",
                                    subkey: nil, value: .int(1))
            ]
        ),
    ]
}
