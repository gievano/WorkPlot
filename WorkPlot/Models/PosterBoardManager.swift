//
//  PosterBoardManager.swift
//  Ketamine
//
//  Injects wallpaper descriptor packs ("tendies") into PosterBoard's
//  extension data store using the bad_query sandbox escape. Ported from
//  leminlimez/Pocket-Poster's PosterBoardManager (tendies-only subset).
//

import Foundation
import ObjectiveC
import ZIPFoundation

final class PosterBoardManager: ObservableObject {

    static let shared = PosterBoardManager()

    static let MaxTendies = 10

    @Published var selectedTendies: [URL] = []

    private init() {}

    // MARK: - Store

    func getTendiesStoreURL() -> URL {
        let storeURL = documentsDirectory.appendingPathComponent("KFC Bucket", conformingTo: .directory)
        if !FileManager.default.fileExists(atPath: storeURL.path()) {
            try? FileManager.default.createDirectory(at: storeURL, withIntermediateDirectories: true)
        }
        return storeURL
    }

    /// Copies a tendie picked by the importer into our own container so later
    /// reads are sandbox-safe, and returns the new URL.
    func importTendies(from url: URL) throws -> URL {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
        let fm = FileManager.default
        let newURL = getTendiesStoreURL().appendingPathComponent(url.lastPathComponent)
        if fm.fileExists(atPath: newURL.path) {
            try fm.removeItem(at: newURL)
        }
        try fm.copyItem(at: url, to: newURL)
        return newURL
    }

    var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Persists tendies data fetched from a remote source into our tendies
    /// store, mirroring `importTendies(from:)` for locally picked files.
    func storeDownloadedTendies(named name: String, data: Data) throws -> URL {
        let fm = FileManager.default
        let safeName = name.isEmpty ? "\(UUID().uuidString).tendies" : name
        let newURL = getTendiesStoreURL().appendingPathComponent(safeName)
        if fm.fileExists(atPath: newURL.path) {
            try fm.removeItem(at: newURL)
        }
        try data.write(to: newURL, options: [.atomic])
        return newURL
    }

    // MARK: - Extension version

    func getExtensionVersion() -> String {
        if #available(iOS 17.0, *) {
            return "61"
        }
        return "59"
    }

    // MARK: - Reset collections

    /// Wipe every custom descriptor from PosterBoard's extension data store.
    func resetCollections(appHash: String) throws {
        let extensionsRoot = BadQuery.applicationContainerPath(appHash: appHash)
            + "/Library/Application Support/PRBPosterExtensionDataStore/\(getExtensionVersion())/Extensions"

        let rootHandle = try BadQuery.consume(path: extensionsRoot, create: true)
        defer { rootHandle.release() }

        let fm = FileManager.default
        guard fm.fileExists(atPath: extensionsRoot) else { return }

        let extDirs = try fm.contentsOfDirectory(atPath: extensionsRoot)
        var wiped = 0
        for extName in extDirs {
            let descriptorsPath = (extensionsRoot as NSString)
                .appendingPathComponent(extName)
                .appending("/descriptors")

            let descHandle = try? BadQuery.consume(path: descriptorsPath, create: true)
            defer { descHandle?.release() }

            guard fm.fileExists(atPath: descriptorsPath) else { continue }
            let items = (try? fm.contentsOfDirectory(atPath: descriptorsPath)) ?? []
            for item in items {
                if item == "__MACOSX" || item.hasPrefix(".") { continue }
                let full = (descriptorsPath as NSString).appendingPathComponent(item)
                try? fm.removeItem(atPath: full)
                wiped += 1
            }
        }
        print("resetCollections: wiped \(wiped) descriptor item(s)")
    }

    // MARK: - PosterBoard

    func openPosterBoard() -> Bool {
        // LSApplicationWorkspace lives in the CoreServices frameworks; make
        // sure they are loaded before resolving the private class.
        dlopen("/System/Library/Frameworks/CoreServices.framework/CoreServices", RTLD_NOW)
        dlopen("/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices", RTLD_NOW)

        guard let cls = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
              let workspace = cls.perform(Selector(("defaultWorkspace")))?.takeUnretainedValue() as? NSObject else {
            return false
        }
        guard let result = workspace.perform(Selector(("openApplicationWithBundleID:")), with: "com.apple.PosterBoard") else {
            return false
        }
        return (result.takeUnretainedValue() as? NSNumber)?.boolValue ?? true
    }

    // MARK: - Tendies

    enum TendieError: LocalizedError {
        case notZip

        var errorDescription: String? {
            "That file is not a valid tendies/zip archive."
        }
    }

    private func unzipFile(at url: URL) throws -> URL {
        let fileData = try Data(contentsOf: url)

        // ZIP magic: files must start with "PK". Rejects garbage uploads
        // before ZIPFoundation can throw a confusing error.
        guard fileData.count >= 4,
              fileData[0] == 0x50, fileData[1] == 0x4B else {
            throw TendieError.notZip
        }

        let normalizedFileName = url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "[ \\%20]", with: "_", options: .regularExpression)
        let fileManager = FileManager()

        let path = documentsDirectory
            .appendingPathComponent("UnzipItems", conformingTo: .directory)
            .appendingPathComponent(UUID().uuidString)
        if !FileManager.default.fileExists(atPath: path.path()) {
            try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        }

        let existingFiles = try FileManager.default.contentsOfDirectory(
            at: path, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        for fileURL in existingFiles {
            try FileManager.default.removeItem(at: fileURL)
        }
        let zipURL = path.appending(path: normalizedFileName)

        try fileData.write(to: zipURL, options: [.atomic])

        var destinationURL = path
        if FileManager.default.fileExists(atPath: zipURL.path()) {
            destinationURL.append(path: "directory")
            try fileManager.unzipItem(at: zipURL, to: destinationURL)
        }

        return destinationURL
    }

    private static let collectionsExt = "com.apple.WallpaperKit.CollectionsPoster"
    private static let photosExt = "com.apple.PhotosUIPrivate.PhotosPosterProvider"
    private static let descriptorMarker = "com.apple.posterkit.provider.descriptor.identifier"

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }

    private static func isDescriptorFolder(_ url: URL) -> Bool {
        guard isDirectory(url) else { return false }
        return FileManager.default.fileExists(
            atPath: url.appendingPathComponent(descriptorMarker).path)
    }

    /// Directory children excluding hidden files and the macOS archive junk
    /// folder `__MACOSX`, which `FileManager`'s `.skipsHiddenFiles` misses.
    private func children(of url: URL) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles)) ?? []
        .filter { $0.lastPathComponent != "__MACOSX" }
    }

    /// Reads a tendie's real PosterBoard structure and returns its descriptor
    /// folders keyed by the actual extension they belong to, mirroring
    /// Pocket-Poster's `getDescriptorsFromTendie`. Handles the three layouts
    /// seen in the wild:
    ///   - `container` (Apple device packs): each
    ///     `Extensions/<ext>/descriptors` folder is mapped to its real `<ext>`,
    ///     so e.g. `com.apple.MercuryPoster` wallpapers no longer get mis-routed
    ///     to collections and silently dropped.
    ///   - `descriptors` / `descriptor` / `ordered-descriptors` -> collections
    ///   - `video-descriptors` / `video-descriptor` -> Photos provider
    /// A single generic wrapper folder (common in "Standalone" exports) is
    /// descended into before the layout check.
    func getDescriptorsFromTendie(_ url: URL) -> [String: [URL]]? {
        var root = url
        let topItems = children(of: url)
        if topItems.count == 1, let only = topItems.first, Self.isDirectory(only) {
            let n = only.lastPathComponent.lowercased()
            let known = ["container", "descriptors", "descriptor",
                         "ordered-descriptors", "ordered-descriptor",
                         "video-descriptors", "video-descriptor"]
            if !known.contains(n) { root = only }
        }

        for dir in children(of: root) {
            let name = dir.lastPathComponent.lowercased()
            if name == "container" {
                guard let extDir = extensionsDir(in: dir) else { continue }
                var ret: [String: [URL]] = [:]
                for ext in children(of: extDir) {
                    guard Self.isDirectory(ext) else { continue }
                    let descrDir = ext.appendingPathComponent("descriptors")
                    guard Self.isDirectory(descrDir) else { continue }
                    let folders = descriptorFolders(in: descrDir)
                    if !folders.isEmpty { ret[ext.lastPathComponent] = folders }
                }
                if !ret.isEmpty { return ret }
            } else if name == "descriptors" || name == "descriptor"
                        || name == "ordered-descriptors" || name == "ordered-descriptor" {
                let folders = descriptorFolders(in: dir)
                if !folders.isEmpty { return [Self.collectionsExt: folders] }
            } else if name == "video-descriptors" || name == "video-descriptor" {
                let folders = descriptorFolders(in: dir)
                if !folders.isEmpty { return [Self.photosExt: folders] }
            }
        }
        return nil
    }

    /// Locates `.../PRBPosterExtensionDataStore/<ver>/Extensions` inside a
    /// PosterBoard container folder, preferring the device's extension version
    /// and falling back to any version folder present in the pack.
    private func extensionsDir(in container: URL) -> URL? {
        let base = container.appendingPathComponent(
            "Library/Application Support/PRBPosterExtensionDataStore")
        let preferred = base.appendingPathComponent(getExtensionVersion())
            .appendingPathComponent("Extensions")
        if Self.isDirectory(preferred) { return preferred }
        for ver in children(of: base) where Self.isDirectory(ver) {
            let candidate = ver.appendingPathComponent("Extensions")
            if Self.isDirectory(candidate) { return candidate }
        }
        return nil
    }

    /// Returns the immediate descriptor subfolders of a `descriptors` directory,
    /// skipping metadata junk like `__MACOSX` and dotfiles.
    private func descriptorFolders(in descriptorsDir: URL) -> [URL] {
        children(of: descriptorsDir).filter { Self.isDirectory($0) }
    }

    /// Deep-recurses a tendie directory looking for descriptor folders,
    /// returning them keyed by the PosterBoard extension they belong to.
    /// Any directory containing a `com.apple.posterkit.provider.descriptor.identifier`
    /// file is treated as a descriptor. Descriptor folders whose parent folder
    /// name contains "video" are mapped to the Photos provider; everything
    /// else to PosterBoard collections. Kept as a fallback for packs with
    /// unusual layouts that `getDescriptorsFromTendie` does not recognise.
    func findDescriptors(in url: URL) throws -> [String: [URL]] {
        var result: [String: [URL]] = [:]

        func collect(_ current: URL, target: String, parent: URL?) {
            for item in children(of: current) {
                if Self.isDescriptorFolder(item) {
                    let parentName = parent?.lastPathComponent.lowercased() ?? ""
                    if target == Self.photosExt {
                        if parentName.contains("video") {
                            result[target, default: []].append(item)
                        }
                    } else if !parentName.contains("video") {
                        result[Self.collectionsExt, default: []].append(item)
                    }
                } else if Self.isDirectory(item) {
                    collect(item, target: target, parent: item)
                }
            }
        }

        collect(url, target: Self.photosExt, parent: nil)
        collect(url, target: Self.collectionsExt, parent: nil)
        return result
    }

    /// Randomizes the wallpaper identifier inside a descriptor folder so
    /// multiple tendies do not collide on the same PosterBoard descriptor ID.
    func randomizeWallpaperId(url: URL) throws {
        let randomizedID = Int.random(in: 9999...99999)
        var files = [URL]()
        if let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let fileURL as URL in enumerator {
                let fileAttributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if fileAttributes.isRegularFile == true {
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
                fromPropertyList: plist, format: .xml, options: 0) else {
                return
            }
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

    // MARK: - Apply

    func applyTendies(appHash: String) throws {
        var extList: [String: [URL]] = [:]
        for url in selectedTendies {
            let unzippedDir = try unzipFile(at: url)
            let descriptors = (try? getDescriptorsFromTendie(unzippedDir))
                ?? (try? findDescriptors(in: unzippedDir)) ?? [:]
            guard !descriptors.isEmpty else { continue }
            extList.merge(descriptors) { (first, second) in first + second }
        }

        for (ext, descriptorFolders) in extList {
            var foldersToWrite: [URL] = []
            for descr in descriptorFolders {
                try randomizeWallpaperId(url: descr)
                foldersToWrite.append(descr)
            }

            let destPath = BadQuery.applicationContainerPath(appHash: appHash)
                + "/Library/Application Support/PRBPosterExtensionDataStore/\(getExtensionVersion())/Extensions/\(ext)/descriptors"
            print("bad_query writing to \(destPath)")

            try BadQuery.ensureDirectory(at: destPath)
            let handle = try BadQuery.consume(path: destPath, create: true)
            defer { handle.release() }

            let fm = FileManager.default
            for descr in foldersToWrite {
                let destName = UUID().uuidString
                let destURL = URL(fileURLWithPath: destPath).appendingPathComponent(destName)
                if fm.fileExists(atPath: destURL.path) {
                    try fm.removeItem(at: destURL)
                }
                try fm.copyItem(at: descr, to: destURL)
            }
        }

        cleanup()
    }

    // MARK: - Cleanup

    func cleanup() {
        try? FileManager.default.removeItem(
            at: documentsDirectory.appendingPathComponent("UnzipItems", conformingTo: .directory))
        for url in selectedTendies {
            try? FileManager.default.removeItem(
                at: documentsDirectory.appendingPathComponent(url.lastPathComponent))
        }
    }
}
