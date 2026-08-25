import Foundation

/// Direct eligibility manipulation — the same file EnsWilde drops via its
/// bookassetd chain, but reached through bad_query on iOS 27 where the
/// SystemGroup tree (/var/containers/Shared/SystemGroup/*) is granted.
/// Domains are merged into the existing plist so unrelated eligibility state
/// is preserved.
enum EligibilityError: LocalizedError {
    case unavailable
    case badPlist
    case writeFailed
    case writeVerificationFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "The eligibility container isn't reachable on this firmware. SystemGroup is only granted on iOS 27; on iOS 26.x containermanagerd refuses it (bad_query -3). Use the Apple Intelligence tweak + Device Spoof in Tweaks instead."
        case .badPlist:
            return "The eligibility plist could not be parsed."
        case .writeFailed:
            return "The write to eligibility.plist failed."
        case .writeVerificationFailed:
            return "The write did not verify. The original file was restored."
        }
    }
}

final class EligibilityManager: ObservableObject {

    static let shared = EligibilityManager()

    @Published var enableGreyMatter = false
    @Published var enableCalcium = false
    @Published private(set) var isBusy = false
    @Published var lastError: String?

    private init() {}

    // MARK: - Paths

    /// bad_query's class-13 route can extend the SystemGroup tree on iOS 27
    /// (containermanagerd grants /var/containers/Shared/SystemGroup/* there),
    /// but only as a directory — it refuses to extend a file leaf. So we always
    /// consume the eligibility container directory and operate on the plist
    /// inside it, mirroring the PosterBoard flow.
    static let eligibilityDirPath = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.eligibility"
    static var plistPath: String { eligibilityDirPath + "/eligibility.plist" }

    /// True when bad_query can actually reach AND write the eligibility
    /// container on this firmware. The SystemGroup tree is only granted on
    /// iOS 27 (bad_query -3 on iOS 26.x where the tree is outside the
    /// containermanager sandbox), so availability is probed rather than assumed.
    static func isReachable() -> Bool {
        guard BadQuery.isAvailable else { return false }
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 else { return false }
        do {
            let handle = try BadQuery.consume(path: eligibilityDirPath, create: true)
            defer { handle.release() }
            let dir = URL(fileURLWithPath: eligibilityDirPath, isDirectory: true)
            let probe = dir.appendingPathComponent(".bq_probe")
            try? FileManager.default.removeItem(at: probe)
            try Data([0x00]).write(to: probe, options: .withoutOverwriting)
            defer { try? FileManager.default.removeItem(at: probe) }
            return true
        } catch {
            return false
        }
    }

    private var backupURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("eligibility_backup.plist")
    }

    // MARK: - Read / write

    private func readCurrent() throws -> Data {
        let handle = try BadQuery.consume(path: Self.eligibilityDirPath, create: true)
        defer { handle.release() }
        let url = URL(fileURLWithPath: Self.plistPath)
        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            throw EligibilityError.unavailable
        }
        return data
    }

    private func write(_ data: Data) throws {
        let url = URL(fileURLWithPath: Self.plistPath)
        let handle = try BadQuery.consume(path: Self.eligibilityDirPath, create: true)
        defer { handle.release() }

        let hadBackup = FileManager.default.fileExists(atPath: backupURL.path)
        if !hadBackup, let original = try? readCurrent() {
            try? original.write(to: backupURL)
        }

        do {
            try data.write(to: url, options: [])
        } catch {
            if hadBackup, let original = try? Data(contentsOf: backupURL) {
                try? original.write(to: url, options: [])
            }
            throw EligibilityError.writeFailed
        }

        guard let readback = try? Data(contentsOf: url), readback == data else {
            if hadBackup, let original = try? Data(contentsOf: backupURL) {
                try? original.write(to: url, options: [])
            }
            throw EligibilityError.writeVerificationFailed
        }
    }

    // MARK: - Apply / reset

    func apply() throws {
        guard Self.isReachable() else { throw EligibilityError.unavailable }
        guard !isBusy else { throw EligibilityError.writeFailed }
        isBusy = true
        defer { isBusy = false }

        var base: [String: Any]
        if let current = try? readCurrent(),
           let parsed = try? PropertyListSerialization.propertyList(
               from: current, options: [], format: nil) as? [String: Any] {
            base = parsed
        } else if let bundled = Bundle.main.url(forResource: "eligibility", withExtension: "plist"),
                  let data = try? Data(contentsOf: bundled),
                  let parsed = try? PropertyListSerialization.propertyList(
                      from: data, options: [], format: nil) as? [String: Any] {
            base = parsed
        } else {
            throw EligibilityError.badPlist
        }

        if enableGreyMatter {
            base["OS_ELIGIBILITY_DOMAIN_GREYMATTER"] = Self.greyMatterDomain
        } else {
            base.removeValue(forKey: "OS_ELIGIBILITY_DOMAIN_GREYMATTER")
        }
        if enableCalcium {
            base["OS_ELIGIBILITY_DOMAIN_CALCIUM"] = Self.calciumDomain
        } else {
            base.removeValue(forKey: "OS_ELIGIBILITY_DOMAIN_CALCIUM")
        }

        let data = try PropertyListSerialization.data(fromPropertyList: base, format: .xml, options: 0)
        try write(data)
    }

    /// Restores the pristine eligibility plist captured on the first apply.
    func reset() throws {
        guard Self.isReachable() else { throw EligibilityError.unavailable }
        guard FileManager.default.fileExists(atPath: backupURL.path) else { return }

        let url = URL(fileURLWithPath: Self.plistPath)
        let handle = try BadQuery.consume(path: Self.eligibilityDirPath, create: true)
        defer { handle.release() }

        let original = try Data(contentsOf: backupURL)
        try original.write(to: url, options: [])
        guard let readback = try? Data(contentsOf: url), readback == original else {
            throw EligibilityError.writeVerificationFailed
        }
    }

    // MARK: - Domains (EnsWilde eligibility.plist)

    static let greyMatterDomain: [String: Any] = [
        "context": [
            "OS_ELIGIBILITY_CONTEXT_ELIGIBLE_DEVICE_LANGUAGES": ["en"]
        ],
        "os_eligibility_answer_source_t": 1,
        "os_eligibility_answer_t": 4,
        "status": [
            "OS_ELIGIBILITY_INPUT_DEVICE_LANGUAGE": 3,
            "OS_ELIGIBILITY_INPUT_DEVICE_REGION_CODE": 3,
            "OS_ELIGIBILITY_INPUT_EXTERNAL_BOOT_DRIVE": 3,
            "OS_ELIGIBILITY_INPUT_GENERATIVE_MODEL_SYSTEM": 3,
            "OS_ELIGIBILITY_INPUT_SHARED_IPAD": 3,
            "OS_ELIGIBILITY_INPUT_SIRI_LANGUAGE": 3,
        ],
    ]

    static let calciumDomain: [String: Any] = [
        "os_eligibility_answer_source_t": 1,
        "os_eligibility_answer_t": 2,
        "status": [
            "OS_ELIGIBILITY_INPUT_CHINA_CELLULAR": 2
        ],
    ]
}
