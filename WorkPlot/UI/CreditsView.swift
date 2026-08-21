import SwiftUI

struct CreditsLink: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
    let url: URL?

    init(name: String, detail: String, urlString: String? = nil) {
        self.name = name
        self.detail = detail
        self.url = urlString.flatMap(URL.init(string:))
    }
}

struct CreditsView: View {
    @ObservedObject private var l10n = L10n.shared

    private let owners = [
        CreditsLink(name: "Adnan.120hz", detail: "Owner", urlString: "https://github.com/adnan120hz"),
        CreditsLink(name: "Gievano", detail: "Owner", urlString: "https://github.com/gievano")
    ]

    private var projects: [CreditsLink] { [
        CreditsLink(name: "bad_query by forcequitOS", detail: l10n.tr("credits.exploit.detail"),
                    urlString: "https://github.com/forcequitOS/bad_query"),
        CreditsLink(name: "0xjohnnydev", detail: l10n.tr("credits.sandbox.detail"),
                    urlString: "https://github.com/0xjohnnydev"),
        CreditsLink(name: "FilzaSlop", detail: "0xjohnnydev",
                    urlString: "https://github.com/0xjohnnydev/FilzaSlop"),
        CreditsLink(name: "Placard", detail: "frs0n",
                    urlString: "https://github.com/frs0n/placard")
    ] }

    private let thanks = ["Mond", "GestaltEdit", "Ketamine", "3105", "Placard", "FilzaSlop"]

    var body: some View {
        List {
            Section(header: Text(l10n.tr("credits.owner"))) {
                ForEach(owners) { linkRow($0) }
            }

            Section(header: Text(l10n.tr("credits.projects"))) {
                ForEach(projects) { linkRow($0) }
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
        HStack {
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
}
