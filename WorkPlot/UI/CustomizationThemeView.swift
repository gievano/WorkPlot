import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let tendies = UTType(filenameExtension: "tendies") ?? .data
}

struct PosterBoardLabView: View {
    @ObservedObject private var manager = ExploitManager.shared
    @ObservedObject private var l10n = L10n.shared

    @State private var isShowingImporter = false
    @State private var isInstalling = false
    @State private var phase = ""
    @State private var installedWallpapers: [String] = []
    @State private var pendingRemoval: String?
    @State private var isLoadingWallpapers = false

    var body: some View {
        NavigationView {
            Group {
                if !manager.sandboxGranted {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.icloud").font(.largeTitle).foregroundColor(.orange)
                        Text(L10n.shared.tr("common.accessLocked"))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                } else if !PosterBoardAccess.isAvailable {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.exclamationmark").font(.largeTitle).foregroundColor(.orange)
                        Text("bad_query tidak tersedia; PosterBoard tidak dapat diakses di perangkat ini.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                } else {
                    wallpaperList
                }
            }
            .navigationTitle(L10n.shared.tr("tab.posterboard"))
            .workPlotScrollBackground()
            .onAppear(perform: reloadInstalled)
            .fileImporter(
                isPresented: $isShowingImporter,
                allowedContentTypes: [.tendies],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first { installTendies(from: url) }
                case .failure(let error):
                    manager.statusText = "Gagal: \(error.localizedDescription)"
                    phase = ""
                }
            }
            .alert(
                l10n.tr("pb.remove.confirm"),
                isPresented: .init(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } })
            ) {
                Button(l10n.tr("pb.remove"), role: .destructive) {
                    if let name = pendingRemoval { remove(name) }
                    pendingRemoval = nil
                }
                Button(l10n.tr("siriai.restart.later"), role: .cancel) { pendingRemoval = nil }
            } message: {
                Text(pendingRemoval ?? "")
            }
        }
    }

    private var wallpaperList: some View {
        List {
            Section(
                header: Text("Wallpaper Lab"),
                footer: Text("Impor paket .tendies (format PocketPoster), validasi struktur descriptor, lalu pasang ke PosterBoard. Respring diperlukan setelah pemasangan.")
            ) {
                Button {
                    isShowingImporter = true
                } label: {
                    Label(L10n.shared.tr("posterboard.import"), systemImage: "square.and.arrow.down")
                }
                .disabled(isInstalling)

                if isInstalling {
                    HStack { ProgressView(); Text(phase) }
                } else if !phase.isEmpty {
                    Text(phase)
                        .font(.caption)
                        .foregroundColor(manager.statusText.hasPrefix("Gagal") ? .orange : .secondary)
                }
            }

            Section(header: Text(l10n.tr("pb.installed"))) {
                if isLoadingWallpapers {
                    HStack { ProgressView(); Text(l10n.tr("pb.loading")).font(.caption) }
                } else if installedWallpapers.isEmpty {
                    Text(l10n.tr("pb.empty"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(installedWallpapers, id: \.self) { name in
                        HStack {
                            Image(systemName: "photo.fill")
                                .foregroundStyle(.pink)
                            Text(name)
                                .font(.system(size: 15, weight: .medium))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button {
                                manager.respringRequested = true
                            } label: {
                                Label(l10n.tr("pb.apply"), systemImage: "checkmark.circle")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.borderless)

                            Button(role: .destructive) {
                                pendingRemoval = name
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                if !installedWallpapers.isEmpty {
                    Button {
                        manager.respringRequested = true
                    } label: {
                        Label(l10n.tr("siriai.restart.respring"), systemImage: "arrow.counterclockwise")
                    }
                }
            }
        }
    }

    /// Pipeline: copy out of the security scope -> validate ZIP & structure ->
    /// extract descriptors -> locate the PosterBoard container -> write.
    /// Runs entirely off the main thread: bad_query directory scans are heavy
    /// and froze the UI when executed synchronously.
    private func installTendies(from sourceURL: URL) {
        isInstalling = true
        phase = ""

        guard sourceURL.pathExtension.lowercased() == "tendies" else {
            phase = l10n.tr("pb.wrongext")
            manager.statusText = phase
            isInstalling = false
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let accessed = sourceURL.startAccessingSecurityScopedResource()
            defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }

            do {
                let data = try Data(contentsOf: sourceURL)

                try TendiesPackage.validate(data)

                let descriptorFolders = try TendiesPackage.extract(data)

                DispatchQueue.main.async { self.phase = "Mencari container PosterBoard..." }
                let appHash = try PosterBoardAccess.findPosterBoardHash()

                DispatchQueue.main.async { self.phase = "Menulis wallpaper..." }
                try PosterBoardAccess.writeDescriptors(appHash: appHash, descriptorFolders: descriptorFolders)

                DispatchQueue.main.async {
                    self.isInstalling = false
                    self.phase = "Wallpaper terpasang. Respring dalam 1 detik..."
                    self.reloadInstalled()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.manager.respringRequested = true
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isInstalling = false
                    self.manager.statusText = "Gagal: \(error.localizedDescription)"
                    self.phase = "Gagal: \(error.localizedDescription)"
                }
            }
        }
    }

    private func remove(_ name: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try PosterBoardAccess.removeWallpaper(named: name)
                DispatchQueue.main.async {
                    self.manager.statusText = "Wallpaper \(name) dihapus."
                    self.reloadInstalled()
                }
            } catch {
                DispatchQueue.main.async {
                    self.manager.statusText = "Gagal: \(error.localizedDescription)"
                }
            }
        }
    }

    private func reloadInstalled() {
        guard manager.sandboxGranted, PosterBoardAccess.isAvailable, !isLoadingWallpapers else { return }
        isLoadingWallpapers = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = (try? PosterBoardAccess.listInstalledWallpapers()) ?? []
            DispatchQueue.main.async {
                self.installedWallpapers = result
                self.isLoadingWallpapers = false
            }
        }
    }
}
