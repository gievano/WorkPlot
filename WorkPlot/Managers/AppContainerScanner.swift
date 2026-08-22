//
//  AppContainerScanner.swift
//  WorkPlot
//
//  Enumerates app data containers through the bad_query exploit (same three
//  scan roots as PatchPackageStore) and measures/removes their Library/Caches
//  contents. Every filesystem touch happens inside a short-lived lease.
//

import Foundation

struct AppContainerInfo: Identifiable {
    let bundleID: String
    let rootPath: String

    var id: String { rootPath }
}

struct CacheReport {
    let app: AppContainerInfo
    let bytes: Int64
}

enum AppContainerScanError: LocalizedError {
    case listingFailed(String)

    var errorDescription: String? {
        switch self {
        case .listingFailed(let path):
            return "Failed to enumerate containers at \(path)"
        }
    }
}

enum AppContainerScanner {
    static let metadataName = ".com.apple.mobile_container_manager.metadata.plist"
    static let containerScanRoots = [
        "/var/mobile/Containers/Data/Application",
        "/var/mobile/Containers/Data/InternalDaemon",
        "/var/mobile/Containers/Data/PluginKitPlugin"
    ]

    /// Lists every data container with a resolvable MCMMetadataIdentifier,
    /// sorted by bundle ID. Unreachable roots are skipped unless nothing at
    /// all could be listed, in which case the last error surfaces.
    static func scanAllContainers() throws -> [AppContainerInfo] {
        var infos: [AppContainerInfo] = []
        var lastError: Error?
        for root in containerScanRoots {
            do {
                for container in try list(root) {
                    guard let bundleID = metadataIdentifier(at: container),
                          !bundleID.isEmpty else { continue }
                    infos.append(AppContainerInfo(bundleID: bundleID, rootPath: container))
                }
            } catch {
                lastError = error
            }
        }
        if infos.isEmpty, let lastError {
            throw lastError
        }
        return infos.sorted {
            $0.bundleID.localizedCaseInsensitiveCompare($1.bundleID) == .orderedAscending
        }
    }

    /// Total recursive size of Library/Caches plus SplashBoard snapshots
    /// (snapshot leftovers live outside Caches and are reported separately).
    static func cacheBytes(for app: AppContainerInfo) -> Int64 {
        let caches = (app.rootPath as NSString).appendingPathComponent("Library/Caches")
        let snapshots = (app.rootPath as NSString).appendingPathComponent("Library/SplashBoard/Snapshots")
        return directoryBytes(at: caches) + directoryBytes(at: snapshots)
    }

    /// Best-effort wipe of the contents of Library/Caches (the folder itself
    /// survives). Individual children that cannot be removed are skipped;
    /// returns the byte count measured immediately before deletion.
    @discardableResult
    static func cleanCache(for app: AppContainerInfo) throws -> Int64 {
        try FileBrowser.ensureSupportedOSForWrite()
        let cachesPath = (app.rootPath as NSString).appendingPathComponent("Library/Caches")
        guard FileManager.default.fileExists(atPath: cachesPath) else { return 0 }

        let freed = directoryBytes(at: cachesPath)
        try BadQueryLeaseScope.withLease(forPath: cachesPath) {
            let fileManager = FileManager.default
            let children = (try? fileManager.contentsOfDirectory(atPath: cachesPath)) ?? []
            for child in children {
                // Best effort: files held open by their app may refuse removal.
                try? fileManager.removeItem(
                    atPath: (cachesPath as NSString).appendingPathComponent(child))
            }
        }
        SessionLogger.shared.log("cache cleaned \(app.bundleID) \(freed) bytes")
        return freed
    }

    // MARK: - Helpers

    private static func directoryBytes(at directoryPath: String) -> Int64 {
        guard FileManager.default.fileExists(atPath: directoryPath) else { return 0 }
        do {
            // Lease first so the enumerator is allowed past the sandbox,
            // mirroring PatchPackageStore's consume-before-read pattern.
            return try BadQueryLeaseScope.withLease(forPath: directoryPath) {
                let fileManager = FileManager.default
                guard let enumerator = fileManager.enumerator(atPath: directoryPath) else {
                    return 0
                }
                var total: Int64 = 0
                for case let subpath as String in enumerator {
                    let child = (directoryPath as NSString).appendingPathComponent(subpath)
                    let attrs = try? fileManager.attributesOfItem(atPath: child)
                    total += attrs?[.size] as? Int64 ?? 0
                }
                return total
            }
        } catch {
            // ponytail: unreadable dirs count as 0; surface per-dir errors if totals ever need to be exact
            return 0
        }
    }

    private static func list(_ path: String) throws -> [String] {
        var cPath = path.utf8CString
        let raw = cPath.withUnsafeMutableBufferPointer { buffer in
            bad_query_list(buffer.baseAddress, 2_000_000)
        }
        guard let raw else { throw AppContainerScanError.listingFailed(path) }
        defer { free(raw) }
        return String(cString: raw)
            .split(separator: "\n")
            .map(String.init)
    }

    private static func metadataIdentifier(at containerPath: String) -> String? {
        let metadataPath = (containerPath as NSString).appendingPathComponent(metadataName)
        guard let handle = consume(path: metadataPath) else { return nil }
        defer { bad_query_release(handle) }
        return (NSDictionary(contentsOfFile: metadataPath) as? [String: Any])?["MCMMetadataIdentifier"]
            as? String
    }

    private static func consume(path: String) -> Int64? {
        guard path.hasPrefix("/") else { return nil }
        var cPath = path.utf8CString
        let result = cPath.withUnsafeMutableBufferPointer { buffer in
            bad_query(buffer.baseAddress, true, nil, false)
        }
        return result >= 0 ? result : nil
    }
}
