import Combine
import Foundation
import SwiftUI

@MainActor
final class GestaltViewModel: ObservableObject {
    @Published var plist: GestaltPlist?
    @Published var isDirty = false
    @Published var isBusy = false
    @Published var notice: GestaltNotice?
    @Published private(set) var hasAttemptedLoad = false
    @Published private(set) var backups: [GestaltBackup] = []
    @Published var selectedTweaks: Set<GestaltTweakID> = []
    @Published private(set) var removedTweaks: Set<GestaltTweakID> = []
    @Published private(set) var stagedSubtype: DynamicIslandChange?
    @Published var modelName = ""
    @Published private(set) var stagesModelName = false
    @Published private(set) var unstagesModelName = false
    @Published var stagesAIRegion = false
    @Published private(set) var unstageAIRegion = false
    @Published private(set) var isRespringing = false
    @Published var posterFiles: [URL] = []

    private let access = GestaltAccess.shared()

    private var pristineCacheExtra: [String: Any]?

    private var pristineCacheData: Data?

    var aiRegionProfile: AIRegionProfile? {
        plist.flatMap(AIRegionProfile.init(plist:))
    }

    var requiresForcedAIEnable: Bool {
        plist != nil && aiRegionProfile == nil
    }

       var isAppleIntelligenceTweaked: Bool {
        guard let cacheExtra = plist?.cacheExtra else { return false }
        let pristine = pristineCacheExtra ?? cacheExtra
        return Self.aiRegionKeys.contains { key in
            aiKey(key, differsIn: cacheExtra, from: pristine)
        }
    }

    var aiRegionToggleState: Bool {
        if unstageAIRegion { return false }
        if stagesAIRegion { return true }
        return isAppleIntelligenceTweaked
    }

    var modelNameToggleState: Bool {
        if unstagesModelName { return false }
        if stagesModelName { return true }
        return isCustomModelNameApplied
    }

    var isCustomModelNameApplied: Bool {
        guard let current = currentArtworkProductDescription,
              let pristine = pristineCacheExtra?[Self.artworkKey] as? [String: Any],
              let stock = pristine["ArtworkDeviceProductDescription"] as? String else {
            return false
        }
        return current != stock
    }

    private var currentArtworkProductDescription: String? {
        guard let artwork = plist?.cacheExtra[Self.artworkKey] as? [String: Any] else {
            return nil
        }
        return artwork["ArtworkDeviceProductDescription"] as? String
    }

    var currentSubtype: Int? {
        guard let artwork = plist?.cacheExtra[Self.artworkKey] as? [String: Any] else {
            return nil
        }
        return artwork["ArtworkDeviceSubType"] as? Int
    }

    var displayedSubtypeSelection: DynamicIslandSelection {
        if let stagedSubtype {
            switch stagedSubtype {
            case .set(let value): return .subtype(value)
            case .restore: return .original
            }
        } else if let current = currentSubtype {
            return .subtype(current)
        } else {
            return .original
        }
    }

    func setDynamicIslandSelection(_ selection: DynamicIslandSelection) {
        switch selection {
        case .original:
            stagedSubtype = .restore
        case .subtype(let value):
            if value == currentSubtype {
                stagedSubtype = nil
            } else {
                stagedSubtype = .set(value)
            }
        }
    }

    var hasStagedTweaks: Bool {
        !selectedTweaks.isEmpty
            || !removedTweaks.isEmpty
            || unstageAIRegion
            || stagedSubtype != nil
            || stagesModelName
            || unstagesModelName
            || stagesAIRegion
    }

    var stagedChangeCount: Int {
        selectedTweaks.count
            + removedTweaks.count
            + (unstageAIRegion ? 1 : 0)
            + (stagedSubtype == nil ? 0 : 1)
            + (stagesModelName ? 1 : 0)
            + (unstagesModelName ? 1 : 0)
            + (stagesAIRegion ? 1 : 0)
    }

    func load() {
        guard !isBusy else { return }
        hasAttemptedLoad = true
        isBusy = true
        notice = nil

        defer { isBusy = false }
        do {
            try access.connect()
            guard let dictionary = try access.readGestalt() as? [String: Any] else {
                throw GestaltEditError.invalidPlist
            }
            plist = GestaltPlist(dict: dictionary)
            captureBaseline(from: dictionary)
            modelName = currentArtworkProductDescription ?? ""
            isDirty = false
            refreshBackups()
            Task.detached(priority: .utility) {
                _ = try? pb.find_pb_container()
            }
        } catch {
            plist = nil
            report(error)
        }
    }

    func runExploit() {
        guard !isBusy else { return }
        isBusy = true
        do {
            try access.connect()
            notice = GestaltNotice(
                kind: .success,
                message: "Exploit succeeded. MobileGestalt is writable."
            )
            if plist == nil,
               let dictionary = try access.readGestalt() as? [String: Any] {
                plist = GestaltPlist(dict: dictionary)
                captureBaseline(from: dictionary)
                isDirty = false
                refreshBackups()
            }
        } catch {
            report(error)
        }
        isBusy = false
    }

    func respring() {
        guard !isRespringing else { return }
        isRespringing = true
    }

    func appendPosterFile(_ url: URL) {
        guard isPBArchive(url) else {
            print("(pb) ignoring unsupported file: \(url.lastPathComponent)")
            return
        }
        if posterFiles.contains(url) { return }
        guard posterFiles.count < 5 else {
            print("(pb) session limit reached: up to 5 packs per session")
            return
        }
        _ = url.startAccessingSecurityScopedResource()
        posterFiles.append(url)
    }

    func removePosterFiles(at offsets: IndexSet) {
        for index in offsets {
            posterFiles[index].stopAccessingSecurityScopedResource()
        }
        posterFiles.remove(atOffsets: offsets)
    }

    func clearPosterFiles() {
        for url in posterFiles {
            url.stopAccessingSecurityScopedResource()
        }
        posterFiles.removeAll()
    }

    func setTweak(_ id: GestaltTweakID, enabled: Bool) {
        if enabled {
            selectedTweaks.insert(id)
            removedTweaks.remove(id)
            if id == .enableLiquidGlassLowPerformance {
                selectedTweaks.remove(.disableLiquidGlassLowPerformance)
                if isCurrentlyApplied(.disableLiquidGlassLowPerformance) {
                    removedTweaks.insert(.disableLiquidGlassLowPerformance)
                }
            } else if id == .disableLiquidGlassLowPerformance {
                selectedTweaks.remove(.enableLiquidGlassLowPerformance)
                if isCurrentlyApplied(.enableLiquidGlassLowPerformance) {
                    removedTweaks.insert(.enableLiquidGlassLowPerformance)
                }
            }
        } else {
            selectedTweaks.remove(id)
            if isCurrentlyApplied(id) {
                removedTweaks.insert(id)
            }
        }
    }

    func isTweakEnabled(_ id: GestaltTweakID) -> Bool {
        if removedTweaks.contains(id) { return false }
        if selectedTweaks.contains(id) { return true }
        return activeTweaks.contains(id)
    }

    var activeTweaks: Set<GestaltTweakID> {
        guard let cacheExtra = plist?.cacheExtra else { return [] }
        let pristine = pristineCacheExtra ?? cacheExtra
        var result = Set<GestaltTweakID>()
        for definition in GestaltTweakCatalog.definitions {
            if definition.isApplied(in: cacheExtra),
               !definition.isApplied(in: pristine) {
                result.insert(definition.id)
            }
        }
        return result
    }

    private func isCurrentlyApplied(_ id: GestaltTweakID) -> Bool {
        guard let definition = GestaltTweakCatalog.definition(for: id),
              let cacheExtra = plist?.cacheExtra else { return false }
        let pristine = pristineCacheExtra ?? cacheExtra
        return definition.isApplied(in: cacheExtra)
            && !definition.isApplied(in: pristine)
    }

    func setAIRegion(enabled: Bool) {
        if enabled {
            stagesAIRegion = true
            unstageAIRegion = false
            if requiresForcedAIEnable {
                notice = GestaltNotice(
                    kind: .riskWarning,
                    message: "This device does not officially support Apple Intelligence. Force enabling spoofs the product, hardware, and CPU model. It may temporarily break Face ID, cause system instability or boot loops, and could require restoring the device. A backup will be created before writing."
                )
            }
        } else {
            stagesAIRegion = false
            unstageAIRegion = isAppleIntelligenceTweaked
        }
    }

    func setModelNameToggled(_ on: Bool) {
        if on {
            stagesModelName = true
            unstagesModelName = false
            if modelName.isEmpty, let current = currentArtworkProductDescription {
                modelName = current
            }
        } else {
            stagesModelName = false
            unstagesModelName = isCustomModelNameApplied
        }
    }

    func clearModelNameStaging() {
        stagesModelName = false
        unstagesModelName = false
    }

    func applySelectedTweaks() {
        guard !isBusy, var pending = plist else { return }
        do {
            var addedKeys = Set<String>()
            for id in selectedTweaks {
                guard let definition = GestaltTweakCatalog.definition(for: id) else { continue }
                for key in definition.values.keys {
                    addedKeys.insert(key)
                }
                try pending.apply(definition: definition)
            }
            if let stagedSubtype {
                switch stagedSubtype {
                case .set(let value):
                    try pending.setDynamicIslandSubtype(value)
                    addedKeys.formUnion([Self.artworkKey, Self.dynamicIslandSupportKey])
                case .restore:
                    pending.restoreDynamicIsland(from: pristineCacheExtra)
                }
            }

            if stagesModelName {
                let name = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { throw GestaltEditError.emptyModelName }
                try pending.setModelName(name)
                addedKeys.insert(Self.artworkKey)
            } else if unstagesModelName {
                restoreArtworkProductDescription(in: &pending)
            }

            for id in removedTweaks {
                guard let definition = GestaltTweakCatalog.definition(for: id) else { continue }
                for key in definition.values.keys where !addedKeys.contains(key) {
                    restoreCacheExtraValue(forKey: key, in: &pending)
                }
                if id == .iPadOS, let pristine = pristineCacheData {
                    pending.dict["CacheData"] = pristine
                }
            }

            var expectedConfiguration: AIRegionConfiguration?
            if stagesAIRegion {
                let configuration = AIRegionConfiguration.resolve(for: pending)
                let profile = configuration.profile
                if let productType = configuration.spoofedProductType,
                   let hardwareModel = configuration.spoofedHardwareModel,
                   let cpuModel = configuration.spoofedCPUModel {
                    pending.setCacheExtra(1, forKey: "A62OafQ85EJAiiqKn4agtg")
                    pending.setCacheExtra(productType, forKey: "h9jDsbgj7xIVeIQ8S3/X3Q")
                    pending.setCacheExtra(hardwareModel, forKey: "oYicEKzVTz4/CxxE05pEgQ")
                    pending.setCacheExtra(cpuModel, forKey: "5pYKlGnYYBzGvAlIU8RjEQ")
                }
                pending.setCacheExtra("LL", forKey: "h63QSdBCiT/z0WU6rdQv6Q")
                pending.setCacheExtra("LL/A", forKey: "yK+xavymRGZ3xWc1tb8XDg")
                pending.setCacheExtra(profile.regulatoryModel, forKey: "97JDvERpVwO+GHtthIh7hA")
                expectedConfiguration = configuration
            } else if unstageAIRegion {
                restoreRegionKeys(in: &pending)
            }

            save(pending, expectedAIRegion: expectedConfiguration) { [weak self] in
                self?.clearStaging()
            }
        } catch {
            report(error)
        }
    }

    func clearStaging() {
        selectedTweaks.removeAll()
        removedTweaks.removeAll()
        stagedSubtype = nil
        stagesModelName = false
        unstagesModelName = false
        stagesAIRegion = false
        unstageAIRegion = false
    }

    func revertTweaks() {
        guard !isBusy else { return }
        guard let snapshot = GestaltBackupStore.loadStockSnapshot() else {
            notice = GestaltNotice(
                kind: .error,
                message: "No stock snapshot is available to revert to. The snapshot is captured the first time the MobileGestalt plist loads successfully, so reopen the app after running the exploit once."
            )
            return
        }
        save(GestaltPlist(dict: snapshot), expectedAIRegion: nil) { [weak self] in
            self?.clearStaging()
        }
    }

    func applyChanges() {
        guard !isBusy, let plist else { return }
        save(plist, expectedAIRegion: nil)
    }

    func createBackup() {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try access.connect()
            let data = try access.readGestaltData()
            let backup = try GestaltBackupStore.create(from: data)
            refreshBackups()
            notice = GestaltNotice(
                kind: .backupCreated,
                message: String(format: "Saved %@.plist. You can export it from the Restore tab.", backup.name)
            )
        } catch {
            report(error)
        }
    }

    func importBackup(from url: URL) {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }

        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        do {
            let data = try Data(contentsOf: url)
            var format = PropertyListSerialization.PropertyListFormat.binary
            guard let dictionary = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: &format
            ) as? [String: Any],
                  dictionary["CacheExtra"] is [String: Any] else {
                throw GestaltEditError.invalidBackup
            }
            let backup = try GestaltBackupStore.create(from: data)
            refreshBackups()
            notice = GestaltNotice(
                kind: .backupCreated,
                message: String(format: "Imported %@ and saved it as %@.plist.", url.lastPathComponent, backup.name)
            )
        } catch {
            report(error)
        }
    }

    func restore(_ backup: GestaltBackup) {
        guard !isBusy else { return }
        do {
            let data = try GestaltBackupStore.data(for: backup)
            var format = PropertyListSerialization.PropertyListFormat.binary
            guard let dictionary = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: &format
            ) as? [String: Any] else {
                throw GestaltEditError.invalidBackup
            }
            save(GestaltPlist(dict: dictionary), expectedAIRegion: nil)
        } catch {
            report(error)
        }
    }

    func delete(_ backup: GestaltBackup) {
        do {
            try GestaltBackupStore.delete(backup)
            refreshBackups()
        } catch {
            report(error)
        }
    }

    func refreshBackups() {
        do {
            backups = try GestaltBackupStore.list()
        } catch {
            report(error)
        }
    }

    private func save(
        _ pendingPlist: GestaltPlist,
        expectedAIRegion: AIRegionConfiguration?,
        completion: (() -> Void)? = nil
    ) {
        isBusy = true
        notice = nil

        var wrote = false
        do {
                if (UserDefaults.standard.object(forKey: "backup_before_write") as? Bool ?? true),
               let originalData = try? access.readGestaltData() {
                do {
                    _ = try GestaltBackupStore.create(from: originalData)
                } catch {
                    print("(gestalt) backup skipped: \(error.localizedDescription)")
                }
            }
            try access.saveGestalt(pendingPlist.dict)
            wrote = true

            if let verification = try? access.readGestalt() as? [String: Any] {
                let verifiedPlist = GestaltPlist(dict: verification)

                if let expectedAIRegion {
                    let cacheExtra = verifiedPlist.cacheExtra
                    guard cacheExtra["h63QSdBCiT/z0WU6rdQv6Q"] as? String == "LL",
                          cacheExtra["yK+xavymRGZ3xWc1tb8XDg"] as? String == "LL/A",
                          cacheExtra["97JDvERpVwO+GHtthIh7hA"] as? String == expectedAIRegion.profile.regulatoryModel else {
                        throw GestaltEditError.verificationFailed
                    }
                    if expectedAIRegion.requiresDeviceSpoofing {
                        guard cacheExtra["A62OafQ85EJAiiqKn4agtg"] as? Int == 1,
                              cacheExtra["h9jDsbgj7xIVeIQ8S3/X3Q"] as? String == expectedAIRegion.spoofedProductType,
                              cacheExtra["oYicEKzVTz4/CxxE05pEgQ"] as? String == expectedAIRegion.spoofedHardwareModel,
                              cacheExtra["5pYKlGnYYBzGvAlIU8RjEQ"] as? String == expectedAIRegion.spoofedCPUModel else {
                            throw GestaltEditError.verificationFailed
                        }
                    }
                }

                plist = verifiedPlist
                isDirty = false
            } else {
                print("(gestalt) could not re-read the plist after a successful write")
            }
        } catch {
            isDirty = true
            report(error)
        }

        if wrote {
            completion?()
            refreshBackups()
            isRespringing = true
        }
        isBusy = false
    }

    private func report(_ error: Error) {
        notice = GestaltNotice(kind: .error, message: error.localizedDescription)
    }

    private static let artworkKey = "oPeik/9e8lQWMszEjbPzng"
    private static let dynamicIslandSupportKey = "YlEtTtHlNesRBMal1CqRaA"
    private static let aiRegionKeys = [
        "h63QSdBCiT/z0WU6rdQv6Q",
        "yK+xavymRGZ3xWc1tb8XDg",
        "zHeENZu+wbg7PUprwNwBWg",
        "97JDvERpVwO+GHtthIh7hA",
        "A62OafQ85EJAiiqKn4agtg",
        "h9jDsbgj7xIVeIQ8S3/X3Q",
        "oYicEKzVTz4/CxxE05pEgQ",
        "5pYKlGnYYBzGvAlIU8RjEQ"
    ]

    private func aiKey(_ key: String, differsIn current: [String: Any], from pristine: [String: Any]) -> Bool {
        switch (current[key], pristine[key]) {
        case (nil, nil):
            return false
        case (nil, _):
            return false
        case (_, nil):
            return true
        case (let currentValue?, let pristineValue?):
            return !Self.aiValuesEqual(currentValue, pristineValue)
        }
    }

    private static func aiValuesEqual(_ lhs: Any, _ rhs: Any) -> Bool {
        if let l = lhs as? NSNumber, let r = rhs as? NSNumber {
            return l == r
        }
        if let l = lhs as? String, let r = rhs as? String {
            return l == r
        }
        return false
    }

    private func restoreCacheExtraValue(forKey key: String, in pending: inout GestaltPlist) {
        if let pristine = pristineCacheExtra?[key] {
            pending.setCacheExtra(pristine, forKey: key)
        } else {
            pending.removeCacheExtraValue(forKey: key)
        }
    }

    private func captureBaseline(from dictionary: [String: Any]) {
        if let snapshot = GestaltBackupStore.loadStockSnapshot(),
           snapshot["CacheExtra"] is [String: Any] {
            pristineCacheExtra = snapshot["CacheExtra"] as? [String: Any]
            pristineCacheData = snapshot["CacheData"] as? Data
        } else {
            let clean = Self.cleanedBaseline(from: dictionary)
            GestaltBackupStore.saveStockSnapshot(clean)
            pristineCacheExtra = clean["CacheExtra"] as? [String: Any]
            pristineCacheData = clean["CacheData"] as? Data
        }
    }

    private static func cleanedBaseline(from dictionary: [String: Any]) -> [String: Any] {
        guard var cacheExtra = dictionary["CacheExtra"] as? [String: Any] else {
            return dictionary
        }
        for definition in GestaltTweakCatalog.definitions where definition.isTweakOnly {
            for key in definition.values.keys {
                cacheExtra.removeValue(forKey: key)
            }
        }
        var cleaned = dictionary
        cleaned["CacheExtra"] = cacheExtra
        return cleaned
    }

    private func restoreRegionKeys(in pending: inout GestaltPlist) {
        for key in Self.aiRegionKeys {
            restoreCacheExtraValue(forKey: key, in: &pending)
        }
    }

    private func restoreArtworkProductDescription(in pending: inout GestaltPlist) {
        guard var artwork = pending.cacheExtra[Self.artworkKey] as? [String: Any] else {
            return
        }
        let stockName = (pristineCacheExtra?[Self.artworkKey] as? [String: Any])?["ArtworkDeviceProductDescription"] as? String
        if let stockName {
            artwork["ArtworkDeviceProductDescription"] = stockName
            pending.setCacheExtra(artwork, forKey: Self.artworkKey)
        } else {
            artwork.removeValue(forKey: "ArtworkDeviceProductDescription")
            pending.setCacheExtra(artwork, forKey: Self.artworkKey)
        }
    }
}

enum DynamicIslandChange: Hashable {
    case set(Int)
    case restore
}

enum DynamicIslandSelection: Hashable {
    case original
    case subtype(Int)
}

private enum GestaltEditError: LocalizedError {
    case invalidPlist
    case invalidBackup
    case verificationFailed
    case emptyModelName

    var errorDescription: String? {
        switch self {
        case .invalidPlist: "The MobileGestalt plist is not a valid dictionary."
        case .invalidBackup: "The backup is not a valid MobileGestalt plist."
        case .verificationFailed: "The MobileGestalt values after writing do not match the expected values."
        case .emptyModelName: "The device model name cannot be empty."
        }
    }
}
