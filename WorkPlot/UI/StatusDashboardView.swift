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
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.cardSpacing) {
                    hero
                    infoCard
                    actionsCard
                    canvasCard
                    logCard
                }
                .padding(18)
                .padding(.bottom, 24)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .wpGlassContainer()
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

    // MARK: - Sections

    private var hero: some View {
        HStack(spacing: 14) {
            Image(systemName: "wand.and.stars.inverse")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.55)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("WorkPlot").font(.title.bold())
                Text("Status & quick actions").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            statusPill
        }
        .padding(18)
        .liquidGlass(cornerRadius: 22)
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(manager.sandboxGranted ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(manager.sandboxGranted ? l10n.tr("home.active") : l10n.tr("home.locked"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(manager.sandboxGranted ? .green : .orange)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .liquidGlass(cornerRadius: 12)
    }

    private var infoCard: some View {
        WPCard {
            VStack(alignment: .leading, spacing: 12) {
                WPSectionHeader(title: l10n.tr("home.info"))
                WPInfoRow(
                    label: l10n.tr("home.buildLabel"),
                    value: manager.osBuild.isEmpty ? "—" : manager.osBuild,
                    valueColor: .blue
                )
                WPInfoRow(
                    label: l10n.tr("status.methodLabel"),
                    value: manager.exploitMethod.isEmpty ? "—" : manager.exploitMethod,
                    valueColor: manager.sandboxGranted ? .green : .orange
                )
                WPInfoRow(
                    label: l10n.tr("home.statusLabel"),
                    value: manager.sandboxGranted ? l10n.tr("home.active") : l10n.tr("home.locked"),
                    valueColor: manager.sandboxGranted ? .green : .orange
                )
                if manager.showsSigningHint {
                    Text(l10n.tr("status.signingHint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var actionsCard: some View {
        WPCard {
            VStack(alignment: .leading, spacing: 12) {
                WPSectionHeader(title: l10n.tr("home.actionsHeader"))
                WPActionButton(title: l10n.tr("status.rdarfix")) { runFixRDAR() }
                    .disabled(!manager.sandboxGranted)
                // Respring tetap di menu utama: fungsinya menyegarkan UI saja.
                WPActionButton(title: l10n.tr("status.respring.refresh"), prominent: false) {
                    manager.requestRespring()
                }
            }
        }
    }

    private var canvasCard: some View {
        WPCard {
            VStack(alignment: .leading, spacing: 12) {
                WPSectionHeader(
                    title: l10n.tr("rdar.custom.header"),
                    subtitle: l10n.tr("rdar.custom.footer")
                )
                HStack(spacing: 12) {
                    TextField(l10n.tr("rdar.custom.width"), text: $customWidth)
                        .keyboardType(.numberPad)
                        .padding(12)
                        .liquidGlass(cornerRadius: 12)
                    TextField(l10n.tr("rdar.custom.height"), text: $customHeight)
                        .keyboardType(.numberPad)
                        .padding(12)
                        .liquidGlass(cornerRadius: 12)
                }
                WPActionButton(title: l10n.tr("rdar.custom.apply"), prominent: false) { applyCanvas() }
                    .disabled(!manager.sandboxGranted || isWorking)
            }
        }
    }

    private var logCard: some View {
        WPCard {
            VStack(alignment: .leading, spacing: 10) {
                WPSectionHeader(title: l10n.tr("home.log"))
                Text(manager.statusText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(
                        manager.statusText.hasPrefix(l10n.failPrefix)
                            || manager.statusText.contains("failed (")
                            || manager.statusText.contains("not visible on disk") ? .orange : .green
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Canvas

    private func applyCanvas() {
        guard let width = Int(customWidth), let height = Int(customHeight),
              width > 0, height > 0 else {
            manager.statusText = l10n.tr("rdar.custom.invalid")
            return
        }
        applyCanvasEveryRoute(width: width, height: height, note: nil)
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
        if let fixed = RDARFix.fixCanvas(machine: machine) {
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
