import SwiftUI

struct GestaltPresetManagerView: View {
    @ObservedObject private var manager = ExploitManager.shared
    @State private var selectedTweaks: Set<GestaltTweakID> = []
    @State private var isApplying = false

    var body: some View {
        NavigationView {
            Group {
                if !manager.sandboxGranted {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.icloud").font(.largeTitle).foregroundColor(.orange)
                        Text("Akses sistem belum aktif.\nBuka tab Status dan tekan \"Periksa Akses Sistem\".")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(GestaltTweakCategory.allCases) { category in
                            Section(header: Text(category.label)) {
                                ForEach(tweaks(in: category)) { tweak in
                                    Toggle(isOn: binding(for: tweak.id)) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 4) {
                                                Text(tweak.title)
                                                if tweak.isRisky {
                                                    Text("RISKY").font(.caption2).bold()
                                                        .foregroundColor(.red)
                                                        .padding(.horizontal, 4).padding(.vertical, 1)
                                                        .background(Color.red.opacity(0.15))
                                                        .cornerRadius(4)
                                                }
                                            }
                                            Text(tweak.detail).font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Gestalt")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(selectedTweaks.isEmpty ? "Apply" : "Apply (\(selectedTweaks.count))") {
                        applySelected()
                    }
                    .disabled(selectedTweaks.isEmpty || isApplying || !manager.sandboxGranted)
                }
            }
        }
    }

    private func tweaks(in category: GestaltTweakCategory) -> [GestaltTweakDefinition] {
        GestaltTweakCatalog.definitions.filter { $0.category == category }
    }

    private func binding(for id: GestaltTweakID) -> Binding<Bool> {
        Binding(
            get: { selectedTweaks.contains(id) },
            set: { enabled in
                if enabled {
                    if id == .enableLiquidGlassLowPerformance { selectedTweaks.remove(.disableLiquidGlassLowPerformance) }
                    if id == .disableLiquidGlassLowPerformance { selectedTweaks.remove(.enableLiquidGlassLowPerformance) }
                    selectedTweaks.insert(id)
                } else {
                    selectedTweaks.remove(id)
                }
            }
        )
    }

    private func applySelected() {
        guard var plist = manager.readGestalt() else {
            manager.statusText = "Gagal: tidak dapat membaca MobileGestalt."
            return
        }

        for id in selectedTweaks {
            guard let def = GestaltTweakCatalog.definition(for: id) else { continue }
            for (key, value) in def.values {
                var cacheExtra = plist["CacheExtra"] as? [String: Any] ?? [:]
                cacheExtra[key] = value
                plist["CacheExtra"] = cacheExtra
            }
        }

        isApplying = true
        let success = manager.saveGestalt(plist)
        isApplying = false

        if success {
            selectedTweaks.removeAll()
            manager.statusText = "Tweak diterapkan. Restart device untuk melihat efek."
        } else {
            manager.statusText = "Gagal menyimpan MobileGestalt."
        }
    }
}
