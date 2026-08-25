import SwiftUI

struct DeviceSpoofingView: View {
    @EnvironmentObject private var store: GestaltStore
    @State private var selected: SpoofTarget?
    @State private var isBusy = false
    @State private var message: String?
    @State private var errorText: String?

    private var realID: String { DeviceSpoofingManager.realMachineIdentifier }

    var body: some View {
        List {
            Section {
                Text("Real device: \(realID)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if store.isDeviceSpoofed {
                    Label("Currently spoofed", systemImage: "cpu")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.caution)
                }
            } header: { Text("Device Spoof") }

            Section("Spoof identity to") {
                ForEach(DeviceSpoofingManager.targets) { target in
                    Button { selected = target } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(target.marketingName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("\(target.productType) · \(target.hwModel) · \(target.cpuName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selected?.id == target.id {
                                Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if let message {
                Section {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }

            Section {
                Button { Task { await apply() } } label: {
                    HStack {
                        if isBusy { ProgressView() }
                        Text("Apply Spoof").font(.body.weight(.semibold))
                    }
                }
                .disabled(isBusy || selected == nil)
            } footer: {
                Text("Revert anytime from Settings → Recovery (restore pristine backup).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
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
