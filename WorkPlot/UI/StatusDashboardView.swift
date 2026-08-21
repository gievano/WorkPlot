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
                        do {
                            try RDARFix.apply()
                            manager.statusText = "RDAR Fix diterapkan. Respring dalam 1 detik..."
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                manager.respringRequested = true
                            }
                        } catch {
                            manager.statusText = "Gagal: \(error.localizedDescription)"
                        }
                    }
                    Button("Matikan Liquid Glass") {
                        manager.statusText = LiquidGlassController.disableGlobal()
                            ? "Liquid Glass dinonaktifkan."
                            : "Liquid Glass gagal dinonaktifkan."
                    }
                    Button("Respring (NeoSpring)") { manager.respringRequested = true }
                }
                Section(header: Text("Log")) {
                    Text(manager.statusText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(manager.statusText.hasPrefix("Gagal") ? .orange : .green)
                }
            }
            .navigationTitle("work.plot")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    MainDashboardSettingsMenu()
                }
            }
        }
    }
}

struct MainDashboardSettingsMenu: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue

    var body: some View {
        Menu {
            Picker(l10n.tr("settings.language"), selection: $l10n.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.label).tag(language)
                }
            }

            Picker(l10n.tr("settings.appearance"), selection: $appearanceMode) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(l10n.tr(mode.labelKey)).tag(mode.rawValue)
                }
            }
        } label: {
            Image(systemName: "gearshape.fill")
        }
    }
}
