import SwiftUI
import UIKit

struct AppIconThumbnail: View {
    let option: AppIconOption

    var body: some View {
        Group {
            if option.id == AppIconCatalog.standard.id {
                Image("Logo").resizable().scaledToFit()
            } else {
                Image(option.previewImageName).resizable().scaledToFit()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

struct AppIconPickerView: View {
    @AppStorage("appIcon") private var appIcon = AppIconCatalog.standard.id
    @State private var showIconError = false
    @State private var iconErrorMessage = ""

    var body: some View {
        List(AppIconCatalog.visible) { option in
            Button { selectIcon(option) } label: {
                HStack(spacing: 14) {
                    AppIconThumbnail(option: option)
                        .frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(option.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text("by \(option.creator)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if appIcon == option.id {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .listStyle(.insetGrouped)
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Could not change app icon", isPresented: $showIconError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(iconErrorMessage)
        }
    }

    private func selectIcon(_ option: AppIconOption) {
        guard UIApplication.shared.supportsAlternateIcons else {
            iconErrorMessage = "Alternate app icons are unavailable on this device."
            showIconError = true
            return
        }
        UIApplication.shared.setAlternateIconName(option.alternateIconName) { error in
            DispatchQueue.main.async {
                if let error {
                    iconErrorMessage = error.localizedDescription
                    showIconError = true
                } else {
                    appIcon = option.id
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        }
    }
}
