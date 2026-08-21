import Foundation

enum GestaltArtworkError: LocalizedError {
    case artworkDictionaryMissing

    var errorDescription: String? {
        switch self {
        case .artworkDictionaryMissing:
            "MobileGestalt tidak punya dictionary ArtworkDevice, jadi Dynamic Island atau nama model tidak bisa diubah."
        }
    }
}

enum GestaltArtwork {
    static let artworkKey = "oPeik/9e8lQWMszEjbPzng"
    static let dynamicIslandCapabilityKey = "YlEtTtHlNesRBMal1CqRaA"

    static func setDynamicIslandSubtype(_ subtype: Int, in plist: inout [String: Any]) throws {
        guard var artwork = (plist["CacheExtra"] as? [String: Any])?[artworkKey] as? [String: Any] else {
            throw GestaltArtworkError.artworkDictionaryMissing
        }
        artwork["ArtworkDeviceSubType"] = subtype
        setArtwork(artwork, in: &plist)
        var cacheExtra = plist["CacheExtra"] as? [String: Any] ?? [:]
        cacheExtra[dynamicIslandCapabilityKey] = 1
        plist["CacheExtra"] = cacheExtra
    }

    static func setModelName(_ name: String, in plist: inout [String: Any]) throws {
        guard var artwork = (plist["CacheExtra"] as? [String: Any])?[artworkKey] as? [String: Any] else {
            throw GestaltArtworkError.artworkDictionaryMissing
        }
        artwork["ArtworkDeviceProductDescription"] = name
        setArtwork(artwork, in: &plist)
    }

    private static func setArtwork(_ artwork: [String: Any], in plist: inout [String: Any]) {
        var cacheExtra = plist["CacheExtra"] as? [String: Any] ?? [:]
        cacheExtra[artworkKey] = artwork
        plist["CacheExtra"] = cacheExtra
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
        .init(subtype: 2622, title: "iPhone 16 Pro"),
        .init(subtype: 2868, title: "iPhone 16 Pro Max"),
        .init(subtype: 2736, title: "iPhone Air")
    ]
}
