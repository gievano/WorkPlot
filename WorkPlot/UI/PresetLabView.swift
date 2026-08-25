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
    @ObservedObject private var manager = WPExploitManager.shared
    @ObservedObject private var store = PresetStore.shared

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
                        Text("System access is locked. Grant the sandbox escape from Home.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        Section(
                            header: Text("Built-in Presets"),
                            footer: Text("Built-in presets stage known MobileGestalt key sets. A backup is created automatically before each write.")
                        ) {
                            ForEach(store.builtinPresets) { preset in
                                presetRow(preset)
                            }
                        }

                        Section(header: Text("Your Presets")) {
                            if store.userPresets.isEmpty {
                                Text("No saved presets yet.")
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
            .navigationTitle("Preset Lab")
            .wpGlassContainer()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingImporter = true
                    } label: {
                        Label("Import Preset File", systemImage: "square.and.arrow.down")
                    }
                }
            }
            .alert(
                "Apply Risky Preset",
                isPresented: Binding(
                    get: { pendingRiskyPreset != nil },
                    set: { if !$0 { pendingRiskyPreset = nil } }
                )
            ) {
                Button("Continue", role: .destructive) {
                    if let preset = pendingRiskyPreset {
                        applyPreset(preset)
                    }
                    pendingRiskyPreset = nil
                }
                Button("Cancel", role: .cancel) { pendingRiskyPreset = nil }
            } message: {
                Text("This preset writes risky keys to MobileGestalt. A backup is created first, but the change may affect system behavior.")
            }
            .alert(
                "Restart Recommended",
                isPresented: $showRestartAlert
            ) {
                Button("Respring") { manager.requestRespring() }
                Button("Later", role: .cancel) {}
            } message: {
                Text("Restart SpringBoard or reboot so the applied values take effect.")
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
                    manager.statusText = String(format: "Import failed: %@", error.localizedDescription)
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
                            Text("Risky").font(.caption2).bold()
                                .foregroundStyle(Theme.caution)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(Theme.caution.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                    Text("\(String(format: "by %@", preset.author)) · \(String(format: "%d keys", preset.values.count))")
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
            manager.statusText = "\(preset.name) OK. \("Restart Recommended")"
            showRestartAlert = true
        } else {
            manager.statusText = "Preset apply failed."
        }
    }

    /// Security-scoped access + JSON decode + persist into Documents/Preset.
    private func importPreset(from url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            let preset = try store.importData(data)
            manager.statusText = String(format: "Imported preset %@", preset.name)
        } catch {
            manager.statusText = "\("Import failed:") \(error.localizedDescription)"
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
