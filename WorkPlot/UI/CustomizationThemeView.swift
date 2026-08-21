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

    var body: some View {
        NavigationView {
            Group {
                if !manager.sandboxGranted {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.icloud").font(.largeTitle).foregroundColor(.orange)
                        Text("Akses sistem belum aktif.\nBuka tab Status dan tekan \"Periksa Akses Sistem\".")
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
                if installedWallpapers.isEmpty {
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
    private func installTendies(from sourceURL: URL) {
        isInstalling = true
        defer { isInstalling = false }

        guard sourceURL.pathExtension.lowercased() == "tendies" else {
            phase = l10n.tr("pb.wrongext")
            manager.statusText = phase
            return
        }

        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }

        do {
            phase = "Membaca paket..."
            let data = try Data(contentsOf: sourceURL)

            phase = "Validasi struktur..."
            try TendiesPackage.validate(data)

            phase = "Ekstrak descriptor..."
            let descriptorFolders = try TendiesPackage.extract(data)

            phase = "Mencari container PosterBoard..."
            let appHash = try PosterBoardAccess.findPosterBoardHash()

            phase = "Menulis wallpaper..."
            try PosterBoardAccess.writeDescriptors(appHash: appHash, descriptorFolders: descriptorFolders)

            phase = "Wallpaper terpasang. Respring dalam 1 detik..."
            reloadInstalled()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                manager.respringRequested = true
            }
        } catch {
            manager.statusText = "Gagal: \(error.localizedDescription)"
            phase = "Gagal: \(error.localizedDescription)"
        }
    }

    private func remove(_ name: String) {
        do {
            try PosterBoardAccess.removeWallpaper(named: name)
            manager.statusText = "Wallpaper \(name) dihapus."
            reloadInstalled()
        } catch {
            manager.statusText = "Gagal: \(error.localizedDescription)"
        }
    }

    private func reloadInstalled() {
        guard PosterBoardAccess.isAvailable else { return }
        installedWallpapers = (try? PosterBoardAccess.listInstalledWallpapers()) ?? []
    }
}
