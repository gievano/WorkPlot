//
//  NuggetWallpaperGalleryView.swift
//  WorkPlot
//
//  Browses the Nugget-Wallpapers catalogs and downloads picked tendies packs
//  straight into the PosterBoard install queue.
//

import SwiftUI

struct NuggetWallpaperGalleryView: View {
    @ObservedObject private var store = NuggetWallpaperStore.shared
    @ObservedObject private var pbManager = PosterBoardManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var source: NuggetWallpaperSource = .custom
    @State private var downloadingIDs: Set<Int> = []
    @State private var downloadedIDs: Set<Int> = []
    @State private var errorMessage = ""
    @State private var showError = false

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("Source", selection: $source) {
                        ForEach(NuggetWallpaperSource.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Tap a wallpaper to download it — it's added straight to your install queue.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    content
                }
                .padding(Theme.pagePadding)
            }
            .scrollIndicators(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Download Wallpapers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task(id: source) { await store.load(source) }
        .alert("Download failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    @ViewBuilder
    private var content: some View {
        let list = store.wallpapers[source]
        if store.isLoading[source] == true && (list?.isEmpty ?? true) {
            ProgressView("Loading \(source.title.lowercased()) wallpapers…")
                .frame(maxWidth: .infinity, minHeight: 240)
        } else if let error = store.loadError[source] {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") { Task { await store.load(source, force: true) } }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
            }
            .frame(maxWidth: .infinity, minHeight: 240)
        } else {
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(list ?? []) { wallpaper in
                    WallpaperCard(
                        wallpaper: wallpaper,
                        previewURL: store.assetURL(for: wallpaper.preview),
                        isDownloading: downloadingIDs.contains(wallpaper.id),
                        isDownloaded: downloadedIDs.contains(wallpaper.id),
                        isQueueFull: pbManager.selectedTendies.count >= PosterBoardManager.MaxTendies,
                        action: { Task { await download(wallpaper) } }
                    )
                }
            }
        }
    }

    private func download(_ wallpaper: NuggetWallpaper) async {
        guard !downloadingIDs.contains(wallpaper.id), !downloadedIDs.contains(wallpaper.id) else { return }
        guard pbManager.selectedTendies.count < PosterBoardManager.MaxTendies else {
            errorMessage = "You can only queue \(PosterBoardManager.MaxTendies) tendies packs at once. Install or remove some first."
            showError = true
            return
        }
        guard let assetURL = store.assetURL(for: wallpaper.url) else {
            errorMessage = "Couldn't build a download link for \(wallpaper.name)."
            showError = true
            return
        }

        downloadingIDs.insert(wallpaper.id)
        defer { downloadingIDs.remove(wallpaper.id) }

        do {
            let (data, _) = try await URLSession.shared.data(from: assetURL)
            let localURL = try pbManager.storeDownloadedTendies(named: assetURL.lastPathComponent, data: data)
            pbManager.selectedTendies.append(localURL)
            downloadedIDs.insert(wallpaper.id)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = "Couldn't download \(wallpaper.name): \(error.localizedDescription)"
            showError = true
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

private struct WallpaperCard: View {
    let wallpaper: NuggetWallpaper
    let previewURL: URL?
    let isDownloading: Bool
    let isDownloaded: Bool
    let isQueueFull: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RemoteAnimatedImage(url: previewURL)
                .aspectRatio(9.0 / 17.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if let contest = wallpaper.contest {
                        Text(contest)
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.55), in: Capsule())
                            .foregroundStyle(.white)
                            .padding(8)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    downloadButton.padding(8)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(wallpaper.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if let subtitle = wallpaper.authors ?? wallpaper.description {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var downloadButton: some View {
        Button(action: action) {
            Group {
                if isDownloading {
                    ProgressView().tint(.white)
                } else if isDownloaded {
                    Image(systemName: "checkmark")
                } else {
                    Image(systemName: "arrow.down")
                }
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(isDownloaded ? Theme.affirmative : Theme.accent, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(isDownloading || isDownloaded || (isQueueFull && !isDownloaded))
        .opacity(isQueueFull && !isDownloaded && !isDownloading ? 0.5 : 1)
    }
}
