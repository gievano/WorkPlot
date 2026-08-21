import SwiftUI

struct MoreMenuView: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var showIconSwitcher = false

    var body: some View {
        NavigationStack {
            List {
                moreRow(l10n.tr("tab.liquidglass"), "drop.fill", .cyan) { AnyView(LiquidGlassView()) }
                moreRow(l10n.tr("tab.posterboard"), "photo.stack.fill", .pink) { AnyView(PosterBoardLabView()) }
                moreRow(l10n.tr("tab.backups"), "arrow.counterclockwise.circle.fill", .orange) { AnyView(BackupRestoreManagerView()) }
                moreRow(l10n.tr("tab.files"), "folder.fill", .blue) { AnyView(FilePatchWorkspaceView()) }

                Section {
                    Button {
                        showIconSwitcher = true
                    } label: {
                        HStack(spacing: 16) {
                            Image(uiImage: MainDashboardView.bigSymbol("paintbrush", size: 30))
                                .foregroundStyle(.purple)
                                .frame(width: 40)
                            Text(l10n.tr("icon.menu"))
                                .font(.system(size: 19, weight: .semibold))
                        }
                        .padding(.vertical, 6)
                    }

                    NavigationLink {
                        CreditsView()
                    } label: {
                        HStack(spacing: 16) {
                            Image(uiImage: MainDashboardView.bigSymbol("heart.circle.fill", size: 30))
                                .foregroundStyle(.red)
                                .frame(width: 40)
                            Text(l10n.tr("credits.header"))
                                .font(.system(size: 19, weight: .semibold))
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
            .navigationTitle(l10n.tr("tab.more"))
        }
        .sheet(isPresented: $showIconSwitcher) {
            AppIconSwitcherSheet()
        }
    }

    private func moreRow(_ title: String, _ icon: String, _ color: Color, destination: @escaping () -> AnyView) -> some View {
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
