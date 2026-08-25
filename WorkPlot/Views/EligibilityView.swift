import SwiftUI
import UIKit

struct EligibilityView: View {
    @ObservedObject private var manager = EligibilityManager.shared
    @State private var isBusy = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var reachable = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    if reachable {
                        controls
                        explanation
                    } else {
                        unavailable
                    }
                }
                .padding(Theme.pagePadding)
                .padding(.bottom, reachable ? 94 : 24)
            }
            .scrollIndicators(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            if isBusy { ProgressOverlay(message: "Updating eligibility") }
        }
        .navigationTitle("Eligibility")
        .navigationBarTitleDisplayMode(.inline)
        .task { reachable = EligibilityManager.isReachable() }
        .safeAreaInset(edge: .bottom) {
            if reachable { applyBar }
        }
        .alert("Eligibility update failed", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Domain controls")
                .font(.largeTitle.weight(.semibold))
            Text("Set the eligibility answers that this device reports to the operating system.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(reachable ? "DIRECT ACCESS AVAILABLE" : "DIRECT ACCESS UNAVAILABLE")
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(reachable ? Theme.affirmative : .secondary)
                .padding(.top, 4)
        }
    }

    private var controls: some View {
        VStack(spacing: 0) {
            domain(
                title: "Apple Intelligence",
                detail: "Enables the GREYMATTER domain for generative model eligibility.",
                symbol: "sparkles",
                isOn: $manager.enableGreyMatter
            )
            Divider().padding(.leading, 44)
            domain(
                title: "China Cellular",
                detail: "Removes the CALCIUM China-cellular eligibility restriction.",
                symbol: "antenna.radiowaves.left.and.right",
                isOn: $manager.enableCalcium
            )
        }
        .padding(.horizontal, 18)
        .liquidGlass()
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How it works").font(.subheadline.weight(.semibold))
            Text("Ketamine merges these answers into the existing eligibility plist. It keeps unrelated state intact and saves the original file before the first change.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var unavailable: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "lock")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("This firmware does not grant write access to the eligibility container.")
                .font(.headline)
            Text("Use the Apple Intelligence and Device Spoof capabilities from Console instead.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
    }

    private var applyBar: some View {
        HStack(spacing: 12) {
            Button("Restore", role: .destructive, action: reset)
                .glassAction()
                .disabled(isBusy)
            Button("Update eligibility", systemImage: "checkmark") { apply() }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
                .glassAction(prominent: true)
                .tint(Theme.accent)
                .disabled(isBusy)
        }
        .padding(.horizontal, Theme.pagePadding)
        .padding(.vertical, 12)
    }

    private func domain(title: String, detail: String, symbol: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.body.weight(.medium))
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .tint(Theme.accent)
        .padding(.vertical, 16)
    }

    private func apply() {
        guard reachable, !isBusy else { return }
        isBusy = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try manager.apply()
                DispatchQueue.main.async {
                    isBusy = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    RespringHelper.shared.trigger()
                }
            } catch {
                DispatchQueue.main.async {
                    isBusy = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }

    private func reset() {
        guard reachable, !isBusy else { return }
        isBusy = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try manager.reset()
                DispatchQueue.main.async {
                    isBusy = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                DispatchQueue.main.async {
                    isBusy = false
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }
}
