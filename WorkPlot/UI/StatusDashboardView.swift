import SwiftUI

struct StatusDashboardView: View {
    @ObservedObject private var manager = ExploitManager.shared

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Informasi Sistem")) {
                    HStack { Text("Build"); Spacer(); Text(manager.osBuild.isEmpty ? "—" : manager.osBuild).foregroundColor(.blue) }
                    HStack { Text("Status"); Spacer(); Text(manager.sandboxGranted ? "Aktif" : "Terkunci").foregroundColor(manager.sandboxGranted ? .green : .orange) }
                }
                Section(header: Text("Aksi")) {
                    Button("Periksa Akses Sistem") { _ = manager.checkSystemPathAccess() }
                    Button("Perbaiki RDAR") {
                        manager.statusText = RDARFix.apply() ? "RDAR Fix diterapkan." : "RDAR Fix gagal."
                    }
                    Button("Matikan Liquid Glass") {
                        manager.statusText = LiquidGlassController.disableGlobal()
                            ? "Liquid Glass dinonaktifkan."
                            : "Liquid Glass gagal dinonaktifkan."
                    }
                    Button("Restart Device") { manager.restartDevice() }
                        .disabled(!manager.sandboxGranted)
                }
                Section(header: Text("Log")) {
                    Text(manager.statusText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(manager.statusText.hasPrefix("Gagal") ? .orange : .green)
                }
            }
            .navigationTitle("work.plot")
        }
    }
}
