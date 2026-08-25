import SwiftUI

struct DeviceSpoofingView: View {
    @EnvironmentObject private var store: GestaltStore
    @State private var selected: SpoofTarget?
    @State private var isBusy = false
    @State private var message: String?
    @State private var errorText: String?

    private var realID: String { DeviceSpoofingManager.realMachineIdentifier }

    private var allTargets: [SpoofTarget?] {
        [nil] + DeviceSpoofingManager.targets
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if store.isDeviceSpoofed {
                    Label("Currently spoofed", systemImage: "cpu")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.caution)
                }

                SectionHeader("Configure Device Spoof")

                VStack(spacing: 0) {
                    ForEach(Array(allTargets.enumerated()), id: \.offset) { index, target in
                        Button {
                            selected = target
                        } label: {
                            HStack {
                                Text(target?.marketingName ?? "None")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selected?.id == target?.id {
                                    Image(systemName: "checkmark").foregroundStyle(.white)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)

                        if index < allTargets.count - 1 {
                            Divider().padding(.horizontal, 16)
                        }
                    }
                }
                .liquidGlass(cornerRadius: 16)

                Text("Changes the reported device identity. Some spoof targets may break Face ID until reverted, so keep a snapshot handy. 'None' keeps the device's real identity.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                ActionButton("Apply Spoof") {
                    Task { await apply() }
                }
                .disabled(isBusy || selected == nil)

                if let message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
            }
            .padding()
        }
        .navigationTitle("Device Spoof")
        .wpGlassContainer()
        .alert("Error", isPresented: .constant(errorText != nil)) {
            Button("OK") { errorText = nil }
        } message: { Text(errorText ?? "") }
    }

    private func apply() async {
        guard let target = selected else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try await store.applyDeviceSpoof(target)
            message = "Spoofed to \(target.marketingName). Respring to apply."
        } catch {
            errorText = error.localizedDescription
        }
    }
}
