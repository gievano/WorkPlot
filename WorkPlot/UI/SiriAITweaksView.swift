import SwiftUI

struct SiriAITweaksView: View {
    @ObservedObject private var manager = ExploitManager.shared
    @ObservedObject private var l10n = L10n.shared

    // Staged changes; nil = leave untouched.
    @State private var siriAIStaged: Bool?
    @State private var appleIntelligenceStaged: Bool?
    @State private var spoofTarget: SpoofTarget?
    @State private var isApplying = false
    @State private var showRestartAlert = false
    @State private var showSpoofWarning = false
    @State private var eligibilityReachable = false

    private var stagedCount: Int {
        (siriAIStaged == nil ? 0 : 1)
            + (appleIntelligenceStaged == nil ? 0 : 1)
            + (spoofTarget == nil ? 0 : 1)
    }

    /// Any staged change that also writes model-identity keys must warn
    /// first: an explicit spoof selection, or Apple Intelligence which
    /// implies a spoof so eligibility checks accept the hardware.
    private var willApplySpoof: Bool {
        spoofTarget != nil || appleIntelligenceStaged == true
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
                        statusSection
                        siriAISection
                        appleIntelligenceSection
                        spoofSection
                        if eligibilityReachable {
                            Section(header: Text(l10n.tr("eligibility.title"))) {
                                NavigationLink(l10n.tr("eligibility.open"), destination: EligibilityView())
                            }
                        }
                        applySection
                    }
                }
            }
            .navigationTitle(l10n.tr("siriai.title"))
            .workPlotScrollBackground()
            .task { eligibilityReachable = EligibilityManager.isReachable() }
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
        }
    }

    // MARK: - Sections

    /// Read-only snapshot of what is actually written on the device.
    private var statusSection: some View {
        Section(header: Text(l10n.tr("siriai.status.header"))) {
            HStack {
                Text(l10n.tr("siriai.status.siri"))
                Spacer()
                Text(siriAIStatusText).foregroundColor(siriAIStatusColor)
            }
            HStack {
                Text(l10n.tr("siriai.status.ai"))
                Spacer()
                Text(appleIntelligenceStatusText)
                    .foregroundColor(appleIntelligenceOn ? Color.green : Color.secondary)
            }
            HStack {
                Text(l10n.tr("siriai.status.spoof"))
                Spacer()
                Text(spoofStatusText).foregroundColor(Color.secondary)
            }
        }
    }

    private var siriAISection: some View {
        Section(
            header: Text(l10n.tr("siriai.section.siri.header")),
            footer: Text(l10n.tr("siriai.section.siri.footer"))
        ) {
            Toggle(l10n.tr("siriai.toggle"), isOn: Binding(
                get: { siriAIStaged ?? currentSiriAI },
                set: { siriAIStaged = $0 }
            ))
        }
    }

    private var appleIntelligenceSection: some View {
        Section(
            header: Text(l10n.tr("siriai.section.ai.header")),
            footer: Text(l10n.tr("siriai.section.ai.footer"))
        ) {
            Toggle(l10n.tr("siriai.ai.toggle"), isOn: Binding(
                get: { appleIntelligenceStaged ?? currentAppleIntelligence },
                set: { handleAppleIntelligenceToggle($0) }
            ))
            if appleIntelligenceStaged == true && spoofTarget != nil {
                Text(l10n.tr("siriai.ai.autospoof"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var spoofSection: some View {
        Section(
            header: Text(l10n.tr("siriai.section.spoof.header")),
            footer: Text(l10n.tr("siriai.spoof.revert"))
        ) {
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

    private var applySection: some View {
        Section {
            Button {
                if willApplySpoof {
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
        } footer: {
            Text(l10n.tr("restart.options.message"))
        }
    }

    // MARK: - Toggle behavior

    /// Turning Apple Intelligence on implies a device spoof (eligibility
    /// checks reject older hardware): auto-pick the newest target unless one
    /// is already staged here or already active on the device.
    private func handleAppleIntelligenceToggle(_ on: Bool) {
        appleIntelligenceStaged = on
        guard on, spoofTarget == nil,
              loadedPlist.flatMap({ DeviceSpoofingManager.currentTarget(in: $0) }) == nil else { return }
        spoofTarget = DeviceSpoofingManager.targets.last
    }

    // MARK: - Current device state

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

    private var siriAIStatusText: String {
        guard let plist = loadedPlist else { return L10n.shared.tr("siriai.status.unknown") }
        switch SiriAIModifier.state(of: plist) {
        case .on: return L10n.shared.tr("siriai.status.on")
        case .off: return L10n.shared.tr("siriai.status.off")
        case .unknown: return L10n.shared.tr("siriai.status.unknown")
        }
    }

    private var siriAIStatusColor: Color {
        guard let plist = loadedPlist else { return .orange }
        switch SiriAIModifier.state(of: plist) {
        case .on: return .green
        case .off: return .secondary
        case .unknown: return .orange
        }
    }

    private var appleIntelligenceOn: Bool {
        currentAppleIntelligence
    }

    private var appleIntelligenceStatusText: String {
        appleIntelligenceOn
            ? L10n.shared.tr("siriai.status.on")
            : L10n.shared.tr("siriai.status.off")
    }

    private var spoofStatusText: String {
        guard let plist = loadedPlist,
              let target = DeviceSpoofingManager.currentTarget(in: plist) else {
            return L10n.shared.tr("siriai.status.spoof.none")
        }
        return target.marketingName
    }

    // MARK: - Staged apply

    /// Applies every staged change in one read-modify-write pass:
    /// backup → mutate → save (verified write) → verify → restart prompt.
    /// All Gestalt I/O runs off the main thread (same rule as the dashboard).
    private func applyChanges() {
        guard !isApplying else { return }
        isApplying = true

        let siriStage = siriAIStaged
        let aiStage = appleIntelligenceStaged
        let spoofStage = spoofTarget

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                guard var plist = self.manager.readGestalt() else {
                    throw ExploitManagerError(message: L10n.shared.tr("common.readFail"))
                }

                // New Siri AI path: CacheData capability patch + Siri mode flag.
                if let enabled = siriStage {
                    try SiriAIModifier.setEnabled(enabled, in: &plist)
                    SiriModeApplier.setEnabled(enabled, in: &plist)
                }
                // Legacy Apple Intelligence path: eligibility key only.
                if let enabled = aiStage {
                    AppleIntelligenceController.setEnabled(enabled, in: &plist)
                }
                if let target = spoofStage {
                    try DeviceSpoofingManager.apply(target, to: &plist)
                }

                try self.manager.saveGestaltOrThrow(plist)

                var verifyLine = ""
                if let target = spoofStage {
                    // Read back from disk so the status distinguishes a write
                    // that landed from one the system dropped (iOS 27 builds
                    // may serve identity from signed cache values instead of
                    // CacheExtra - GoldenNugget dropped MobileGestalt for 27
                    // entirely; this line keeps us honest about which side failed).
                    let v = self.manager.readGestalt()
                        .map { DeviceSpoofingManager.verify(target: target, in: $0) } ?? (matched: 0, total: 0)
                    verifyLine = String(
                        format: L10n.shared.tr("siriai.spoof.verify"),
                        target.marketingName, v.matched, v.total
                    )
                    if v.total == 0 || v.matched < v.total {
                        verifyLine += "\n" + L10n.shared.tr("rdar.verify.fail")
                    }
                }

                DispatchQueue.main.async {
                    self.isApplying = false
                    self.siriAIStaged = nil
                    self.appleIntelligenceStaged = nil
                    self.spoofTarget = nil
                    self.manager.statusText = "\(L10n.shared.tr("siriai.apply")) OK. \(L10n.shared.tr("siriai.restart.title"))"
                        + (verifyLine.isEmpty ? "" : "\n\(verifyLine)")
                    self.showRestartAlert = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.isApplying = false
                    self.manager.statusText = String(
                        format: L10n.shared.tr("common.failPrefix"),
                        error.localizedDescription
                    )
                }
            }
        }
    }
}
