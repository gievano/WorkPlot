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
                }
                Section("Logs & About") {
                    NavigationLink("Session Log", destination: SessionLogView())
                    NavigationLink("Credits", destination: CreditsView())
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
