//
//  PresetLabView.swift
//  WorkPlot
//
//  Applies built-in and user presets in one MobileGestalt pass. Risky
//  presets require explicit confirmation, mirroring the Siri AI spoof flow.
//

import SwiftUI
import UniformTypeIdentifiers

struct PresetLabView: View {
    @ObservedObject private var manager = ExploitManager.shared
    @ObservedObject private var store = PresetStore.shared
    @ObservedObject private var l10n = L10n.shared

    @State private var pendingRiskyPreset: WorkPlotPreset?
    @State private var showRestartAlert = false
    @State private var isShowingImporter = false
    @State private var sharedExportURL: IdentifiableURL?

    struct IdentifiableURL: Identifiable {
        let url: URL
        var id: URL { url }
    }

    var body: some View {
        NavigationView {
            Group {
                if !manager.sandboxGranted {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.icloud").font(.largeTitle).foregroundColor(.orange)
                        Text(l10n.tr("common.accessLocked"))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        Section(
                            header: Text(l10n.tr("preset.builtinHeader")),
                            footer: Text(l10n.tr("preset.footer"))
                        ) {
                            ForEach(store.builtinPresets) { preset in
                                presetRow(preset)
                            }
                        }

                        Section(header: Text(l10n.tr("preset.userHeader"))) {
                            if store.userPresets.isEmpty {
                                Text(l10n.tr("preset.userEmpty"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            ForEach(store.userPresets) { preset in
                                presetRow(preset)
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    store.remove(store.userPresets[index])
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(l10n.tr("preset.title"))
            .workPlotScrollBackground()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingImporter = true
                    } label: {
                        Label(l10n.tr("preset.importFile"), systemImage: "square.and.arrow.down")
                    }
                }
            }
            .alert(
                l10n.tr("preset.confirm.title"),
                isPresented: Binding(
                    get: { pendingRiskyPreset != nil },
                    set: { if !$0 { pendingRiskyPreset = nil } }
                )
            ) {
                Button(l10n.tr("danger.spoof.continue"), role: .destructive) {
                    if let preset = pendingRiskyPreset {
                        applyPreset(preset)
                    }
                    pendingRiskyPreset = nil
                }
                Button(l10n.tr("common.cancel"), role: .cancel) { pendingRiskyPreset = nil }
            } message: {
                Text(l10n.tr("preset.confirm.message"))
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
            .fileImporter(
                isPresented: $isShowingImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first { importPreset(from: url) }
                case .failure(let error):
                    manager.statusText = "Gagal impor: \(error.localizedDescription)"
                }
            }
            .sheet(item: $sharedExportURL) { item in
                ActivityShareSheet(items: [item.url])
            }
        }
    }

    private func presetRow(_ preset: WorkPlotPreset) -> some View {
        Button {
            if preset.risky {
                pendingRiskyPreset = preset
            } else {
                applyPreset(preset)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(preset.name)
                        if preset.risky {
                            Text(l10n.tr("common.risky")).font(.caption2).bold()
                                .foregroundColor(.red)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(Color.red.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                    Text("\(String(format: l10n.tr("preset.author"), preset.author)) · \(String(format: l10n.tr("preset.keysCount"), preset.values.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    if let url = try? store.exportURL(for: preset) {
                        sharedExportURL = IdentifiableURL(url: url)
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.borderless)
            }
        }
        .buttonStyle(.plain)
    }

    private func applyPreset(_ preset: WorkPlotPreset) {
        if store.apply(preset) {
            manager.statusText = "\(preset.name) OK. \(l10n.tr("restart.rec.title"))"
            showRestartAlert = true
        } else {
            manager.statusText = l10n.tr("preset.applyFailed")
        }
    }

    /// Security-scoped access + JSON decode + persist into Documents/Preset.
    private func importPreset(from url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            let preset = try store.importData(data)
            manager.statusText = String(format: l10n.tr("preset.importOk"), preset.name)
        } catch {
            manager.statusText = "\(l10n.tr("preset.importFail")) \(error.localizedDescription)"
        }
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
