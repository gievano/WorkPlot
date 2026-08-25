//
//  WallpaperPosterBoardManager.swift
//  WorkPlot
//
//  Adapted from Pocket Poster's PosterBoardManager.swift (GPL-3.0).
//  Imports .tendies packages, extracts PosterBoard descriptors, and applies
//  them by symlinking into the PosterBoard app container (requires the
//  bad_query escape to be active). Apply logic mirrors Ketamine 1:1: randomize
//  each descriptor id, then copy it straight into the real container under a
//  bad_query lease so the write is authorized.
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

    private static let descriptorMarker = "com.apple.posterkit.provider.descriptor.identifier"

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }

    private static func isDescriptorFolder(_ url: URL) -> Bool {
        isDirectory(url)
            && FileManager.default.fileExists(
                atPath: url.appendingPathComponent(descriptorMarker).path)
    }

    /// Randomizes the wallpaper identifier inside a descriptor folder so
    /// multiple tendies do not collide on the same PosterBoard descriptor ID.
    /// Ported 1:1 from Ketamine's PosterBoardManager.randomizeWallpaperId.
    private func randomizeWallpaperId(url: URL) throws {
        let randomizedID = Int.random(in: 9999...99999)
        var files: [URL] = []
        if let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let fileURL as URL in enumerator {
                if (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true {
                    files.append(fileURL)
                }
            }
        }

        func setPlistValue(file: String, key: String, value: Any) {
            guard let plistData = FileManager.default.contents(atPath: file),
                  var plist = try? PropertyListSerialization.propertyList(
                      from: plistData, options: [], format: nil) as? [String: Any] else {
                return
            }
            plist[key] = value
            guard let updatedData = try? PropertyListSerialization.data(
                fromPropertyList: plist, format: .xml, options: 0) else { return }
            try? updatedData.write(to: URL(fileURLWithPath: file))
        }

        for file in files {
            switch file.lastPathComponent {
            case Self.descriptorMarker:
                try String(randomizedID).data(using: .utf8)?.write(to: file)
            case "com.apple.posterkit.provider.contents.userInfo":
                setPlistValue(file: file.path(), key: "wallpaperRepresentingIdentifier", value: randomizedID)
            case "Wallpaper.plist":
                setPlistValue(file: file.path(), key: "identifier", value: randomizedID)
            default:
                continue
            }
        }
    }

    // MARK: Apply

    /// Applies all selected tendies + generated videos to PosterBoard.
    /// `appHash` is the auto-detected (or provided) PosterBoard container hash.
    ///
    /// Mirrors Ketamine's applyTendies: build a list of (ext, descriptor dir)
    /// pairs, then for each ext create ONE descriptor symlink, randomize every
    /// descriptor's id, and copy it straight into the real PosterBoard
    /// container (renamed to a fresh UUID) under a bad_query lease.
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
                    // A returned folder is either a descriptors container
                    // (container-style tendie) or the descriptor folder itself
                    // (flat-style). Mirror Ketamine: add it directly when it
                    // already contains the descriptor marker, else enumerate.
                    if Self.isDescriptorFolder(folder) {
                        pending.append(PendingDescriptor(ext: ext, directory: folder))
                    } else {
                        for descr in try FileManager.default.contentsOfDirectory(
                            at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
                        ) where descr.lastPathComponent != "__MACOSX" {
                            pending.append(PendingDescriptor(ext: ext, directory: descr))
                        }
                    }
                }
            }
            // NOTE: do NOT remove unzippedDir here — the descriptor directories
            // in `pending` still live inside it. Cleanup happens after the copy
            // loop below, otherwise copyItem fails with "former doesn't exist".
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

        // Group by extension so each extension's descriptors are written once,
        // then drop every descriptor straight into the real container — mirroring
        // Ketamine: lease the directories via bad_query and copy directly. No
        // symlink/`.Trash` trick (that was what threw "permission to save .trash").
        let grouped = Dictionary(grouping: pending, by: { $0.ext })
        let extVer = WallpaperSymlink.getExtensionVersion()
        let fm = FileManager.default
        for (ext, items) in grouped {
            let realPath = "/var/mobile/Containers/Data/Application/\(appHash)/Library/Application Support/PRBPosterExtensionDataStore/\(extVer)/Extensions/\(ext)/descriptors"
            // Ensure the descriptors directory exists: lease the parent, create it.
            let parent = (realPath as NSString).deletingLastPathComponent
            try BadQueryLeaseScope.withLease(forPath: parent) {
                try? fm.createDirectory(atPath: realPath, withIntermediateDirectories: true)
            }
            try BadQueryLeaseScope.withLease(forPath: realPath) {
                for item in items {
                    try randomizeWallpaperId(url: item.directory)
                    let newURL = URL(fileURLWithPath: realPath)
                        .appendingPathComponent(UUID().uuidString, isDirectory: true)
                    try fm.copyItem(at: item.directory, to: newURL)
                }
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

    // MARK: Reset collections

    /// Wipe every custom descriptor from PosterBoard's extension data store,
    /// mirroring Ketamine's `PosterBoardManager.resetCollections`: acquire a
    /// bad_query lease on the Extensions root, then for each extension remove
    /// every descriptor folder under its `/descriptors` path. Robust on-device
    /// because it writes through the lease directly instead of the old
    /// symlink + `.Trash` trick, and it clears ALL extensions (not just
    /// CollectionsPoster).
    func resetCollections(appHash: String) throws {
        let extVer = WallpaperSymlink.getExtensionVersion()
        let extensionsRoot = "/var/mobile/Containers/Data/Application/\(appHash)/Library/Application Support/PRBPosterExtensionDataStore/\(extVer)/Extensions"
        let fm = FileManager.default
        guard fm.fileExists(atPath: extensionsRoot) else { return }

        try BadQueryLeaseScope.withLease(forPath: extensionsRoot) {
            let extDirs = (try? fm.contentsOfDirectory(atPath: extensionsRoot)) ?? []
            for extName in extDirs {
                let descriptorsPath = (extensionsRoot as NSString)
                    .appendingPathComponent(extName)
                    .appendingPathComponent("descriptors")
                // Lease each descriptors path before removing its contents so
                // the sandbox write is authorized under bad_query.
                try? BadQueryLeaseScope.withLease(forPath: descriptorsPath) {
                    guard fm.fileExists(atPath: descriptorsPath) else { return }
                    let items = (try? fm.contentsOfDirectory(atPath: descriptorsPath)) ?? []
                    for item in items where item != "__MACOSX" && !item.hasPrefix(".") {
                        let full = (descriptorsPath as NSString).appendingPathComponent(item)
                        try? fm.removeItem(atPath: full)
                    }
                }
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
