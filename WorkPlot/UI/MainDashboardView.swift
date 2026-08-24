import SwiftUI

enum DashboardTab: String, CaseIterable {
    case home, poster, siri, gestalt, fields
    case liquid, backups, preset, files, containers, logs
    case update, icon, appearance, credits

    var title: String {
        switch self {
        case .home: return "Home"
        case .poster: return "PosterBoard"
        case .siri: return "Siri AI"
        case .gestalt: return "Gestalt"
        case .fields: return "Fields"
        case .liquid: return "Liquid"
        case .backups: return "Backups"
        case .preset: return "Preset Lab"
        case .files: return "Files"
        case .containers: return "Containers"
        case .logs: return "Logs"
        case .update: return "Update"
        case .icon: return "Icon"
        case .appearance: return "Appearance"
        case .credits: return "Credits"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .poster: return "square.stack.3d.up"
        case .siri: return "brain.head.profile"
        case .gestalt: return "cpu"
        case .fields: return "list.bullet.rectangle"
        case .liquid: return "drop.fill"
        case .backups: return "arrow.counterclockwise.circle.fill"
        case .preset: return "wand.and.stars"
        case .files: return "folder.fill"
        case .containers: return "shippingbox"
        case .logs: return "scroll.text.fill"
        case .update: return "arrow.triangle.down.circle"
        case .icon: return "paintbrush"
        case .appearance: return "paintpalette"
        case .credits: return "heart.circle.fill"
        }
    }

    @ViewBuilder var content: some View {
        switch self {
        case .home: StatusDashboardView()
        case .poster: WallpaperView()
        case .siri: SiriAITweaksView()
        case .gestalt: GestaltPresetManagerView()
        case .fields: GestaltFieldEditorView()
        case .liquid: LiquidGlassView()
        case .backups: BackupRestoreManagerView()
        case .preset: PresetLabView()
        case .files: FilePatchWorkspaceView()
        case .containers: AppContainersView()
        case .logs: SessionLogView()
        case .update: UpdateCheckerSheet(showDoneButton: false)
        case .icon: AppIconSwitcherSheet(showDoneButton: false)
        case .appearance: AppearanceView()
        case .credits: CreditsView()
        }
    }
}

struct MainDashboardView: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue
    @State private var selected: DashboardTab = .home
    @State private var showCompatWarning = false
    @State private var detectedBuild = ""

    var body: some View {
        VStack(spacing: 0) {
            selected.content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(DashboardTab.allCases, id: \.self) { tab in
                        tabPill(tab)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
        }
        .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.colorScheme)
        .onAppear(perform: checkCompatibility)
        .alert(l10n.tr("compat.title"), isPresented: $showCompatWarning) {
            Button(l10n.tr("common.done"), role: .cancel) {}
        } message: {
            Text(String(format: l10n.tr("compat.message"), detectedBuild))
        }
    }

    private func tabPill(_ tab: DashboardTab) -> some View {
        Button {
            selected = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18))
                Text(tab.title)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(selected == tab ? Theme.accent : .secondary)
            .frame(minWidth: 54)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(
                selected == tab
                    ? Theme.accent.opacity(0.15)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func checkCompatibility() {
        let build = GestaltAccess.currentOSBuild()
        let supported = GestaltAccess.isRunningSupportedOS()
        guard !build.isEmpty, !supported else { return }
        detectedBuild = build
        showCompatWarning = true
    }
}
