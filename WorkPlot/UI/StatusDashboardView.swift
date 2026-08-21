import SwiftUI

struct StatusDashboardView: View {
    @ObservedObject private var manager = ExploitManager.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var showRestartAlert = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(l10n.tr("tab.status"))) {
                    HStack { Text("Build"); Spacer(); Text(manager.osBuild.isEmpty ? "—" : manager.osBuild).foregroundColor(.blue) }
                    HStack { Text("Status"); Spacer(); Text(manager.sandboxGranted ? "Aktif" : "Terkunci").foregroundColor(manager.sandboxGranted ? .green : .orange) }
                }
                Section(header: Text("Aksi")) {
                    Button(l10n.tr("status.checkaccess")) { _ = manager.checkSystemPathAccess() }
                    Button(l10n.tr("status.rdarfix")) {
                        do {
                            try RDARFix.apply()
                            manager.statusText = "\(l10n.tr("status.rdarfix")) OK. \(l10n.tr("restart.rec.title"))"
                            showRestartAlert = true
                        } catch {
                            manager.statusText = "Gagal: \(error.localizedDescription)"
                        }
                    }
                    .disabled(!manager.sandboxGranted)
                    Button(l10n.tr("status.lg.disable")) {
                        manager.statusText = LiquidGlassController.disableGlobal()
                            ? "Liquid Glass dinonaktifkan."
                            : "Liquid Glass gagal dinonaktifkan."
                        if manager.statusText.hasPrefix("Liquid Glass dinonaktifkan") {
                            showRestartAlert = true
                        }
                    }
                    .disabled(!manager.sandboxGranted)
                    // Respring tetap di menu utama: fungsinya menyegarkan UI saja.
                    Button(l10n.tr("status.respring.refresh")) { manager.respringRequested = true }

                    Button {
                        showBackgroundPicker = true
                    } label: {
                        Label(l10n.tr("bg.pick"), systemImage: "photo")
                    }
                }
                Section(header: Text(l10n.tr("credits.header"))) {
                    Link("gievano", destination: URL(string: "https://github.com/gievano")!)
                    Link("Adnan 120Hz", destination: URL(string: "https://github.com/adnan120hz")!)
                    Text(l10n.tr("credits.disclaimer"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Section(header: Text("Log")) {
                    Text(manager.statusText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(manager.statusText.hasPrefix("Gagal") ? .orange : .green)
                }
            }
            .navigationTitle("work.plot")
            .scrollContentBackground(.hidden)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    MainDashboardSettingsMenu()
                }
            }
            .alert(
                l10n.tr("restart.rec.title"),
                isPresented: $showRestartAlert
            ) {
                Button(l10n.tr("siriai.restart.respring")) { manager.respringRequested = true }
                Button(l10n.tr("siriai.restart.later"), role: .cancel) {}
            } message: {
                Text(l10n.tr("restart.rec.message"))
            }
            .sheet(isPresented: $showBackgroundPicker) {
                BackgroundPickerSheet()
            }
        }
    }

    @State private var showBackgroundPicker = false
}

struct MainDashboardSettingsMenu: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue
    @State private var showBackgroundPicker = false

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

            Button {
                showBackgroundPicker = true
            } label: {
                Label(l10n.tr("bg.pick"), systemImage: "photo")
            }
        } label: {
            Image(systemName: "gearshape.fill")
        }
        .sheet(isPresented: $showBackgroundPicker) {
            BackgroundPickerSheet()
        }
    }
}
