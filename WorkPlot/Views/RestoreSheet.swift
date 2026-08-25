import SwiftUI

struct RestoreSheet: View {
    @EnvironmentObject private var store: GestaltStore
    @Environment(\.dismiss) private var dismiss
    @State private var done = false
    @State private var showConfirm = false
    @State private var isRestoring = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .center) {
                    Image(systemName: done ? "checkmark" : "arrow.counterclockwise")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(done ? Theme.affirmative : .white)
                        .frame(width: 52, height: 52)
                        .background((done ? Theme.affirmative : .white).opacity(0.13), in: Circle())
                    Spacer()
                    Text(done ? "COMPLETE" : "RECOVERY")
                        .font(.caption2.weight(.bold))
                        .tracking(0.9)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(done ? "Original file restored" : "Return to baseline")
                        .font(.title2.weight(.semibold))
                    Text(done ? "Restart your device to complete the recovery." : "Replace the edited MobileGestalt cache with the pristine file captured before your first change.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if let info = store.backup.info {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("RECOVERY POINT")
                            .font(.caption2.weight(.bold))
                            .tracking(0.7)
                            .foregroundStyle(.secondary)
                        Text(info.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.body.weight(.medium))
                        Text(ByteCountFormatter.string(fromByteCount: Int64(info.byteCount), countStyle: .file))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Theme.destructive)
                }
                Spacer()
                if !done && errorMessage == nil {
                    ActionButton(title: "Restore recovery point", systemImage: "arrow.counterclockwise", isBusy: isRestoring) {
                        showConfirm = true
                    }
                }
            }
            .padding(Theme.pagePadding)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .confirmationDialog("Restore recovery point", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Restore", role: .destructive, action: runRestore)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This replaces the current MobileGestalt cache with your pristine backup. Keep the device powered until it finishes.")
        }
    }

    private func runRestore() {
        errorMessage = nil
        isRestoring = true
        Task {
            do {
                _ = try await store.restore()
                isRestoring = false
                done = true
            } catch {
                isRestoring = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
