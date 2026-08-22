import SwiftUI

struct LiquidGlassView: View {
    @ObservedObject private var manager = ExploitManager.shared
    @State private var mode: LiquidGlassMode = .systemDefault
    @State private var sliderDisabled = false
    @State private var isApplying = false
    @State private var showRestartAlert = false
    @State private var didLoadState = false
    @State private var loadError: String?

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
                        if let loadError {
                            Section {
                                Text(loadError)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }

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

                        Section(header: Text(L10n.shared.tr("lg.section.global")), footer: Text(L10n.shared.tr("lg.globalFooter"))) {
                            Toggle(L10n.shared.tr("lg.toggle.disable"), isOn: $sliderDisabled)
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
                            .disabled(isApplying)

                            Button(role: .destructive) {
                                manager.respringRequested = true
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
                Button(L10n.shared.tr("siriai.restart.respring")) { manager.respringRequested = true }
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
        guard let state = LiquidGlassController.currentState() else {
            loadError = L10n.shared.tr("lg.state.loadFail")
            return
        }
        mode = LiquidGlassMode.allCases.first {
            $0 != .systemDefault && $0.cacheExtraValue == state.cacheExtraValue
        } ?? .systemDefault
        sliderDisabled = state.sliderDisabled
    }

    private func applyChanges() {
        isApplying = true
        let mode = mode
        let sliderDisabled = sliderDisabled

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try LiquidGlassController.apply(mode: mode, sliderDisabled: sliderDisabled)
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
}
