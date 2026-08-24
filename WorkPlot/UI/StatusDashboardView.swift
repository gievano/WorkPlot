import SwiftUI

struct StatusDashboardView: View {
    @ObservedObject private var manager = ExploitManager.shared
    @ObservedObject private var l10n = L10n.shared
    @State private var showRestartAlert = false
    @State private var isWorking = false
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
                        runFixRDAR()
                    }
                    .disabled(!manager.sandboxGranted)
                    Button(l10n.tr("status.lg.disable")) {
                        manager.statusText = L10n.shared.tr("common.working")
                        DispatchQueue.global(qos: .userInitiated).async {
                            do {
                                let lines = try LiquidGlassController.disableGlobal()
                                DispatchQueue.main.async {
                                    manager.statusText = L10n.shared.tr("lg.disabled") + "\n" + lines.joined(separator: "\n")
                                    showRestartAlert = true
                                }
                            } catch {
                                DispatchQueue.main.async {
                                    manager.statusText = String(format: l10n.tr("common.failPrefix"), error.localizedDescription)
                                }
                            }
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
                        applyCanvasEveryRoute(width: width, height: height, note: nil)
                    }
                    .disabled(!manager.sandboxGranted || isWorking)
                }
                Section(header: Text(l10n.tr("home.log"))) {
                    Text(manager.statusText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(manager.statusText.hasPrefix(l10n.failPrefix)
                                         || manager.statusText.contains("failed (")
                                         || manager.statusText.contains("not visible on disk") ? .orange : .green)
                }
            }
            .navigationTitle("WorkPlot")
            .workPlotScrollBackground()
            .scrollDismissesKeyboard(.immediately)
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

    /// One tap writes BOTH known canvas routes - MobileGestalt's
    /// MainScreenCanvasSizes and the classic IOMobileGraphicsFamily plist -
    /// then reports each result honestly. Which route this build honors is
    /// only visible after a full restart.
    private func applyCanvasEveryRoute(width: Int, height: Int, note: String?) {
        guard !isWorking else { return }
        isWorking = true
        manager.statusText = L10n.shared.tr("common.working")

        // All Gestalt + bad_query filesystem work is synchronous and can probe
        // dozens of containers, so it must run off the main thread or the UI
        // freezes (the same pattern LiquidGlassView.applyChanges uses).
        DispatchQueue.global(qos: .userInitiated).async {
            var lines: [String] = []

            do {
                guard var plist = self.manager.readGestalt() else {
                    throw RDARFixError(message: L10n.shared.tr("common.readFail"))
                }
                RDARFix.applyCanvasSizesGestalt(to: &plist, canvasWidth: width, canvasHeight: height)
                try self.manager.saveGestaltOrThrow(plist)
                let verified = self.manager.readGestalt().map {
                    RDARFix.verifyCanvasSizesGestalt(in: $0, canvasWidth: width, canvasHeight: height)
                } ?? false
                lines.append(verified ? "Gestalt: written and verified on disk"
                                      : "Gestalt: \(L10n.shared.tr("rdar.verify.fail"))")
            } catch {
                lines.append("Gestalt: failed (\(error.localizedDescription))")
            }

            do {
                switch try RDARFix.apply(canvasWidth: width, canvasHeight: height) {
                case .applied: lines.append("Graphics plist: patched")
                case .alreadyFixed: lines.append("Graphics plist: already set")
                }
            } catch {
                lines.append("Graphics plist: failed (\(error.localizedDescription))")
            }

            let result = "\(self.l10n.tr("rdar.custom.apply")) (\(width)x\(height))\n"
                + lines.joined(separator: "\n")
                + "\nFull restart required - respring does NOT apply canvas."
                + (note.map { "\n\($0)" } ?? "")
            SessionLogger.shared.log("canvas \(width)x\(height): \(lines.joined(separator: " | "))")

            DispatchQueue.main.async {
                self.manager.statusText = result
                self.showRestartAlert = true
                self.isWorking = false
            }
        }
    }

    /// Never trust UIScreen for the one-tap fix: during an active RDAR state
    /// nativeBounds reports the broken canvas, and Display Zoom reports the
    /// zoomed buffer - either written back keeps the screen broken.
    private func runFixRDAR() {
        let machine = DeviceCapability.machineIdentifier
        let width: Int
        let height: Int
        let note: String?
        if let fixed = RDARFix.knownGoodNativeCanvas(machine: machine) {
            width = fixed.width
            height = fixed.height
            note = nil
        } else {
            let bounds = UIScreen.main.nativeBounds
            width = Int(bounds.width)
            height = Int(bounds.height)
            note = "Unknown device (\(machine)) - using reported screen bounds."
        }
        applyCanvasEveryRoute(width: width, height: height, note: note)
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
