import SwiftUI

struct AppIcon: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let colors: [Color]

    static var all: [AppIcon] { [
        AppIcon(id: "", titleKey: "WorkPlot", subtitleKey: "Default",
                colors: [.blue, .indigo]),
        AppIcon(id: "WPWorkplot2", titleKey: "WorkPlot 2", subtitleKey: "Custom",
                colors: [.blue, .purple])
        ]
    }

    init(id: String, titleKey: String, subtitleKey: String, colors: [Color]) {
        self.id = id
        self.title = L10n.shared.tr(titleKey)
        self.subtitle = L10n.shared.tr(subtitleKey)
        self.colors = colors
    }
}

struct AppIconSwitcherSheet: View {
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.dismiss) private var dismiss
    let showDoneButton: Bool
    @State private var currentAltName: String? = UIApplication.shared.alternateIconName
    @State private var pendingIcon: AppIcon?
    @State private var errorMessage: String?

    init(showDoneButton: Bool = true) {
        self.showDoneButton = showDoneButton
    }

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 20)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(AppIcon.all) { icon in
                        iconCell(icon)
                    }
                }
                .padding()

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }
            }
            .navigationTitle(l10n.tr("icon.menu"))
            .wpGlassContainer()
            .toolbar {
                if showDoneButton {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(l10n.tr("common.done")) { dismiss() }
                    }
                }
            }
            .alert(l10n.tr("icon.confirm.title"), isPresented: .init(
                get: { pendingIcon != nil },
                set: { if !$0 { pendingIcon = nil } }
            )) {
                Button(l10n.tr("icon.confirm.change")) {
                    if let pendingIcon { apply(pendingIcon.id) }
                    pendingIcon = nil
                }
                Button(l10n.tr("siriai.restart.later"), role: .cancel) { pendingIcon = nil }
            } message: {
                Text(l10n.tr("icon.confirm.message"))
            }
        }
    }

    private func iconCell(_ icon: AppIcon) -> some View {
        Button {
            guard currentAltName != icon.id else { return }
            pendingIcon = icon
        } label: {
            VStack(spacing: 8) {
                Image(icon.id.isEmpty ? "Logo" : icon.id + "Preview")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(alignment: .bottomTrailing) {
                        if currentAltName == icon.id {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white, .blue)
                                .offset(x: 6, y: 6)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .strokeBorder(currentAltName == icon.id ? Color.blue : .clear, lineWidth: 3)
                    )
                VStack(spacing: 2) {
                    Text(icon.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(icon.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// Empty id means the primary icon: setAlternateIconName requires nil
    /// there — passing "" fails with "no icon named" on device.
    private func apply(_ iconId: String) {
        let altName: String? = iconId.isEmpty ? nil : iconId
        UIApplication.shared.setAlternateIconName(altName) { error in
            DispatchQueue.main.async {
                if let error {
                    errorMessage = "\(l10n.tr("icon.error.prefix"))\(error.localizedDescription)"
                } else {
                    currentAltName = altName
                    errorMessage = nil
                }
            }
        }
    }
}
