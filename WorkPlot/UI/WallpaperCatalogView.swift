//
//  WallpaperCatalogView.swift
//  WorkPlot
//
//  Browses the online wallpaper catalog (community + Apple entries) and
//  installs entries straight into PosterBoard.
//

import SwiftUI

struct WallpaperCatalogView: View {
    @ObservedObject private var manager = ExploitManager.shared
    @ObservedObject private var l10n = L10n.shared

    @State private var kind: CatalogKind = .custom
    @State private var entries: [CatalogKind: [CatalogEntry]] = [:]
    @State private var isLoading = false
    @State private var fetchError: String?
    @State private var installingID: Int?
    @State private var downloadAlert: String?

    private var canInstall: Bool {
        manager.sandboxGranted && PosterBoardAccess.isAvailable && installingID == nil
    }

    var body: some View {
        NavigationStack {
            Group {
                if !manager.sandboxGranted || !PosterBoardAccess.isAvailable {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.icloud").font(.largeTitle).foregroundColor(.orange)
                        Text(l10n.tr("common.accessLocked"))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                } else {
                    catalogList
                }
            }
            .navigationTitle(l10n.tr("cat.title"))
            .workPlotScrollBackground()
            .task(id: kind) { await load() }
            .alert(
                String(format: l10n.tr("cat.downloadFail"), downloadAlert ?? ""),
                isPresented: .init(
                    get: { downloadAlert != nil },
                    set: { if !$0 { downloadAlert = nil } }
                )
            ) {}
        }
    }

    private var catalogList: some View {
        List {
            Section {
                Picker("", selection: $kind) {
                    ForEach(CatalogKind.allCases) { candidate in
                        Text(l10n.tr(candidate == .custom ? "cat.custom" : "cat.apple"))
                            .tag(candidate)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if let fetchError {
                    VStack(spacing: 8) {
                        Text(String(format: l10n.tr("cat.catalogFail"), fetchError))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button {
                            Task { await load(force: true) }
                        } label: {
                            Label(l10n.tr("common.retry"), systemImage: "arrow.clockwise")
                        }
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(entries[kind] ?? []) { entry in
                        entryRow(entry)
                    }
                }
            }
        }
    }

    private func entryRow(_ entry: CatalogEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: WallpaperCatalogService.previewURL(for: entry)) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                ZStack {
                    Color(.secondarySystemBackground)
                    ProgressView()
                }
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .cornerRadius(12)

            Text(entry.name)
                .font(.system(size: 15, weight: .medium))

            if let description = entry.description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let authors = entry.authors {
                Text(String(format: l10n.tr("cat.byAuthor"), authors))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            applyControl(entry)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func applyControl(_ entry: CatalogEntry) -> some View {
        if installingID == entry.id {
            HStack(spacing: 8) {
                ProgressView()
                Text(String(format: l10n.tr("cat.installing"), entry.name))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Button {
                apply(entry)
            } label: {
                Label(l10n.tr("cat.apply"), systemImage: "arrow.down.circle")
            }
            .disabled(!canInstall)
        }
    }

    private func load(force: Bool = false) async {
        if !force, entries[kind] != nil { return }
        isLoading = true
        fetchError = nil
        do {
            entries[kind] = try await WallpaperCatalogService.fetchCatalog(kind: kind)
        } catch {
            fetchError = error.localizedDescription
        }
        isLoading = false
    }

    /// Downloads and installs off the main actor; only state mutations hop back.
    private func apply(_ entry: CatalogEntry) {
        guard canInstall else { return }
        installingID = entry.id
        Task {
            do {
                let descriptorFolders = try await WallpaperCatalogService.downloadAndExtract(entry: entry)
                _ = try WallpaperCatalogService.install(descriptorFolders: descriptorFolders, name: entry.name)
                await MainActor.run {
                    manager.statusText = String(format: l10n.tr("cat.appliedOk"), entry.name)
                    installingID = nil
                    manager.respringRequested = true
                }
            } catch {
                SessionLogger.shared.log("catalog install failed: \(entry.name): \(error.localizedDescription)")
                await MainActor.run {
                    installingID = nil
                    downloadAlert = error.localizedDescription
                }
            }
        }
    }
}
