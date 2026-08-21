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
            "bad_query tidak tersedia di sistem ini."
        case .containerNotFound:
            "Container data PosterBoard tidak ditemukan."
        case .listFailed:
            "Gagal meng enumerasi container aplikasi."
        case .writeFailed(let detail):
            "Gagal menulis wallpaper: \(detail)"
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
            "/var/mobile/Containers/Data/PluginKitPlugin"
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
    static func writeDescriptors(appHash: String, descriptorFolders: [URL]) throws {
        let destination = applicationContainerPath(hash: appHash)
            + "/Library/Application Support/PRBPosterExtensionDataStore/61/Extensions/"
            + extensionID + "/descriptors"

        guard let handle = consume(path: destination, create: true) else {
            throw PosterBoardError.writeFailed("sandbox extension tidak diperoleh.")
        }
        defer { bad_query_release(handle) }

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: destination) {
            try fileManager.createDirectory(atPath: destination, withIntermediateDirectories: true)
        }

        for descriptor in descriptorFolders {
            let target = URL(fileURLWithPath: destination, isDirectory: true)
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try fileManager.copyItem(at: descriptor, to: target)
        }
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
        guard let raw = path.utf8CString.withUnsafeMutableBufferPointer(({ buffer in
            bad_query_list(buffer.baseAddress, 2_000_000)
        })) else { throw PosterBoardError.listFailed }
        defer { free(raw) }
        return String(cString: raw)
            .split(whereSeparator: \.isNewline)
            .map(String.init)
    }
}
