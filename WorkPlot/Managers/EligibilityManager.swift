//
//  EligibilityManager.swift
//  WorkPlot
//
//  Direct eligibility.plist manipulation on iOS 27: writes the GREYMATTER and
//  CALCIUM domains so the device reports the answers required for Apple
//  Intelligence and China-cellular eligibility. Reached through bad_query
//  where the SystemGroup tree is granted (iOS 27 only).
//

import Foundation

enum EligibilityError: LocalizedError {
    case unavailable
    case badPlist
    case writeFailed
    case writeVerificationFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "The eligibility container isn't reachable on this firmware. SystemGroup is only granted on iOS 27; on iOS 26.x containermanagerd refuses it. Use the Apple Intelligence tweak + Device Spoof in Tweaks instead."
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
    /// but only as a directory — it refuses to extend a file leaf. So we
    /// consume the eligibility container directory and operate on the plist
    /// inside it.
    static let eligibilityDirPath = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.eligibility"
    static var plistPath: String { eligibilityDirPath + "/eligibility.plist" }

    static func isReachable() -> Bool {
        guard BadQueryBridgeAvailable() else { return false }
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 else { return false }
        do {
            return try BadQueryLeaseScope.withLease(forPath: eligibilityDirPath) {
                let dir = URL(fileURLWithPath: eligibilityDirPath, isDirectory: true)
                let probe = dir.appendingPathComponent(".bq_probe")
                try? FileManager.default.removeItem(at: probe)
                try Data([0x00]).write(to: probe, options: .atomic)
                defer { try? FileManager.default.removeItem(at: probe) }
                return true
            }
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
        let url = URL(fileURLWithPath: Self.plistPath)
        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            throw EligibilityError.unavailable
        }
        return data
    }

    private func write(_ data: Data) throws {
        let url = URL(fileURLWithPath: Self.plistPath)
        let hadBackup = FileManager.default.fileExists(atPath: backupURL.path)
        if !hadBackup, let original = try? readCurrent() {
            try? original.write(to: backupURL)
        }

        do {
            try InodeWriter.writeVerifiedInPlace(data, to: Self.plistPath)
        } catch {
            if hadBackup, let original = try? Data(contentsOf: backupURL) {
                try? InodeWriter.writeVerifiedInPlace(original, to: Self.plistPath)
            }
            throw EligibilityError.writeFailed
        }

        guard let readback = try? Data(contentsOf: url), readback == data else {
            if hadBackup, let original = try? Data(contentsOf: backupURL) {
                try? InodeWriter.writeVerifiedInPlace(original, to: Self.plistPath)
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

        // The eligibility plist is only reachable inside a bad_query lease, so
        // both the read and the write must happen within withLease.
        try BadQueryLeaseScope.withLease(forPath: Self.eligibilityDirPath) {
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

            let out = try PropertyListSerialization.data(fromPropertyList: base, format: .xml, options: 0)
            try write(out)
        }
    }

    /// Restores the pristine eligibility plist captured on the first apply.
    func reset() throws {
        guard Self.isReachable() else { throw EligibilityError.unavailable }
        guard FileManager.default.fileExists(atPath: backupURL.path) else { return }

        let original = try Data(contentsOf: backupURL)
        try BadQueryLeaseScope.withLease(forPath: Self.eligibilityDirPath) {
            try InodeWriter.writeVerifiedInPlace(original, to: Self.plistPath)
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

// MARK: - UI

import SwiftUI

struct EligibilityView: View {
    @ObservedObject private var manager = EligibilityManager.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var isBusy = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var reachable = false

    var body: some View {
        Group {
            if !reachable {
                unavailable
            } else {
                List {
                    controlsSection
                    explanationSection
                }
            }
        }
        .navigationTitle(l10n.tr("eligibility.title"))
        .navigationBarTitleDisplayMode(.inline)
        .workPlotScrollBackground()
        .task { reachable = EligibilityManager.isReachable() }
        .alert(l10n.tr("eligibility.error.title"), isPresented: $showErrorAlert) {
            Button(l10n.tr("common.ok"), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .safeAreaInset(edge: .bottom) {
            if reachable { applyBar }
        }
    }

    private var controlsSection: some View {
        Section {
            Toggle(isOn: $manager.enableGreyMatter) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.tr("eligibility.greymatter"))
                        .font(.body.weight(.medium))
                    Text(l10n.tr("eligibility.greymatter.detail"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(isBusy)
            Toggle(isOn: $manager.enableCalcium) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.tr("eligibility.calcium"))
                        .font(.body.weight(.medium))
                    Text(l10n.tr("eligibility.calcium.detail"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(isBusy)
        } header: {
            Text(reachable ? l10n.tr("eligibility.reachable") : l10n.tr("eligibility.unreachable"))
                .font(.caption2.weight(.bold))
                .foregroundStyle(reachable ? .green : .secondary)
        }
    }

    private var explanationSection: some View {
        Section {
            Text(l10n.tr("eligibility.explanation"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var unavailable: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "lock")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(l10n.tr("eligibility.unavailable.title"))
                .font(.headline)
            Text(l10n.tr("eligibility.unavailable.detail"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var applyBar: some View {
        HStack(spacing: 12) {
            Button(l10n.tr("eligibility.restore"), role: .destructive, action: runReset)
                .disabled(isBusy)
            Button {
                runApply()
            } label: {
                if isBusy {
                    ProgressView()
                } else {
                    Text(l10n.tr("eligibility.apply"))
                }
            }
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
            .disabled(isBusy)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }

    private func runApply() {
        guard reachable, !isBusy else { return }
        isBusy = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try manager.apply()
                DispatchQueue.main.async {
                    isBusy = false
                    ExploitManager.shared.requestRespring()
                }
            } catch {
                DispatchQueue.main.async {
                    isBusy = false
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }

    private func runReset() {
        guard reachable, !isBusy else { return }
        isBusy = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try manager.reset()
                DispatchQueue.main.async {
                    isBusy = false
                    ExploitManager.shared.requestRespring()
                }
            } catch {
                DispatchQueue.main.async {
                    isBusy = false
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }
}
