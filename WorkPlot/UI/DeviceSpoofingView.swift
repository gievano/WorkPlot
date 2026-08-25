import SwiftUI

struct DeviceSpoofingView: View {
    @EnvironmentObject private var store: GestaltStore
    @State private var selected: SpoofTarget?
    @State private var isConfiguring = false
    @State private var isBusy = false
    @State private var message: String?
    @State private var errorText: String?

    private var allTargets: [SpoofTarget?] {
        [nil] + DeviceSpoofingManager.targets
    }

    private var selectionBinding: Binding<Int> {
        Binding(
            get: { allTargets.firstIndex { $0?.id == selected?.id } ?? 0 },
            set: { selected = allTargets[$0] }
        )
    }

    /// Same caption contract as TweakCatalogTile: open panel reads
    /// "Configuring"; otherwise show state or the current target.
    private var spoofCaption: String {
        if isConfiguring { return "Configuring" }
        if store.isDeviceSpoofed { return "Spoofed" }
        return selected?.marketingName ?? "None"
    }

    private func toggleConfiguration() {
        withAnimation(.snappy) { isConfiguring.toggle() }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if store.isDeviceSpoofed {
                    Label("Currently spoofed", systemImage: "cpu")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.caution)
                }

                Button { toggleConfiguration() } label: {
                    // Mirrors TweakCatalogTile 1:1 so the spoof card reads
                    // exactly like a configurable tweak tile.
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Image(systemName: "iphone.and.arrow.forward")
                                .font(.body.weight(.medium))
                                .foregroundStyle(isConfiguring ? .white : .secondary)
                            Spacer()
                            Image(systemName: store.isDeviceSpoofed ? "checkmark.circle.fill" : "circle")
                                .font(.caption)
                                .foregroundStyle(isConfiguring ? .white : Color(uiColor: .tertiaryLabel))
                        }
                        Spacer(minLength: 8)
                        Text("Device Spoof")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(spoofCaption)
                            .font(.caption)
                            .foregroundStyle(isConfiguring ? .white : .secondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 142, maxHeight: .infinity, alignment: .leading)
                    .padding(16)
                    .background(isConfiguring ? .white.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .liquidGlass(cornerRadius: 22)
                }
                .buttonStyle(.plain)

                if isConfiguring {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader("Configure Device Spoof")

                        Picker("Option", selection: selectionBinding) {
                            ForEach(Array(allTargets.enumerated()), id: \.offset) { index, target in
                                Text(target?.marketingName ?? "None").tag(index)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 138)
                        .liquidGlass()

                        Label("Changes the reported device identity. Some spoof targets may break Face ID until reverted, so keep a snapshot handy. 'None' keeps the device's real identity.", systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                ActionButton(title: "Apply Spoof") {
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
