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
                            if !DeviceCapability.supports(.iphone14ProOrLater) {
                                Text(L10n.shared.tr("gestalt.island.warn"))
                                    .font(.caption2)
                                    .foregroundColor(.orange)
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
                    .scrollDismissesKeyboard(.immediately)
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
                    // Island enable vs the off-switches are opposites;
                    // the hide/show pair excludes itself.
                    if id == .supportsDynamicIsland {
                        selectedTweaks.remove(.hideDynamicIslandOn)
                    }
                    if id == .hideDynamicIslandOn {
                        selectedTweaks.remove(.supportsDynamicIsland)
                        selectedTweaks.remove(.hideDynamicIslandOff)
                    }
                    if id == .hideDynamicIslandOff {
                        selectedTweaks.remove(.hideDynamicIslandOn)
                    }
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

        // Declared at function scope: the save section below appends the
        // SpringBoard route results to the success status.
        var springBoardLines: [String] = []
        do {
            if selectedTweaks.contains(.aiRegionUS) {
                try AIRegionApplier.apply(to: &plist)
            }
            if selectedTweaks.contains(.rdarCanvasGestalt) {
                // Canvas size comes from this device's native bounds.
                RDARFix.applyCanvasSizesGestalt(to: &plist, machine: DeviceCapability.machineIdentifier)
            }
            if let subtype = dynamicIslandSubtype {
                try GestaltArtwork.setDynamicIslandSubtype(subtype, in: &plist)
            }
            if selectedTweaks.contains(.hideDynamicIslandOn) {
                // Non-fatal on purpose: the Gestalt capability=0 stage is an
                // independent hide route, so a failed/unreachable flag write
                // must not abort the whole apply (it used to - EPERM killed
                // BOTH routes and the island fix never landed).
                do {
                    springBoardLines += try SpringBoardPlist.setSuppressed(true)
                } catch {
                    springBoardLines.append("SpringBoard: failed (\(error.localizedDescription))")
                }
            }
            if selectedTweaks.contains(.hideDynamicIslandOff) {
                // Stock state = capability key ABSENT; hideDynamicIslandOn
                // stages it at 0, so restore must clear it too or the island
                // stays suppressed on builds that honor the legacy route.
                var cacheExtra = plist["CacheExtra"] as? [String: Any] ?? [:]
                cacheExtra.removeValue(forKey: "YlEtTtHlNesRBMal1CqRaA")
                plist["CacheExtra"] = cacheExtra
                do {
                    springBoardLines += try SpringBoardPlist.setSuppressed(false)
                } catch {
                    springBoardLines.append("SpringBoard: failed (\(error.localizedDescription))")
                }
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
            if !springBoardLines.isEmpty {
                manager.statusText += "\n" + springBoardLines.joined(separator: "\n")
            }
            showRestartAlert = true
        } catch {
            manager.statusText = String(
                format: L10n.shared.tr("common.failPrefix"),
                error.localizedDescription
            )
        }
    }
}
