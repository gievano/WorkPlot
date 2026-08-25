import SwiftUI

// Shared UI building blocks — own concept, refined glass. Section headers,
// action buttons, progress and toast, all wired to Theme.liquidGlass.

struct WPSectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
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

/// Labeled key/value row used inside info cards (device build, method,
/// status, etc.). Value color carries state (green = ok, orange = warn).
struct WPInfoRow: View {
    let label: String
    var value: String = "—"
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(label).font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(valueColor)
                .multilineTextAlignment(.trailing)
        }
    }
}

/// Centered, icon-led placeholder for empty / locked / error states so every
/// list and detail screen reads the same when there is nothing to show.
struct WPEmptyState: View {
    let icon: String
    let title: String
    var message: String?
    var tint: Color = .secondary

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(tint)
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
