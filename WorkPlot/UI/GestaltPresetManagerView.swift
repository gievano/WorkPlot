import SwiftUI

struct GestaltPresetManagerView: View {
    @ObservedObject private var manager = ExploitManager.shared
    @State private var selectedTweaks: Set<GestaltTweakID> = []
    @State private var dynamicIslandSubtype: Int?
    @State private var changesModelName = false
    @State private var modelName = ""
    @State private var isApplying = false
    @State private var showRestartAlert = false

    private var stagedChangeCount: Int {
        selectedTweaks.count
            + (dynamicIslandSubtype == nil ? 0 : 1)
            + ((changesModelName && !modelName.trimmingCharacters(in: .whitespaces).isEmpty) ? 1 : 0)
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
                        Section(
                            header: Text("Dynamic Island"),
                            footer: Text(L10n.shared.tr("gestalt.islandFooter"))
                        ) {
                            Picker("Tipe", selection: $dynamicIslandSubtype) {
                                Text(L10n.shared.tr("common.default")).tag(Int?.none)
                                ForEach(DynamicIslandOption.all) { option in
                                    Text("\(option.title) (\(option.subtype))").tag(Int?.some(option.subtype))
                                }
                            }
                        }

                        Section(header: Text(L10n.shared.tr("gestalt.modelHeader"))) {
                            Toggle("Ubah Nama Model", isOn: $changesModelName)
                            if changesModelName {
                                TextField("cth. iPhone 16 Pro", text: $modelName)
                                    .autocorrectionDisabled()
                            }
                        }

                        ForEach(GestaltTweakCategory.allCases) { category in
                            Section(header: Text(category.label)) {
                                ForEach(tweaks(in: category)) { tweak in
                                    Toggle(isOn: binding(for: tweak.id)) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack(spacing: 4) {
                                                Text(tweak.title)
                                                if tweak.isRisky {
                                                    Text(L10n.shared.tr("common.risky")).font(.caption2).bold()
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
                    .workPlotScrollBackground()
                }
            }
            .navigationTitle("Gestalt")
            .alert(
                L10n.shared.tr("restart.rec.title"),
                isPresented: $showRestartAlert
            ) {
                Button(L10n.shared.tr("siriai.restart.respring")) { manager.respringRequested = true }
                Button(L10n.shared.tr("siriai.restart.later"), role: .cancel) {}
            } message: {
                Text(L10n.shared.tr("restart.rec.message"))
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(stagedChangeCount == 0 ? "Apply" : "Apply (\(stagedChangeCount))") {
                        applySelected()
                    }
                    .disabled(stagedChangeCount == 0 || isApplying || !manager.sandboxGranted)
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

        do {
            if selectedTweaks.contains(.aiRegionUS) {
                try AIRegionApplier.apply(to: &plist)
            }
            if let subtype = dynamicIslandSubtype {
                try GestaltArtwork.setDynamicIslandSubtype(subtype, in: &plist)
            }
            if changesModelName {
                let name = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else {
                    throw PlistValueError.invalid("Nama model tidak boleh kosong.")
                }
                try GestaltArtwork.setModelName(name, in: &plist)
            }
            if selectedTweaks.contains(.iPadOS) {
                try GestaltCacheDataPatch.applyiPadOSMode(to: &plist)
            }
        } catch {
            manager.statusText = "Gagal: \(error.localizedDescription)"
            return
        }

        isApplying = true
        let success = manager.saveGestalt(plist)
        isApplying = false

        if success {
            selectedTweaks.removeAll()
            dynamicIslandSubtype = nil
            changesModelName = false
            modelName = ""
            manager.statusText = "Tweak diterapkan. \(L10n.shared.tr("restart.rec.title"))"
            showRestartAlert = true
        } else {
            manager.statusText = "Gagal menyimpan MobileGestalt."
        }
    }
}
