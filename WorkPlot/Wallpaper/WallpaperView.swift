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

    var body: some View {
        NavigationView {
            List {
                importSection
                appliedSection
                cowabungaSection
                videoSection
                if CarPlayManager.supportsCarPlay() { carplaySection }
                settingsSection
            }
            .navigationTitle("Wallpaper")
            .onAppear(perform: loadCowabunga)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [UTType(filenameExtension: "tendies") ?? .data]) { result in
            if case let .success(url) = result {
                importTendies(url)
            }
        }
        .fileImporter(isPresented: $showVideoImporter, allowedContentTypes: [.movie]) { result in
            if case let .success(url) = result, url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                importVideo(url)
            }
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
    }

    // MARK: Sections

    private var importSection: some View {
        Section("Import") {
            Button("Import .tendies file") { showImporter = true }
            Button("Make from video") { showVideoImporter = true }
            Link("Browse Cowabun.ga", destination: URL(string: WallpaperPosterBoardManager.WallpapersURL)!)
        }
    }

    private var appliedSection: some View {
        Section("Selected (\(poster.selectedTendies.count)/\(WallpaperPosterBoardManager.MaxTendies))") {
            ForEach(poster.selectedTendies, id: \.self) { url in
                HStack {
                    Text(url.lastPathComponent)
                    Spacer()
                    Button("Remove") { poster.selectedTendies.removeAll { $0 == url } }
                        .foregroundColor(.red)
                }
            }
            Button("Apply to PosterBoard") { applySelected() }
                .disabled(poster.selectedTendies.isEmpty || pbHash.isEmpty)
        }
    }

    private var cowabungaSection: some View {
        Section("Cowabunga Catalogue") {
            Picker("Sort", selection: $cowabungaFilter) {
                ForEach(WallpaperFilterType.allCases, id: \.self) { Text($0.rawValue) }
            }
            .onChange(of: cowabungaFilter) { reloadCowabunga() }
            if cowabunga.isEmpty {
                Text(cowabungaLoaded ? "No wallpapers found." : "Loading...")
            } else {
                ForEach(cowabunga) { wp in
                    Button {
                        WallpaperDownloadManager.shared.startTendiesDownload(
                            for: WallpaperCowabungaAPI.shared.getDownloadURLForWallpaper(wp)
                        )
                    } label: {
                        HStack {
                            if let url = URL(string: WallpaperCowabungaAPI.shared.getPreviewURLForWallpaper(wp).absoluteString) {
                                AsyncImage(url: url) { $0.resizable() } placeholder: { Color.gray }
                                    .frame(width: 48, height: 48).cornerRadius(8)
                            }
                            VStack(alignment: .leading) {
                                Text(wp.name)
                                if let desc = wp.description { Text(desc).font(.caption).foregroundColor(.secondary) }
                            }
                        }
                    }
                }
            }
        }
    }

    private var videoSection: some View {
        Section("Video") {
            ForEach(poster.videos) { info in
                HStack {
                    Text("Video clip")
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
            Button("Clear video") { poster.videos.removeAll() }
        }
    }

    private var carplaySection: some View {
        Section("CarPlay Wallpaper") {
            TextField("CarPlay app hash", text: $carplayHash)
            PhotosPicker("Light image", selection: Binding<PhotosPickerItem?>(
                get: { nil },
                set: { item in Task { carplayLight = try? await item?.loadTransferable(type: Data.self) } }
            ), matching: .images)
            PhotosPicker("Dark image", selection: Binding<PhotosPickerItem?>(
                get: { nil },
                set: { item in Task { carplayDark = try? await item?.loadTransferable(type: Data.self) } }
            ), matching: .images)
            TextField("Name", text: $carplayName)
            Button("Apply CarPlay") { applyCarPlay() }
                .disabled(carplayHash.isEmpty || carplayLight == nil || carplayDark == nil)
        }
    }

    private var settingsSection: some View {
        Section("Settings") {
            TextField("PosterBoard app hash (from Nugget)", text: $pbHash)
            Button("Reset Collections") { resetCollections() }
            Button("Clear Cache") {
                try? WallpaperPosterBoardManager.clearCache()
                poster.selectedTendies.removeAll()
                poster.videos.removeAll()
            }
            Link("Fallback Shortcut", destination: URL(string: WallpaperPosterBoardManager.ShortcutURL)!)
        }
    }

    // MARK: Actions

    private func importTendies(_ url: URL) {
        guard url.pathExtension == "tendies" else {
            UIApplication.shared.alert(body: "Only .tendies files can be imported!"); return
        }
        guard poster.selectedTendies.count < WallpaperPosterBoardManager.MaxTendies else {
            UIApplication.shared.alert(title: "Max Tendies Reached", body: "Only \(WallpaperPosterBoardManager.MaxTendies) descriptors can be applied."); return
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

    private func importVideo(_ url: URL) {
        if WallpaperVideoHandler.isVideoTooLong(at: url) {
            UIApplication.shared.alert(title: "Video too long", body: "Your video must be \(WallpaperVideoHandler.MaxDurationSecs) seconds or less.")
            return
        }
        poster.videos.append(LoadInfo(loadState: .loaded(Movie(url: url))))
    }

    private func applySelected() {
        guard !pbHash.isEmpty else {
            UIApplication.shared.alert(title: "App Hash required", body: "Set the PosterBoard app hash from Nugget in Settings."); return
        }
        exploit.checkSystemPathAccess()
        guard exploit.sandboxGranted else {
            UIApplication.shared.alert(title: "Exploit not active", body: "Run the bad_query exploit from the Home tab first."); return
        }
        do {
            try poster.applyTendies(appHash: pbHash)
            UIApplication.shared.dismissAlert()
            Haptic.shared.notify(.success)
            UIApplication.shared.alert(title: "Applied", body: "Open Wallpaper settings and pick your new poster.")
        } catch {
            UIApplication.shared.dismissAlert()
            UIApplication.shared.alert(title: "Apply failed", body: error.localizedDescription)
        }
    }

    private func applyCarPlay() {
        guard let light = carplayLight, let dark = carplayDark else { return }
        guard !carplayHash.isEmpty else {
            UIApplication.shared.alert(title: "App Hash required", body: "Set the CarPlay app hash from Nugget in Settings."); return
        }
        exploit.checkSystemPathAccess()
        guard exploit.sandboxGranted else {
            UIApplication.shared.alert(title: "Exploit not active", body: "Run the bad_query exploit from the Home tab first."); return
        }
        let wp = CarPlayWallpaper(
            name: carplayName, lightImage: UIImage(data: light) ?? UIImage(),
            darkImage: UIImage(data: dark) ?? UIImage(),
            selectedImageDataLight: light, selectedImageDataDark: dark
        )
        do {
            try CarPlayManager.applyCarPlay(appHash: carplayHash, wallpapers: [wp])
            Haptic.shared.notify(.success)
            UIApplication.shared.alert(title: "CarPlay Applied", body: "Check your car's CarPlay wallpaper settings.")
        } catch {
            UIApplication.shared.alert(title: "CarPlay failed", body: error.localizedDescription)
        }
    }

    private func resetCollections() {
        // Wipe custom PosterBoard descriptors via bad_query, then respring.
        exploit.checkSystemPathAccess()
        guard exploit.sandboxGranted else {
            UIApplication.shared.alert(title: "Exploit not active", body: "Run the bad_query exploit from the Home tab first."); return
        }
        let _ = try? WallpaperSymlink.createDescriptorsSymlink(appHash: pbHash, ext: "com.apple.WallpaperKit.CollectionsPoster")
        defer { WallpaperSymlink.cleanup() }
        try? FileManager.default.trashItem(at: WallpaperSymlink.getLCDocumentsDirectory().appendingPathComponent(".Trash"), resultingItemURL: nil)
        ExploitManager.shared.requestRespring()
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
            importTendies(url)
        }
    }
}
