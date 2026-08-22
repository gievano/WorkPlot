//
//  PatchPackageStore.swift
//  WorkPlot
//
//  Import/apply/rollback of .wplot-style patch packages stored as folders in
//  Documents/Patch Packages/<name>/. App-sandbox side (manifest, replacements,
//  originals) uses plain FileManager; every write outside the sandbox goes
//  through a bad_query lease + InodeWriter so the target inode survives.
//

import CryptoKit
import Foundation

struct PatchPackageRule: Codable {
    let bundleID: String
    let path: String
}

struct PatchPackageManifest: Codable {
    let name: String
    let passwordHash: String?
    let rules: [PatchPackageRule]

    var requiresPassword: Bool { passwordHash != nil }
}

enum PatchPackageError: LocalizedError {
    case manifestInvalid(String)
    case nameInvalid(String)
    case wrongPassword
    case containerNotFound(String)
    case scanFailed(String)
    case partialFailure(String, [String])

    var errorDescription: String? {
        let l10n = L10n.shared
        switch self {
        case .manifestInvalid(let detail):
            return "\(l10n.tr("pp.manifestInvalid")) \(detail)"
        case .nameInvalid(let name):
            return "Invalid package name: \(name)"
        case .wrongPassword:
            return l10n.tr("pp.wrongPassword")
        case .containerNotFound(let bundleID):
            return "No data container found for \(bundleID)"
        case .scanFailed(let path):
            return "Failed to enumerate containers at \(path)"
        case .partialFailure(let name, let failures):
            return "patch package \(name) finished with failures:\n" +
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

    static func listPackages() -> [String] {
        guard let root = try? packagesDirectory(),
              let names = try? FileManager.default.contentsOfDirectory(atPath: root.path) else {
            return []
        }
        return names
            .filter { name in
                var isDir: ObjCBool = false
                return FileManager.default.fileExists(
                    atPath: root.appendingPathComponent(name).path, isDirectory: &isDir)
                    && isDir.boolValue
            }
            .sorted()
    }

    static func loadInfo(name: String) -> PatchPackageManifest? {
        guard let packageDir = try? packageURL(name: name),
              let data = try? Data(contentsOf: packageDir.appendingPathComponent("manifest.json")),
              let manifest = try? decodeManifest(data) else {
            return nil
        }
        return manifest
    }

    static func requiresPassword(name: String) -> Bool {
        loadInfo(name: name)?.requiresPassword ?? false
    }

    static func hasOriginals(name: String) -> Bool {
        guard let url = try? packageURL(name: name) else { return false }
        let originals = url.appendingPathComponent("originals", isDirectory: true)
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: originals.path) else {
            return false
        }
        return !contents.isEmpty
    }

    /// Imports a package folder: validates its manifest and copies only the
    /// manifest + replacements into the store under a unique name.
    static func importPackage(from folderURL: URL) throws {
        let manifestData = try Data(contentsOf: folderURL.appendingPathComponent("manifest.json"))
        let manifest = try validatedManifest(try decodeManifest(manifestData))

        let root = try packagesDirectory()
        var destination = root.appendingPathComponent(manifest.name, isDirectory: true)
        var suffix = 2
        while FileManager.default.fileExists(atPath: destination.path) {
            destination = root.appendingPathComponent("\(manifest.name)-\(suffix)", isDirectory: true)
            suffix += 1
        }

        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("workplot-pkg-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            try FileManager.default.copyItem(
                at: folderURL.appendingPathComponent("manifest.json"),
                to: staging.appendingPathComponent("manifest.json"))
            let replacementsSource = folderURL.appendingPathComponent("replacements", isDirectory: true)
            if FileManager.default.fileExists(atPath: replacementsSource.path) {
                try FileManager.default.copyItem(
                    at: replacementsSource,
                    to: staging.appendingPathComponent("replacements", isDirectory: true))
            }
            try FileManager.default.moveItem(at: staging, to: destination)
        } catch {
            try? FileManager.default.removeItem(at: staging)
            throw error
        }
        SessionLogger.shared.log("patch package \(manifest.name) imported")
    }

    /// Applies every rule: backs up stock bytes once (originals are never
    /// overwritten), then rewrites the target inode inside a lease. Rules that
    /// already succeeded stay applied; a combined error names every failure.
    static func apply(name: String, password: String?) throws {
        try FileBrowser.ensureSupportedOSForWrite()
        let manifest = try validatedManifest(try loadManifest(name: name))
        try checkPassword(manifest, password)

        let packageRoot = try packageURL(name: name)
        var roots: [String: String] = [:]
        var failures: [String] = []

        for rule in manifest.rules {
            do {
                let targetPath = try resolveTargetPath(rule, roots: &roots)
                let originalFile = packageRoot
                    .appendingPathComponent("originals", isDirectory: true)
                    .appendingPathComponent(rule.bundleID + rule.path)
                if !FileManager.default.fileExists(atPath: originalFile.path) {
                    // Idempotent: first apply captures stock; later applies keep it.
                    let stockBytes = try FileBrowser.readData(at: targetPath)
                    try ensureParentDirectory(of: originalFile)
                    try stockBytes.write(to: originalFile, options: .atomic)
                }
                let replacementFile = packageRoot
                    .appendingPathComponent("replacements", isDirectory: true)
                    .appendingPathComponent(rule.bundleID + rule.path)
                let replacementBytes = try Data(contentsOf: replacementFile)
                try BadQueryLeaseScope.withLease(forPath: targetPath) {
                    try InodeWriter.writeVerifiedInPlace(replacementBytes, to: targetPath)
                }
            } catch {
                failures.append("\(rule.bundleID)\(rule.path): \(error.localizedDescription)")
            }
        }

        let applied = manifest.rules.count - failures.count
        SessionLogger.shared.log("patch package \(name) applied (\(applied)/\(manifest.rules.count) rules)")
        if !failures.isEmpty {
            throw PatchPackageError.partialFailure(name, failures)
        }
    }

    /// Restores every rule that has an original backup. Password check mirrors
    /// apply so rollback cannot be used to bypass protection.
    static func rollBack(name: String, password: String?) throws {
        try FileBrowser.ensureSupportedOSForWrite()
        let manifest = try validatedManifest(try loadManifest(name: name))
        try checkPassword(manifest, password)

        let packageRoot = try packageURL(name: name)
        var roots: [String: String] = [:]
        var restored = 0
        var failures: [String] = []

        for rule in manifest.rules {
            let originalFile = packageRoot
                .appendingPathComponent("originals", isDirectory: true)
                .appendingPathComponent(rule.bundleID + rule.path)
            guard FileManager.default.fileExists(atPath: originalFile.path) else { continue }
            do {
                let targetPath = try resolveTargetPath(rule, roots: &roots)
                let originalBytes = try Data(contentsOf: originalFile)
                try BadQueryLeaseScope.withLease(forPath: targetPath) {
                    try InodeWriter.writeVerifiedInPlace(originalBytes, to: targetPath)
                }
                restored += 1
            } catch {
                failures.append("\(rule.bundleID)\(rule.path): \(error.localizedDescription)")
            }
        }

        SessionLogger.shared.log(
            "patch package \(name) rolled back (\(restored)/\(manifest.rules.count) rules)")
        if !failures.isEmpty {
            throw PatchPackageError.partialFailure(name, failures)
        }
    }

    static func deletePackage(name: String) throws {
        // Documents area only - plain FileManager, no lease needed.
        try FileManager.default.removeItem(at: try packageURL(name: name))
    }

    // MARK: - Container resolution (generalized from PosterBoardAccess)

    private static let metadataName = ".com.apple.mobile_container_manager.metadata.plist"
    private static let containerScanRoots = [
        "/var/mobile/Containers/Data/Application",
        "/var/mobile/Containers/Data/InternalDaemon",
        "/var/mobile/Containers/Data/PluginKitPlugin"
    ]

    private static func resolveTargetPath(
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

    // MARK: - Internals

    private static func packageURL(name: String) throws -> URL {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("/"), trimmed != ".", trimmed != ".." else {
            throw PatchPackageError.nameInvalid(name)
        }
        return try packagesDirectory().appendingPathComponent(trimmed, isDirectory: true)
    }

    private static func loadManifest(name: String) throws -> PatchPackageManifest {
        let manifestURL = try packageURL(name: name).appendingPathComponent("manifest.json")
        let data = try Data(contentsOf: manifestURL)
        return try decodeManifest(data)
    }

    private static func decodeManifest(_ data: Data) throws -> PatchPackageManifest {
        do {
            return try JSONDecoder().decode(PatchPackageManifest.self, from: data)
        } catch {
            throw PatchPackageError.manifestInvalid(error.localizedDescription)
        }
    }

    private static func validatedManifest(_ manifest: PatchPackageManifest) throws -> PatchPackageManifest {
        let name = manifest.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !name.contains("/") else {
            throw PatchPackageError.manifestInvalid("missing or invalid name")
        }
        guard !manifest.rules.isEmpty else {
            throw PatchPackageError.manifestInvalid("rules must not be empty")
        }
        for rule in manifest.rules {
            guard !rule.bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw PatchPackageError.manifestInvalid("rule bundleID must not be empty")
            }
            guard rule.path.hasPrefix("/"), rule.path.count > 1, !rule.path.hasSuffix("/") else {
                throw PatchPackageError.manifestInvalid("rule path must be absolute: \(rule.path)")
            }
        }
        return manifest
    }

    private static func trimmedRulePath(_ rule: PatchPackageRule) -> String {
        String(rule.path.dropFirst()) // strip leading "/" so appendingPathComponent stays relative
    }

    private static func ensureParentDirectory(of fileURL: URL) throws {
        let parent = fileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parent.path) {
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        }
    }

    private static func checkPassword(_ manifest: PatchPackageManifest, _ password: String?) throws {
        guard let hash = manifest.passwordHash else { return }
        guard let password, sha256Hex(password) == hash.lowercased() else {
            throw PatchPackageError.wrongPassword
        }
    }

    private static func sha256Hex(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
