import SwiftUI

struct LiquidGlassView: View {
    @ObservedObject private var manager = ExploitManager.shared
    @State private var mode: LiquidGlassMode = .systemDefault
    @State private var isApplying = false
    @State private var isDisabling = false
    @State private var showRestartAlert = false
    @State private var didLoadState = false

    var body: some View {
        NavigationView {
            Group {
                if !manager.sandboxGranted {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.icloud").font(.largeTitle).foregroundColor(.orange)
                        Text(L10n.shared.tr("common.accessLocked"))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        Section(header: Text(L10n.shared.tr("lg.renderMode"))) {
                            Picker(L10n.shared.tr("lg.renderMode"), selection: $mode) {
                                ForEach(LiquidGlassMode.allCases) { m in
                                    Text(m.label).tag(m)
                                }
                            }
                            .pickerStyle(.inline)

                            Text(L10n.shared.tr(mode.descriptionKey))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Section {
                            Button {
                                applyChanges()
                            } label: {
                                if isApplying {
                                    HStack { ProgressView(); Text(L10n.shared.tr("common.applying")) }
                                } else {
                                    Text(L10n.shared.tr("common.apply"))
                                }
                            }
                            .disabled(isApplying || isDisabling)

                            Button {
                                disableGlobally()
                            } label: {
                                if isDisabling {
                                    HStack { ProgressView(); Text(L10n.shared.tr("common.working")) }
                                } else {
                                    Text(L10n.shared.tr("status.lg.disable"))
                                }
                            }
                            .disabled(isDisabling || isApplying || !manager.sandboxGranted)

                            Button(role: .destructive) {
                                manager.requestRespring()
                            } label: {
                                Label(L10n.shared.tr("status.respring.refresh"), systemImage: "arrow.counterclockwise")
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.shared.tr("tab.liquidglass"))
            .workPlotScrollBackground()
            .alert(
                L10n.shared.tr("restart.rec.title"),
                isPresented: $showRestartAlert
            ) {
                Button(L10n.shared.tr("siriai.restart.respring")) { manager.requestRespring() }
                Button(L10n.shared.tr("siriai.restart.later"), role: .cancel) {}
            } message: {
                Text(L10n.shared.tr("restart.rec.message"))
            }
            .onAppear(perform: loadCurrentState)
        }
    }

    private func loadCurrentState() {
        guard !didLoadState else { return }
        didLoadState = true
        mode = LiquidGlassController.currentMode()
    }

    private func applyChanges() {
        guard !isApplying else { return }
        isApplying = true
        let mode = mode

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try LiquidGlassController.apply(mode: mode)
                DispatchQueue.main.async {
                    self.isApplying = false
                    self.manager.statusText = "\(L10n.shared.tr("lg.applied")) \(L10n.shared.tr("restart.rec.title"))"
                    self.showRestartAlert = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.isApplying = false
                    self.manager.statusText = String(
                        format: L10n.shared.tr("common.failPrefix"),
                        error.localizedDescription
                    )
                }
            }
        }
    }

    private func disableGlobally() {
        guard !isDisabling else { return }
        isDisabling = true

        // GlobalPreferences writes are synchronous bad_query filesystem work,
        // same off-main-thread rule as applyChanges.
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let lines = try LiquidGlassController.disableGlobal()
                DispatchQueue.main.async {
                    self.isDisabling = false
                    self.manager.statusText = L10n.shared.tr("lg.disabled") + "\n" + lines.joined(separator: "\n")
                    self.mode = LiquidGlassController.currentMode()
                    self.showRestartAlert = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.isDisabling = false
                    self.manager.statusText = String(
                        format: L10n.shared.tr("common.failPrefix"),
                        error.localizedDescription
                    )
                }
            }
        }
    }
}
