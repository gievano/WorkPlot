//
//  WallpaperPosterBoardManager.swift
//  WorkPlot
//
//  Adapted from Pocket Poster's PosterBoardManager.swift (GPL-3.0).
//  Imports .tendies packages, extracts PosterBoard descriptors, and applies
//  them by symlinking into the PosterBoard app container (requires the
//  bad_query escape to be active). Apply logic mirrors Ketamine: move each
//  descriptor straight into the real container, no re-zip / id randomization.
//
//  Source: github.com/leminlimez/Pocket-Poster
//

import Foundation
import UIKit

final class WallpaperPosterBoardManager: ObservableObject {
    static let ShortcutURL = "https://www.icloud.com/shortcuts/a28d2c02ca11453cb5b8f91c12cfa692"
    static let WallpapersURL = "https://cowabun.ga/wallpapers"
    static let MaxTendies = 10
    static let shared = WallpaperPosterBoardManager()

    @Published var selectedTendies: [URL] = []
    @Published var videos: [LoadInfo] = []

    func getTendiesStoreURL() -> URL {
        let url = WallpaperSymlink.getDocumentsDirectory()
            .appendingPathComponent("KFC Bucket", conformingTo: .directory)
        if !FileManager.default.fileExists(atPath: url.path()) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    func openPosterBoard() -> Bool {
        guard let obj = objc_getClass("LSApplicationWorkspace") as? NSObject else { return false }
        let workspace = obj.perform(Selector(("defaultWorkspace")))?.takeUnretainedValue() as? NSObject
        return workspace?.perform(Selector(("openApplicationWithBundleID:")), with: "com.apple.PosterBoard") != nil
    }

    func runShortcut(named name: String) {
        guard let url = URL(string: "shortcuts://run-shortcut?name=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        else { return }
        UIApplication.shared.open(url)
    }

    // MARK: Unzip

    /// Extracts a .tendies (zip) into a fresh temp directory and returns it.
    private func unzipFile(at url: URL) throws -> URL {
        let fileName = url.deletingPathExtension().lastPathComponent
        let normalized = fileName.replacingOccurrences(of: "[ \\%20]", with: "_", options: .regularExpression)
        let fileData = try Data(contentsOf: url)

        let base = WallpaperSymlink.getDocumentsDirectory()
            .appendingPathComponent("UnzipItems", conformingTo: .directory)
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let destination = base.appendingPathComponent(normalized)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        // WorkPlot's ZipArchive handles stored + deflate entries.
        _ = try ZipArchive.writeArchive(fileData, to: destination)
        return destination
    }

    // MARK: Descriptor extraction

    /// Maps each PosterBoard extension id to the folder holding its descriptors.
    func getDescriptorsFromTendie(_ url: URL) throws -> [String: [URL]]? {
        for dir in try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            let fileName = dir.lastPathComponent.lowercased()
            if fileName == "container" {
                let extDir = dir.appendingPathComponent("Library/Application Support/PRBPosterExtensionDataStore/61/Extensions")
                var retList: [String: [URL]] = [:]
                for ext in try FileManager.default.contentsOfDirectory(at: extDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
                    retList[ext.lastPathComponent] = [ext.appendingPathComponent("descriptors")]
                }
                return retList
            } else if ["descriptor", "descriptors", "ordered-descriptor", "ordered-descriptors"].contains(fileName) {
                return ["com.apple.WallpaperKit.CollectionsPoster": [dir]]
            } else if ["video-descriptor", "video-descriptors"].contains(fileName) {
                return ["com.apple.PhotosUIPrivate.PhotosPosterProvider": [dir]]
            }
        }
        return nil
    }

    // MARK: Apply

    /// Applies all selected tendies + generated videos to PosterBoard.
    /// `appHash` is the auto-detected (or provided) PosterBoard container hash.
    ///
    /// Mirrors Ketamine's applyTendies: build a list of (ext, descriptor dir)
    /// pairs, then for each ext create ONE descriptor symlink and move every
    /// descriptor straight into the real PosterBoard container (renamed to a
    /// fresh UUID). No re-zip, no trash — so it is both correct and fast.
    func applyTendies(appHash: String) throws {
        struct PendingDescriptor {
            let ext: String
            let directory: URL
        }
        var pending: [PendingDescriptor] = []

        // Selected .tendies packages.
        for url in selectedTendies {
            let unzippedDir = try unzipFile(at: url)
            guard let descriptorMap = try getDescriptorsFromTendie(unzippedDir) else { continue }
            for (ext, folders) in descriptorMap {
                for folder in folders {
                    for descr in try FileManager.default.contentsOfDirectory(
                        at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
                    ) where descr.lastPathComponent != "__MACOSX" {
                        pending.append(PendingDescriptor(ext: ext, directory: descr))
                    }
                }
            }
            try? FileManager.default.removeItem(at: unzippedDir)
        }

        // Generated video wallpapers (each CAML is a single descriptor dir).
        for video in videos {
            if case let .loaded(movie) = video.loadState {
                do {
                    let caml = try WallpaperVideoHandler.createCaml(from: movie.url, autoReverses: video.autoReverses)
                    pending.append(PendingDescriptor(ext: "com.apple.WallpaperKit.CollectionsPoster", directory: caml))
                } catch {
                    print(error.localizedDescription)
                }
            }
        }

        guard !pending.isEmpty else { return }

        // Group by extension so each extension's symlink is created once, then
        // drop every descriptor of that extension into the real container.
        let grouped = Dictionary(grouping: pending, by: { $0.ext })
        for (ext, items) in grouped {
            _ = try WallpaperSymlink.createDescriptorsSymlink(appHash: appHash, ext: ext)
            let symlink = WallpaperSymlink.getSymlinkURL()
            for item in items {
                let newURL = symlink.appendingPathComponent(UUID().uuidString, isDirectory: true)
                try FileManager.default.moveItem(at: item.directory, to: newURL)
            }
        }

        WallpaperSymlink.cleanup()

        for url in selectedTendies {
            try? FileManager.default.removeItem(at: WallpaperSymlink.getDocumentsDirectory().appendingPathComponent("UnzipItems", conformingTo: .directory))
            try? FileManager.default.removeItem(at: WallpaperSymlink.getDocumentsDirectory().appendingPathComponent(url.lastPathComponent))
            try? FileManager.default.removeItem(at: WallpaperSymlink.getDocumentsDirectory().appendingPathComponent(url.deletingPathExtension().lastPathComponent))
        }
    }

    static func clearCache() throws {
        WallpaperSymlink.cleanup()
        let docDir = WallpaperSymlink.getDocumentsDirectory()
        for file in try FileManager.default.contentsOfDirectory(at: docDir, includingPropertiesForKeys: nil) {
            if file.lastPathComponent != "CarPlayPhotos" {
                try FileManager.default.removeItem(at: file)
            }
        }
    }

    // MARK: Hash discovery (no Nugget required)

    /// Locates the PosterBoard container UUID by scanning all app containers
    /// through the bad_query escape (same source AppContainerScanner uses).
    static func discoverPosterBoardHash() -> String? {
        discoverHash(bundleID: "com.apple.PosterBoard")
            ?? discoverHashByStore()
    }

    static func discoverCarPlayHash() -> String? {
        discoverHash(bundleID: "com.apple.CarPlayApp")
    }

    private static func discoverHash(bundleID: String) -> String? {
        guard let containers = try? AppContainerScanner.scanAllContainers() else { return nil }
        return containers
            .first { $0.bundleID == bundleID }
            .map { ($0.rootPath as NSString).lastPathComponent }
    }

    /// Fallback: a container whose PosterBoard data store directory exists.
    private static func discoverHashByStore() -> String? {
        guard let containers = try? AppContainerScanner.scanAllContainers() else { return nil }
        let store = "Library/Application Support/PRBPosterExtensionDataStore"
        return containers
            .first { FileManager.default.fileExists(atPath: ($0.rootPath as NSString).appendingPathComponent(store)) }
            .map { ($0.rootPath as NSString).lastPathComponent }
    }
}
