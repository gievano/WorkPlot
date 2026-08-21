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

struct LiquidGlassState {
    var cacheExtraValue: Int?
    var sliderDisabled: Bool
}

struct LiquidGlassError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct LiquidGlassController {
    static let cacheExtraKey = "SAGvsp6O6kAQ4fEfDJpC4Q"

    static func currentState() -> LiquidGlassState? {
        guard let plist = ExploitManager.shared.readGestalt() else { return nil }
        return state(from: plist)
    }

    static func state(from plist: [String: Any]) -> LiquidGlassState {
        let cacheExtra = plist["CacheExtra"] as? [String: Any] ?? [:]
        let featureFlags = plist["FeatureFlags"] as? [String: Any] ?? [:]
        return LiquidGlassState(
            cacheExtraValue: cacheExtra[cacheExtraKey] as? Int,
            sliderDisabled: (featureFlags["LiquidGlassSlider"] as? Int) == 0
        )
    }

    static func apply(mode: LiquidGlassMode, sliderDisabled: Bool) throws {
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

        var featureFlags = plist["FeatureFlags"] as? [String: Any] ?? [:]
        featureFlags["LiquidGlassSlider"] = sliderDisabled ? 0 : 1
        plist["FeatureFlags"] = featureFlags

        try ExploitManager.shared.saveGestaltOrThrow(plist)
    }

    static func disableGlobal() throws {
        try apply(mode: .systemDefault, sliderDisabled: true)
    }
}
