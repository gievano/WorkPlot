import SwiftUI

struct MoreMenuView: View {
    @ObservedObject private var l10n = L10n.shared

    var body: some View {
        NavigationStack {
            List {
                moreRow(l10n.tr("tab.liquidglass"), "drop.fill", .cyan) { LiquidGlassView() }
                moreRow(l10n.tr("tab.posterboard"), "photo.stack.fill", .pink) { PosterBoardLabView() }
                moreRow(l10n.tr("tab.backups"), "arrow.counterclockwise.circle.fill", .orange) { BackupRestoreManagerView() }
                moreRow(l10n.tr("tab.files"), "folder.fill", .blue) { FilePatchWorkspaceView() }
            }
            .navigationTitle(l10n.tr("tab.more"))
        }
    }

    private func moreRow<D: View>(_ title: String, _ icon: String, _ color: Color, @ViewBuilder destination: @escaping () -> D) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 16) {
                Image(uiImage: MainDashboardView.bigSymbol(icon, size: 30))
                    .foregroundStyle(color)
                    .frame(width: 40)
                Text(title)
                    .font(.system(size: 19, weight: .semibold))
            }
            .padding(.vertical, 6)
        }
    }
}
