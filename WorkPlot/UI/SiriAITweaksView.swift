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
    @State private var didLoadState = false

    private var stagedCount: Int {
        (siriAIStaged == nil ? 0 : 1)
            + (appleIntelligenceStaged == nil ? 0 : 1)
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
                        spoofSection
                        appleIntelligenceSection
                        applySection
                    }
                }
            }
            .navigationTitle(l10n.tr("siriai.title"))
            .workPlotScrollBackground()
            .alert(
                l10n.tr("siriai.restart.title"),
                isPresented: $showRestartAlert
            ) {
                Button(l10n.tr("siriai.restart.respring")) {
                    manager.respringRequested = true
                }
                Button(l10n.tr("siriai.restart.later"), role: .cancel) {}
            } message: {
                Text(l10n.tr("siriai.restart.message"))
            }
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
        }
    }

    private var spoofSection: some View {
        Section(header: Text(l10n.tr("siriai.spoof"))) {
            Picker(l10n.tr("siriai.spoof"), selection: $spoofTarget) {
                Text(l10n.tr("siriai.spoof.none")).tag(SpoofTarget?.none)
                ForEach(DeviceSpoofingManager.targets) { target in
                    Text(target.marketingName).tag(SpoofTarget?.some(target))
                }
            }
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
                manager.respringRequested = true
            } label: {
                Label("Respring", systemImage: "arrow.counterclockwise")
            }
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

    private func loadCurrentState() {
        guard !didLoadState else { return }
        didLoadState = true
    }

    // MARK: - Staged apply

    /// Applies every staged change in one read-modify-write pass:
    /// backup → mutate → save (verified write) → respring.
    private func applyChanges() {
        guard var plist = loadedPlist else {
            manager.statusText = "Gagal: tidak dapat membaca MobileGestalt."
            return
        }

        do {
            if let enabled = siriAIStaged {
                try SiriAIModifier.setEnabled(enabled, in: &plist)
            }
            if let enabled = appleIntelligenceStaged {
                AppleIntelligenceController.setEnabled(enabled, in: &plist)
            }
            if let target = spoofTarget {
                try DeviceSpoofingManager.apply(target, to: &plist)
            }
        } catch {
            manager.statusText = "Gagal: \(error.localizedDescription)"
            return
        }

        isApplying = true
        let success = manager.saveGestalt(plist)
        isApplying = false

        if success {
            siriAIStaged = nil
            appleIntelligenceStaged = nil
            spoofTarget = nil
            manager.statusText = "\(l10n.tr("siriai.apply")) OK. \(l10n.tr("siriai.restart.title"))"
            // Siri AI tweaks require a device restart before they take
            // effect; the user picks between respring now or later.
            showRestartAlert = true
        } else {
            manager.statusText = "Gagal menyimpan MobileGestalt."
        }
    }
}
