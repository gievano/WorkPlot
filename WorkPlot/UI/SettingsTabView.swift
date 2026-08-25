import SwiftUI

struct SettingsTabView: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var showUpdate = false
    @State private var showIcon = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Features")) {
                    NavigationLink(destination: LiquidGlassView()) {
                        Label(l10n.tr("tab.liquidglass"), systemImage: "drop.fill")
                    }
                    NavigationLink(destination: BackupRestoreManagerView()) {
                        Label(l10n.tr("tab.backups"), systemImage: "arrow.counterclockwise.circle.fill")
                    }
                    NavigationLink(destination: PresetLabView()) {
                        Label(l10n.tr("preset.title"), systemImage: "wand.and.stars")
                    }
                    NavigationLink(destination: FilePatchWorkspaceView()) {
                        Label(l10n.tr("tab.files"), systemImage: "folder.fill")
                    }
                }
                Section(header: Text("Tools")) {
                    NavigationLink(destination: AppContainersView()) {
                        Label(l10n.tr("ac.title"), systemImage: "shippingbox")
                    }
                    NavigationLink(destination: SessionLogView()) {
                        Label(l10n.tr("sessionlog.title"), systemImage: "scroll.text.fill")
                    }
                    NavigationLink(destination: GestaltFieldEditorView()) {
                        Label(l10n.tr("tab.fields"), systemImage: "list.bullet.rectangle")
                    }
                    Button { showUpdate = true } label: {
                        Label(l10n.tr("upd.check"), systemImage: "arrow.triangle.down.circle")
                    }
                    Button { showIcon = true } label: {
                        Label(l10n.tr("icon.menu"), systemImage: "paintbrush")
                    }
                }
                Section(header: Text("Appearance")) {
                    NavigationLink(destination: AppearanceView()) {
                        Label("Appearance", systemImage: "paintpalette")
                    }
                }
                Section(header: Text(l10n.tr("credits.header"))) {
                    NavigationLink(destination: CreditsView()) {
                        Label(l10n.tr("credits.header"), systemImage: "heart.circle.fill")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .wpGlassContainer()
            .sheet(isPresented: $showUpdate) { UpdateCheckerSheet() }
            .sheet(isPresented: $showIcon) { AppIconSwitcherSheet() }
        }
    }
}
