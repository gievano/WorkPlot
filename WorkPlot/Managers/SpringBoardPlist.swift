import Foundation

enum SpringBoardPlistError: LocalizedError {
    case notReachable

    var errorDescription: String? {
        L10n.shared.tr("sb.error.notReachable")
    }
}

/// Direct SpringBoard preference edits. The suppression flag below is the
/// ONLY known switch that truly hides the Dynamic Island on NATIVE island
/// devices - MobileGestalt's DeviceSupportsDynamicIsland is an enable-only
/// override (writing 0 leaves the hardware default = island stays). Mirrors
/// Nugget >= 7.2 "Hide Dynamic Island Completely" and EnsWilde.
enum SpringBoardPlist {
    static let suppressKey = "SBSuppressDynamicIslandCompletely"

    static var candidatePaths: [String] {
        var paths = [
            "/var/mobile/Library/Preferences/com.apple.springboard.plist",
            "/private/var/mobile/Library/Preferences/com.apple.springboard.plist",
            "/var/preferences/com.apple.springboard.plist",
        ]
        // System-container sweep, same idea as the graphics-plist probe.
        let containerRoot = "/var/containers/Data/System"
        if let entries = try? FileManager.default.contentsOfDirectory(atPath: containerRoot) {
            for entry in entries.prefix(64) {
                paths.append("\(containerRoot)/\(entry)/Library/Preferences/com.apple.springboard.plist")
            }
        }
        return paths
    }

    /// Returns one honest status line per reachable plist copy; throws only
    /// when no copy was readable at all. InodeWriter snapshots the original
    /// bytes and rolls back on any failed/partial write.
    @discardableResult
    static func setSuppressed(_ suppressed: Bool) throws -> [String] {
        var lines: [String] = []
        var reachedAny = false
        for path in candidatePaths {
            guard let data = FileManager.default.contents(atPath: path),
                  var plist = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any] else {
                continue
            }
            reachedAny = true
            let current = (plist[suppressKey] as? Bool) ?? false
            if current == suppressed {
                lines.append("\(path): already \(suppressed ? "hidden" : "visible")")
                continue
            }
            plist[suppressKey] = suppressed
            let out = try PropertyListSerialization.data(fromPropertyList: plist, format: .binary, options: 0)
            // The direct open(O_WRONLY) inside InodeWriter needs a bad_query
            // lease - without it every write dies with errno=1 EPERM and the
            // caller's whole apply aborts (same root cause as Liquid Glass #51).
            try BadQueryLeaseScope.withLease(forPath: path) {
                try InodeWriter.writeVerifiedInPlace(out, to: path)
            }
            lines.append("\(path): patched")
        }
        guard reachedAny else { throw SpringBoardPlistError.notReachable }
        return lines
    }
}
