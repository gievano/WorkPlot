//
//  WallpaperView.swift
//  WorkPlot
//
//  New "Wallpaper" tab. Wires the ported Pocket Poster managers into the
//  WorkPlot UI: import .tendies, apply to PosterBoard, browse/download the
//  Cowabunga catalogue, make wallpapers from video, and CarPlay wallpapers.
//
//  Pocket Poster logic is GPL-3.0 (see THIRD_PARTY_NOTICES.md).
//

import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct WallpaperView: View {
    @ObservedObject private var poster = WallpaperPosterBoardManager.shared
    @ObservedObject private var dlManager = WallpaperDownloadManager.shared
    @ObservedObject private var exploit = ExploitManager.shared

    @AppStorage("wpPbHash") private var pbHash = ""
    @AppStorage("wpCarplayHash") private var carplayHash = ""

    @State private var showImporter = false
    @State private var showVideoImporter = false
    @State private var cowabunga: [DownloadableWallpaper] = []
    @State private var cowabungaFilter: WallpaperFilterType = .newest
    @State private var cowabungaLoaded = false
    @State private var carplayLight: Data?
    @State private var carplayDark: Data?
    @State private var carplayName = "Custom"

    private var tendieType: UTType {
        .tendies
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.cardSpacing) {
                importCard
                appliedCard
                cowabungaCard
                videoCard
                if CarPlayManager.supportsCarPlay() { carplayCard }
                diagnosticsCard
            }
            .padding(.bottom, 24)
        }
        .navigationTitle("Wallpaper")
        .wpGlassContainer()
        .onAppear(perform: loadCowabunga)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [tendieType], allowsMultipleSelection: true) { result in
            importTendies(result)
        }
        .fileImporter(isPresented: $showVideoImporter, allowedContentTypes: [.movie]) { result in
            if case let .success(url) = result {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                importVideo(url)
            }
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
    }

    // MARK: Cards — WorkPlot layout (own concept, not Ketamine's stacked buttons)

    private var importCard: some View {
        WPCard {
            VStack(alignment: .leading, spacing: 12) {
                WPSectionHeader(title: "Import")
                WPActionButton(title: "Import .tendies file") { showImporter = true }
                WPActionButton(title: "Make from video", prominent: false) { showVideoImporter = true }
                Link(destination: URL(string: WallpaperPosterBoardManager.WallpapersURL)!) {
                    Text("Browse Cowabun.ga").font(.body.weight(.medium)).foregroundStyle(Theme.accent)
                }
            }
        }
    }

    private var appliedCard: some View {
        WPCard {
            VStack(alignment: .leading, spacing: 12) {
                WPSectionHeader(
                    title: "Selected Posters",
                    subtitle: "\(poster.selectedTendies.count)/\(WallpaperPosterBoardManager.MaxTendies) descriptors"
                )
                ForEach(poster.selectedTendies, id: \.self) { url in
                    HStack {
                        Text(url.lastPathComponent).font(.subheadline)
                        Spacer()
                        Button("Remove") { poster.selectedTendies.removeAll { $0 == url } }
                            .font(.footnote).foregroundColor(.red)
                    }
                }
                WPActionButton(title: "Apply to PosterBoard") { applySelected() }
                    .disabled(poster.selectedTendies.isEmpty)
            }
        }
    }

    private var cowabungaCard: some View {
        WPCard {
            VStack(alignment: .leading, spacing: 12) {
                WPSectionHeader(title: "Cowabunga Catalogue")
                Picker("Sort", selection: $cowabungaFilter) {
                    ForEach(WallpaperFilterType.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .onChange(of: cowabungaFilter) { _ in reloadCowabunga() }
                if cowabunga.isEmpty {
                    Text(cowabungaLoaded ? "No wallpapers found." : "Loading…")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    ForEach(cowabunga) { wp in
                        Button {
                            WallpaperDownloadManager.shared.startTendiesDownload(
                                for: WallpaperCowabungaAPI.shared.getDownloadURLForWallpaper(wp)
                            )
                        } label: {
                            HStack(spacing: 12) {
                                if let url = URL(string: WallpaperCowabungaAPI.shared.getPreviewURLForWallpaper(wp).absoluteString) {
                                    AsyncImage(url: url) { $0.resizable() } placeholder: { Color.gray }
                                        .frame(width: 48, height: 48).cornerRadius(8)
                                }
                                VStack(alignment: .leading) {
                                    Text(wp.name).font(.subheadline.weight(.medium))
                                    if let desc = wp.description { Text(desc).font(.caption).foregroundColor(.secondary) }
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }

    private var videoCard: some View {
        WPCard {
            VStack(alignment: .leading, spacing: 12) {
                WPSectionHeader(title: "Video")
                ForEach(poster.videos) { info in
                    HStack {
                        Text("Video clip").font(.subheadline)
                        Spacer()
                        Toggle("Auto-reverse", isOn: Binding(
                            get: { info.autoReverses },
                            set: { newValue in
                                if let i = poster.videos.firstIndex(of: info) {
                                    poster.videos[i].autoReverses = newValue
                                }
                            }
                        ))
                    }
                }
                WPActionButton(title: "Clear video", prominent: false) { poster.videos.removeAll() }
            }
        }
    }

    private var carplayCard: some View {
        WPCard {
            VStack(alignment: .leading, spacing: 12) {
                WPSectionHeader(title: "CarPlay Wallpaper")
                PhotosPicker("Light image", selection: Binding<PhotosPickerItem?>(
                    get: { nil },
                    set: { item in Task { carplayLight = try? await item?.loadTransferable(type: Data.self) } }
                ), matching: .images)
                PhotosPicker("Dark image", selection: Binding<PhotosPickerItem?>(
                    get: { nil },
                    set: { item in Task { carplayDark = try? await item?.loadTransferable(type: Data.self) } }
                ), matching: .images)
                TextField("Name", text: $carplayName)
                    .textFieldStyle(.roundedBorder)
                WPActionButton(title: "Apply CarPlay") { applyCarPlay() }
                    .disabled(carplayLight == nil || carplayDark == nil)
            }
        }
    }

    private var diagnosticsCard: some View {
        WPCard {
            VStack(alignment: .leading, spacing: 12) {
                WPSectionHeader(title: "Diagnostics")
                WPActionButton(title: "Detect PosterBoard", prominent: false) { detectHash() }
                if !pbHash.isEmpty {
                    Text("PosterBoard: \(pbHash)").font(.caption).foregroundColor(.secondary)
                }
                if CarPlayManager.supportsCarPlay() {
                    WPActionButton(title: "Detect CarPlay", prominent: false) { detectCarPlayHash() }
                    if !carplayHash.isEmpty {
                        Text("CarPlay: \(carplayHash)").font(.caption).foregroundColor(.secondary)
                    }
                }
                WPActionButton(title: "Reset Collections", prominent: false) { resetCollections() }
                WPActionButton(title: "Clear Cache", prominent: false) {
                    try? WallpaperPosterBoardManager.clearCache()
                    poster.selectedTendies.removeAll()
                    poster.videos.removeAll()
                }
                Link("Fallback Shortcut", destination: URL(string: WallpaperPosterBoardManager.ShortcutURL)!)
                    .font(.body.weight(.medium)).foregroundStyle(Theme.accent)
            }
        }
    }

    // MARK: Actions

    private func importTendies(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                guard poster.selectedTendies.count < WallpaperPosterBoardManager.MaxTendies else {
                    UIApplication.shared.alert(
                        title: "Max Tendies Reached",
                        body: "Only \(WallpaperPosterBoardManager.MaxTendies) descriptors can be applied."
                    )
                    break
                }
                do {
                    let newURL = try WallpaperDownloadManager.shared.copyTendies(from: url)
                    poster.selectedTendies.append(newURL)
                    Haptic.shared.notify(.success)
                } catch {
                    Haptic.shared.notify(.error)
                    UIApplication.shared.alert(title: "Failed to import tendies", body: error.localizedDescription)
                }
            }
        case .failure(let error):
            UIApplication.shared.alert(title: "Import failed", body: error.localizedDescription)
        }
    }

    private func importVideo(_ url: URL) {
        if WallpaperVideoHandler.isVideoTooLong(at: url) {
            UIApplication.shared.alert(title: "Video too long", body: "Your video must be \(WallpaperVideoHandler.MaxDurationSecs) seconds or less.")
            return
        }
        poster.videos.append(LoadInfo(loadState: .loaded(Movie(url: url))))
    }

    private func applySelected() {
        exploit.checkSystemPathAccess()
        guard exploit.sandboxGranted else {
            UIApplication.shared.alert(title: "Exploit not active", body: "Run the bad_query exploit from the Home tab first."); return
        }
        guard !poster.selectedTendies.isEmpty else { return }

        let startHash = pbHash
        // Show the respring overlay at once so the wait happens on the black
        // screen instead of a "Applying Wallpapers" dialog. The actual crash
        // is armed only after the apply work finishes (see armRespringCrash).
        ExploitManager.shared.beginRespring()

        var watchdog: DispatchWorkItem?
        watchdog = DispatchWorkItem {
            ExploitManager.shared.respringRequested = false
            ExploitManager.shared.respringCrashArmed = false
            UIApplication.shared.alert(title: "Apply timed out", body: "The operation took too long. Make sure the bad_query exploit is active, then try again.")
        }
        if let watchdog {
            DispatchQueue.main.asyncAfter(deadline: .now() + 120, execute: watchdog)
        }

        Task.detached(priority: .userInitiated) { [weak poster] in
            var hash = startHash
            if hash.isEmpty {
                hash = WallpaperPosterBoardManager.discoverPosterBoardHash() ?? ""
            }
            guard !hash.isEmpty else {
                watchdog?.cancel()
                await MainActor.run {
                    ExploitManager.shared.respringRequested = false
                    ExploitManager.shared.respringCrashArmed = false
                    UIApplication.shared.alert(title: "PosterBoard not found", body: "Could not locate the PosterBoard container. Make sure the exploit is active.")
                }
                return
            }
            do {
                try poster?.applyTendies(appHash: hash)
                watchdog?.cancel()
                await MainActor.run {
                    Haptic.shared.notify(.success)
                    ExploitManager.shared.armRespringCrash()
                }
            } catch {
                watchdog?.cancel()
                await MainActor.run {
                    ExploitManager.shared.respringRequested = false
                    ExploitManager.shared.respringCrashArmed = false
                    UIApplication.shared.alert(title: "Apply failed", body: error.localizedDescription)
                }
            }
        }
    }

    private func applyCarPlay() {
        guard let light = carplayLight, let dark = carplayDark else { return }
        exploit.checkSystemPathAccess()
        guard exploit.sandboxGranted else {
            UIApplication.shared.alert(title: "Exploit not active", body: "Run the bad_query exploit from the Home tab first."); return
        }
        let startHash = carplayHash
        let name = carplayName
        UIApplication.shared.change(title: "Applying CarPlay...", body: "Locating CarPlay...")
        Task.detached(priority: .userInitiated) {
            var hash = startHash
            if hash.isEmpty {
                hash = WallpaperPosterBoardManager.discoverCarPlayHash() ?? ""
            }
            guard !hash.isEmpty else {
                await MainActor.run {
                    UIApplication.shared.dismissAlert()
                    UIApplication.shared.alert(title: "CarPlay not found", body: "Could not locate the CarPlay container. Make sure the exploit is active.")
                }
                return
            }
            let wp = CarPlayWallpaper(
                name: name, lightImage: UIImage(data: light) ?? UIImage(),
                darkImage: UIImage(data: dark) ?? UIImage(),
                selectedImageDataLight: light, selectedImageDataDark: dark
            )
            do {
                try CarPlayManager.applyCarPlay(appHash: hash, wallpapers: [wp])
                await MainActor.run {
                    UIApplication.shared.dismissAlert()
                    Haptic.shared.notify(.success)
                    ExploitManager.shared.requestRespring()
                }
            } catch {
                await MainActor.run {
                    UIApplication.shared.dismissAlert()
                    UIApplication.shared.alert(title: "CarPlay failed", body: error.localizedDescription)
                }
            }
        }
    }

    private func resetCollections() {
        // Wipe custom PosterBoard descriptors via bad_query, then respring.
        exploit.checkSystemPathAccess()
        guard exploit.sandboxGranted else {
            UIApplication.shared.alert(title: "Exploit not active", body: "Run the bad_query exploit from the Home tab first."); return
        }
        let startHash = pbHash
        UIApplication.shared.change(title: "Resetting...", body: "Wiping custom descriptors...")
        Task.detached(priority: .userInitiated) {
            var hash = startHash
            if hash.isEmpty {
                hash = WallpaperPosterBoardManager.discoverPosterBoardHash() ?? ""
            }
            guard !hash.isEmpty else {
                await MainActor.run {
                    UIApplication.shared.dismissAlert()
                    UIApplication.shared.alert(title: "PosterBoard not found", body: "Could not locate the PosterBoard container.")
                }
                return
            }
            _ = try? WallpaperSymlink.createDescriptorsSymlink(appHash: hash, ext: "com.apple.WallpaperKit.CollectionsPoster")
            WallpaperSymlink.cleanup()
            try? FileManager.default.trashItem(at: WallpaperSymlink.getLCDocumentsDirectory().appendingPathComponent(".Trash"), resultingItemURL: nil)
            await MainActor.run {
                UIApplication.shared.dismissAlert()
                ExploitManager.shared.requestRespring()
            }
        }
    }

    private func detectHash() {
        exploit.checkSystemPathAccess()
        guard exploit.sandboxGranted else {
            UIApplication.shared.alert(title: "Exploit not active", body: "Run the bad_query exploit from the Home tab first."); return
        }
        UIApplication.shared.change(title: "Detecting...", body: "Scanning app containers...")
        Task.detached(priority: .userInitiated) {
            let hash = WallpaperPosterBoardManager.discoverPosterBoardHash()
            await MainActor.run {
                UIApplication.shared.dismissAlert()
                if let hash {
                    pbHash = hash
                    Haptic.shared.notify(.success)
                } else {
                    Haptic.shared.notify(.error)
                    UIApplication.shared.alert(title: "Not found", body: "Could not locate the PosterBoard container.")
                }
            }
        }
    }

    private func detectCarPlayHash() {
        exploit.checkSystemPathAccess()
        guard exploit.sandboxGranted else {
            UIApplication.shared.alert(title: "Exploit not active", body: "Run the bad_query exploit from the Home tab first."); return
        }
        UIApplication.shared.change(title: "Detecting...", body: "Scanning app containers...")
        Task.detached(priority: .userInitiated) {
            let hash = WallpaperPosterBoardManager.discoverCarPlayHash()
            await MainActor.run {
                UIApplication.shared.dismissAlert()
                if let hash {
                    carplayHash = hash
                    Haptic.shared.notify(.success)
                } else {
                    Haptic.shared.notify(.error)
                    UIApplication.shared.alert(title: "Not found", body: "Could not locate the CarPlay container.")
                }
            }
        }
    }

    private func loadCowabunga() { reloadCowabunga() }

    private func reloadCowabunga() {
        Task {
            do {
                let list = try await WallpaperCowabungaAPI.shared.fetchWallpapers(type: .custom)
                let filtered = WallpaperCowabungaAPI.shared.filterWallpapers(list, cowabungaFilter)
                DispatchQueue.main.async {
                    cowabunga = filtered
                    cowabungaLoaded = true
                }
            } catch {
                DispatchQueue.main.async { cowabungaLoaded = true }
            }
        }
    }

    private func handleIncomingURL(_ url: URL) {
        if url.absoluteString.starts(with: "pocketposter://download") {
            WallpaperDownloadManager.shared.startTendiesDownload(for: url)
        } else if url.absoluteString.starts(with: "pocketposter://app-hash?uuid=") {
            pbHash = url.absoluteString.replacingOccurrences(of: "pocketposter://app-hash?uuid=", with: "")
        } else if url.pathExtension == "tendies" {
            importTendies(.success([url]))
        }
    }
}
