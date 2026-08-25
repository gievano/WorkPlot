import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: GestaltStore
    @ObservedObject private var respring = RespringHelper.shared
    @AppStorage("hasAcceptedDisclaimer") private var hasAcceptedDisclaimer = false

    var body: some View {
        Group {
            switch DeviceCompatibility.currentStatus {
            case .supported:
                MainTabView()
            case .unsupported(let reason):
                UnsupportedView(reason: reason)
            }
        }
        .overlay {
            if respring.isRespringing {
                NeoSpringView()
            }
        }
        .fullScreenCover(isPresented: .constant(!hasAcceptedDisclaimer)) {
            DisclaimerView { hasAcceptedDisclaimer = true }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Tweaks", systemImage: "switch.2") }
            PosterBoardView()
                .tabItem { Label("PosterBoard", systemImage: "square.stack.3d.up") }
            SiriAISetupView()
                .tabItem { Label("Siri AI Setup", systemImage: "brain.head.profile") }
            SystemHubView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
            WorkPlotHubView()
                .tabItem { Label("WorkPlot", systemImage: "app.badge.checkmark") }
        }
    }
}
