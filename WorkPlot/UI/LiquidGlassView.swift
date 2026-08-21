import SwiftUI

struct LiquidGlassView: View {
    @ObservedObject private var manager = ExploitManager.shared
    @State private var mode: LiquidGlassMode = .systemDefault
    @State private var sliderDisabled = false
    @State private var isApplying = false
    @State private var didLoadState = false

    var body: some View {
        NavigationView {
            Group {
                if !manager.sandboxGranted {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.icloud").font(.largeTitle).foregroundColor(.orange)
                        Text("Akses sistem belum aktif.\nBuka tab Status dan tekan \"Periksa Akses Sistem\".")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        Section(header: Text("Mode Render")) {
                            Picker("Mode", selection: $mode) {
                                ForEach(LiquidGlassMode.allCases) { m in
                                    Text(m.label).tag(m)
                                }
                            }
                            .pickerStyle(.inline)

                            let stateDescription: String = {
                                switch mode {
                                case .systemDefault:
                                    return "Menghapus override dan mengikuti nilai bawaan perangkat."
                                case .lowPerformanceOff:
                                    return "Liquid Glass dirender penuh (butuh GPU kuat, boros baterai)."
                                case .lowPerformanceOn:
                                    return "Efek glass disederhanakan untuk hemat performa."
                                }
                            }()
                            Text(stateDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Section(header: Text("Global"), footer: Text("Menonaktifkan Liquid Glass Slider secara global di seluruh sistem.")) {
                            Toggle("Matikan Liquid Glass", isOn: $sliderDisabled)
                        }

                        Section {
                            Button {
                                applyChanges()
                            } label: {
                                if isApplying {
                                    HStack { ProgressView(); Text("Menerapkan...") }
                                } else {
                                    Text("Apply")
                                }
                            }
                            .disabled(isApplying)

                            Button(role: .destructive) {
                                manager.respringRequested = true
                            } label: {
                                Label("Respring Sekarang", systemImage: "arrow.counterclockwise")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Liquid Glass")
            .onAppear(perform: loadCurrentState)
        }
    }

    private func loadCurrentState() {
        guard !didLoadState, let state = LiquidGlassController.currentState() else { return }
        mode = LiquidGlassMode.allCases.first {
            $0 != .systemDefault && $0.cacheExtraValue == state.cacheExtraValue
        } ?? .systemDefault
        sliderDisabled = state.sliderDisabled
        didLoadState = true
    }

    private func applyChanges() {
        isApplying = true
        defer { isApplying = false }

        guard LiquidGlassController.apply(mode: mode, sliderDisabled: sliderDisabled) else {
            manager.statusText = "Gagal menyimpan Liquid Glass."
            return
        }

        manager.statusText = "Liquid Glass diterapkan. Respring dalam 1 detik..."
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            manager.respringRequested = true
        }
    }
}
