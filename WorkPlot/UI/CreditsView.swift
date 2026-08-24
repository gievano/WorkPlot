import SwiftUI

struct CreditsLink: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
    let url: URL?
    let tiktokURL: URL?
    let githubUser: String?

    init(name: String, detail: String, urlString: String? = nil, githubUser: String? = nil, tiktok: String? = nil) {
        self.name = name
        self.detail = detail
        self.url = urlString.flatMap(URL.init(string:))
        self.tiktokURL = tiktok.flatMap(URL.init(string:))
        self.githubUser = githubUser
    }
}

struct CreditsView: View {
    @ObservedObject private var l10n = L10n.shared

    private let owners = [
        CreditsLink(name: "Adnan.120hz", detail: "Owner",
                    urlString: "https://github.com/adnan120hz", githubUser: "adnan120hz"),
        CreditsLink(name: "Gievano", detail: "Owner",
                    urlString: "https://github.com/gievano", githubUser: "gievano")
    ]

    private var projects: [CreditsLink] { [
        CreditsLink(name: "bad_query", detail: l10n.tr("credits.exploit.detail"),
                    urlString: "https://github.com/forcequitOS/bad_query", githubUser: "forcequitOS"),
        // Single entry per person/project: the author, FilzaSlop, and the
        // PoC groundwork previously appeared as separate rows.
        CreditsLink(name: "FilzaSlop (HouseArrest sandbox escape)", detail: l10n.tr("credits.sandbox.detail"),
                    urlString: "https://github.com/0xjohnnydev/FilzaSlop", githubUser: "0xjohnnydev"),
        CreditsLink(name: "Nugget & GestaltEdit", detail: l10n.tr("credits.nugget.detail"),
                    urlString: "https://github.com/leminlimez/Nugget", githubUser: "leminlimez"),
        CreditsLink(name: "3105", detail: l10n.tr("credits.3105.detail"),
                    urlString: "https://github.com/YangJiiii/3105", githubUser: "YangJiiii"),
        CreditsLink(name: "neospring (respring)", detail: l10n.tr("credits.respring.detail"),
                    urlString: "https://github.com/rooootdev/neospring", githubUser: "rooootdev"),
        CreditsLink(name: "Placard", detail: "frs0n",
                    urlString: "https://github.com/frs0n/placard", githubUser: "frs0n")
    ] }

    private var testers: [CreditsLink] { [
        CreditsLink(name: "nguyenls3005-cell", detail: l10n.tr("credits.tester.detail"),
                    urlString: "https://github.com/nguyenls3005-cell", githubUser: "nguyenls3005-cell",
                    tiktok: "https://www.tiktok.com/@lsnguyyniu"),
    ] }

    private let thanks = ["Mond", "Ketamine", "Toto"]

    @State private var tiktokLink: CreditsLink?
    @State private var showTikTokDialog = false

    var body: some View {
        List {
            Section(header: Text(l10n.tr("credits.owner"))) {
                ForEach(owners) { linkRow($0) }
            }

            Section(header: Text(l10n.tr("credits.projects"))) {
                ForEach(projects) { linkRow($0) }
            }

            Section(header: Text(l10n.tr("credits.tester"))) {
                ForEach(testers) { testerRow($0) }
            }

            Section(header: Text(l10n.tr("credits.thanks"))) {
                Text(thanks.joined(separator: ", "))
                    .font(.system(size: 16, weight: .medium))
            }

            Section {
                Text(l10n.tr("credits.disclaimer"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(l10n.tr("credits.header"))
        .wpGlassContainer()
        .confirmationDialog("Open TikTok?", isPresented: $showTikTokDialog, titleVisibility: .visible) {
            Button("Open TikTok Profile") {
                if let url = tiktokLink?.tiktokURL { UIApplication.shared.open(url) }
            }
            Button("GitHub Profile") {
                if let url = tiktokLink?.url { UIApplication.shared.open(url) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(tiktokLink.map { "Choose a profile to open for \($0.name)." } ?? "")
        }
    }

    /// Tester rows carry a TikTok link, so tapping pops a profile picker
    /// instead of jumping straight to GitHub.
    private func testerRow(_ link: CreditsLink) -> some View {
        Button {
            tiktokLink = link
            showTikTokDialog = true
        } label: {
            rowContent(link)
        }
        .buttonStyle(.plain)
    }

    private func linkRow(_ link: CreditsLink) -> some View {
        Group {
            if let url = link.url {
                Link(destination: url) {
                    rowContent(link)
                }
            } else {
                rowContent(link)
            }
        }
    }

    private func rowContent(_ link: CreditsLink) -> some View {
        HStack(spacing: 12) {
            avatar(for: link)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(link.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(link.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if link.url != nil {
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func avatar(for link: CreditsLink) -> some View {
        if let user = link.githubUser,
           let url = URL(string: "https://github.com/\(user).png?size=80") {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    placeholderAvatar
                default:
                    ProgressView()
                        .frame(width: 40, height: 40)
                        .background(Color.gray.opacity(0.2))
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
        } else {
            placeholderAvatar
        }
    }

    private var placeholderAvatar: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .frame(width: 40, height: 40)
            .foregroundStyle(.gray)
    }
}
