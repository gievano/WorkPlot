//
//  PatchPackageStore.swift
//  WorkPlot
//
//  Container-resolution and write engine shared by the native .3105 patch
//  flow (Patch3105). Finds an app's data container by bundle ID through the
//  bad_query exploit and rewrites target inodes inside short-lived leases.
//  The old folder-package UI was removed; originals for .3105 patches live
//  under Documents/Patch Packages/<packageID>/originals/.
//

import Foundation

struct PatchPackageRule {
    let bundleID: String
    let path: String
}

enum PatchPackageError: LocalizedError {
    case containerNotFound(String)
    case scanFailed(String)
    case partialFailure(String, [String])

    var errorDescription: String? {
        let l10n = L10n.shared
        switch self {
        case .containerNotFound(let bundleID):
            return "No data container found for \(bundleID)"
        case .scanFailed(let path):
            return "\(l10n.tr("pp.scanFailed")) \(path)"
        case .partialFailure(let name, let failures):
            return "patch \(name) finished with failures:\n" +
                failures.joined(separator: "\n")
        }
    }
}

enum PatchPackageStore {

    static func packagesDirectory() throws -> URL {
        let documents = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false)
        let directory = documents.appendingPathComponent("Patch Packages", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    /// Where stock bytes of an applied .3105 patch are preserved so a future
    /// rollback feature can restore them.
    static func originalsDirectory(packageID: String) throws -> URL {
        let safeID = packageID.replacingOccurrences(of: "/", with: "_")
        let directory = try packagesDirectory()
            .appendingPathComponent(safeID, isDirectory: true)
            .appendingPathComponent("originals", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    // MARK: - Container resolution

    private static let metadataName = ".com.apple.mobile_container_manager.metadata.plist"
    private static let containerScanRoots = [
        "/var/mobile/Containers/Data/Application",
        "/var/mobile/Containers/Data/InternalDaemon",
        "/var/mobile/Containers/Data/PluginKitPlugin",
        // iOS 27 containerizes some system daemons here.
        "/var/containers/Data/System"
    ]

    static func resolveTargetPath(
        _ rule: PatchPackageRule,
        roots: inout [String: String]
    ) throws -> String {
        let root: String
        if let cached = roots[rule.bundleID] {
            root = cached
        } else {
            root = try findContainerRoot(bundleID: rule.bundleID)
            roots[rule.bundleID] = root
        }
        return (root as NSString).appendingPathComponent(trimmedRulePath(rule))
    }

    private static func findContainerRoot(bundleID: String) throws -> String {
        for scanRoot in containerScanRoots {
            for container in try list(scanRoot) {
                guard metadataIdentifier(at: container) == bundleID else { continue }
                return container
            }
        }
        throw PatchPackageError.containerNotFound(bundleID)
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

    private static func list(_ path: String) throws -> [String] {
        var cPath = path.utf8CString
        let raw = cPath.withUnsafeMutableBufferPointer { buffer in
            bad_query_list(buffer.baseAddress, 2_000_000)
        }
        guard let raw else { throw PatchPackageError.scanFailed(path) }
        defer { free(raw) }
        return String(cString: raw)
            .split(separator: "\n")
            .map(String.init)
    }

    // MARK: - Helpers

    static func ensureParentDirectory(of fileURL: URL) throws {
        let parent = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parent.path) {
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        }
    }

    private static func trimmedRulePath(_ rule: PatchPackageRule) -> String {
        String(rule.path.dropFirst()) // strip leading "/" so appendingPathComponent stays relative
    }
}
