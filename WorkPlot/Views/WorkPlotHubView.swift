import SwiftUI

struct WorkPlotHubView: View {
    @State private var showUpdater = false

    var body: some View {
        NavigationStack {
            List {
                Section("Tweak & Tools") {
                    NavigationLink("RDARFix (Canvas)", destination: RDARFixView())
                    NavigationLink("FilePatch 3105", destination: FilePatchWorkspaceView())
                    NavigationLink("App Containers", destination: AppContainersView())
                    NavigationLink("CarPlay Wallpaper", destination: CarPlayWallpaperView())
                    NavigationLink("Gestalt Field Editor", destination: GestaltFieldEditorView())
                    NavigationLink("Preset Lab", destination: PresetLabView())
                    NavigationLink("Gestalt Presets", destination: GestaltPresetManagerView())
                }
                Section("Logs & About") {
                    NavigationLink("Session Log", destination: SessionLogView())
                    NavigationLink("Credits", destination: CreditsView())
                }
                Section {
                    Button("Ganti App Icon") { showIconSwitcher = true }
                    Button("Check for Updates") { showUpdater = true }
                }
                Section {
                    Button("Check for Updates") { showUpdater = true }
                }
            }
            .navigationTitle("WorkPlot")
            .sheet(isPresented: $showUpdater) {
                UpdateCheckerSheet()
            }
        }
    }
}
