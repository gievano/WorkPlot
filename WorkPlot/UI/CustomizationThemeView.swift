import SwiftUI

struct PosterBoardLabView: View {
    @ObservedObject private var manager = ExploitManager.shared

    @State private var isShowingImporter = false
    @State private var isInstalling = false
    @State private var phase = ""

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

                        Section {
                            Button {
                                manager.respringRequested = true
                            } label: {
                                Label("Respring", systemImage: "arrow.counterclockwise")
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.shared.tr("tab.posterboard"))
            .scrollContentBackground(.hidden)
            .fileImporter(
                isPresented: $isShowingImporter,
                allowedContentTypes: [.data],
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
        }
    }

    /// Pipeline: copy out of the security scope → validate ZIP & structure →
    /// extract descriptors → locate the PosterBoard container → write.
    private func installTendies(from sourceURL: URL) {
        isInstalling = true
        defer { isInstalling = false }

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
            manager.statusText = "Wallpaper \(sourceURL.lastPathComponent) terpasang."
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                manager.respringRequested = true
            }
        } catch {
            manager.statusText = "Gagal: \(error.localizedDescription)"
            phase = "Gagal: \(error.localizedDescription)"
        }
    }
}
