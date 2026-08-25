import SwiftUI

struct SiriAISetupView: View {
    @EnvironmentObject private var store: GestaltStore
    @State private var mode: Mode = .appleIntelligence
    @State private var confirmedModelDownloaded = false
    @State private var isBusy = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showRebootNotice = false

    enum Mode: String, CaseIterable, Identifiable {
        case siri = "Siri"
        case appleIntelligence = "Apple Intelligence"
        case siriAI = "Siri AI"

        var id: String { rawValue }
    }

    /// Siri AI is the only mode that needs an extra confirmation — the model
    /// has to have finished downloading before the key can be bumped.
    private var canApply: Bool {
        mode != .siriAI || confirmedModelDownloaded
    }

    var body: some View {
        NavigationStack {
            Group {
                if DeviceCompatibility.supportsFullFeatureSet {
                    ZStack {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 28) {
                                header
                                Picker("Capability", selection: $mode) {
                                    ForEach(Mode.allCases) { option in
                                        Text(option.rawValue).tag(option)
                                    }
                                }
                                .pickerStyle(.segmented)
                                if mode == .siriAI { siriAIWarning }
                                disclaimer
                                if mode == .siriAI { modelConfirmation }
                            }
                            .padding(Theme.pagePadding)
                            .padding(.bottom, 94)
                        }
                        .scrollIndicators(.hidden)
                        if isBusy { ProgressOverlay(message: "Applying") }
                    }
                    .safeAreaInset(edge: .bottom) { actionBar }
                } else {
                    FeatureUnsupportedView(feature: "Siri AI Setup")
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Siri AI Setup")
            .navigationBarTitleDisplayMode(.large)
            .task { await store.refreshSpoofState() }
            .alert("Could not apply changes", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .alert("Reboot required", isPresented: $showRebootNotice) {
                Button("OK") { RespringHelper.shared.trigger() }
            } message: {
                Text("After respring please reboot your device.")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Theme.caution)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 5) {
                Text("Beta feature")
                    .font(.headline)
                Text("Siri AI Setup is experimental and may cause unintended behavior, including instability, boot loops, or requiring a device restore. Use at your own risk.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    private var siriAIWarning: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "exclamationmark.octagon.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.destructive)
            VStack(alignment: .leading, spacing: 6) {
                Text("Rarely works in its current state")
                    .font(.headline)
                Text("Siri AI is the least reliable feature in Ketamine and may have no effect on your device. You can still apply it, but it isn't expected to succeed.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Theme.destructive.opacity(0.13),
                    in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    @ViewBuilder
    private var disclaimer: some View {
        switch mode {
        case .siri:
            disclaimerCard(
                title: "Revert to Siri",
                detail: "Restores every key Apple Intelligence changed — including the device spoof — and turns generative-model support back off."
            )
        case .appleIntelligence:
            disclaimerCard(
                title: "Enable Apple Intelligence",
                detail: "Sets the US regulatory-region keys, and spoofs the product, hardware, and CPU model if this device isn't natively eligible. Spoofing may temporarily break Face ID. The previous values are saved first, so this can be reversed."
            )
        case .siriAI:
            disclaimerCard(
                title: "Enable Siri AI",
                detail: "Requires Apple Intelligence to already be applied and its model fully downloaded. Spoofs the device if needed, then upgrades generative-model support to the Siri AI level."
            )
        }
    }

    private func disclaimerCard(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.body.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if store.isDeviceSpoofed {
                Label("This device is currently spoofed.", systemImage: "cpu")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.caution)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .liquidGlass()
    }

    private var modelConfirmation: some View {
        Toggle(isOn: $confirmedModelDownloaded) {
            Text("Apple Intelligence model finished downloading")
                .font(.subheadline.weight(.medium))
        }
        .tint(Theme.accent)
        .padding(18)
        .liquidGlass()
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            if store.isDeviceSpoofed {
                Button("Unspoof", action: unspoof)
                    .glassAction()
                    .disabled(isBusy)
            }
            Button("Apply", systemImage: "checkmark") { apply() }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .glassAction(prominent: true)
                .tint(Theme.accent)
                .disabled(isBusy || !canApply)
        }
        .padding(.horizontal, Theme.pagePadding)
        .padding(.vertical, 12)
    }

    private func apply() {
        guard !isBusy else { return }
        isBusy = true
        Task {
            do {
                switch mode {
                case .appleIntelligence:
                    _ = try await store.applyAIRegion()
                case .siri:
                    _ = try await store.applySiri()
                case .siriAI:
                    _ = try await store.applySiriAI()
                    confirmedModelDownloaded = false
                }
                isBusy = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                showRebootNotice = true
            } catch {
                isBusy = false
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }

    private func unspoof() {
        guard !isBusy else { return }
        isBusy = true
        Task {
            do {
                _ = try await store.unspoofDevice()
                isBusy = false
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                showRebootNotice = true
            } catch {
                isBusy = false
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
}
