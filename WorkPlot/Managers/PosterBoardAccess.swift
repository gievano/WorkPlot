//
//  PosterBoardAccess.swift
//  WorkPlot
//
//  Swift port of the PosterBoard access subset of Placard's BadQuery.swift
//  (https://github.com/frs0n/placard, GPLv3). Locates the PosterBoard data
//  container and writes wallpaper descriptors through bad_query.
//

import Foundation

enum PosterBoardError: LocalizedError {
    case unsupportedSystem
    case containerNotFound
    case listFailed
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSystem:
            "bad_query is unavailable on this system."
        case .containerNotFound:
            "The PosterBoard data container was not found."
        case .listFailed:
            "Failed to enumerate application containers."
        case .writeFailed(let detail):
            "Failed to write wallpaper: \(detail)"
        }
    }
}

enum PosterBoardAccess {
    static let posterBoardBundleID = "com.apple.PosterBoard"
    static let extensionID = "com.apple.WallpaperKit.CollectionsPoster"

    private static let metadataName = ".com.apple.mobile_container_manager.metadata.plist"
    private static let cachedHashKey = "PosterBoardContainerHash"

    static var isAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return bad_query_is_available()
        #endif
    }

    /// Finds the hash (UUID) of PosterBoard's application data container by
    /// scanning candidate roots and reading each MCM metadata plist.
    static func findPosterBoardHash() throws -> String {
        if let cached = UserDefaults.standard.string(forKey: cachedHashKey),
           bundleID(at: applicationContainerPath(hash: cached)) == posterBoardBundleID {
            return cached
        }

        for root in [
            "/var/mobile/Containers/Data/Application",
            "/var/mobile/Containers/Data/InternalDaemon",
            "/var/mobile/Containers/Data/PluginKitPlugin",
            // iOS 27 containerizes some system daemons here.
            "/var/containers/Data/System"
        ] {
            for path in try list(root) where bundleID(at: path) == posterBoardBundleID {
                let hash = URL(fileURLWithPath: path).lastPathComponent
                UserDefaults.standard.set(hash, forKey: cachedHashKey)
                return hash
            }
        }
        throw PosterBoardError.containerNotFound
    }

    /// Copies prepared descriptor folders into PosterBoard's extension store.
    /// Returns the UUID folder names created; they are journaled so installs
    /// can be undone from the theme view.
    @discardableResult
    static func writeDescriptors(appHash: String, descriptorFolders: [URL]) throws -> [String] {
        let storeRoot = applicationContainerPath(hash: appHash)
            + "/Library/Application Support/PRBPosterExtensionDataStore"
        let destination = storeRoot
            + "/" + liveGeneration(in: storeRoot)
            + "/Extensions/" + extensionID + "/descriptors"

        guard let handle = consume(path: destination, create: true) else {
            throw PosterBoardError.writeFailed("sandbox extension was not acquired.")
        }
        defer { bad_query_release(handle) }

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: destination) {
            try fileManager.createDirectory(atPath: destination, withIntermediateDirectories: true)
        }

        var createdNames: [String] = []
        for descriptor in descriptorFolders {
            let target = URL(fileURLWithPath: destination, isDirectory: true)
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try fileManager.copyItem(at: descriptor, to: target)
            createdNames.append(target.lastPathComponent)
        }

        // Journal only after every copy succeeded so partial installs are
        // never recorded as fully added.
        WallpaperJournal.shared.record(createdNames)
        return createdNames
    }

    // MARK: - Installed wallpaper management

    /// Picks the newest numeric generation folder that already exists on the
    /// device (3105-style live layout discovery) instead of assuming 61;
    /// falls back to 61 when the store is empty or unreadable.
    private static func liveGeneration(in storeRoot: String) -> String {
        let names = ((try? list(storeRoot)) ?? [])
            .filter { !$0.isEmpty && $0.allSatisfy(\.isNumber) }
        guard let newest = names.compactMap(Int.init).max() else { return "61" }
        return String(newest)
    }

    private static func descriptorsPath(appHash: String) -> String {
        applicationContainerPath(hash: appHash)
            + "/Library/Application Support/PRBPosterExtensionDataStore/"
            + liveGeneration(in: applicationContainerPath(hash: appHash)
                + "/Library/Application Support/PRBPosterExtensionDataStore")
            + "/Extensions/" + extensionID + "/descriptors"
    }

    /// Lists installed wallpaper descriptor folders (UUID directory names).
    /// Intentionally does NOT parse Descriptor.plist here: reading sandboxed
    /// files during list rendering caused UI freezes on device.
    static func listInstalledWallpapers() throws -> [String] {
        let appHash = try findPosterBoardHash()
        let destination = descriptorsPath(appHash: appHash)
        guard FileManager.default.fileExists(atPath: destination) else { return [] }
        return try list(destination).sorted()
    }

    /// Removes one installed wallpaper descriptor folder by name.
    static func removeWallpaper(named name: String) throws {
        let appHash = try findPosterBoardHash()
        let target = URL(fileURLWithPath: descriptorsPath(appHash: appHash), isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)

        guard let handle = consume(path: target.path, create: false) else {
            throw PosterBoardError.writeFailed("sandbox extension was not acquired.")
        }
        defer { bad_query_release(handle) }

        guard FileManager.default.fileExists(atPath: target.path) else { return }
        try FileManager.default.removeItem(at: target)
    }

    // MARK: - Internals

    private static func applicationContainerPath(hash: String) -> String {
        "/var/mobile/Containers/Data/Application/\(hash)"
    }

    private static func bundleID(at containerPath: String) -> String? {
        let metadataPath = (containerPath as NSString).appendingPathComponent(metadataName)
        guard let handle = consume(path: metadataPath, create: true) else { return nil }
        defer { bad_query_release(handle) }
        return (NSDictionary(contentsOfFile: metadataPath) as? [String: Any])?["MCMMetadataIdentifier"] as? String
    }

    private static func consume(path: String, create: Bool) -> Int64? {
        guard path.hasPrefix("/") else { return nil }
        var cPath = path.utf8CString
        let result = cPath.withUnsafeMutableBufferPointer { buffer in
            bad_query(buffer.baseAddress, create, nil, false)
        }
        return result >= 0 ? result : nil
    }

    private static func list(_ path: String) throws -> [String] {
        var cPath = path.utf8CString
        let raw = cPath.withUnsafeMutableBufferPointer { buffer in
            bad_query_list(buffer.baseAddress, 2_000_000)
        }
        guard let raw else { throw PosterBoardError.listFailed }
        defer { free(raw) }
        return String(cString: raw)
            .split(whereSeparator: \.isNewline)
            .map(String.init)
    }
}
