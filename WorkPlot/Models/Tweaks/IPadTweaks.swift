import Foundation

/// iPad category tweaks — these spoof iPad-only capabilities onto an
/// iPhone, so they're gated to `.iOSOnly` and hidden on real iPads.
enum IPadTweaks {
    static let all: [Tweak] = [
        Tweak(
            id: "ipados",
            title: "iPadOS Mode",
            subtitle: "Spoof iPadOS capabilities and patch CacheData.",
            category: .ipad,
            symbol: "ipad",
            isRisky: true,
            notes: "Highly experimental. Do not enable if you use an alphanumeric passcode. Always backed up.",
            requiresCacheDataPatch: true,
            platform: .iOSOnly,
            modifications: [
                GestaltModification(key: "mG0AnH/Vy1veoqoLRAIgTA",
                                    subkey: nil, value: .int(1)),
                GestaltModification(key: "UCG5MkVahJxG1YULbbd5Bg",
                                    subkey: nil, value: .int(1)),
                GestaltModification(key: "ZYqko/XM5zD3XBfN5RmaXA",
                                    subkey: nil, value: .int(1)),
                GestaltModification(key: "nVh/gwNpy7Jv1NOk00CMrw",
                                    subkey: nil, value: .int(1)),
                GestaltModification(key: "uKc7FPnEO++lVhHWHFlGbQ",
                                    subkey: nil, value: .int(1)),
            ]
        ),
        Tweak(
            id: "iphoneos",
            title: "iOS Mode",
            subtitle: "Spoof iOS capabilities and patch CacheData.",
            category: .ipad,
            symbol: "ipad",
            isRisky: true,
            notes: "Highly experimental. Do not enable if you use an alphanumeric passcode. Always backed up.",
            requiresCacheDataPatch: true,
            platform: .iPadOSOnly,
            modifications: [
                GestaltModification(key: "mG0AnH/Vy1veoqoLRAIgTA",
                                    subkey: nil, value: .int(0)),
                GestaltModification(key: "UCG5MkVahJxG1YULbbd5Bg",
                                    subkey: nil, value: .int(0)),
                GestaltModification(key: "ZYqko/XM5zD3XBfN5RmaXA",
                                    subkey: nil, value: .int(0)),
                GestaltModification(key: "nVh/gwNpy7Jv1NOk00CMrw",
                                    subkey: nil, value: .int(0)),
                GestaltModification(key: "uKc7FPnEO++lVhHWHFlGbQ",
                                    subkey: nil, value: .int(0)),
            ]
        ),
        Tweak(
            id: "ipad-apps",
            title: "Allow iPad Apps",
            subtitle: "Allow iPad apps to install on iPhone.",
            category: .ipad,
            symbol: "apps.iphone",
            isRisky: false,
            notes: nil,
            platform: .iOSOnly,
            modifications: [
                GestaltModification(key: "9MZ5AdH43csAUajl/dU+IQ",
                                    subkey: nil, value: .intArray([1, 2]))
            ]
        ),
    ]
}
