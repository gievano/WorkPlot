import Foundation

public struct LiquidGlassController {
    public static func disableGlobal() -> Bool {
        guard var plist = ExploitManager.shared.readGestalt() else { return false }
        var flags = plist["FeatureFlags"] as? [String: Any] ?? [:]
        flags["LiquidGlassSlider"] = 0
        plist["FeatureFlags"] = flags
        return ExploitManager.shared.saveGestalt(plist)
    }
}
