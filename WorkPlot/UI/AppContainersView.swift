//
//  AppContainersView.swift
//  WorkPlot
//
//  Lists every app data container found by AppContainerScanner with a
//  bundle-ID search filter; tapping a row opens the per-app cache cleaner.
//  The toolbar offers a clean-all shortcut across every scanned container.
//

import SwiftUI

struct AppContainersView: View {
    @ObservedObject private var manager = ExploitManager.shared
    @ObservedObject private var l10n = L10n.shared

    @State private var containers: [AppContainerInfo] = []
    @State private var isLoading = false
    @State private var isCleaningAll = false
    @State private var loadError: String?
    @State private var searchText = ""

    private var filteredContainers: [AppContainerInfo] {
        searchText.isEmpty
            ? containers
            : containers.filter { $0.bundleID.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationView {
            Group {
                if !manager.sandboxGranted {
                    WPEmptyState(icon: "lock", title: l10n.tr("home.locked"))
                } else if isLoading || isCleaningAll {
                    ProgressView()
                        .controlSize(.large)
                } else if let loadError {
                    WPEmptyState(icon: "exclamationmark.triangle", title: loadError, tint: .red)
                } else if filteredContainers.isEmpty {
                    WPEmptyState(icon: "shippingbox", title: l10n.tr("ac.empty"))
                } else {
                    containerList
                }
            }
            .navigationTitle(l10n.tr("ac.title"))
            .wpGlassContainer()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            cleanAllCaches()
                        } label: {
                            Label(l10n.tr("cc.cleanAll"), systemImage: "trash")
                        }
                        .disabled(containers.isEmpty)
                    } label: {
                        Label(l10n.tr("cc.allApps"), systemImage: "ellipsis.circle")
                    }
                    .disabled(isLoading || isCleaningAll)
                }
            }
            .onAppear(perform: reloadContainers)
        }
    }

    private var containerList: some View {
        List {
            Section(l10n.tr("cc.allApps")) {
                ForEach(filteredContainers) { app in
                    NavigationLink(destination: CacheCleanerView(app: app)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.bundleID)
                                .font(.system(size: 15, weight: .medium, design: .monospaced))
                            Text(app.rootPath)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            }
        }
        .searchable(text: $searchText)
        .refreshable { reloadContainers() }
    }

    private func reloadContainers() {
        isLoading = true
        loadError = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try AppContainerScanner.scanAllContainers() }
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let scanned): containers = scanned
                case .failure(let error): loadError = error.localizedDescription
                }
            }
        }
    }

    private func cleanAllCaches() {
        isCleaningAll = true
        DispatchQueue.global(qos: .userInitiated).async {
            var totalBytes: Int64 = 0
            var cleanedCount = 0
            for app in (try? AppContainerScanner.scanAllContainers()) ?? containers {
                do {
                    totalBytes += try AppContainerScanner.cleanCache(for: app)
                    cleanedCount += 1
                } catch {
                    SessionLogger.shared.log(
                        "cache clean failed \(app.bundleID): \(error.localizedDescription)")
                }
            }
            DispatchQueue.main.async {
                isCleaningAll = false
                manager.statusText = String(
                    format: l10n.tr("cc.cleanedOk"),
                    ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file),
                    "\(l10n.tr("cc.allApps")) (\(cleanedCount))"
                )
            }
        }
    }
}
