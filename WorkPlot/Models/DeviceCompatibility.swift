import Foundation

// MARK: - Compatibility

/// Supported OS range per the class-13 MobileGestalt bug:
///   iOS 18.0 ... iOS 27.0 beta 4 (build 24A5390f)
/// Anything newer than 27.0 beta 4 is patched and unsupported.
enum DeviceCompatibility {

    /// Reference build of the newest verified-supported OS (27.0 beta 4).
    static let newestSupportedBuild = Build(alpha: "A", number: 5390, seed: "f")

    struct OSInfo {
        let version: OperatingSystemVersion
        let build: String?
    }

    enum Status {
        case supported
        case unsupported(reason: String)
    }

    struct Build: Comparable {
        let alpha: String
        let number: Int
        let seed: String

        static func < (lhs: Build, rhs: Build) -> Bool {
            if lhs.alpha != rhs.alpha { return lhs.alpha < rhs.alpha }
            if lhs.number != rhs.number { return lhs.number < rhs.number }
            return lhs.seed < rhs.seed
        }

        /// "24A5390f" -> (alpha: "A", number: 5390, seed: "f")
        static func parse(_ raw: String) -> Build? {
            let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let letterStart = s.firstIndex(where: { $0.isLetter }) else { return nil }
            var letterEnd = letterStart
            while letterEnd < s.endIndex, s[letterEnd].isLetter {
                letterEnd = s.index(after: letterEnd)
            }
            let alpha = String(s[letterStart..<letterEnd]).uppercased()

            let numStart = letterEnd
            var numEnd = numStart
            while numEnd < s.endIndex, s[numEnd].isNumber {
                numEnd = s.index(after: numEnd)
            }
            guard numStart < numEnd, let number = Int(String(s[numStart..<numEnd])) else {
                return nil
            }
            let seed = String(s[numEnd...])
            return Build(alpha: alpha, number: number, seed: seed)
        }
    }

    /// Reads the marketing OS version and build string of the running system.
    static func currentOS() -> OSInfo {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        var build: String? = nil
        let paths = [
            "/System/Library/CoreServices/SystemVersion.plist",
            "/System/Library/CoreServices/.system_version.plist"
        ]
        for p in paths {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: p)),
               let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
               let b = plist["ProductBuildVersion"] as? String {
                build = b
                break
            }
        }
        return OSInfo(version: version, build: build)
    }

    /// Evaluates support. `build` may be nil; iOS 27 then falls back to
    /// conservative behavior (treated as unsupported with an explanation).
    static func evaluate(version: OperatingSystemVersion,
                         build: String?) -> Status {
        let major = version.majorVersion

        if major < 26 {
            return .unsupported(reason:
                "This app requires iOS 26.0 or newer. You are running iOS \(major).")
        }

        if major > 27 {
            return .unsupported(reason:
                "iOS \(major) is patched. The MobileGestalt access used by this app is only verified up to iOS 27.0 beta 4 (build 24A5390f).")
        }

        if major == 27 {
            guard let raw = build, let parsed = Build.parse(raw) else {
                return .unsupported(reason:
                    "Unable to verify your iOS 27 build. Only up to iOS 27.0 beta 4 (build 24A5390f) is supported; newer builds are patched.")
            }
            if parsed > newestSupportedBuild {
                return .unsupported(reason:
                    "Your build \(raw) is newer than 27.0 developer beta 4 (24A5390f) and is patched.")
            }
        }

        return .supported
    }

    static var currentStatus: Status {
        let os = currentOS()
        return evaluate(version: os.version, build: os.build)
    }

    static var currentInfo: OSInfo { currentOS() }

    // MARK: - Feature gating

    /// Tweaks and Siri AI Setup need iOS 27 for full support. iOS 26.x is
    /// limited to PosterBoard, which works standalone on both versions.
    static func fullFeatureStatus(feature: String) -> Status {
        let version = currentOS().version
        if version.majorVersion < 27 {
            return .unsupported(reason:
                "\(feature) requires iOS 27. You are running iOS \(version.majorVersion).\(version.minorVersion), which currently supports PosterBoard only.")
        }
        return .supported
    }

    static var supportsFullFeatureSet: Bool {
        if case .supported = fullFeatureStatus(feature: "This feature") { return true }
        return false
    }
}
