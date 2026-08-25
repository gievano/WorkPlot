import SwiftUI
import UIKit

struct SystemHubView: View {
    @EnvironmentObject private var store: GestaltStore
    @State private var showRestore = false
    @State private var showGoldToast = false
    @State private var showIconSwitcher = false

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    status
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader("Tools")
                        Button { showRestore = true } label: {
                            HubToolCard(
                                title: "Recovery",
                                detail: store.backup.hasBackup ? "Restore the pristine MobileGestalt backup" : "A backup is created on first apply",
                                symbol: "arrow.uturn.backward"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        SectionHeader("Application")
                        NavigationLink { SettingsView() } label: {
                            HubToolCard(
                                title: "Preferences",
                                detail: "PosterBoard access and theme",
                                symbol: "paintbrush"
                            )
                        }
                        .buttonStyle(.plain)
                        Button { showIconSwitcher = true } label: {
                            HubToolCard(
                                title: "App Icon",
                                detail: "Change the app icon",
                                symbol: "app"
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    credits
                    thanks
                }
                .padding(Theme.pagePadding)
            }
            .scrollIndicators(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showRestore) { RestoreSheet() }
        .sheet(isPresented: $showIconSwitcher) { AppIconSwitcherSheet(showDoneButton: true) }
        .toast(isPresented: $showGoldToast, message: "You've struck a gold!")
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text("WorkPlot").font(.title3.weight(.semibold))
                Text("WorkPlot Toolkit  v\(version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device access")
                .font(.title3.weight(.semibold))
            HStack(spacing: 12) {
                Image(systemName: store.backup.hasBackup ? "checkmark.shield.fill" : "shield")
                    .foregroundStyle(store.backup.hasBackup ? Theme.affirmative : Theme.accent)
                    .font(.title2)
                Text(store.backup.hasBackup ? "Backup is available" : "No backup has been created")
                    .font(.subheadline.weight(.medium))
                Spacer()
            }
            .padding(18)
            .liquidGlass()
        }
    }

    private var credits: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Credits")
            credit("Gievano", "WorkPlot Developer", "https://github.com/gievano")
            credit("Adnan.120hz", "Idea Contributor, and testing during development", "https://github.com/adnan120hz")
            credit("Nouvborne", "Ketamine (base framework)", "https://github.com/Nouvborne", easterEgg: unlockGoldenK)
            credit("forcequitOS", "bad_query", "https://github.com/forcequitOS")
            credit("0xjohnnydev", "FilzaSlop (sandbox escape)", "https://github.com/0xjohnnydev")
            credit("leminlimez", "Nugget & GestaltEdit", "https://github.com/leminlimez")
            credit("YangJiiii", "3105", "https://github.com/YangJiiii")
            credit("rooootdev", "neospring (respring)", "https://github.com/rooootdev", easterEgg: {
                RespringHelper.shared.trigger()
            })
            credit("frs0n", "Placard", "https://github.com/frs0n")
        }
    }

    private var thanks: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Big thanks to")
            thanksRow("Mond", "Supporter")
            thanksRow("Toto", "Supporter")
            Text("…and everyone in the WorkPlot community who tested and reported issues.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
    }

    private func thanksRow(_ name: String, _ role: String) -> some View {
        HStack {
            Text(name).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
            Text(role).font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 7)
    }

    /// `easterEgg`, when set, fires on a long press without blocking the
    /// row's normal tap-to-open-link behavior (a quick tap still opens
    /// `url`; only a sustained press triggers it).
    private func credit(_ name: String, _ role: String, _ url: String, easterEgg: (() -> Void)? = nil) -> some View {
        let row = Link(destination: URL(string: url)!) {
            HStack {
                Text(name).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                Text(role).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 7)
        }
        return Group {
            if let easterEgg {
                row.simultaneousGesture(
                    LongPressGesture(minimumDuration: 10).onEnded { _ in easterEgg() }
                )
            } else {
                row
            }
        }
    }

    /// One-time unlock for the hidden "Golden K" icon. Once unlocked this is
    /// a no-op forever after — no repeat toast, no repeat haptic.
    private func unlockGoldenK() {
        guard !AppIconCatalog.isUnlocked("WPWorkplot2") else { return }
        AppIconCatalog.unlock("WPWorkplot2")
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        showGoldToast = true
    }
}

struct HubToolCard: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.semibold)).foregroundStyle(.primary)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(18)
        .liquidGlass()
    }
}
