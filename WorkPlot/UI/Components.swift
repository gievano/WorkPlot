import SwiftUI

// Shared UI building blocks — own concept, refined glass. Section headers,
// action buttons, progress and toast, all wired to Theme.liquidGlass.

struct WPSectionHeader: View {
    let title: String
    var subtitle: String?
    var icon: String?

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Theme.accent)
                    .tracking(1.2)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 2)
    }
}

struct WPActionButton: View {
    let title: String
    var isBusy: Bool = false
    var prominent: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isBusy { ProgressView().controlSize(.small) }
                Text(isBusy ? "Please wait…" : title)
            }
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .glassAction(forceProminent: prominent)
        .disabled(isBusy)
    }
}

struct WPCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content.wpCard()
    }
}

struct WPProgressOverlay: View {
    let message: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                if let message {
                    Text(message).font(.callout).foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .liquidGlass(cornerRadius: 20)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
        }
    }
}

struct WPToast: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.footnote.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .liquidGlass(cornerRadius: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
            .padding(.bottom, 8)
    }
}
