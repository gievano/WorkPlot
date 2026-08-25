//
//  UpdateCheckerSheet.swift
//  WorkPlot
//
//  Minimal sheet that runs UpdaterService and shows the outcome with a
//  link to the release page when a newer tag exists.
//

import SwiftUI

struct UpdateCheckerSheet: View {
    private enum Phase: Equatable {
        case idle
        case checking
        case upToDate
        case available(tag: String, url: URL)
        case failed(String)
    }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let showDoneButton: Bool
    @State private var phase: Phase = .idle

    init(showDoneButton: Bool = true) {
        self.showDoneButton = showDoneButton
    }

    var body: some View {
        NavigationView {
            Group {
                switch phase {
                case .idle:
                    WPActionButton(title: "Check for Updates", action: check)
                case .checking:
                    ProgressView()
                case .upToDate:
                    Text(String(format: "You are on the latest version (%@).", UpdaterService.currentVersion))
                        .font(.system(size: 14))
                        .multilineTextAlignment(.center)
                        .padding()
                case .available(let tag, let url):
                    VStack(spacing: 16) {
                        Text(String(format: "New version available: %@", tag))
                            .font(.system(size: 15, weight: .semibold))
                            .multilineTextAlignment(.center)
                        WPActionButton(title: "Open Release") { openURL(url) }
                    }
                    .padding()
                case .failed(let message):
                    VStack(spacing: 16) {
                        Text(String(format: "Check failed: %@", message))
                            .font(.system(size: 14))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        WPActionButton(title: "Check for Updates", action: check)
                    }
                    .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .wpGlassContainer()
            .toolbar {
                if showDoneButton {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }

    private func check() {
        phase = .checking
        Task {
            do {
                let release = try await UpdaterService.latestRelease()
                let newer = UpdaterService.isNewer(release.tag)
                await MainActor.run {
                    phase = newer
                        ? .available(tag: release.tag, url: release.url)
                        : .upToDate
                }
            } catch {
                await MainActor.run {
                    phase = .failed(error.localizedDescription)
                }
            }
        }
    }
}
