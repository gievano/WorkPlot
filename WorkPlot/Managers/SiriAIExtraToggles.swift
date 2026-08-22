//
//  SiriAIExtraToggles.swift
//  WorkPlot
//
//  Dua toggle tambahan untuk section Siri AI:
//  1. Sinkronisasi key ProductType utama (h9jDsbgj7xIVeIQ8S3/X3Q) dengan
//     target spoof yang dipilih; OFF menghapus key (removeValue).
//  2. Key eligibility Apple Intelligence (A62OafQ85EJAiiqKn4agtg = 1)
//     sebagai toggle tunggal tanpa menyentuh key lain.
//

import Foundation

enum ModelSpoofKeyError: LocalizedError {
    case missingSpoofTarget

    var errorDescription: String? {
        "Select a spoofed device in the Spoof section before enabling the ProductType key."
    }
}

struct ModelSpoofKeyApplier {
    static let cacheExtraKey = AIRegionKeys.productType

    /// ON hanya bila nilai key sudah sama dengan ProductType target spoof
    /// efektif (yang dipilih di UI atau yang sedang tertulis di device).
    static func isEnabled(in plist: [String: Any], target: SpoofTarget?) -> Bool {
        guard let target else { return false }
        let cacheExtra = plist["CacheExtra"] as? [String: Any] ?? [:]
        return cacheExtra[cacheExtraKey] as? String == target.productType
    }

    static func setEnabled(
        _ enabled: Bool,
        target: SpoofTarget?,
        in plist: inout [String: Any]
    ) throws {
        var cacheExtra = plist["CacheExtra"] as? [String: Any] ?? [:]
        if enabled {
            guard let target else { throw ModelSpoofKeyError.missingSpoofTarget }
            cacheExtra[cacheExtraKey] = target.productType
        } else {
            cacheExtra.removeValue(forKey: cacheExtraKey)
        }
        plist["CacheExtra"] = cacheExtra
    }
}

struct AIRegionEligibilityApplier {
    static let cacheExtraKey = AIRegionKeys.eligibility
    private static let enabledValue = 1

    static func isEnabled(in plist: [String: Any]) -> Bool {
        let cacheExtra = plist["CacheExtra"] as? [String: Any] ?? [:]
        return cacheExtra[cacheExtraKey] as? Int == enabledValue
    }

    /// Berbeda dari AppleIntelligenceController: versi ini hanya menyentuh
    /// key eligibility, tanpa ikut men-set key Siri mode.
    static func setEnabled(_ enabled: Bool, in plist: inout [String: Any]) {
        var cacheExtra = plist["CacheExtra"] as? [String: Any] ?? [:]
        if enabled {
            cacheExtra[cacheExtraKey] = enabledValue
        } else {
            cacheExtra.removeValue(forKey: cacheExtraKey)
        }
        plist["CacheExtra"] = cacheExtra
    }
}
