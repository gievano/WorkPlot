//
//  CacheCleanerView.swift
//  WorkPlot
//
//  Per-app cache detail: shows the measured Library/Caches footprint and
//  wipes its contents through AppContainerScanner inside a bad_query lease.
//

import SwiftUI

struct CacheCleanerView: View {
    let app: AppContainerInfo

    @ObservedObject private var manager = ExploitManager.shared
    @ObservedObject private var l10n = L10n.shared

    @State private var cacheBytes: Int64?
    @State private var isMeasuring = true
    @State private var isCleaning = false
    @State private var confirmClean = false

    private var byteString: String {
        ByteCountFormatter.string(fromByteCount: cacheBytes ?? 0, countStyle: .file)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.bundleID)
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                    Text(app.rootPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
            Section {
                HStack {
                    Image(systemName: "internaldrive")
                        .foregroundColor(.secondary)
                    if isMeasuring {
                        ProgressView()
                    } else if (cacheBytes ?? 0) == 0 {
                        Text(l10n.tr("cc.noCache"))
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    } else {
                        Text(byteString)
                            .font(.system(size: 15, weight: .medium))
                    }
                }
                Button(role: .destructive) {
                    confirmClean = true
                } label: {
                    Label(l10n.tr("cc.clean"), systemImage: "trash")
                        .font(.system(size: 15))
                }
                .disabled(isMeasuring || isCleaning || (cacheBytes ?? 0) == 0 || !manager.sandboxGranted)
            }
            Section {
                Text(manager.statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle(app.bundleID)
        .navigationBarTitleDisplayMode(.inline)
            .wpGlassContainer()
        .confirmationDialog(
            l10n.tr("cc.clean"),
            isPresented: $confirmClean,
            titleVisibility: .visible
        ) {
            Button(l10n.tr("cc.clean"), role: .destructive) {
                cleanCache()
            }
        }
        .onAppear(perform: measure)
    }

    private func measure() {
        guard !isCleaning else { return }
        isMeasuring = true
        DispatchQueue.global(qos: .userInitiated).async {
            let bytes = AppContainerScanner.cacheBytes(for: app)
            DispatchQueue.main.async {
                cacheBytes = bytes
                isMeasuring = false
            }
        }
    }

    private func cleanCache() {
        isCleaning = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let freed = try AppContainerScanner.cleanCache(for: app)
                DispatchQueue.main.async {
                    manager.statusText = String(
                        format: l10n.tr("cc.cleanedOk"),
                        ByteCountFormatter.string(fromByteCount: freed, countStyle: .file),
                        app.bundleID
                    )
                }
            } catch {
                DispatchQueue.main.async {
                    manager.statusText = String(
                        format: l10n.tr("common.failPrefix"), error.localizedDescription)
                }
            }
            DispatchQueue.main.async {
                isCleaning = false
                measure()
            }
        }
    }
}
