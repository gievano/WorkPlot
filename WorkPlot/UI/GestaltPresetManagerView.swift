import SwiftUI

struct GestaltPresetManagerView: View {
    @ObservedObject private var manager = ExploitManager.shared
    @State private var selectedTweaks: Set<GestaltTweakID> = []
    @State private var dynamicIslandSubtype: Int?
    @State private var changesModelName = false
    @State private var modelName = ""
    @State private var isApplying = false
    @State private var showRestartAlert = false
    @State private var showRestoreConfirm = false

    private var stagedChangeCount: Int {
        selectedTweaks.count
            + (dynamicIslandSubtype == nil ? 0 : 1)
            + ((changesModelName && !modelName.trimmingCharacters(in: .whitespaces).isEmpty) ? 1 : 0)
    }

    var body: some View {
        NavigationView {
            Group {
                if !manager.sandboxGranted {
                    lockedView
                } else {
                    content
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
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
            .onAppear { manager.refreshBackups() }
        }
    }

    private var lockedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.icloud").font(.largeTitle).foregroundColor(.orange)
            Text(L10n.shared.tr("common.accessLocked"))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                restoreCard
                identityGroup
                ForEach(GestaltTweakCategory.allCases) { category in
                    categorySection(category)
                }
                Spacer(minLength: 40)
            }
            .padding(18)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: "wand.and.stars.inverse")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.55)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("WorkPlot").font(.title.bold())
                    Text(L10n.shared.tr("tab.gestalt")).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }
            HStack(spacing: 8) {
                Image(systemName: hasStockBackup ? "checkmark.shield.fill" : "shield")
                    .foregroundStyle(hasStockBackup ? Color(.systemGreen) : .orange)
                Text(hasStockBackup ? L10n.shared.tr("backup.hasBackup") : L10n.shared.tr("backup.noneYet"))
                    .font(.caption.weight(.medium))
                Spacer()
            }
        }
        .padding(18)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var hasStockBackup: Bool {
        manager.backups.contains { $0.name == "Stock Snapshot" }
    }

    private var restoreCard: some View {
        Button { showRestoreConfirm = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.shared.tr("backup.revertStock"))
                        .font(.body.weight(.semibold))
                    Text(L10n.shared.tr("gestalt.restoreHint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!manager.sandboxGranted || !hasStockBackup)
        .confirmationDialog(L10n.shared.tr("backup.restoreConfirmTitle"), isPresented: $showRestoreConfirm) {
            Button(L10n.shared.tr("pb.apply"), role: .destructive) { restoreStock() }
            Button(L10n.shared.tr("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.shared.tr("backup.restoreMsg"))
        }
    }

    private func restoreStock() {
        manager.refreshBackups()
        guard let target = manager.backups.first(where: { $0.name == "Stock Snapshot" })
              ?? manager.backups.last else {
            manager.statusText = L10n.shared.tr("common.noBackup")
            return
        }
        if manager.restore(target) {
            manager.statusText = L10n.shared.tr("backup.restoreOk")
            manager.requestRespring()
        } else {
            manager.statusText = String(format: L10n.shared.tr("common.failPrefix"), "")
        }
    }

    private var identityGroup: some View {
        VStack(alignment: .leading, spacing: 12) {
            WPCategoryHeader(L10n.shared.tr("gestalt.identityHeader"))
            VStack(spacing: 12) {
                Picker(L10n.shared.tr("fields.typeHeader"), selection: $dynamicIslandSubtype) {
                    Text(L10n.shared.tr("common.default")).tag(Int?.none)
                    ForEach(DynamicIslandOption.all) { option in
                        Text("\(option.title) (\(option.subtype))").tag(Int?.some(option.subtype))
                    }
                }
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                if !DeviceCapability.supports(.iphone14ProOrLater) {
                    Text(L10n.shared.tr("gestalt.island.warn"))
                        .font(.caption2).foregroundColor(.orange)
                        .padding(.horizontal, 4)
                }

                Toggle(L10n.shared.tr("gestalt.changeModelName"), isOn: $changesModelName)
                    .padding(14)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                if changesModelName {
                    TextField(L10n.shared.tr("gestalt.modelNamePlaceholder"), text: $modelName)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }

    private func categorySection(_ category: GestaltTweakCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            WPCategoryHeader(category.label)
            VStack(spacing: 12) {
                ForEach(tweaks(in: category)) { tweak in
                    tweakCard(tweak)
                }
            }
        }
    }

    private func tweakCard(_ tweak: GestaltTweakDefinition) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(tweak.title).font(.body.weight(.semibold))
                    if tweak.isRisky {
                        Text(L10n.shared.tr("common.risky")).font(.caption2).bold()
                            .foregroundColor(.red)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Color.red.opacity(0.15))
                            .cornerRadius(4)
                    }
                    if tweak.isExperimental {
                        Text(L10n.shared.tr("common.experimental")).font(.caption2).bold()
                            .foregroundColor(.orange)
                            .padding(.horizontal, 5).padding(.vertical, 1).padding(.horizontal, 5)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(4)
                    }
                }
                Text(tweak.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if tweak.isSupportedOnThisDevice {
                Toggle("", isOn: binding(for: tweak.id)).labelsHidden()
            } else {
                Toggle("", isOn: .constant(false)).labelsHidden().disabled(true)
                Text(L10n.shared.tr("gestalt.deviceUnsupported"))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func tweaks(in category: GestaltTweakCategory) -> [GestaltTweakDefinition] {
        GestaltTweakCatalog.definitions.filter { $0.category == category }
    }

    private struct WPCategoryHeader: View {
        let title: String
        var body: some View {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.8)
                .padding(.horizontal, 4)
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
            if selectedTweaks.contains(.internalFeatures) {
                // CacheData patches are best-effort: an unresolved offset on
                // this firmware must not abort the whole apply, only warn.
                for key in ["EqrsVvjcYDdxHBiQmGhAWw", "Oji6HRoPi7rH7HPdWVakuw", "LBJfwOEzExRxzlAnSuI7eg"] {
                    do {
                        guard var cacheData = plist["CacheData"] as? Data else { continue }
                        try setCacheData(1, forKey: key, in: &cacheData)
                        plist["CacheData"] = cacheData
                    } catch {
                        springBoardLines.append("Internal Features (\(key)): \(error.localizedDescription)")
                    }
                }
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
