import Foundation

public struct LiquidGlassController {
    public static func disableGlobal() -> Bool {
        let path = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"
        guard var plist = FileSystemAccessor.readPlist(from: path) else { return false }
        var flags = plist["FeatureFlags"] as? [String: Any] ?? [:]
        flags["LiquidGlassSlider"] = 0
        plist["FeatureFlags"] = flags
        return FileSystemAccessor.writePlist(plist, to: path)
    }
}
