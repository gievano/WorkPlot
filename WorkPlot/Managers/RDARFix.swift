//
//  RDARFix.swift
//  WorkPlot
//
//  Fixes the rdar canvas/wallpaper blur bug by patching canvas dimensions
//  into com.apple.iomobilegraphicsfamily.plist through the transactional
//  InodeWriter. Keeps a one-time persistent backup of the stock plist so the
//  original state can always be restored.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

struct RDARFixError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum RDARFixApplyResult {
    case applied
    case alreadyFixed
}

struct RDARFix {
    static let leasePath = "/var/preferences/com.apple.iomobilegraphicsfamily.plist"
    static let filePath = "/private/var/preferences/com.apple.iomobilegraphicsfamily.plist"
    static let backupDirectoryName = "RDAR Backups"

    struct BackupMetadata: Codable {
        let originalPath: String
        let backedUpAt: Date
        let byteCount: Int
        let appVersion: String
    }

    // MARK: - Pure helpers
    // Shared by apply()/restoreOriginalCanvas() and compiled into
    // Support/RDARFixCheck.swift on macOS for CI.

    /// ponytail: flat "_" substitution is enough for the known system paths;
    /// switch to percent-encoding if many distinct paths ever land here.
    static func sanitizedBackupName(forPath path: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        let mapped = String(path.map { allowed.contains($0) ? $0 : "_" })
        switch mapped {
        case "", ".", "..":
            return "backup"
        default:
            return mapped
        }
    }

    static func backupURLs(in rootDirectory: URL,
                           forPath path: String) -> (data: URL, metadata: URL) {
        let base = rootDirectory.appendingPathComponent(sanitizedBackupName(forPath: path))
        return (base, base.appendingPathExtension("json"))
    }

    /// True when the plist already carries exactly these canvas dimensions,
    /// letting apply() skip every write. Unparseable data counts as not fixed.
    static func plistIsAlreadyFixed(_ data: Data,
                                    canvasWidth: Int,
                                    canvasHeight: Int) -> Bool {
        guard let plist = try? PropertyListSerialization.propertyList(
            from: data, options: [], format: nil) as? [String: Any] else {
            return false
        }
        return plist["canvas_width"] as? Int == canvasWidth &&
               plist["canvas_height"] as? Int == canvasHeight
    }

    /// Patched serialization of `original`, preserving its plist format and
    /// every unrelated key.
    static func patchedPlistData(_ original: Data,
                                 canvasWidth: Int,
                                 canvasHeight: Int) throws -> Data {
        var format = PropertyListSerialization.PropertyListFormat.binary
        guard var plist = try? PropertyListSerialization.propertyList(
            from: original, options: [], format: &format) as? [String: Any] else {
            throw RDARFixError(message: "The plist contents are not a valid dictionary.")
        }

        plist["canvas_width"] = canvasWidth
        plist["canvas_height"] = canvasHeight

        guard let outData = try? PropertyListSerialization.data(
            fromPropertyList: plist, format: format, options: 0) else {
            throw RDARFixError(message: "Failed to serialize the plist.")
        }
        return outData
    }

    /// Copies the stock bytes plus a JSON sidecar into `rootDirectory` once.
    /// Existing backups are never overwritten: the first backup captures the
    /// untouched stock condition. Returns true only when a new backup was
    /// created (a lost sidecar is rebuilt without touching the bytes).
    @discardableResult
    static func createPersistentBackupIfMissing(originalData: Data,
                                                forPath path: String,
                                                in rootDirectory: URL,
                                                now: Date = Date(),
                                                appVersion: String = RDARFix.currentAppVersion) throws -> Bool {
        let fileManager = FileManager.default
        let urls = backupURLs(in: rootDirectory, forPath: path)
        try fileManager.createDirectory(at: rootDirectory,
                                        withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: urls.data.path) {
            if !fileManager.fileExists(atPath: urls.metadata.path) {
                try writeBackupMetadata(for: originalData, path: path,
                                        now: now, appVersion: appVersion, to: urls.metadata)
            }
            return false
        }

        try originalData.write(to: urls.data, options: .atomic)
        try writeBackupMetadata(for: originalData, path: path,
                                now: now, appVersion: appVersion, to: urls.metadata)
        return true
    }

    private static func writeBackupMetadata(for originalData: Data,
                                            path: String,
                                            now: Date,
                                            appVersion: String,
                                            to url: URL) throws {
        let metadata = BackupMetadata(originalPath: path,
                                      backedUpAt: now,
                                      byteCount: originalData.count,
                                      appVersion: appVersion)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let encoded = try encoder.encode(metadata)
        try encoded.write(to: url, options: .atomic)
    }

    /// Reads back the persisted stock bytes and sidecar for `path`, or nil
    /// when either file is missing/corrupt or records a different origin path.
    static func storedBackup(in rootDirectory: URL,
                             forPath path: String) -> (data: Data, metadata: BackupMetadata)? {
        let urls = backupURLs(in: rootDirectory, forPath: path)
        guard let raw = try? Data(contentsOf: urls.data),
              let metadataRaw = try? Data(contentsOf: urls.metadata),
              let metadata = try? JSONDecoder().decode(BackupMetadata.self, from: metadataRaw),
              metadata.originalPath == path else {
            return nil
        }
        return (raw, metadata)
    }

    static func persistentBackupRoot() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(backupDirectoryName, isDirectory: true)
    }

    static var hasPersistentBackup: Bool {
        storedBackup(in: persistentBackupRoot(), forPath: filePath) != nil
    }

    static var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    // MARK: - Device entry points
    // Everything below touches the bad_query sandbox lease and is therefore
    // only built on iOS; the macOS CI harness compiles the pure helpers above.

    #if canImport(UIKit)
    /// Canvas size is detected from the device's native screen bounds at
    /// runtime: a hardcoded resolution only matched one iPhone model and
    /// caused the fix to misbehave on every other device.
    @discardableResult
    static func apply() throws -> RDARFixApplyResult {
        let bounds = UIScreen.main.nativeBounds
        return try apply(canvasWidth: Int(bounds.width),
                         canvasHeight: Int(bounds.height))
    }

    @discardableResult
    static func apply(canvasWidth: Int,
                      canvasHeight: Int) throws -> RDARFixApplyResult {
        do {
            return try BadQueryLeaseScope.withLease(forPath: leasePath) {
                guard let current = FileManager.default.contents(atPath: filePath) else {
                    throw RDARFixError(message: "The plist at \(filePath) could not be read.")
                }

                if plistIsAlreadyFixed(current,
                                       canvasWidth: canvasWidth,
                                       canvasHeight: canvasHeight) {
                    return .alreadyFixed
                }

                // Snapshot the stock plist before any write succeeds or fails.
                try createPersistentBackupIfMissing(
                    originalData: current, forPath: filePath,
                    in: persistentBackupRoot())

                let outData = try patchedPlistData(current,
                                                   canvasWidth: canvasWidth,
                                                   canvasHeight: canvasHeight)
                try InodeWriter.writeVerifiedInPlace(outData, to: filePath)
                return .applied
            }
        } catch let error as BadQueryLeaseError {
            throw RDARFixError(message:
                "Access to \(filePath) was denied. This RDAR path needs an active " +
                "bad_query sandbox lease for that exact path; the CMG fallback cannot " +
                "provide it because it only opens the MobileGestaltCache container, " +
                "not arbitrary preference paths. Retry after the exploit reports a " +
                "successful connection. (\(error.localizedDescription))")
        }
    }

    /// Writes the persisted stock bytes back over the live plist using the
    /// same verified + rollback write as apply().
    static func restoreOriginalCanvas() throws {
        guard let backup = storedBackup(in: persistentBackupRoot(),
                                        forPath: filePath) else {
            throw RDARFixError(message: "No persistent backup exists yet for \(filePath). " +
                "Run the fix once first; the backup is taken from the stock plist.")
        }

        do {
            try BadQueryLeaseScope.withLease(forPath: leasePath) {
                try InodeWriter.writeVerifiedInPlace(backup.data, to: filePath)
            }
        } catch let error as BadQueryLeaseError {
            throw RDARFixError(message:
                "Access to \(filePath) was denied during restore. This RDAR path needs " +
                "an active bad_query sandbox lease for that exact path; the CMG fallback " +
                "cannot provide it because it only opens the MobileGestaltCache container. " +
                "Retry after the exploit reports a successful connection. " +
                "(\(error.localizedDescription))")
        }
    }
    #endif
}
