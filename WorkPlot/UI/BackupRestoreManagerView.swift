import SwiftUI
import UniformTypeIdentifiers

struct BackupRestoreManagerView: View {
    @ObservedObject private var manager = ExploitManager.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var isShowingImporter = false
    @State private var backupPendingRestore: GestaltBackup?

    var body: some View {
        NavigationView {
            Group {
                if manager.backups.isEmpty {
                    Text(L10n.shared.tr("backup.empty"))
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
            .navigationTitle(l10n.tr("tab.backups"))
            .workPlotScrollBackground()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            createBackup()
                        } label: {
                            Label(l10n.tr("backup.create"), systemImage: "plus.circle")
                        }
                        .disabled(!manager.sandboxGranted)

                        Button {
                            isShowingImporter = true
                        } label: {
                            Label(l10n.tr("backup.importMenu"), systemImage: "square.and.arrow.down")
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
                String(format: l10n.tr("backup.restoreConfirm"), backupPendingRestore?.name ?? ""),
                isPresented: Binding(
                    get: { backupPendingRestore != nil },
                    set: { if !$0 { backupPendingRestore = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button(l10n.tr("pb.apply"), role: .destructive) {
                    if let backup = backupPendingRestore {
                        if manager.restore(backup) {
                            manager.statusText = l10n.tr("backup.restoreOk")
                            manager.respringRequested = true
                        }
                    }
                    backupPendingRestore = nil
                }
                Button(l10n.tr("common.cancel"), role: .cancel) { backupPendingRestore = nil }
            } message: {
                Text(l10n.tr("backup.restoreMsg"))
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
