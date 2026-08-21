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
        }
    }
}
