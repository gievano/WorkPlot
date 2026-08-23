import SwiftUI
import UniformTypeIdentifiers

struct PosterBoardLabView: View {
    @ObservedObject private var manager = ExploitManager.shared
    @ObservedObject private var l10n = L10n.shared

    @State private var isShowingImporter = false
    @State private var isShowingCatalog = false
    @State private var isInstalling = false
    @State private var phase = ""
    @State private var installedWallpapers: [String] = []
    @State private var pendingRemoval: String?
    @State private var isLoadingWallpapers = false
    @State private var bundledWallpapers: [URL] = []
    @State private var journalCount = 0
    @State private var isShowingJournalReset = false

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
                } else if !PosterBoardAccess.isAvailable {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.exclamationmark").font(.largeTitle).foregroundColor(.orange)
                        Text(l10n.tr("pb.badqueryUnavailable"))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    }
                } else {
                    wallpaperList
                }
            }
            .navigationTitle(L10n.shared.tr("tab.posterboard"))
            .workPlotScrollBackground()
            .onAppear {
                reloadInstalled()
                bundledWallpapers = Self.bundledTendies()
            }
            .fileImporter(
                isPresented: $isShowingImporter,
                // .zip stays selectable because file providers often label a
                // tendies package by its content type instead of extension.
                allowedContentTypes: [.tendies, .zip],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first { installTendies(from: url) }
                case .failure(let error):
                    manager.statusText = String(format: l10n.tr("common.failPrefix"), error.localizedDescription)
                    phase = ""
                }
            }
            .alert(
                l10n.tr("pb.remove.confirm"),
                isPresented: .init(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } })
            ) {
                Button(l10n.tr("pb.remove"), role: .destructive) {
                    if let name = pendingRemoval { remove(name) }
                    pendingRemoval = nil
                }
                Button(l10n.tr("siriai.restart.later"), role: .cancel) { pendingRemoval = nil }
            } message: {
                Text(pendingRemoval ?? "")
            }
            .alert(
                l10n.tr("wpj.reset"),
                isPresented: $isShowingJournalReset
            ) {
                Button(l10n.tr("pb.remove"), role: .destructive) { resetJournal() }
                Button(l10n.tr("siriai.restart.later"), role: .cancel) {}
            } message: {
                Text(String(format: l10n.tr("wpj.resetConfirm"), journalCount))
            }
        }
    }

    private var wallpaperList: some View {
        List {
            Section(
                header: Text(l10n.tr("pb.labHeader")),
                footer: Text(l10n.tr("pb.labFooter"))
            ) {
                Button {
                    isShowingImporter = true
                } label: {
                    Label(L10n.shared.tr("posterboard.import"), systemImage: "square.and.arrow.down")
                }
                .disabled(isInstalling)

                Button {
                    isShowingCatalog = true
                } label: {
                    Label(L10n.shared.tr("cat.openCatalog"), systemImage: "sparkles")
                }
                .sheet(isPresented: $isShowingCatalog) {
                    WallpaperCatalogView()
                }
                .disabled(isInstalling)

                if isInstalling {
                    HStack { ProgressView(); Text(phase) }
                } else if !phase.isEmpty {
                    Text(phase)
                        .font(.caption)
                        .foregroundColor(manager.statusText.hasPrefix(l10n.failPrefix) ? .orange : .secondary)
                }
            }

            Section(header: Text(l10n.tr("pb.builtin.header"))) {
                if bundledWallpapers.isEmpty {
                    Text(l10n.tr("pb.builtin.none"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(bundledWallpapers, id: \.self) { url in
                        HStack {
                            Image(systemName: "photo.fill")
                                .foregroundStyle(.pink)
                            Text(url.deletingPathExtension().lastPathComponent)
                                .font(.system(size: 15, weight: .medium))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button {
                                installTendies(from: url)
                            } label: {
                                Label(l10n.tr("pb.builtin.install"), systemImage: "arrow.down.circle")
                            }
                            .buttonStyle(.borderless)
                            .disabled(isInstalling)
                        }
                    }
                }
            }

            Section(header: Text(l10n.tr("pb.installed"))) {
                if isLoadingWallpapers {
                    HStack { ProgressView(); Text(l10n.tr("pb.loading")).font(.caption) }
                } else if installedWallpapers.isEmpty {
                    Text(l10n.tr("pb.empty"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(installedWallpapers, id: \.self) { name in
                        HStack {
                            Image(systemName: "photo.fill")
                                .foregroundStyle(.pink)
                            Text(name)
                                .font(.system(size: 15, weight: .medium))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button {
                                manager.requestRespring()
                            } label: {
                                Label(l10n.tr("pb.apply"), systemImage: "checkmark.circle")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.borderless)

                            Button(role: .destructive) {
                                pendingRemoval = name
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                if !installedWallpapers.isEmpty {
                    Button {
                        manager.requestRespring()
                    } label: {
                        Label(l10n.tr("siriai.restart.respring"), systemImage: "arrow.counterclockwise")
                    }
                }
            }

            Section(header: Text(l10n.tr("wpj.title"))) {
                if journalCount == 0 {
                    Text(l10n.tr("wpj.empty"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Label(String(format: l10n.tr("wpj.countLabel"), journalCount), systemImage: "list.badge.rectangle")
                        .font(.system(size: 15, weight: .medium))
                    Button(role: .destructive) {
                        isShowingJournalReset = true
                    } label: {
                        Label(l10n.tr("wpj.reset"), systemImage: "trash")
                    }
                }
            }
        }
    }

    /// Bundled tendies live flat in the bundle root when Xcode copies the
    /// synchronized Resources folder as groups, or under their folder name
    /// if it ships as a folder reference — check both.
    private static func bundledTendies() -> [URL] {
        var urls = Bundle.main.urls(forResourcesWithExtension: "tendies", subdirectory: nil) ?? []
        if urls.isEmpty {
            urls = Bundle.main.urls(forResourcesWithExtension: "tendies", subdirectory: "TendiesWallpapers") ?? []
        }
        return urls.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }

    /// Pipeline: copy out of the security scope -> validate ZIP & structure ->
    /// extract descriptors -> locate the PosterBoard container -> write.
    /// Runs entirely off the main thread: bad_query directory scans are heavy
    /// and froze the UI when executed synchronously.
    private func installTendies(from sourceURL: URL) {
        isInstalling = true
        phase = ""

        guard sourceURL.pathExtension.lowercased() == "tendies" else {
            phase = l10n.tr("pb.wrongext")
            manager.statusText = phase
            isInstalling = false
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let accessed = sourceURL.startAccessingSecurityScopedResource()
            defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }

            do {
                let data = try Data(contentsOf: sourceURL)

                try TendiesPackage.validate(data)

                let descriptorFolders = try TendiesPackage.extract(data)
                TendiesPackage.randomizeIdentifiers(in: descriptorFolders)

                DispatchQueue.main.async { self.phase = l10n.tr("pb.phase.finding") }
                let appHash = try PosterBoardAccess.findPosterBoardHash()

                DispatchQueue.main.async { self.phase = l10n.tr("pb.phase.writing") }
                try PosterBoardAccess.writeDescriptors(appHash: appHash, descriptorFolders: descriptorFolders)

                Self.openPosterBoardApp()

                DispatchQueue.main.async {
                    self.isInstalling = false
                    self.phase = l10n.tr("pb.guide")
                    self.reloadInstalled()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.manager.respringRequested = true
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.isInstalling = false
                    self.manager.statusText = String(format: self.l10n.tr("common.failPrefix"), error.localizedDescription)
                    self.phase = String(format: self.l10n.tr("common.failPrefix"), error.localizedDescription)
                }
            }
        }
    }

    /// Opens PosterBoard after a successful install so the new wallpaper is
    /// immediately visible (same UX as Pocket Poster).
    private static func openPosterBoardApp() {
        guard let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
              let workspace = cls.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() else { return }
        _ = workspace.perform(NSSelectorFromString("openApplicationWithBundleID:"), with: "com.apple.PosterBoard")
    }

    private func remove(_ name: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try PosterBoardAccess.removeWallpaper(named: name)
                DispatchQueue.main.async {
                    self.manager.statusText = String(format: self.l10n.tr("pb.removedOk"), name)
                    self.reloadInstalled()
                }
            } catch {
                DispatchQueue.main.async {
                    self.manager.statusText = String(format: self.l10n.tr("common.failPrefix"), error.localizedDescription)
                }
            }
        }
    }

    private func resetJournal() {
        let names = WallpaperJournal.shared.addedDescriptors
        DispatchQueue.global(qos: .userInitiated).async {
            var removed: [String] = []
            for name in names {
                if (try? PosterBoardAccess.removeWallpaper(named: name)) != nil {
                    removed.append(name)
                }
            }
            // Only journal entries whose descriptor actually went away.
            if removed.count == names.count {
                WallpaperJournal.shared.removeAll()
            } else {
                WallpaperJournal.shared.remove(removed)
            }
            SessionLogger.shared.log("wallpaper journal reset: \(removed.count) removed")
            DispatchQueue.main.async {
                self.manager.statusText = String(format: self.l10n.tr("wpj.removedOk"), removed.count)
                self.journalCount = WallpaperJournal.shared.addedDescriptors.count
                self.reloadInstalled()
            }
        }
    }

    private func reloadInstalled() {
        guard manager.sandboxGranted, PosterBoardAccess.isAvailable, !isLoadingWallpapers else { return }
        isLoadingWallpapers = true
        DispatchQueue.global(qos: .userInitiated).async {
            let result = (try? PosterBoardAccess.listInstalledWallpapers()) ?? []
            DispatchQueue.main.async {
                self.installedWallpapers = result
                self.isLoadingWallpapers = false
                self.journalCount = WallpaperJournal.shared.addedDescriptors.count
            }
        }
    }
}
