import Foundation
import SwiftUI

// MARK: - Errors

enum ApplyError: LocalizedError {
    case noTweaksSelected
    case busy
    case activationFailed
    case missingPath
    case badPlist
    case missingCacheData
    case noBackup
    case writeFailed
    case writeVerificationFailed
    case restoreVerificationFailed
    case appleIntelligenceNotReady

    var errorDescription: String? {
        switch self {
        case .noTweaksSelected: return "Select at least one tweak first."
        case .busy: return "Another operation is in progress."
        case .activationFailed: return "Could not obtain access to the MobileGestalt cache on this device."
        case .missingPath: return "The MobileGestalt path is unavailable."
        case .badPlist: return "The MobileGestalt plist could not be parsed."
        case .missingCacheData: return "CacheData is missing from the MobileGestalt plist."
        case .noBackup: return "No backup exists yet. Apply tweaks once to create one."
        case .writeFailed: return "The write to the MobileGestalt plist failed."
        case .writeVerificationFailed: return "The write did not verify. The original file was restored."
        case .restoreVerificationFailed: return "The restore did not verify. Please try again."
        case .appleIntelligenceNotReady: return "Apple Intelligence must be applied first (A62OafQ85EJAiiqKn4agtg must be 1)."
        }
    }
}

// MARK: - Results

struct ApplyResult: Equatable {
    let appliedCount: Int
    let warnings: [String]
    let binaryPatchApplied: Bool
    let backedUpFirstTime: Bool
}

struct RestoreResult: Equatable {
    let byteCount: Int
}

// MARK: - Store

@MainActor
final class GestaltStore: ObservableObject {

    @Published var tweaks: [Tweak] = TweakCatalog.available()
    @Published private(set) var isBusy = false
    @Published private(set) var lastApply: ApplyResult?
    @Published private(set) var lastRestore: RestoreResult?
    @Published private(set) var isDeviceSpoofed = false
    @Published var lastError: String?

    let backup = BackupManager()

    var enabledCount: Int { tweaks.filter(\.isEnabled).count }
    var backupInfo: BackupManager.BackupInfo? { backup.info }

    // MARK: Persistence

    private let defaults = UserDefaults.standard

    private static func key(_ field: String, _ id: String) -> String {
        "tweak.\(field).\(id)"
    }

    private func loadTweakState() {
        for idx in tweaks.indices {
            let id = tweaks[idx].id
            tweaks[idx].isEnabled = defaults.bool(forKey: Self.key("enabled", id))
            tweaks[idx].selectedIndex = defaults.object(forKey: Self.key("picker", id)) as? Int ?? tweaks[idx].selectedIndex
            tweaks[idx].textValue = defaults.string(forKey: Self.key("text", id)) ?? tweaks[idx].textValue
        }
    }

    init() {
        loadTweakState()
    }

    // MARK: Toggle plumbing

    func isEnabled(_ id: String) -> Bool {
        tweaks.first { $0.id == id }?.isEnabled ?? false
    }

    func setEnabled(_ on: Bool, for id: String) {
        guard let idx = tweaks.firstIndex(where: { $0.id == id }) else { return }
        tweaks[idx].isEnabled = on
        defaults.set(on, forKey: Self.key("enabled", id))
    }

    func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { self.isEnabled(id) },
            set: { self.setEnabled($0, for: id) }
        )
    }

    func pickerBinding(for id: String) -> Binding<Int> {
        Binding(
            get: { self.tweaks.first { $0.id == id }?.selectedIndex ?? 0 },
            set: { v in
                guard let idx = self.tweaks.firstIndex(where: { $0.id == id }) else { return }
                self.tweaks[idx].selectedIndex = v
                self.defaults.set(v, forKey: Self.key("picker", id))
            }
        )
    }

    func textBinding(for id: String) -> Binding<String> {
        Binding(
            get: { self.tweaks.first { $0.id == id }?.textValue ?? "" },
            set: { v in
                guard let idx = self.tweaks.firstIndex(where: { $0.id == id }) else { return }
                self.tweaks[idx].textValue = v
                self.defaults.set(v, forKey: Self.key("text", id))
            }
        )
    }

    func resetToggles() {
        for idx in tweaks.indices { tweaks[idx].isEnabled = false }
        lastError = nil
    }

    // MARK: AI Region key snapshot

    /// CacheExtra keys carrying the device-identity spoof. `unspoofDevice()`
    /// reverses only these, leaving the Siri/eligibility keys in place.
    private static let spoofKeys = [
        "h9jDsbgj7xIVeIQ8S3/X3Q", // ProductType
        "oYicEKzVTz4/CxxE05pEgQ", // HardwareModel
        "5pYKlGnYYBzGvAlIU8RjEQ", // CPU model
    ]

    /// CacheExtra keys carrying Siri / Apple Intelligence eligibility.
    private static let siriKeys = [
        "A62OafQ85EJAiiqKn4agtg",
        "h63QSdBCiT/z0WU6rdQv6Q",
        "yK+xavymRGZ3xWc1tb8XDg",
        "97JDvERpVwO+GHtthIh7hA",
    ]

    /// Every CacheExtra key the Siri / Apple Intelligence / Siri AI flow can
    /// touch. `applySiri()` reverses these back to their saved values.
    private static var aiRegionKeys: [String] { siriKeys + spoofKeys }

    private static func aiRegionSnapshotPresenceKey(_ key: String) -> String { "aiRegionBackup.hasValue.\(key)" }
    private static func aiRegionSnapshotValueKey(_ key: String) -> String { "aiRegionBackup.value.\(key)" }

    /// Saves a key's current value into the app's own container (UserDefaults)
    /// the first time it's touched, so it can be reversed later. Never
    /// overwrites an existing snapshot — it always holds the value from
    /// before Ketamine first modified the key.
    private func snapshotAIRegionKeyIfNeeded(_ key: String, in cacheExtra: [String: Any]) {
        let presenceKey = Self.aiRegionSnapshotPresenceKey(key)
        guard defaults.object(forKey: presenceKey) == nil else { return }
        if let value = cacheExtra[key] {
            defaults.set(value, forKey: Self.aiRegionSnapshotValueKey(key))
            defaults.set(true, forKey: presenceKey)
        } else {
            defaults.set(false, forKey: presenceKey)
        }
    }

    /// Applies the device-identity spoof when `configuration` calls for one,
    /// snapshotting each key first. Devices already eligible for Apple
    /// Intelligence resolve to no spoof and are left untouched. Returns a
    /// warning describing the spoof, or `nil` when none was needed.
    private func applySpoof(_ configuration: AIRegionConfiguration,
                            to cacheExtra: inout [String: Any]) -> String? {
        guard let productType = configuration.spoofedProductType,
              let hardwareModel = configuration.spoofedHardwareModel,
              let cpuModel = configuration.spoofedCPUModel else { return nil }
        for key in Self.spoofKeys { snapshotAIRegionKeyIfNeeded(key, in: cacheExtra) }
        cacheExtra["h9jDsbgj7xIVeIQ8S3/X3Q"] = productType
        cacheExtra["oYicEKzVTz4/CxxE05pEgQ"] = hardwareModel
        cacheExtra["5pYKlGnYYBzGvAlIU8RjEQ"] = cpuModel
        return "Device wasn't natively eligible — spoofed to \(configuration.profile.marketingName) (\(configuration.profile.regulatoryModel))."
    }

    /// True when CacheExtra advertises a product type other than the real
    /// hardware. Reads the live plist, so it reflects spoofs applied by any
    /// route — not just this session.
    func refreshSpoofState() async {
        guard !isBusy else { return }
        let access = MobileGestaltAccess()
        guard (try? access.activate()) != nil else { return }
        defer { access.deactivate() }
        guard let path = access.mobileGestaltPath,
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let parsed = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let plist = parsed as? [String: Any],
              let cacheExtra = plist["CacheExtra"] as? [String: Any]
        else { return }
        let reported = cacheExtra["h9jDsbgj7xIVeIQ8S3/X3Q"] as? String
        isDeviceSpoofed = reported != nil && reported != AIRegionProfile.machineIdentifier
    }

    // MARK: Engine

    /// Reads the live plist, applies every enabled tweak to an in-memory
    /// copy, writes it back in place (preserving ownership/permissions) and
    /// verifies the read-back. If verification fails the pristine backup is
    /// restored automatically so the device is never left in a broken state.
    func apply() async throws -> ApplyResult {
        try await apply(only: nil)
    }

    /// Same engine as `apply()`, but restricted to the given tweak IDs —
    /// tweaks staged elsewhere in the app (e.g. the Tweaks console) are left
    /// untouched even if they're currently enabled.
    func apply(only ids: Set<String>) async throws -> ApplyResult {
        try await apply(only: ids)
    }

    private func apply(only ids: Set<String>?) async throws -> ApplyResult {
        let scopedEnabledCount = tweaks.filter { $0.isEnabled && (ids == nil || ids!.contains($0.id)) }.count
        guard scopedEnabledCount > 0 else { throw ApplyError.noTweaksSelected }
        guard !isBusy else { throw ApplyError.busy }
        isBusy = true
        defer { isBusy = false }

        let access = MobileGestaltAccess()
        guard (try? access.activate()) != nil else {
            throw ApplyError.activationFailed
        }
        defer { access.deactivate() }

        guard let path = access.mobileGestaltPath else { throw ApplyError.missingPath }
        let url = URL(fileURLWithPath: path)

        let current = try Data(contentsOf: url)

        // Pristine backup — created once from the untouched file.
        let hadBackup = backup.hasBackup
        try backup.ensureBackup(from: current)

        guard var plist = try PropertyListSerialization.propertyList(
            from: current, format: nil) as? [String: Any]
        else { throw ApplyError.badPlist }

        var cacheExtra = (plist["CacheExtra"] as? [String: Any]) ?? [:]
        var applied = 0
        var warnings: [String] = []

        for tweak in tweaks where tweak.isEnabled && (ids == nil || ids!.contains(tweak.id)) {
            do {
                var mods = tweak.modifications
                if let detail = tweak.detail {
                    switch detail {
                    case .picker(let options):
                        guard tweak.selectedIndex >= 0 && tweak.selectedIndex < options.count else {
                            warnings.append("\(tweak.title): invalid picker selection, skipped.")
                            continue
                        }
                        guard tweak.selectedIndex < tweak.pickerValues.count else {
                            warnings.append("\(tweak.title): picker values mismatch, skipped.")
                            continue
                        }
                        // Replace the picker value with the selected option.
                        let selectedValue = tweak.pickerValues[tweak.selectedIndex]
                        mods = tweak.modifications.map { m in
                            if m.isPicker {
                                return GestaltModification(key: m.key, subkey: m.subkey,
                                                           value: selectedValue)
                            }
                            return m
                        }
                        applied += 1
                    case .textField:
                        if tweak.textValue.isEmpty {
                            warnings.append("\(tweak.title): no text entered, skipped.")
                            continue
                        } else {
                            mods = tweak.modifications.map { m in
                                GestaltModification(key: m.key, subkey: m.subkey,
                                                    value: .string(tweak.textValue))
                            }
                            applied += 1
                        }
                    }
                } else {
                    applied += 1
                }
                for mod in mods {
                    switch mod.value {
                    case .remove:
                        if let subkey = mod.subkey {
                            if var dict = cacheExtra[mod.key] as? [String: Any] {
                                dict.removeValue(forKey: subkey)
                                cacheExtra[mod.key] = dict
                            }
                        } else {
                            cacheExtra.removeValue(forKey: mod.key)
                        }
                    case .keepCurrent:
                        break
                    default:
                        if let subkey = mod.subkey {
                            var dict = (cacheExtra[mod.key] as? [String: Any]) ?? [:]
                            dict[subkey] = mod.value.plistObject
                            cacheExtra[mod.key] = dict
                        } else {
                            cacheExtra[mod.key] = mod.value.plistObject
                        }
                    }
                }
            }
        }

        plist["CacheExtra"] = cacheExtra

        // Optional binary patch (iPadOS).
        var binaryPatch = false
        if tweaks.contains(where: { $0.isEnabled && $0.requiresCacheDataPatch && (ids == nil || ids!.contains($0.id)) }) {
            guard let cacheData = plist["CacheData"] as? Data else {
                throw ApplyError.missingCacheData
            }
            plist["CacheData"] = try CacheDataPatch.apply(to: cacheData)
            binaryPatch = true
        }

        var cacheDataPatches: [(key: String, value: Int)] = []
        for tweak in tweaks where ids == nil || ids!.contains(tweak.id) {
            for mod in tweak.modifications where mod.cacheDataKey != nil {
                let patchValue: Int
                if tweak.isEnabled {
                    guard case .int(let v) = mod.value else { continue }
                    patchValue = v
                } else {
                    patchValue = mod.cacheDataDisabledValue ?? 0
                }
                cacheDataPatches.removeAll { $0.key == mod.cacheDataKey }
                cacheDataPatches.append((mod.cacheDataKey!, patchValue))
            }
        }
        if !cacheDataPatches.isEmpty {
            guard var cacheData = plist["CacheData"] as? Data else {
                throw ApplyError.missingCacheData
            }
            var appliedCacheData = false
            for patch in cacheDataPatches {
                do {
                    try CacheDataPatch.set(patch.value, forKey: patch.key, in: &cacheData)
                    appliedCacheData = true
                } catch {
                    warnings.append("CacheData offset unavailable for key \(patch.key) on this iOS — skipped.")
                }
            }
            if appliedCacheData {
                plist["CacheData"] = cacheData
                binaryPatch = true
            }
        }

        let newData = try PropertyListSerialization.data(
            fromPropertyList: plist, format: .binary, options: 0)

        do {
            try newData.write(to: url, options: []) // in place: keeps uid/gid
        } catch {
            // Never leave the device half-written.
            try? backup.restoreData().write(to: url, options: [])
            throw ApplyError.writeFailed
        }

        // Verify read-back; self-heal from the pristine backup on mismatch.
        guard let readback = try? Data(contentsOf: url), readback == newData else {
            try? backup.restoreData().write(to: url, options: [])
            throw ApplyError.writeVerificationFailed
        }

        let result = ApplyResult(
            appliedCount: applied,
            warnings: warnings,
            binaryPatchApplied: binaryPatch,
            backedUpFirstTime: !hadBackup
        )
        lastApply = result
        lastError = warnings.isEmpty ? nil : warnings.joined(separator: "\n")
        return result
    }

    /// Ported 1:1 from GestaltEdit's "Enable Siri AI (US Region)" — always
    /// sets the US regulatory region keys, and if this device isn't already
    /// an Apple Intelligence-eligible model, additionally spoofs its
    /// identity to one that is. See `AIRegionConfiguration`.
    func applyAIRegion() async throws -> ApplyResult {
        guard !isBusy else { throw ApplyError.busy }
        isBusy = true
        defer { isBusy = false }

        let access = MobileGestaltAccess()
        guard (try? access.activate()) != nil else {
            throw ApplyError.activationFailed
        }
        defer { access.deactivate() }

        guard let path = access.mobileGestaltPath else { throw ApplyError.missingPath }
        let url = URL(fileURLWithPath: path)

        let current = try Data(contentsOf: url)

        let hadBackup = backup.hasBackup
        try backup.ensureBackup(from: current)

        guard var plist = try PropertyListSerialization.propertyList(
            from: current, format: nil) as? [String: Any]
        else { throw ApplyError.badPlist }

        var cacheExtra = (plist["CacheExtra"] as? [String: Any]) ?? [:]

        let configuration = AIRegionConfiguration.resolve(for: cacheExtra)
        var warnings: [String] = []

        // Save each key's pre-existing value into the app's own container
        // before overwriting it, so applySiri() can reverse this later.
        for key in Self.siriKeys {
            snapshotAIRegionKeyIfNeeded(key, in: cacheExtra)
        }
        if let warning = applySpoof(configuration, to: &cacheExtra) {
            warnings.append(warning)
        }

        cacheExtra["A62OafQ85EJAiiqKn4agtg"] = 1
        cacheExtra["h63QSdBCiT/z0WU6rdQv6Q"] = "LL"
        cacheExtra["yK+xavymRGZ3xWc1tb8XDg"] = "LL/A"
        cacheExtra["97JDvERpVwO+GHtthIh7hA"] = configuration.profile.regulatoryModel

        plist["CacheExtra"] = cacheExtra

        let newData = try PropertyListSerialization.data(
            fromPropertyList: plist, format: .binary, options: 0)

        do {
            try newData.write(to: url, options: [])
        } catch {
            try? backup.restoreData().write(to: url, options: [])
            throw ApplyError.writeFailed
        }

        guard let readback = try? Data(contentsOf: url), readback == newData else {
            try? backup.restoreData().write(to: url, options: [])
            throw ApplyError.writeVerificationFailed
        }

        let result = ApplyResult(
            appliedCount: 1,
            warnings: warnings,
            binaryPatchApplied: false,
            backedUpFirstTime: !hadBackup
        )
        lastApply = result
        lastError = warnings.isEmpty ? nil : warnings.joined(separator: "\n")
        isDeviceSpoofed = configuration.requiresDeviceSpoofing
        return result
    }

    /// Reverses whatever `applyAIRegion()` changed — restores every AI
    /// region key to the value `snapshotAIRegionKeyIfNeeded` saved before
    /// Ketamine first touched it (removing keys that didn't exist before),
    /// then forces `A62OafQ85EJAiiqKn4agtg` back to 0 regardless of what
    /// that restore produced.
    func applySiri() async throws -> ApplyResult {
        guard !isBusy else { throw ApplyError.busy }
        isBusy = true
        defer { isBusy = false }

        let access = MobileGestaltAccess()
        guard (try? access.activate()) != nil else {
            throw ApplyError.activationFailed
        }
        defer { access.deactivate() }

        guard let path = access.mobileGestaltPath else { throw ApplyError.missingPath }
        let url = URL(fileURLWithPath: path)

        let current = try Data(contentsOf: url)

        let hadBackup = backup.hasBackup
        try backup.ensureBackup(from: current)

        guard var plist = try PropertyListSerialization.propertyList(
            from: current, format: nil) as? [String: Any]
        else { throw ApplyError.badPlist }

        var cacheExtra = (plist["CacheExtra"] as? [String: Any]) ?? [:]

        for key in Self.aiRegionKeys {
            let presenceKey = Self.aiRegionSnapshotPresenceKey(key)
            guard defaults.object(forKey: presenceKey) != nil else { continue }
            if defaults.bool(forKey: presenceKey) {
                cacheExtra[key] = defaults.object(forKey: Self.aiRegionSnapshotValueKey(key))
            } else {
                cacheExtra.removeValue(forKey: key)
            }
        }
        cacheExtra["A62OafQ85EJAiiqKn4agtg"] = 0

        plist["CacheExtra"] = cacheExtra

        let newData = try PropertyListSerialization.data(
            fromPropertyList: plist, format: .binary, options: 0)

        do {
            try newData.write(to: url, options: [])
        } catch {
            try? backup.restoreData().write(to: url, options: [])
            throw ApplyError.writeFailed
        }

        guard let readback = try? Data(contentsOf: url), readback == newData else {
            try? backup.restoreData().write(to: url, options: [])
            throw ApplyError.writeVerificationFailed
        }

        let result = ApplyResult(
            appliedCount: 1,
            warnings: [],
            binaryPatchApplied: false,
            backedUpFirstTime: !hadBackup
        )
        lastApply = result
        lastError = nil
        isDeviceSpoofed = false
        return result
    }

    /// Siri AI requires Apple Intelligence to already be set up
    /// (`A62OafQ85EJAiiqKn4agtg == 1`) — spoofs the device identity when
    /// needed, then bumps the key to 2.
    func applySiriAI() async throws -> ApplyResult {
        guard !isBusy else { throw ApplyError.busy }
        isBusy = true
        defer { isBusy = false }

        let access = MobileGestaltAccess()
        guard (try? access.activate()) != nil else {
            throw ApplyError.activationFailed
        }
        defer { access.deactivate() }

        guard let path = access.mobileGestaltPath else { throw ApplyError.missingPath }
        let url = URL(fileURLWithPath: path)

        let current = try Data(contentsOf: url)

        guard var plist = try PropertyListSerialization.propertyList(
            from: current, format: nil) as? [String: Any]
        else { throw ApplyError.badPlist }
        var cacheExtra = (plist["CacheExtra"] as? [String: Any]) ?? [:]

        guard (cacheExtra["A62OafQ85EJAiiqKn4agtg"] as? Int) == 1 else {
            throw ApplyError.appleIntelligenceNotReady
        }

        let hadBackup = backup.hasBackup
        try backup.ensureBackup(from: current)

        let configuration = AIRegionConfiguration.resolve(for: cacheExtra)
        var warnings: [String] = []
        snapshotAIRegionKeyIfNeeded("A62OafQ85EJAiiqKn4agtg", in: cacheExtra)
        if let warning = applySpoof(configuration, to: &cacheExtra) {
            warnings.append(warning)
        }

        cacheExtra["A62OafQ85EJAiiqKn4agtg"] = 2
        plist["CacheExtra"] = cacheExtra

        let newData = try PropertyListSerialization.data(
            fromPropertyList: plist, format: .binary, options: 0)

        do {
            try newData.write(to: url, options: [])
        } catch {
            try? backup.restoreData().write(to: url, options: [])
            throw ApplyError.writeFailed
        }

        guard let readback = try? Data(contentsOf: url), readback == newData else {
            try? backup.restoreData().write(to: url, options: [])
            throw ApplyError.writeVerificationFailed
        }

        let result = ApplyResult(
            appliedCount: 1,
            warnings: warnings,
            binaryPatchApplied: false,
            backedUpFirstTime: !hadBackup
        )
        lastApply = result
        lastError = warnings.isEmpty ? nil : warnings.joined(separator: "\n")
        isDeviceSpoofed = configuration.requiresDeviceSpoofing
        return result
    }

    /// Removes only the device-identity spoof, restoring each spoof key to
    /// the value saved before Ketamine first wrote it. Siri / Apple
    /// Intelligence eligibility keys are deliberately left as they are, so
    /// the device keeps whatever capability it was granted.
    func unspoofDevice() async throws -> ApplyResult {
        guard !isBusy else { throw ApplyError.busy }
        isBusy = true
        defer { isBusy = false }

        let access = MobileGestaltAccess()
        guard (try? access.activate()) != nil else {
            throw ApplyError.activationFailed
        }
        defer { access.deactivate() }

        guard let path = access.mobileGestaltPath else { throw ApplyError.missingPath }
        let url = URL(fileURLWithPath: path)

        let current = try Data(contentsOf: url)

        let hadBackup = backup.hasBackup
        try backup.ensureBackup(from: current)

        guard var plist = try PropertyListSerialization.propertyList(
            from: current, format: nil) as? [String: Any]
        else { throw ApplyError.badPlist }

        var cacheExtra = (plist["CacheExtra"] as? [String: Any]) ?? [:]

        for key in Self.spoofKeys {
            let presenceKey = Self.aiRegionSnapshotPresenceKey(key)
            if defaults.object(forKey: presenceKey) == nil {
                // Never snapshotted, so Ketamine never wrote it — but the
                // device still reports a spoof, so drop the key entirely.
                cacheExtra.removeValue(forKey: key)
            } else if defaults.bool(forKey: presenceKey) {
                cacheExtra[key] = defaults.object(forKey: Self.aiRegionSnapshotValueKey(key))
            } else {
                cacheExtra.removeValue(forKey: key)
            }
        }

        plist["CacheExtra"] = cacheExtra

        let newData = try PropertyListSerialization.data(
            fromPropertyList: plist, format: .binary, options: 0)

        do {
            try newData.write(to: url, options: [])
        } catch {
            try? backup.restoreData().write(to: url, options: [])
            throw ApplyError.writeFailed
        }

        guard let readback = try? Data(contentsOf: url), readback == newData else {
            try? backup.restoreData().write(to: url, options: [])
            throw ApplyError.writeVerificationFailed
        }

        let result = ApplyResult(
            appliedCount: 1,
            warnings: [],
            binaryPatchApplied: false,
            backedUpFirstTime: !hadBackup
        )
        lastApply = result
        lastError = nil
        isDeviceSpoofed = false
        return result
    }

    /// Restores the pristine MobileGestalt plist captured on the first apply.
    func restore() async throws -> RestoreResult {
        guard backup.hasBackup else { throw ApplyError.noBackup }
        guard !isBusy else { throw ApplyError.busy }
        isBusy = true
        defer { isBusy = false }

        let access = MobileGestaltAccess()
        guard (try? access.activate()) != nil else {
            throw ApplyError.activationFailed
        }
        defer { access.deactivate() }

        guard let path = access.mobileGestaltPath else { throw ApplyError.missingPath }
        let url = URL(fileURLWithPath: path)

        let pristine = try backup.restoreData()
        do {
            try pristine.write(to: url, options: [])
        } catch {
            throw ApplyError.writeFailed
        }

        guard let readback = try? Data(contentsOf: url), readback == pristine else {
            throw ApplyError.restoreVerificationFailed
        }

        let result = RestoreResult(byteCount: pristine.count)
        lastRestore = result
        lastError = nil
        return result
    }
}
