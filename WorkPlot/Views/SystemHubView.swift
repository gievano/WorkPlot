import SwiftUI
import UIKit

struct SystemHubView: View {
    @EnvironmentObject private var store: GestaltStore
    @State private var showRestore = false
    @State private var showGoldToast = false

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
                    }
                    credits
                    thanks
                    discordLink
                }
                .padding(Theme.pagePadding)
            }
            .scrollIndicators(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showRestore) { RestoreSheet() }
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
                Text("Ketamine").font(.title3.weight(.semibold))
                Text("MG Toolkit  v\(version)")
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
            credit("Nouvborne", "Ketamine developer", "https://github.com/Nouvborne", easterEgg: unlockGoldenK)
            credit("0xjohnnydev", "MobileHouseArrest PoC", "https://github.com/0xjohnnydev")
            credit("forcequitOS", "bad_query", "https://github.com/forcequitOS")
            credit("leminlimez", "Pocket Poster", "https://github.com/leminlimez")
            credit("rooootdev", "NeoSpring", "https://github.com/rooootdev", easterEgg: {
                RespringHelper.shared.trigger()
            })
        }
    }

    private var thanks: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Big thanks to")
            thanksRow("Lemonz", "Discord Manager")
            thanksRow("Sierra", "Discord Moderator")
            Text("…and the rest of our Discord team.")
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

    private var discordLink: some View {
        Link(destination: URL(string: "https://discord.gg/Wt8dj8E8ZN")!) {
            HStack(spacing: 12) {
                Image(systemName: "bubble.right.fill")
                    .font(.title3)
                    .foregroundStyle(Color(red: 0.35, green: 0.42, blue: 0.91))
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Join our Discord").font(.body.weight(.semibold)).foregroundStyle(.primary)
                    Text("Community support and updates").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(18)
            .liquidGlass()
        }
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
        guard !AppIconCatalog.isUnlocked("AppIconGold") else { return }
        AppIconCatalog.unlock("AppIconGold")
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
