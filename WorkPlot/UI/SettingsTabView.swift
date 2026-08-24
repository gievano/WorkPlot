import SwiftUI

struct SettingsTabView: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var showUpdate = false
    @State private var showIcon = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    featuresSection
                    toolsSection
                    appearanceSection
                    aboutSection
                }
                .padding(Theme.pagePadding)
            }
            .navigationTitle("Settings")
            .wpGlassContainer()
            .sheet(isPresented: $showUpdate) { UpdateCheckerSheet() }
            .sheet(isPresented: $showIcon) { AppIconSwitcherSheet() }
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            WPSectionHeader(title: "Features")
            VStack(spacing: 0) {
                moreRow { LiquidGlassView() } label: {
                    Label(l10n.tr("tab.liquidglass"), systemImage: "drop.fill")
                }
                divider
                moreRow { BackupRestoreManagerView() } label: {
                    Label(l10n.tr("tab.backups"), systemImage: "arrow.counterclockwise.circle.fill")
                }
                divider
                moreRow { PresetLabView() } label: {
                    Label(l10n.tr("preset.title"), systemImage: "wand.and.stars")
                }
                divider
                moreRow { FilePatchWorkspaceView() } label: {
                    Label(l10n.tr("tab.files"), systemImage: "folder.fill")
                }
            }
            .wpCard()
        }
    }

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            WPSectionHeader(title: "Tools")
            VStack(spacing: 0) {
                moreRow { AppContainersView() } label: {
                    Label(l10n.tr("ac.title"), systemImage: "shippingbox")
                }
                divider
                moreRow { SessionLogView() } label: {
                    Label(l10n.tr("sessionlog.title"), systemImage: "scroll.text.fill")
                }
                divider
                moreRow { GestaltFieldEditorView() } label: {
                    Label(l10n.tr("tab.fields"), systemImage: "list.bullet.rectangle")
                }
                divider
                moreButton { showUpdate = true } label: {
                    Label(l10n.tr("upd.check"), systemImage: "arrow.triangle.down.circle")
                }
                divider
                moreButton { showIcon = true } label: {
                    Label(l10n.tr("icon.menu"), systemImage: "paintbrush")
                }
            }
            .wpCard()
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            WPSectionHeader(title: "Appearance")
            VStack(spacing: 0) {
                moreRow { AppearanceView() } label: {
                    Label("Appearance", systemImage: "paintpalette")
                }
            }
            .wpCard()
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            WPSectionHeader(title: l10n.tr("credits.header"))
            VStack(spacing: 0) {
                moreRow { CreditsView() } label: {
                    Label(l10n.tr("credits.header"), systemImage: "heart.circle.fill")
                }
            }
            .wpCard()
        }
    }

    private var divider: some View {
        Divider().padding(.leading, 44)
    }

    private func moreRow<Content: View>(
        @ViewBuilder destination: () -> Content,
        @ViewBuilder label: () -> some View
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                label()
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private func moreButton(
        action: @escaping () -> Void,
        @ViewBuilder label: () -> some View
    ) -> some View {
        Button(action: action) {
            HStack {
                label()
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.accent)
    }
}
