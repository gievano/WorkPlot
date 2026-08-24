import Foundation

enum LiquidGlassMode: String, CaseIterable, Identifiable {
    case systemDefault
    case lowPerformanceOff
    case lowPerformanceOn

    var id: String { rawValue }

    var label: String {
        L10n.shared.tr(labelKey)
    }

    var labelKey: String {
        switch self {
        case .systemDefault: "lg.mode.default"
        case .lowPerformanceOff: "lg.mode.off"
        case .lowPerformanceOn: "lg.mode.on"
        }
    }

    var descriptionKey: String {
        switch self {
        case .systemDefault: "lg.desc.default"
        case .lowPerformanceOff: "lg.desc.off"
        case .lowPerformanceOn: "lg.desc.on"
        }
    }

    var cacheExtraValue: Int? {
        switch self {
        case .systemDefault: nil
        case .lowPerformanceOff: 0
        case .lowPerformanceOn: 1
        }
    }
}

struct LiquidGlassError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct LiquidGlassController {
    /// IsSolariumLowPerformanceDevice (PoomSmart/MGKeys deobfuscation):
    /// tells the system this device gets the non-refractive fallback look.
    static let cacheExtraKey = "SAGvsp6O6kAQ4fEfDJpC4Q"

    static func currentMode() -> LiquidGlassMode {
        guard let plist = ExploitManager.shared.readGestalt(),
              let cacheExtra = plist["CacheExtra"] as? [String: Any],
              let value = cacheExtra[cacheExtraKey] as? Int else { return .systemDefault }
        return LiquidGlassMode.allCases.first { $0.cacheExtraValue == value } ?? .systemDefault
    }

    static func apply(mode: LiquidGlassMode) throws {
        guard var plist = ExploitManager.shared.readGestalt() else {
            throw LiquidGlassError(message: L10n.shared.tr("lg.error.read"))
        }

        var cacheExtra = plist["CacheExtra"] as? [String: Any] ?? [:]
        if let value = mode.cacheExtraValue {
            cacheExtra[cacheExtraKey] = value
        } else {
            cacheExtra.removeValue(forKey: cacheExtraKey)
        }
        plist["CacheExtra"] = cacheExtra

        // Cleanup: older builds wrote an invented top-level flag that no
        // iOS component reads - remove it instead of compounding the lie.
        if var featureFlags = plist["FeatureFlags"] as? [String: Any],
           featureFlags.removeValue(forKey: "LiquidGlassSlider") != nil {
            plist["FeatureFlags"] = featureFlags
        }

        try ExploitManager.shared.saveGestaltOrThrow(plist)
    }

    /// Real Solarium suppression following Nugget >= 7.2 / EnsWilde: bool
    /// keys in global preferences, NOT MobileGestalt (the Gestalt side only
    /// forces the low-performance renderer). Honored on iOS 26.x builds;
    /// later builds may ignore them - status lines stay honest per path.
    static func disableGlobal() throws -> [String] {
        var lines: [String] = []

        guard var plist = ExploitManager.shared.readGestalt() else {
            throw LiquidGlassError(message: L10n.shared.tr("lg.error.read"))
        }
        var cacheExtra = plist["CacheExtra"] as? [String: Any] ?? [:]
        cacheExtra[cacheExtraKey] = 1
        plist["CacheExtra"] = cacheExtra
        try ExploitManager.shared.saveGestaltOrThrow(plist)
        lines.append("MobileGestalt: IsSolariumLowPerformanceDevice = 1")

        lines += try GlobalPreferences.setSolariumSuppressed(true)
        return lines
    }
}

/// Probe-and-patch every reachable copy of the global preference domain,
/// same pattern as SpringBoardPlist. InodeWriter snapshots original bytes
/// and rolls back failed/partial writes.
private enum GlobalPreferences {
    static let paths = [
        "/var/Managed Preferences/mobile/.GlobalPreferences.plist",
        "/var/mobile/Library/Preferences/.GlobalPreferences.plist",
        "/private/var/mobile/Library/Preferences/.GlobalPreferences.plist",
    ]

    static let solariumKeys: [String: Bool] = [
        "com.apple.SwiftUI.DisableSolarium": true,
        "SolariumForceFallback": true,
    ]

    static func setSolariumSuppressed(_ suppressed: Bool) throws -> [String] {
        var lines: [String] = []
        var reachedAny = false
        for path in paths {
            guard let data = FileManager.default.contents(atPath: path) else { continue }
            var format = PropertyListSerialization.PropertyListFormat.binary
            guard var plist = (try? PropertyListSerialization.propertyList(from: data, options: [], format: &format)) as? [String: Any] else {
                continue
            }
            reachedAny = true
            var changed = false
            for (key, value) in solariumKeys {
                if suppressed {
                    if (plist[key] as? Bool) != value {
                        plist[key] = value
                        changed = true
                    }
                } else if plist[key] != nil {
                    plist.removeValue(forKey: key)
                    changed = true
                }
            }
            if changed {
                let out = try PropertyListSerialization.data(fromPropertyList: plist, format: format, options: 0)
                // The direct InodeWriter open() needs a bad_query lease, just
                // like RDARFix.apply - without it open(O_WRONLY) returns EPERM.
                try BadQueryLeaseScope.withLease(forPath: path) {
                    try InodeWriter.writeVerifiedInPlace(out, to: path)
                }
                lines.append("\(path): \(suppressed ? "solarium suppressed" : "solarium keys restored")")
            } else {
                lines.append("\(path): already \(suppressed ? "suppressed" : "clean")")
            }
        }
        guard reachedAny else {
            throw LiquidGlassError(message: L10n.shared.tr("lg.error.globalNotReachable"))
        }
        return lines
    }
}
