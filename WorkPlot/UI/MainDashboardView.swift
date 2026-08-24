import SwiftUI

struct MainDashboardView: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue
    @State private var showCompatWarning = false
    @State private var detectedBuild = ""

    var body: some View {
        ZStack {
            AppBackground()
            TabView {
                StatusDashboardView().tabItem { Label(l10n.tr("tab.home"), systemImage: "house.fill") }
                GestaltPresetManagerView().tabItem { Label(l10n.tr("tab.gestalt"), systemImage: "cpu") }
                GestaltFieldEditorView().tabItem { Label(l10n.tr("tab.fields"), systemImage: "list.bullet.rectangle") }
                SiriAITweaksView().tabItem { Label(l10n.tr("tab.siriai"), systemImage: "waveform") }
                MoreMenuView().tabItem { Label(l10n.tr("tab.more"), systemImage: "ellipsis.circle.fill") }
            }
        }
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
        guard !build.isEmpty, !GestaltAccess.isRunningSupportedOS() else { return }
        detectedBuild = build
        showCompatWarning = true
    }
}
