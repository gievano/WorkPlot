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
                stagedCard
                hero
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
        .liquidGlass(cornerRadius: 22)
    }

    private var hasStockBackup: Bool {
        manager.backups.contains { $0.name == "Stock Snapshot" }
    }

    private var stagedCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(
                        LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.6)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(stagedChangeCount == 0
                         ? "No changes staged"
                         : "\(stagedChangeCount) changes staged")
                        .font(.headline.bold())
                    Text("Review staged changes before writing to the mobile gestalt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if stagedChangeCount > 0 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(selectedTweaks), id: \.self) { id in
                            if let def = GestaltTweakCatalog.definition(for: id) {
                                Image(systemName: def.icon)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(Theme.accent))
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(selectedTweaks), id: \.self) { id in
                        if let def = GestaltTweakCatalog.definition(for: id) {
                            Button { toggle(id) } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: def.icon).foregroundStyle(Theme.accent)
                                    Text(def.title).font(.subheadline)
                                    Spacer()
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if dynamicIslandSubtype != nil {
                        stagedRow(icon: "rectangle.topthird.inset.filled",
                                  text: "Dynamic Island subtype")
                    }
                    if changesModelName && !modelName.trimmingCharacters(in: .whitespaces).isEmpty {
                        stagedRow(icon: "wrench",
                                  text: "Model name: \(modelName)")
                    }
                }

                WPActionButton(
                    title: "Apply (\(stagedChangeCount)) changes",
                    isBusy: isApplying
                ) { applySelected() }
                .disabled(stagedChangeCount == 0)

                HStack(spacing: 10) {
                    WPActionButton(title: "Backup", prominent: false) { createBackup() }
                    WPActionButton(title: "Restore Pristine", prominent: false) {
                        if hasStockBackup { showRestoreConfirm = true }
                    }
                    .disabled(!hasStockBackup)
                }
            }
        }
        .padding(18)
        .liquidGlass(cornerRadius: 22)
        .confirmationDialog("Restore Pristine", isPresented: $showRestoreConfirm) {
            Button("Restore", role: .destructive) { restoreStock() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This reverts all gestalt changes to the Stock Snapshot. The device will respring.")
        }
    }

    private func stagedRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Theme.accent)
            Text(text).font(.subheadline)
            Spacer()
        }
    }

    private func createBackup() {
        guard let data = manager.readGestaltData() else {
            manager.statusText = "Could not read gestalt to back up."
            return
        }
        do {
            let backup = try GestaltBackupStore.create(from: data)
            manager.refreshBackups()
            manager.statusText = "Backup \"\(backup.name)\" saved."
        } catch {
            manager.statusText = "Backup failed: \(error.localizedDescription)"
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
            WPSectionHeader(title: L10n.shared.tr("gestalt.identityHeader"))
            VStack(spacing: 12) {
                Picker(L10n.shared.tr("fields.typeHeader"), selection: $dynamicIslandSubtype) {
                    Text(L10n.shared.tr("common.default")).tag(Int?.none)
                    ForEach(DynamicIslandOption.all) { option in
                        Text("\(option.title) (\(option.subtype))").tag(Int?.some(option.subtype))
                    }
                }
                .padding(14)
                .liquidGlass(cornerRadius: 16)

                if !DeviceCapability.supports(.iphone14ProOrLater) {
                    Text(L10n.shared.tr("gestalt.island.warn"))
                        .font(.caption2).foregroundColor(.orange)
                        .padding(.horizontal, 4)
                }

                Toggle(L10n.shared.tr("gestalt.changeModelName"), isOn: $changesModelName)
                    .padding(14)
                    .liquidGlass(cornerRadius: 16)
                if changesModelName {
                    TextField(L10n.shared.tr("gestalt.modelNamePlaceholder"), text: $modelName)
                        .autocorrectionDisabled()
                        .padding(14)
                        .liquidGlass(cornerRadius: 16)
                }
            }
        }
    }

    private func categorySection(_ category: GestaltTweakCategory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            WPSectionHeader(title: category.label)
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                ForEach(tweaks(in: category)) { tweak in
                    tweakBox(tweak)
                }
            }
        }
    }

    private func tweakBox(_ tweak: GestaltTweakDefinition) -> some View {
        let isOn = selectedTweaks.contains(tweak.id)
        let supported = tweak.isSupportedOnThisDevice
        return Button {
            toggle(tweak.id)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Image(systemName: tweak.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(supported ? Theme.accent : .secondary)
                    Spacer()
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isOn ? Theme.accent : .secondary)
                }
                Text(tweak.title)
                    .font(.system(size: 13, weight: .semibold))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                if !tweak.detail.isEmpty {
                    Text(tweak.detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                if tweak.isRisky || tweak.isExperimental {
                    HStack(spacing: 6) {
                        if tweak.isRisky {
                            HStack(spacing: 3) {
                                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10))
                                Text("Risky").font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(.red)
                        }
                        if tweak.isExperimental {
                            HStack(spacing: 3) {
                                Image(systemName: "flask.fill").font(.system(size: 10))
                                Text("Experimental").font(.system(size: 10, weight: .bold))
                            }
                            .foregroundStyle(.orange)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
            .liquidGlass(cornerRadius: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isOn ? Theme.accent : .clear, lineWidth: 2)
            )
            .opacity(supported ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!supported)
    }

    private func tweaks(in category: GestaltTweakCategory) -> [GestaltTweakDefinition] {
        GestaltTweakCatalog.definitions.filter { $0.category == category }
    }

    private func toggle(_ id: GestaltTweakID) {
        if selectedTweaks.contains(id) {
            selectedTweaks.remove(id)
        } else {
            if id == .enableLiquidGlassLowPerformance { selectedTweaks.remove(.disableLiquidGlassLowPerformance) }
            if id == .disableLiquidGlassLowPerformance { selectedTweaks.remove(.enableLiquidGlassLowPerformance) }
            if id == .supportsDynamicIsland { selectedTweaks.remove(.hideDynamicIslandOn) }
            if id == .hideDynamicIslandOn {
                selectedTweaks.remove(.supportsDynamicIsland)
                selectedTweaks.remove(.hideDynamicIslandOff)
            }
            if id == .hideDynamicIslandOff { selectedTweaks.remove(.hideDynamicIslandOn) }
            selectedTweaks.insert(id)
        }
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
