import SwiftUI

struct AppIconSwitcherSheet: View {
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.dismiss) private var dismiss
    @State private var currentAltName: String? = UIApplication.shared.alternateIconName
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                iconRow(title: l10n.tr("icon.default"), subtitle: "WorkPlot Classic", altName: nil)
                iconRow(title: l10n.tr("icon.collage"), subtitle: "WP Devices", altName: "WPCollage")
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle(l10n.tr("icon.menu"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l10n.tr("common.done")) { dismiss() }
                }
            }
        }
    }

    private func iconRow(title: String, subtitle: String, altName: String?) -> some View {
        Button {
            select(altName)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 18, weight: .semibold)).foregroundStyle(.primary)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if currentAltName == altName {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title3)
                }
            }
        }
    }

    private func select(_ altName: String?) {
        guard UIApplication.shared.alternateIconName != altName else { return }
        UIApplication.shared.setAlternateIconName(altName) { error in
            DispatchQueue.main.async {
                if let error {
                    errorMessage = error.localizedDescription
                } else {
                    currentAltName = altName
                    errorMessage = nil
                }
            }
        }
    }
}
