import SwiftUI

struct StatusDashboardView: View {
    @ObservedObject private var manager = ExploitManager.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var showRestartAlert = false
    @State private var customWidth = ""
    @State private var customHeight = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(l10n.tr("home.info"))) {
                    HStack { Text(l10n.tr("home.buildLabel")); Spacer(); Text(manager.osBuild.isEmpty ? "—" : manager.osBuild).foregroundColor(.blue) }
                    HStack { Text(l10n.tr("status.methodLabel")); Spacer(); Text(manager.exploitMethod.isEmpty ? "—" : manager.exploitMethod).foregroundColor(manager.sandboxGranted ? .green : .orange) }
                    HStack { Text(l10n.tr("home.statusLabel")); Spacer(); Text(manager.sandboxGranted ? l10n.tr("home.active") : l10n.tr("home.locked")).foregroundColor(manager.sandboxGranted ? .green : .orange) }
                    if manager.showsSigningHint {
                        Text(l10n.tr("status.signingHint"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Section(header: Text(l10n.tr("home.actionsHeader"))) {
                    Button(l10n.tr("status.rdarfix")) {
                        do {
                            // One-tap path: canvas dimensions via MobileGestalt
                            // (MainScreenCanvasSizes) - the plist locations the
                            // old probe targeted are unreachable on iOS 27.
                            let bounds = UIScreen.main.nativeBounds
                            try applyCanvas(width: Int(bounds.width),
                                            height: Int(bounds.height),
                                            label: l10n.tr("status.rdarfix"))
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
                    Button(l10n.tr("status.respring.refresh")) { manager.requestRespring() }
                }
                Section(header: Text(l10n.tr("rdar.custom.header")),
                        footer: Text(l10n.tr("rdar.custom.footer"))) {
                    HStack {
                        TextField(l10n.tr("rdar.custom.width"), text: $customWidth)
                            .keyboardType(.numberPad)
                        TextField(l10n.tr("rdar.custom.height"), text: $customHeight)
                            .keyboardType(.numberPad)
                    }
                    Button(l10n.tr("rdar.custom.apply")) {
                        guard let width = Int(customWidth), let height = Int(customHeight),
                              width > 0, height > 0 else {
                            manager.statusText = l10n.tr("rdar.custom.invalid")
                            return
                        }
                        do {
                            try applyCanvas(width: width, height: height,
                                            label: l10n.tr("rdar.custom.apply"))
                        } catch {
                            manager.statusText = String(format: l10n.tr("common.failPrefix"), error.localizedDescription)
                        }
                    }
                    .disabled(!manager.sandboxGranted)
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
            // Canvas tweaks are read at boot time, so a respring is not
            // enough - offer the full escalation flow (respring/userspace/
            // full restart with honest manual guidance).
            .heavyRestartFlow(isPresented: $showRestartAlert)
        }
    }

    /// Applies canvas sizes through the gestalt route, then reads the plist
    /// back from disk and compares bytes. A write the system silently drops
    /// now reports "not visible on disk" instead of a false OK.
    private func applyCanvas(width: Int, height: Int, label: String) throws {
        guard var plist = manager.readGestalt() else {
            throw RDARFixError(message: L10n.shared.tr("common.readFail"))
        }
        RDARFix.applyCanvasSizesGestalt(to: &plist, canvasWidth: width, canvasHeight: height)
        try manager.saveGestaltOrThrow(plist)

        let verified = manager.readGestalt().map {
            RDARFix.verifyCanvasSizesGestalt(in: $0, canvasWidth: width, canvasHeight: height)
        } ?? false

        if verified {
            manager.statusText = "\(label) OK (\(width)x\(height)). \(l10n.tr("restart.rec.title"))"
            SessionLogger.shared.log("rdar canvas \(width)x\(height) applied and verified on disk")
            showRestartAlert = true
        } else {
            manager.statusText = "\(label): \(l10n.tr("rdar.verify.fail"))"
            SessionLogger.shared.log("rdar canvas \(width)x\(height): write not visible on disk after save")
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
