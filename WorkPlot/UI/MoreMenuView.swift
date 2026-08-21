import SwiftUI

struct MoreMenuView: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var showIconSwitcher = false

    var body: some View {
        NavigationStack {
            List {
                NavigationLink { LiquidGlassView() } label: {
                    Label(l10n.tr("tab.liquidglass"), systemImage: "drop.fill")
                }
                NavigationLink { PosterBoardLabView() } label: {
                    Label(l10n.tr("tab.posterboard"), systemImage: "photo.stack.fill")
                }
                NavigationLink { BackupRestoreManagerView() } label: {
                    Label(l10n.tr("tab.backups"), systemImage: "arrow.counterclockwise.circle.fill")
                }
                NavigationLink { PresetLabView() } label: {
                    Label(l10n.tr("preset.title"), systemImage: "wand.and.stars")
                }
                NavigationLink { FilePatchWorkspaceView() } label: {
                    Label(l10n.tr("tab.files"), systemImage: "folder.fill")
                }

                Section {
                    Button {
                        showIconSwitcher = true
                    } label: {
                        Label(l10n.tr("icon.menu"), systemImage: "paintbrush")
                    }

                    NavigationLink { CreditsView() } label: {
                        Label(l10n.tr("credits.header"), systemImage: "heart.circle.fill")
                    }
                }
            }
            .navigationTitle(l10n.tr("tab.more"))
        }
        .sheet(isPresented: $showIconSwitcher) {
            AppIconSwitcherSheet()
        }
    }
}
