import SwiftUI

struct SiriAITweaksView: View {
    @ObservedObject private var manager = ExploitManager.shared
    @ObservedObject private var l10n = L10n.shared

    // Staged changes; nil = leave untouched.
    @State private var siriAIStaged: Bool?
    @State private var appleIntelligenceStaged: Bool?
    @State private var siriModeStaged: Bool?
    @State private var modelKeyStaged: Bool?
    @State private var eligibilityStaged: Bool?
    @State private var spoofTarget: SpoofTarget?
    @State private var isApplying = false
    @State private var showRestartAlert = false
    @State private var showSpoofWarning = false
    @State private var didLoadState = false

    private var stagedCount: Int {
        (siriAIStaged == nil ? 0 : 1)
            + (appleIntelligenceStaged == nil ? 0 : 1)
            + (siriModeStaged == nil ? 0 : 1)
            + (modelKeyStaged == nil ? 0 : 1)
            + (eligibilityStaged == nil ? 0 : 1)
            + (spoofTarget == nil ? 0 : 1)
    }

    var body: some View {
        NavigationView {
            Group {
                if !manager.sandboxGranted {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.icloud").font(.largeTitle).foregroundColor(.orange)
                        Text(L10n.shared.tr("common.accessLocked"))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        siriAISection
                        siriModeSection
                        siriCameraSection
                        spoofSection
                        appleIntelligenceSection
                        applySection
                    }
                }
            }
            .navigationTitle(l10n.tr("siriai.title"))
            .workPlotScrollBackground()
            .heavyRestartFlow(isPresented: $showRestartAlert)
            .alert(
                l10n.tr("danger.spoof.title"),
                isPresented: $showSpoofWarning
            ) {
                Button(l10n.tr("danger.spoof.continue"), role: .destructive) { applyChanges() }
                Button(l10n.tr("siriai.restart.later"), role: .cancel) {}
            } message: {
                Text(l10n.tr("danger.spoof.message"))
            }
            .onAppear(perform: loadCurrentState)
        }
    }

    private var siriAISection: some View {
        Section(
            header: Text(l10n.tr("siriai.toggle")),
            footer: Text(l10n.tr("siriai.toggle.detail"))
        ) {
            Toggle(isOn: Binding(
                get: { siriAIStaged ?? currentSiriAI },
                set: { siriAIStaged = $0 }
            )) {
                Text(l10n.tr("siriai.toggle"))
            }
            Toggle(isOn: Binding(
                get: { modelKeyStaged ?? currentModelKeyOn },
                set: { modelKeyStaged = $0 }
            )) {
                Text(l10n.tr("siriai.modelkey.toggle"))
            }
            Text(l10n.tr("siriai.modelkey.detail"))
                .font(.caption)
                .foregroundColor(.secondary)
            Toggle(isOn: Binding(
                get: { eligibilityStaged ?? currentEligibilityOnly },
                set: { eligibilityStaged = $0 }
            )) {
                Text(l10n.tr("siriai.eligibility.toggle"))
            }
            Text(l10n.tr("siriai.eligibility.detail"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var siriModeSection: some View {
        Section(
            header: Text(l10n.tr("siriai.sirimode.header")),
            footer: Text(l10n.tr("siriai.sirimode.detail"))
        ) {
            Toggle(isOn: Binding(
                get: { siriModeStaged ?? currentSiriMode },
                set: { siriModeStaged = $0 }
            )) {
                Text(l10n.tr("siriai.sirimode.toggle"))
            }
        }
    }

    /// EXPERIMENTAL: iOS 27 exposes Siri in the Camera through the same
    /// Siri AI mode; no dedicated verified CacheExtra key exists yet, so we
    /// only surface guidance instead of writing unverified keys.
    private var siriCameraSection: some View {
        Section(header: Text(l10n.tr("siriai.siricam.header"))) {
            HStack(spacing: 4) {
                Text(l10n.tr("common.experimental")).font(.caption2).bold()
                    .foregroundColor(.orange)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(4)
            }
            Text(l10n.tr("siriai.siricam.note"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var spoofSection: some View {
        Section(header: Text(l10n.tr("siriai.spoof")), footer: Text(l10n.tr("siriai.spoof.revert"))) {
            Picker(l10n.tr("siriai.spoof"), selection: $spoofTarget) {
                Text(l10n.tr("siriai.spoof.none")).tag(SpoofTarget?.none)
                ForEach(DeviceSpoofingManager.targets) { target in
                    Text(target.marketingName).tag(SpoofTarget?.some(target))
                }
            }
            if let target = spoofTarget, let plist = loadedPlist {
                Text(String(format: l10n.tr("siriai.spoof.keysCount"),
                            DeviceSpoofingManager.changedKeyCount(in: plist, target: target)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(String(format: l10n.tr("siriai.spoof.detected"),
                        DeviceSpoofingManager.realMachineIdentifier))
                .font(.caption)
                .foregroundColor(.secondary)
            Text(l10n.tr("siriai.warning"))
                .font(.caption).bold()
                .foregroundColor(.red)
        }
    }

    private var appleIntelligenceSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { appleIntelligenceStaged ?? currentAppleIntelligence },
                set: { appleIntelligenceStaged = $0 }
            )) {
                Text(l10n.tr("siriai.ai.toggle"))
            }
        }
    }

    private var applySection: some View {
        Section {
            Button {
                if spoofTarget != nil {
                    showSpoofWarning = true
                } else {
                    applyChanges()
                }
            } label: {
                if isApplying {
                    HStack { ProgressView(); Text(l10n.tr("siriai.apply") + "...") }
                } else {
                    Text(stagedCount == 0 ? l10n.tr("siriai.apply") : "\(l10n.tr("siriai.apply")) (\(stagedCount))")
                }
            }
            .disabled(stagedCount == 0 || isApplying)

            Button {
                manager.requestRespring()
            } label: {
                Label(l10n.tr("siriai.restart.respring"), systemImage: "arrow.counterclockwise")
            }

            Text(l10n.tr("siri.rebootHint"))
                .font(.caption)
                .foregroundColor(.secondary)
            Text(l10n.tr("siri.waitlistNote"))
                .font(.caption)
                .foregroundColor(.secondary)
        } footer: {
            Text(l10n.tr("restart.options.message"))
        }
    }

    // MARK: - State

    private var loadedPlist: [String: Any]? {
        manager.readGestalt()
    }

    private var currentSiriAI: Bool {
        guard let plist = loadedPlist else { return false }
        if case .on = SiriAIModifier.state(of: plist) { return true }
        return false
    }

    private var currentAppleIntelligence: Bool {
        guard let plist = loadedPlist else { return false }
        return AppleIntelligenceController.isEnabled(in: plist)
    }

    private var currentSiriMode: Bool {
        guard let plist = loadedPlist,
              let cacheExtra = plist["CacheExtra"] as? [String: Any],
              let value = cacheExtra[SiriModeApplier.cacheExtraKey] as? Int else { return false }
        return value == SiriModeApplier.enabledValue
    }

    /// Effective spoof target: the picker selection, or what is already
    /// written on the device when the user did not stage a new one.
    private var effectiveSpoofTarget: SpoofTarget? {
        if let spoofTarget { return spoofTarget }
        guard let plist = loadedPlist else { return nil }
        return DeviceSpoofingManager.currentTarget(in: plist)
    }

    private var currentModelKeyOn: Bool {
        guard let plist = loadedPlist else { return false }
        return ModelSpoofKeyApplier.isEnabled(in: plist, target: effectiveSpoofTarget)
    }

    private var currentEligibilityOnly: Bool {
        guard let plist = loadedPlist else { return false }
        return AIRegionEligibilityApplier.isEnabled(in: plist)
    }

    private func loadCurrentState() {
        guard !didLoadState else { return }
        didLoadState = true
    }

    // MARK: - Staged apply

    /// Applies every staged change in one read-modify-write pass:
    /// backup → mutate → save (verified write) → respring.
    private func applyChanges() {
        guard var plist = loadedPlist else {
            manager.statusText = l10n.tr("common.readFail")
            return
        }

        do {
            if let enabled = siriAIStaged {
                try SiriAIModifier.setEnabled(enabled, in: &plist)
            }
            if let enabled = siriModeStaged {
                SiriModeApplier.setEnabled(enabled, in: &plist)
            }
            if let enabled = appleIntelligenceStaged {
                AppleIntelligenceController.setEnabled(enabled, in: &plist)
            }
            // Spoof first so the single-key toggle below either re-asserts
            // the same ProductType or deliberately clears the primary key.
            if let target = spoofTarget {
                try DeviceSpoofingManager.apply(target, to: &plist)
            }
            if let enabled = modelKeyStaged {
                try ModelSpoofKeyApplier.setEnabled(enabled, target: effectiveSpoofTarget, in: &plist)
            }
            if let enabled = eligibilityStaged {
                AIRegionEligibilityApplier.setEnabled(enabled, in: &plist)
            }
        } catch {
            manager.statusText = String(format: l10n.tr("common.failPrefix"), error.localizedDescription)
            return
        }

        isApplying = true
        defer { isApplying = false }
        do {
            try manager.saveGestaltOrThrow(plist)
            siriAIStaged = nil
            siriModeStaged = nil
            appleIntelligenceStaged = nil
            modelKeyStaged = nil
            eligibilityStaged = nil
            spoofTarget = nil
            manager.statusText = "\(l10n.tr("siriai.apply")) OK. \(l10n.tr("siriai.restart.title"))"
            // Siri AI tweaks require a restart; the shared flow offers
            // respring or manual userspace/full restart guidance.
            showRestartAlert = true
        } catch {
            manager.statusText = String(
                format: l10n.tr("common.failPrefix"),
                error.localizedDescription
            )
        }
    }
}
