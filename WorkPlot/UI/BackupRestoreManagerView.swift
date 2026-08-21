import SwiftUI
import UniformTypeIdentifiers

struct BackupRestoreManagerView: View {
    @ObservedObject private var manager = ExploitManager.shared
    @State private var isShowingImporter = false
    @State private var backupPendingRestore: GestaltBackup?

    var body: some View {
        NavigationView {
            Group {
                if manager.backups.isEmpty {
                    Text("Belum ada backup.\nTekan \"Periksa Akses Sistem\" di tab Status untuk memulai.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(manager.backups) { backup in
                            Button {
                                backupPendingRestore = backup
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(backup.name).font(.body)
                                    HStack {
                                        Text(backup.createdAt, style: .date)
                                        Text(backup.createdAt, style: .time)
                                        Spacer()
                                        ShareLink(item: backup.url) {
                                            Image(systemName: "square.and.arrow.up")
                                        }
                                        .buttonStyle(.borderless)
                                        Text(ByteCountFormatter.string(fromByteCount: backup.byteCount, countStyle: .file))
                                            .foregroundColor(.secondary)
                                    }
                                    .font(.caption)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                manager.delete(manager.backups[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("Backups")
            .scrollContentBackground(.hidden)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            createBackup()
                        } label: {
                            Label("Buat Backup Sekarang", systemImage: "plus.circle")
                        }
                        .disabled(!manager.sandboxGranted)

                        Button {
                            isShowingImporter = true
                        } label: {
                            Label("Impor Backup...", systemImage: "square.and.arrow.down")
                        }

                        EditButton()
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .fileImporter(
                isPresented: $isShowingImporter,
                allowedContentTypes: [.data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first { importBackup(from: url) }
                case .failure(let error):
                    manager.statusText = "Gagal impor: \(error.localizedDescription)"
                }
            }
            .confirmationDialog(
                "Restore \(backupPendingRestore?.name ?? "")?",
                isPresented: Binding(
                    get: { backupPendingRestore != nil },
                    set: { if !$0 { backupPendingRestore = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Restore", role: .destructive) {
                    if let backup = backupPendingRestore {
                        _ = manager.restore(backup)
                    }
                    backupPendingRestore = nil
                }
                Button("Batal", role: .cancel) { backupPendingRestore = nil }
            } message: {
                Text("Kondisi saat ini akan dibackup otomatis dulu, jadi restore bisa dibatalkan.")
            }
            .onAppear { manager.refreshBackups() }
        }
    }

    private func createBackup() {
        guard let data = manager.readGestaltData() else {
            manager.statusText = "Gagal: tidak dapat membaca MobileGestalt."
            return
        }
        do {
            _ = try GestaltBackupStore.create(from: data)
            manager.refreshBackups()
            manager.statusText = "Backup berhasil dibuat."
        } catch {
            manager.statusText = "Gagal membuat backup: \(error.localizedDescription)"
        }
    }

    private func importBackup(from url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            var format = PropertyListSerialization.PropertyListFormat.binary
            guard let dictionary = try PropertyListSerialization.propertyList(
                from: data, options: [], format: &format) as? [String: Any],
                  dictionary["CacheExtra"] is [String: Any] else {
                throw PlistValueError.invalid("File bukan MobileGestalt plist yang valid (CacheExtra tidak ditemukan).")
            }
            _ = try GestaltBackupStore.create(from: data)
            manager.refreshBackups()
            manager.statusText = "Backup \(url.lastPathComponent) diimpor."
        } catch {
            manager.statusText = "Gagal impor: \(error.localizedDescription)"
        }
    }
}
