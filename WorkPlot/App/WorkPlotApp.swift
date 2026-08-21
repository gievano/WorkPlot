import SwiftUI

@main
struct WorkPlotApp: App {
    @ObservedObject private var manager = ExploitManager.shared

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
}
