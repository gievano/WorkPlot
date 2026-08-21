import SwiftUI

@main
struct WorkPlotApp: App {
    @ObservedObject private var manager = ExploitManager.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var presetImportMessage: String?

    var body: some Scene {
        WindowGroup {
            MainDashboardView()
                .overlay {
                    if manager.respringRequested {
                        RespringOverlayView()
                            .brightness(-1.0)
                            .ignoresSafeArea()
                    }
                }
                .onAppear(perform: autoCheckAccess)
                .onOpenURL(perform: handlePresetURL)
                .alert(
                    "WorkPlot",
                    isPresented: Binding(
                        get: { presetImportMessage != nil },
                        set: { if !$0 { presetImportMessage = nil } }
                    )
                ) {
                    Button(l10n.tr("common.done"), role: .cancel) {}
                } message: {
                    Text(presetImportMessage ?? "")
                }
        }
    }

    /// Runs the sandbox access probe once at launch so users do not have to
    /// tap "Periksa Akses Sistem" manually.
    private func autoCheckAccess() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard !manager.sandboxGranted else { return }
            _ = manager.checkSystemPathAccess()
        }
    }

    /// workplot://preset?data=<base64url(JSON preset)> imports a shared preset.
    private func handlePresetURL(_ url: URL) {
        guard url.scheme?.lowercased() == "workplot",
              url.host?.lowercased() == "preset",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let payload = items.first(where: { $0.name == "data" })?.value else {
            presetImportMessage = l10n.tr("preset.importFail")
            return
        }

        do {
            let preset = try PresetStore.shared.importURLPayload(payload)
            presetImportMessage = String(format: l10n.tr("preset.importOk"), preset.name)
        } catch {
            presetImportMessage = l10n.tr("preset.importFail")
        }
    }
}
