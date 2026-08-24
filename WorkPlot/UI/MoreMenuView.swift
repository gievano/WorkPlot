import SwiftUI

struct MoreMenuView: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var showIconSwitcher = false
    @State private var showUpdateChecker = false

    var body: some View {
        NavigationStack {
            List {
                NavigationLink { LiquidGlassView() } label: {
                    Label(l10n.tr("tab.liquidglass"), systemImage: "drop.fill")
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
                NavigationLink { WallpaperView() } label: {
                    Label("Wallpaper", systemImage: "photo")
                }

                Section {
                    NavigationLink { AppContainersView() } label: {
                        Label(l10n.tr("ac.title"), systemImage: "shippingbox")
                    }
                    NavigationLink { SessionLogView() } label: {
                        Label(l10n.tr("sessionlog.title"), systemImage: "scroll.text.fill")
                    }
                    Button {
                        showUpdateChecker = true
                    } label: {
                        Label(l10n.tr("upd.check"), systemImage: "arrow.triangle.down.circle")
                    }
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
            .wpGlassContainer()
        }
        .sheet(isPresented: $showIconSwitcher) {
            AppIconSwitcherSheet()
        }
        .sheet(isPresented: $showUpdateChecker) {
            UpdateCheckerSheet()
        }
    }
}
