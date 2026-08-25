import SwiftUI

struct UnsupportedView: View {
    let reason: String

    private var os: DeviceCompatibility.OSInfo { DeviceCompatibility.currentInfo }

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            Spacer()
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 8) {
                Text("Ketamine cannot run here")
                    .font(.title2.weight(.semibold))
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                detail("iOS version", "\(os.version.majorVersion).\(os.version.minorVersion).\(os.version.patchVersion)")
                Divider()
                detail("Build", os.build ?? "Unknown")
                Divider()
                detail("Latest verified", "27.0 developer beta 4")
            }
            .padding(.horizontal, 18)
            .liquidGlass()
            Text("Newer firmware patched the ability to modify MobileGestalt.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(Theme.pagePadding)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private func detail(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium).textSelection(.enabled)
        }
        .font(.subheadline)
        .padding(.vertical, 14)
    }
}

/// Lightweight in-tab placeholder for features gated behind a newer iOS
/// version, used where the rest of the app (and other tabs) remain usable.
struct FeatureUnsupportedView: View {
    let feature: String

    private var os: DeviceCompatibility.OSInfo { DeviceCompatibility.currentInfo }

    private var reason: String {
        if case .unsupported(let reason) = DeviceCompatibility.fullFeatureStatus(feature: feature) {
            return reason
        }
        return ""
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Theme.caution)
            VStack(spacing: 8) {
                Text("Unsupported on this iOS version")
                    .font(.title3.weight(.semibold))
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}
