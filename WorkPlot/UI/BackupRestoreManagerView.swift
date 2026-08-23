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
                            if let stock = manager.backups.first(where: { $0.name == "Stock Snapshot" }) {
                                backupPendingRestore = stock
                            }
                        } label: {
                            Label(l10n.tr("backup.revertStock"), systemImage: "arrow.uturn.backward.circle")
                        }
                        .disabled(!manager.sandboxGranted || !manager.backups.contains { $0.name == "Stock Snapshot" })

                        Button {
                            do {
                                try RDARFix.restoreOriginalCanvas()
                                manager.statusText = "\(l10n.tr("rdar.restoreCanvas")) OK. \(l10n.tr("restart.rec.title"))"
                                manager.requestRespring()
                                SessionLogger.shared.log("rdar original canvas restored")
                            } catch {
                                manager.statusText = String(format: l10n.tr("common.failPrefix"), error.localizedDescription)
                                SessionLogger.shared.log("rdar canvas restore failed: \(error.localizedDescription)")
                            }
                        } label: {
                            Label(l10n.tr("rdar.restoreCanvas"), systemImage: "photo")
                        }

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
                    manager.statusText = String(format: l10n.tr("common.importFailedDetail"), error.localizedDescription)
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
                            manager.requestRespring()
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
            manager.statusText = L10n.shared.tr("common.readFail")
            return
        }
        do {
            _ = try GestaltBackupStore.create(from: data)
            manager.refreshBackups()
            manager.statusText = L10n.shared.tr("backup.createOk")
        } catch {
            manager.statusText = String(format: L10n.shared.tr("backup.createFail"), error.localizedDescription)
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
                throw PlistValueError.invalid(L10n.shared.tr("backup.invalidFile"))
            }
            _ = try GestaltBackupStore.create(from: data)
            manager.refreshBackups()
            manager.statusText = String(format: L10n.shared.tr("backup.importedOk"), url.lastPathComponent)
        } catch {
            manager.statusText = String(format: L10n.shared.tr("common.importFailedDetail"), error.localizedDescription)
        }
    }
}
