import SwiftUI

// Shared UI building blocks — own concept, same intent as Ketamine's
// Components (section headers, action buttons, progress, toast) but named
// for WorkPlot and wired to Theme.liquidGlass.

struct WPSectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(0.8)
            if let subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }
}

struct WPActionButton: View {
    let title: String
    var isBusy: Bool = false
    var prominent: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isBusy { ProgressView().controlSize(.small) }
                Text(isBusy ? "" : title)
            }
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .glassAction(forceProminent: prominent)
        .disabled(isBusy)
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
            .padding(.bottom, 8)
    }
}
