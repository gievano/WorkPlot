import SwiftUI

struct MainDashboardView: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue

    var body: some View {
        ZStack {
            AppBackground()
            TabView {
                StatusDashboardView().tabItem { Label(l10n.tr("tab.status"), systemImage: "shield.checkered") }
                GestaltPresetManagerView().tabItem { Label(l10n.tr("tab.gestalt"), systemImage: "cpu") }
                GestaltFieldEditorView().tabItem { Label(l10n.tr("tab.fields"), systemImage: "list.bullet.rectangle") }
                SiriAITweaksView().tabItem { Label(l10n.tr("tab.siriai"), systemImage: "waveform") }
                LiquidGlassView().tabItem { Label(l10n.tr("tab.liquidglass"), systemImage: "drop.fill") }
                PosterBoardLabView().tabItem { Label(l10n.tr("tab.posterboard"), systemImage: "photo.stack.fill") }
                BackupRestoreManagerView().tabItem { Label(l10n.tr("tab.backups"), systemImage: "arrow.counterclockwise.circle.fill") }
                FilePatchWorkspaceView().tabItem { Label("Files", systemImage: "folder.fill") }
            }
        }
        .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.colorScheme)
    }
}
