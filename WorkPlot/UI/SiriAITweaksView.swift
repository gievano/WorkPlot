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
                    lockedView
                } else {
                    content
                }
            }
            .navigationTitle(l10n.tr("siriai.title"))
            .navigationBarTitleDisplayMode(.inline)
            .wpGlassContainer()
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

    private var lockedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.icloud").font(.largeTitle).foregroundColor(.orange)
            Text(L10n.shared.tr("common.accessLocked"))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                warningBanner
                statusCard
                modeCards
                spoofCard
                applyCard
                Spacer(minLength: 40)
            }
            .padding(18)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    // MARK: - Warning

    private var warningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 22))
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Siri AI is experimental")
                    .font(.subheadline.bold())
                Text("These tweaks may be unstable on some firmwares. Use at your own risk.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .liquidGlass(cornerRadius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Status

    private var statusCard: some View {
        WPCard {
            VStack(alignment: .leading, spacing: 12) {
                WPSectionHeader(title: l10n.tr("siriai.status.header"))
                statusRow(l10n.tr("siriai.status.siri"), value: siriAIStatusText, color: siriAIStatusColor)
                statusRow(l10n.tr("siriai.status.ai"),
                          value: appleIntelligenceStatusText,
                          color: appleIntelligenceOn ? .green : .secondary)
                statusRow(l10n.tr("siriai.status.spoof"), value: spoofStatusText, color: .secondary)
            }
        }
    }

    private func statusRow(_ label: String, value: String, color: Color) -> some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Text(value).font(.subheadline.weight(.medium)).foregroundColor(color)
        }
    }

    // MARK: - Mode cards (left: revert, middle: AI, right: Siri AI)

    private var modeCards: some View {
        HStack(alignment: .top, spacing: 12) {
            modeCard(
                icon: "arrow.uturn.backward.circle.fill",
                title: "Siri Menu Revert",
                note: "Reset Siri & AI changes back to stock.",
                action: WPActionButton(title: "Revert", prominent: false) { revertAll() }
            )
            modeCard(
                icon: "brain",
                title: "Apple Intelligence",
                note: "Toggle Apple Intelligence eligibility.",
                action: WPActionButton(
                    title: (appleIntelligenceStaged ?? currentAppleIntelligence) ? "Disable" : "Enable",
                    prominent: false
                ) { handleAppleIntelligenceToggle(!((appleIntelligenceStaged ?? currentAppleIntelligence))) }
            )
            modeCard(
                icon: "waveform.circle.fill",
                title: "Siri AI",
                note: "Enable the new Siri AI mode.",
                action: WPActionButton(
                    title: (siriAIStaged ?? currentSiriAI) ? "Disable" : "Enable",
                    prominent: false
                ) { siriAIStaged = !((siriAIStaged ?? currentSiriAI)) }
            )
        }
    }

    private func modeCard(icon: String, title: String, note: String, action: some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(Theme.accent)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Text(note)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Spacer(minLength: 0)
            action
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 158, alignment: .leading)
        .liquidGlass(cornerRadius: 16)
    }

    // MARK: - Spoof

    private var spoofCard: some View {
        WPCard {
            VStack(alignment: .leading, spacing: 12) {
                WPSectionHeader(
                    title: l10n.tr("siriai.section.spoof.header"),
                    subtitle: "Risky — changes the reported device model."
                )
                Picker(l10n.tr("siriai.spoof"), selection: $spoofTarget) {
                    Text(l10n.tr("siriai.spoof.none")).tag(SpoofTarget?.none)
                    ForEach(DeviceSpoofingManager.targets) { target in
                        Text(target.marketingName).tag(SpoofTarget?.some(target))
                    }
                }
                .pickerStyle(.menu)
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
                if eligibilityReachable {
                    NavigationLink(l10n.tr("eligibility.open"), destination: EligibilityView())
                }
                Text(l10n.tr("siriai.warning"))
                    .font(.caption).bold()
                    .foregroundColor(.red)
            }
        }
    }

    // MARK: - Apply

    private var applyCard: some View {
        VStack(spacing: 12) {
            WPActionButton(
                title: stagedCount == 0 ? l10n.tr("siriai.apply") : "\(l10n.tr("siriai.apply")) (\(stagedCount))",
                isBusy: isApplying
            ) {
                if willApplySpoof {
                    showSpoofWarning = true
                } else {
                    applyChanges()
                }
            }
            .disabled(stagedCount == 0 || isApplying)
            WPActionButton(title: l10n.tr("siriai.restart.respring"), prominent: false) {
                manager.requestRespring()
            }
            Text(l10n.tr("siri.rebootHint"))
                .font(.caption)
                .foregroundColor(.secondary)
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

    private func revertAll() {
        siriAIStaged = false
        appleIntelligenceStaged = false
        spoofTarget = nil
        applyChanges()
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
