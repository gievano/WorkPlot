import SwiftUI

struct MainDashboardView: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue
    @State private var showCompatWarning = false
    @State private var detectedBuild = ""

    var body: some View {
        TabView {
            StatusDashboardView()
                .tabItem { Label("Home", systemImage: "house.fill") }
            WallpaperView()
                .tabItem { Label("PosterBoard", systemImage: "square.stack.3d.up") }
            GestaltPresetManagerView()
                .tabItem { Label("Gestalt", systemImage: "cpu") }
            SiriAITweaksView()
                .tabItem { Label("Siri AI", systemImage: "waveform") }
            SettingsTabView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Theme.accent)
        .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.colorScheme)
        .onAppear(perform: checkCompatibility)
        .alert(l10n.tr("compat.title"), isPresented: $showCompatWarning) {
            Button(l10n.tr("common.done"), role: .cancel) {}
        } message: {
            Text(String(format: l10n.tr("compat.message"), detectedBuild))
        }
    }

    private func checkCompatibility() {
        let build = GestaltAccess.currentOSBuild()
        let supported = GestaltAccess.isRunningSupportedOS()
        guard !build.isEmpty, !supported else { return }
        detectedBuild = build
        showCompatWarning = true
    }
}
