import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: GestaltStore
    /// `nil` selects "All" — every tweak, uncategorized.
    @State private var category: TweakCategory? = .display
    @State private var configurationID: String?
    @State private var searchText = ""

    private var consoleCategories: [TweakCategory] {
        TweakCategory.allCases.filter { cat in
            cat != .ai &&
            (store.tweaks.contains { $0.category == cat } || toolDefs.contains { $0.category == cat })
        }
    }

    private var selectedTweaks: [Tweak] {
        store.tweaks.filter(\.isEnabled)
    }

    var body: some View {
        NavigationStack {
            Group {
                if DeviceCompatibility.supportsFullFeatureSet {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            commandStatus
                            categoryRail
                            catalog
                            if !selectedTweaks.isEmpty { activeConfiguration }
                            respringButton
                        }
                        .padding(.horizontal, Theme.pagePadding)
                        .padding(.bottom, 32)
                    }
                    .scrollIndicators(.hidden)
                    .searchable(text: $searchText, prompt: "Search tweaks")
                } else {
                    FeatureUnsupportedView(feature: "Tweaks")
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Tweaks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if DeviceCompatibility.supportsFullFeatureSet {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink { ApplyChangesView() } label: {
                            Image(systemName: "bolt.horizontal.circle")
                        }
                        .disabled(store.enabledCount == 0)
                    }
                }
            }
        }
    }

    private var commandStatus: some View {
        HStack(alignment: .center, spacing: 16) {
            AppMark(name: "ConsoleGlyph", size: 52, tint: store.enabledCount == 0 ? .secondary : Theme.accent)
            VStack(alignment: .leading, spacing: 4) {
                Text(store.enabledCount == 0 ? "No changes staged" : "\(store.enabledCount) changes staged")
                    .font(.headline)
                Text(store.enabledCount == 0 ? "Tap a capability to turn it on." : "Tap any active capability again to turn it off.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
    }

    private var categoryRail: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 9) {
                categoryPill(title: "All", isSelected: category == nil) { category = nil }
                ForEach(consoleCategories) { item in
                    categoryPill(title: item.rawValue, isSelected: category == item) { category = item }
                }
            }
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -Theme.pagePadding)
        .padding(.horizontal, Theme.pagePadding)
    }

    private func categoryPill(title: String, isSelected: Bool, select: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) {
                select()
                configurationID = nil
            }
        } label: {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isSelected ? Theme.accent.opacity(0.14) : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var catalog: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(visibleCategories, id: \.self) { cat in
                categorySection(cat)
            }
        }
    }

    private var visibleCategories: [TweakCategory] {
        if let category { return [category] }
        return TweakCategory.allCases.filter { cat in
            cat != .ai && (
                store.tweaks.contains { $0.category == cat && $0.id != "product-type" && matchesSearch($0.title) } ||
                toolDefs.contains { $0.category == cat && $0.id != "respring" && matchesSearch($0.title) }
            )
        }
    }

    private func matchesSearch(_ title: String) -> Bool {
        searchText.isEmpty || title.localizedCaseInsensitiveContains(searchText)
    }

    private func categorySection(_ cat: TweakCategory) -> some View {
        let tweaks = store.tweaks.filter { $0.category == cat && $0.id != "product-type" && matchesSearch($0.title) }
        let tools = toolDefs.filter { $0.category == cat && $0.id != "respring" && matchesSearch($0.title) }
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(cat.rawValue)
            HStack {
                Text("\(tweaks.count + tools.count) available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            // Laid out row by row rather than as one LazyVGrid so the
            // configuration panel can sit directly under the row holding the
            // tile that opened it, instead of after the whole catalog.
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(tweakRows(tweaks).enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(row) { tweak in
                            Button { toggle(tweak) } label: {
                                TweakCatalogTile(tweak: tweak, isConfiguring: configurationID == tweak.id)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint(tweak.isEnabled ? "Disables this capability" : "Enables this capability")
                        }
                        // Keeps a lone trailing tile at half width.
                        if row.count == 1 { Color.clear.frame(maxWidth: .infinity) }
                    }
                    if let tweak = configuringTweak,
                       row.contains(where: { $0.id == tweak.id }),
                       let detail = tweak.detail {
                        InlineTweakConfiguration(tweak: tweak, detail: detail)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                ForEach(Array(toolRows(tools).enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(row) { tool in
                            toolCatalogTile(tool)
                        }
                        if row.count == 1 { Color.clear.frame(maxWidth: .infinity) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func toolCatalogTile(_ tool: ToolDef) -> some View {
        if let destination = tool.destination {
            NavigationLink(destination: destination()) {
                ToolTile(title: tool.title, detail: tool.subtitle, symbol: tool.symbol)
            }
            .buttonStyle(.plain)
        } else if let action = tool.action {
            Button(action: action) {
                ToolTile(title: tool.title, detail: tool.subtitle, symbol: tool.symbol)
            }
            .buttonStyle(.plain)
        }
    }

    private var toolDefs: [ToolDef] {
        [
            ToolDef(id: "rdarfix", title: "RDARFix", subtitle: "Edit resolusi layar lewat canvas exploit", symbol: "wand.and.stars", category: .display, destination: { AnyView(RDARFixView()) }),
            ToolDef(id: "carplay", title: "CarPlay Wallpaper", subtitle: "Ganti wallpaper layar CarPlay", symbol: "car", category: .display, destination: { AnyView(CarPlayWallpaperView()) }),
            ToolDef(id: "respring", title: "Respring", subtitle: "Restart SpringBoard tanpa reboot", symbol: "arrow.clockwise", category: .system, action: { RespringHelper.shared.trigger() }),
            ToolDef(id: "appcontainers", title: "App Containers", subtitle: "Kelola container & data aplikasi", symbol: "shippingbox", category: .system, destination: { AnyView(AppContainersView()) }),
            ToolDef(id: "filepatch", title: "FilePatch 3105", subtitle: "Sunting file sistem read/write", symbol: "doc.badge.gearshape", category: .system, destination: { AnyView(FilePatchWorkspaceView()) }),
            ToolDef(id: "devicespoof", title: "Device Spoof", subtitle: "Spoof identitas perangkat", symbol: "iphone.and.arrow.forward", category: .system, destination: { AnyView(DeviceSpoofingView()) }),
            ToolDef(id: "gestalteditor", title: "Gestalt Field Editor", subtitle: "Edit cache MobileGestalt", symbol: "slider.horizontal.3", category: .gestalt, destination: { AnyView(GestaltFieldEditorView()) }),
            ToolDef(id: "presetlab", title: "Preset Lab", subtitle: "Racik & simpan preset Gestalt", symbol: "flask", category: .gestalt, destination: { AnyView(PresetLabView()) }),
            ToolDef(id: "sessionlog", title: "Session Log", subtitle: "Lihat log debug sesi exploit", symbol: "doc.plaintext", category: .info, destination: { AnyView(SessionLogView()) }),
            ToolDef(id: "updates", title: "Check for Updates", subtitle: "Cek & pasang pembaruan", symbol: "arrow.down.app", category: .info, destination: { AnyView(UpdateCheckerSheet(showDoneButton: true)) }),
        ]
    }

    private struct ToolDef: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let symbol: String
        let category: TweakCategory
        var destination: (() -> AnyView)? = nil
        var action: (() -> Void)? = nil
    }

    private var respringButton: some View {
        Button { RespringHelper.shared.trigger() } label: {
            Label("Respring", systemImage: "arrow.clockwise")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .liquidGlass(cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Restart SpringBoard")
    }

    /// Split a list into rows of two, matching the old grid.
    private func tweakRows(_ tweaks: [Tweak]) -> [[Tweak]] {
        stride(from: 0, to: tweaks.count, by: 2).map { start in
            Array(tweaks[start..<min(start + 2, tweaks.count)])
        }
    }

    private func toolRows(_ tools: [ToolDef]) -> [[ToolDef]] {
        stride(from: 0, to: tools.count, by: 2).map { start in
            Array(tools[start..<min(start + 2, tools.count)])
        }
    }

    private var configuringTweak: Tweak? {
        guard let configurationID,
              let tweak = store.tweaks.first(where: { $0.id == configurationID }),
              tweak.isEnabled else { return nil }
        return tweak
    }

    private var activeConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Staged configuration", detail: "\(selectedTweaks.count)")
            VStack(spacing: 0) {
                ForEach(Array(selectedTweaks.prefix(4).enumerated()), id: \.element.id) { index, tweak in
                    HStack(spacing: 12) {
                        Image(systemName: tweak.symbol)
                            .foregroundStyle(Theme.accent)
                            .frame(width: 24)
                        Text(tweak.title)
                        Spacer()
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.accent)
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(.vertical, 13)
                    if index < min(selectedTweaks.count, 4) - 1 { Divider().padding(.leading, 36) }
                }
                if selectedTweaks.count > 4 {
                    Text("+ \(selectedTweaks.count - 4) more changes")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 14)
                }
            }
            .padding(.horizontal, 18)
            .liquidGlass()
        }
    }

    struct ToolTile: View {
        let title: String
        let detail: String
        let symbol: String

        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: symbol)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.accent)
                Spacer(minLength: 8)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 142, maxHeight: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.clear, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .liquidGlass(cornerRadius: 22)
        }
    }

    private func toggle(_ tweak: Tweak) {
        let willEnable = !tweak.isEnabled
        withAnimation(.snappy) {
            store.setEnabled(willEnable, for: tweak.id)
            configurationID = willEnable && tweak.detail != nil ? tweak.id : nil
        }
    }
}

struct TweakCatalogTile: View {
    let tweak: Tweak
    let isConfiguring: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: tweak.symbol)
                    .font(.body.weight(.medium))
                    .foregroundStyle(tweak.isEnabled ? Theme.accent : .secondary)
                Spacer()
                Image(systemName: tweak.isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .foregroundStyle(tweak.isEnabled ? Theme.accent : Color(uiColor: .tertiaryLabel))
            }
            Spacer(minLength: 8)
            Text(tweak.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(tweak.isEnabled ? (isConfiguring ? "Configuring" : "Enabled") : tweak.subtitle)
                .font(.caption)
                .foregroundStyle(tweak.isEnabled ? Theme.accent : .secondary)
                .lineLimit(2)
        }
        // maxHeight lets paired tiles match the tallest in their row, the way
        // the grid used to. Applied before the padding so the glass background
        // expands with it.
        .frame(maxWidth: .infinity, minHeight: 142, maxHeight: .infinity, alignment: .leading)
        .padding(16)
        .background(tweak.isEnabled ? Theme.accent.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .liquidGlass(cornerRadius: 22)
    }
}

struct InlineTweakConfiguration: View {
    @EnvironmentObject private var store: GestaltStore
    let tweak: Tweak
    let detail: TweakDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Configure \(tweak.title)")
            switch detail {
            case .picker(let options):
                Picker("Option", selection: store.pickerBinding(for: tweak.id)) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        Text(option).tag(index)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 138)
                .liquidGlass()
            case .textField(let placeholder, let keyboard):
                TextField(placeholder, text: store.textBinding(for: tweak.id))
                    .keyboardType(keyboard == .numeric ? .numberPad : .default)
                    .textFieldStyle(.roundedBorder)
                    .padding(18)
                    .liquidGlass()
            }
            if let note = tweak.notes {
                Label(note, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ApplyChangesView: View {
    @EnvironmentObject private var store: GestaltStore
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showRestore = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Command").font(.largeTitle.weight(.semibold))
                Text("Review staged changes before writing to the MobileGestalt cache.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(Array(store.tweaks.filter(\.isEnabled).enumerated()), id: \.element.id) { index, tweak in
                        Label(tweak.title, systemImage: tweak.symbol)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                        if index < store.enabledCount - 1 { Divider() }
                    }
                }
                .padding(.horizontal, 18)
                .liquidGlass()
                ActionButton(title: "Apply \(store.enabledCount) changes", systemImage: "bolt.fill", isBusy: store.isBusy, action: apply)
                Button("Restore pristine backup", role: .destructive) { showRestore = true }
                    .frame(maxWidth: .infinity)
                    .glassAction()
                    .disabled(!store.backup.hasBackup)
            }
            .padding(Theme.pagePadding)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .sheet(isPresented: $showRestore) { RestoreSheet() }
        .alert("Could not apply changes", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func apply() {
        Task {
            do {
                _ = try await store.apply()
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                RespringHelper.shared.trigger()
            } catch {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
}
