import SwiftUI

struct BackupRestoreManagerView: View {
    @ObservedObject private var manager = ExploitManager.shared

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
                                _ = manager.restore(backup)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(backup.name).font(.body)
                                    HStack {
                                        Text(backup.createdAt, style: .date)
                                        Text(backup.createdAt, style: .time)
                                        Spacer()
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .onAppear { manager.refreshBackups() }
        }
    }
}
