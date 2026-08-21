import SwiftUI

public struct MainDashboardView: View {
    public var body: some View {
        TabView {
            StatusDashboardView().tabItem { Label("Status", systemImage: "shield.checkered") }
            GestaltPresetManagerView().tabItem { Label("Gestalt", systemImage: "cpu") }
            CustomizationThemeView().tabItem { Label("Customization", systemImage: "paintbrush.fill") }
            FilePatchWorkspaceView().tabItem { Label("Files", systemImage: "folder.fill") }
            BackupRestoreManagerView().tabItem { Label("Backups", systemImage: "arrow.counterclockwise.circle.fill") }
        }
        .preferredColorScheme(.dark)
    }
}
