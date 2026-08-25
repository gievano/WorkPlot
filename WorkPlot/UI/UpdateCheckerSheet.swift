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

    @ObservedObject private var l10n = L10n.shared
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
                    WPActionButton(title: l10n.tr("upd.check"), action: check)
                case .checking:
                    ProgressView()
                case .upToDate:
                    Text(String(format: l10n.tr("upd.latest"), UpdaterService.currentVersion))
                        .font(.system(size: 14))
                        .multilineTextAlignment(.center)
                        .padding()
                case .available(let tag, let url):
                    VStack(spacing: 16) {
                        Text(String(format: l10n.tr("upd.newVersion"), tag))
                            .font(.system(size: 15, weight: .semibold))
                            .multilineTextAlignment(.center)
                        WPActionButton(title: l10n.tr("upd.openRelease")) { openURL(url) }
                    }
                    .padding()
                case .failed(let message):
                    VStack(spacing: 16) {
                        Text(String(format: l10n.tr("upd.fail"), message))
                            .font(.system(size: 14))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        WPActionButton(title: l10n.tr("upd.check"), action: check)
                    }
                    .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .wpGlassContainer()
            .toolbar {
                if showDoneButton {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(l10n.tr("common.done")) { dismiss() }
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
