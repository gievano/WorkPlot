import Foundation

/// Device category tweaks.
enum DeviceTweaks {
    static let all: [Tweak] = [
        Tweak(
            id: "model-name",
            title: "Device Model Name",
            subtitle: "Change the model name shown in Settings.",
            category: .device,
            symbol: "iphone",
            isRisky: false,
            notes: nil,
            detail: .textField(placeholder: "Custom model name", keyboard: .plain),
            modifications: [
                GestaltModification(key: "oPeik/9e8lQWMszEjbPzng",
                                    subkey: "ArtworkDeviceProductDescription",
                                    value: .string(""))
            ]
        ),
        Tweak(
            id: "device-subtype",
            title: "Device Artwork Subtype",
            subtitle: "Report a different device model for artwork/UI behavior.",
            category: .device,
            symbol: "iphone.gen3",
            isRisky: true,
            notes: "Changes the reported device. Some subtypes disable the Dynamic Island; some devices only support certain values. 'Original' keeps the device's current value. 'None' disables the Dynamic Island.",
            detail: .picker(options: [
                "Original",
                "None (Disable Dynamic Island)",
                "iPhone 14 Pro",
                "iPhone 14 Pro Max",
                "iPhone 15 Pro Max",
                "iPhone 16 Pro",
                "iPhone 16 Pro Max",
                "iPhone Air",
            ]),
            pickerValues: [.keepCurrent, .int(0), .int(2436), .int(2796), .int(2976), .int(2622), .int(2868), .int(2736)],
            modifications: [
                GestaltModification(key: "oPeik/9e8lQWMszEjbPzng",
                                    subkey: "ArtworkDeviceSubType",
                                    value: .keepCurrent, isPicker: true)
            ]
        ),
        // Full-identity spoof routed through DeviceSpoofingManager in
        // GestaltStore.apply() — its write-set spans ~20 CacheExtra keys and
        // name keys that only overwrite when already cached, which plain
        // GestaltModifications can't express.
        Tweak(
            id: Tweak.deviceSpoofTweakID,
            title: "Device Spoof",
            subtitle: "Spoof the reported model for Apple Intelligence eligibility.",
            category: .device,
            symbol: "iphone.and.arrow.forward",
            isRisky: true,
            notes: "Spoofs every model-identity key at once (ProductType, board, marketing name). May break Face ID until reverted — restore the pristine backup to undo. 'None' keeps your real identity.",
            detail: .picker(options:
                ["None (Real Identity)"] + DeviceSpoofingManager.targets.map(\.marketingName)),
            modifications: []
        ),
    ]
}
