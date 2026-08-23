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
                            header: Text(L10n.shared.tr("gestalt.islandHeader")),
                            footer: Text(L10n.shared.tr("gestalt.islandFooter"))
                        ) {
                            Picker(L10n.shared.tr("fields.typeHeader"), selection: $dynamicIslandSubtype) {
                                Text(L10n.shared.tr("common.default")).tag(Int?.none)
                                ForEach(DynamicIslandOption.all) { option in
                                    Text("\(option.title) (\(option.subtype))").tag(Int?.some(option.subtype))
                                }
                            }
                        }

                        Section(header: Text(L10n.shared.tr("gestalt.modelHeader"))) {
                            Toggle(L10n.shared.tr("gestalt.changeModelName"), isOn: $changesModelName)
                            if changesModelName {
                                TextField(L10n.shared.tr("gestalt.modelNamePlaceholder"), text: $modelName)
                                    .autocorrectionDisabled()
                            }
                        }

                        ForEach(GestaltTweakCategory.allCases) { category in
                            Section(header: Text(category.label)) {
                                ForEach(tweaks(in: category)) { tweak in
                                    VStack(alignment: .leading, spacing: 2) {
                                        if tweak.isSupportedOnThisDevice {
                                            Toggle(isOn: binding(for: tweak.id)) {
                                                tweakLabel(tweak)
                                            }
                                        } else {
                                            Toggle(isOn: .constant(false)) {
                                                tweakLabel(tweak)
                                            }
                                            .disabled(true)
                                            Text(L10n.shared.tr("gestalt.deviceUnsupported"))
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }

                    }
                    .workPlotScrollBackground()
                }
            }
            .navigationTitle(L10n.shared.tr("tab.gestalt"))
            .heavyRestartFlow(isPresented: $showRestartAlert)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(stagedChangeCount == 0
                           ? L10n.shared.tr("common.apply")
                           : "\(L10n.shared.tr("common.apply")) (\(stagedChangeCount))") {
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

    private func tweakLabel(_ tweak: GestaltTweakDefinition) -> some View {
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
                if tweak.isExperimental {
                    Text(L10n.shared.tr("common.experimental")).font(.caption2).bold()
                        .foregroundColor(.orange)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Color.orange.opacity(0.15))
                        .cornerRadius(4)
                }
            }
            Text(tweak.detail).font(.caption).foregroundColor(.secondary)
        }
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
            manager.statusText = L10n.shared.tr("common.readFail")
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
            if selectedTweaks.contains(.rdarCanvasGestalt) {
                // Canvas size comes from this device's native bounds.
                RDARFix.applyCanvasSizesGestalt(to: &plist)
            }
            if let subtype = dynamicIslandSubtype {
                try GestaltArtwork.setDynamicIslandSubtype(subtype, in: &plist)
            }
            if changesModelName {
                let name = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else {
                    throw PlistValueError.invalid(L10n.shared.tr("gestalt.error.emptyName"))
                }
                try GestaltArtwork.setModelName(name, in: &plist)
            }
            if selectedTweaks.contains(.iPadOS) {
                try GestaltCacheDataPatch.applyiPadOSMode(to: &plist)
            }
            // Dual-cache tweaks share one idempotent capability-flag flip
            // inside CacheData; applying it here keeps every selected toggle
            // in the SAME read-modify-write transaction as the CacheExtra
            // mutations above.
            if selectedTweaks.contains(where: {
                GestaltTweakCatalog.definition(for: $0)?.requiresCacheDataFlag == true
            }) {
                try CacheDataPatcher.applyCapabilityFlag(to: &plist)
            }
        } catch {
            manager.statusText = String(format: L10n.shared.tr("common.failPrefix"), error.localizedDescription)
            return
        }

        isApplying = true
        defer { isApplying = false }
        do {
            try manager.saveGestaltOrThrow(plist)
            selectedTweaks.removeAll()
            dynamicIslandSubtype = nil
            changesModelName = false
            modelName = ""
            manager.statusText = "\(L10n.shared.tr("gestalt.status.applied")) \(L10n.shared.tr("restart.rec.title"))"
            showRestartAlert = true
        } catch {
            manager.statusText = String(
                format: L10n.shared.tr("common.failPrefix"),
                error.localizedDescription
            )
        }
    }
}
