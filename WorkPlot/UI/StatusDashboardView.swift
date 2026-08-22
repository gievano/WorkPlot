import SwiftUI

struct StatusDashboardView: View {
    @ObservedObject private var manager = ExploitManager.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var showRestartAlert = false

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(l10n.tr("home.info"))) {
                    HStack { Text(l10n.tr("home.buildLabel")); Spacer(); Text(manager.osBuild.isEmpty ? "—" : manager.osBuild).foregroundColor(.blue) }
                    HStack { Text(l10n.tr("home.statusLabel")); Spacer(); Text(manager.sandboxGranted ? l10n.tr("home.active") : l10n.tr("home.locked")).foregroundColor(manager.sandboxGranted ? .green : .orange) }
                }
                Section(header: Text(l10n.tr("home.actionsHeader"))) {
                    Button(l10n.tr("status.rdarfix")) {
                        do {
                            try RDARFix.apply()
                            manager.statusText = "\(l10n.tr("status.rdarfix")) OK. \(l10n.tr("restart.rec.title"))"
                            showRestartAlert = true
                        } catch {
                            manager.statusText = String(format: l10n.tr("common.failPrefix"), error.localizedDescription)
                        }
                    }
                    .disabled(!manager.sandboxGranted)
                    Button(l10n.tr("status.lg.disable")) {
                        do {
                            try LiquidGlassController.disableGlobal()
                            manager.statusText = L10n.shared.tr("lg.disabled")
                            showRestartAlert = true
                        } catch {
                            manager.statusText = String(format: l10n.tr("common.failPrefix"), error.localizedDescription)
                        }
                    }
                    .disabled(!manager.sandboxGranted)
                    // Respring tetap di menu utama: fungsinya menyegarkan UI saja.
                    Button(l10n.tr("status.respring.refresh")) { manager.respringRequested = true }
                }
                Section(header: Text(l10n.tr("home.log"))) {
                    Text(manager.statusText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(manager.statusText.hasPrefix(l10n.failPrefix) ? .orange : .green)
                }
            }
            .navigationTitle("WorkPlot")
            .workPlotScrollBackground()
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
        }
    }
}

struct MainDashboardSettingsMenu: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue
    @State private var showIconSwitcher = false

    var body: some View {
        Menu {
            Picker(l10n.tr("settings.appearance"), selection: $appearanceMode) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(l10n.tr(mode.labelKey)).tag(mode.rawValue)
                }
            }

            Button {
                showIconSwitcher = true
            } label: {
                Label(l10n.tr("icon.menu"), systemImage: "paintbrush")
            }
        } label: {
            Image(systemName: "gearshape.fill")
        }
        .sheet(isPresented: $showIconSwitcher) {
            AppIconSwitcherSheet()
        }
    }
}
