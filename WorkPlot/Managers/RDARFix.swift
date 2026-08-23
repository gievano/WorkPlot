//
//  RDARFix.swift
//  WorkPlot
//
//  Fixes the rdar canvas/wallpaper blur bug by patching canvas dimensions
//  into the device's com.apple.iokit.IOMobileGraphicsFamily plist (probing
//  several known locations) through the transactional InodeWriter. Keeps a
//  one-time persistent backup of the stock plist so the original state can
//  always be restored.
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
    static let backupDirectoryName = "RDAR Backups"

    /// Candidate locations of the canvas plist, tried in order. The classic
    /// jailbreak-era location is the IOKit-cased filename under
    /// /var/mobile/Library/Preferences (BetterRes/misakaX/FixRDAR4XR11);
    /// lowercase daemon-pref variants exist on some builds. ContainerManager
    /// rejects queries for absent targets, so probing candidates is how we
    /// find the one that exists on this build.
    /// ponytail: linear probe of 3 known paths; add Data/System container
    /// discovery only if a build ships none of these.
    static let candidatePaths: [(lease: String, file: String)] = [
        ("/var/mobile/Library/Preferences/com.apple.iokit.IOMobileGraphicsFamily.plist",
         "/private/var/mobile/Library/Preferences/com.apple.iokit.IOMobileGraphicsFamily.plist"),
        ("/var/preferences/com.apple.iokit.IOMobileGraphicsFamily.plist",
         "/private/var/preferences/com.apple.iokit.IOMobileGraphicsFamily.plist"),
        ("/var/preferences/com.apple.iomobilegraphicsfamily.plist",
         "/private/var/preferences/com.apple.iomobilegraphicsfamily.plist"),
    ]

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
        candidatePaths.contains { storedBackup(in: persistentBackupRoot(), forPath: $0.file) != nil }
    }

    static var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    // MARK: - Gestalt-level canvas fix

    /// MGKeys: "ybGkijAwLTwevankfVzsDQ" = MainScreenCanvasSizes (iOS 10+).
    /// Canvas dimensions are ALSO served through MobileGestalt, which we can
    /// write via the proven gestaltcache/CMG path - no graphics-plist
    /// filesystem access required. Preserves an existing value's shape when
    /// present; otherwise writes a little-endian UInt32 width+height blob.
    /// ponytail: 8-byte LE pair matches what community tooling writes;
    /// adjust if a device trace shows a richer struct.
    static let mainScreenCanvasSizesKey = "ybGkijAwLTwevankfVzsDQ"

    static func applyCanvasSizesGestalt(to plist: inout [String: Any],
                                        canvasWidth: Int,
                                        canvasHeight: Int) {
        guard canvasWidth > 0, canvasHeight > 0,
              canvasWidth <= Int(UInt32.max), canvasHeight <= Int(UInt32.max) else { return }
        var cacheExtra = plist["CacheExtra"] as? [String: Any] ?? [:]

        let pair: [UInt8] = [
            UInt8(truncatingIfNeeded: canvasWidth), UInt8(truncatingIfNeeded: canvasWidth >> 8),
            UInt8(truncatingIfNeeded: canvasWidth >> 16), UInt8(truncatingIfNeeded: canvasWidth >> 24),
            UInt8(truncatingIfNeeded: canvasHeight), UInt8(truncatingIfNeeded: canvasHeight >> 8),
            UInt8(truncatingIfNeeded: canvasHeight >> 16), UInt8(truncatingIfNeeded: canvasHeight >> 24),
        ]

        switch cacheExtra[mainScreenCanvasSizesKey] {
        case let existing as Data where existing.count >= 8:
            var patched = existing
            patched.replaceSubrange(0..<8, with: Data(pair))
            cacheExtra[mainScreenCanvasSizesKey] = patched
        case let existing as [Int] where existing.count >= 2:
            var patched = existing
            patched[0] = canvasWidth
            patched[1] = canvasHeight
            cacheExtra[mainScreenCanvasSizesKey] = patched
        case let existing as [UInt32] where existing.count >= 2:
            var patched = existing
            patched[0] = UInt32(canvasWidth)
            patched[1] = UInt32(canvasHeight)
            cacheExtra[mainScreenCanvasSizesKey] = patched
        default:
            cacheExtra[mainScreenCanvasSizesKey] = Data(pair)
        }
        plist["CacheExtra"] = cacheExtra
    }

    static func applyCanvasSizesGestalt(to plist: inout [String: Any]) {
        #if canImport(UIKit)
        let bounds = UIScreen.main.nativeBounds
        applyCanvasSizesGestalt(to: &plist,
                                canvasWidth: Int(bounds.width),
                                canvasHeight: Int(bounds.height))
        #endif
    }

    // MARK: - Device entry points
    // Everything below touches the bad_query sandbox lease and is therefore
    // only built on iOS; the macOS CI harness compiles the pure helpers above.

    #if canImport(UIKit)
    /// Marker thrown while probing a candidate: lease or read failed, so the
    /// resolver should try the next location instead of surfacing an error.
    private struct CandidateUnavailable: Error {}

    /// Probes every candidate until one yields a readable plist through its
    /// bad_query lease, then runs `body` inside that lease.
    private static func withResolvedTarget<T>(_ body: (String) throws -> T) throws -> T {
        var failures: [String] = []
        for candidate in candidatePaths {
            do {
                return try BadQueryLeaseScope.withLease(forPath: candidate.lease) {
                    guard FileManager.default.fileExists(atPath: candidate.file) ||
                          FileManager.default.contents(atPath: candidate.file) != nil else {
                        throw CandidateUnavailable()
                    }
                    return try body(candidate.file)
                }
            } catch let error as BadQueryLeaseError {
                failures.append("\(candidate.file): \(error.localizedDescription)")
            } catch is CandidateUnavailable {
                failures.append("\(candidate.file): not present on this build")
            }
        }

        // iOS 27 containerizes system daemons under /var/containers/Data/System
        // (newly reachable per forcequitOS/bad_query). Probe each container's
        // Preferences copy of the graphics plist.
        // ponytail: linear probe capped at 64 containers to bound worst case.
        let systemContainers = (try? listDirectory("/var/containers/Data/System")) ?? []
        for name in systemContainers.prefix(64) where !name.isEmpty {
            let leasePath = "/var/containers/Data/System/\(name)/Library/Preferences/com.apple.iokit.IOMobileGraphicsFamily.plist"
            let filePath = "/private\(leasePath)"
            do {
                return try BadQueryLeaseScope.withLease(forPath: leasePath) {
                    guard FileManager.default.contents(atPath: filePath) != nil else {
                        throw CandidateUnavailable()
                    }
                    return try body(filePath)
                }
            } catch let error as BadQueryLeaseError {
                failures.append("\(filePath): \(error.localizedDescription)")
            } catch is CandidateUnavailable {
                failures.append("\(filePath): not present on this build")
            }
        }

        throw RDARFixError(message:
            "No canvas plist location is reachable on this build. Tried:\n" +
            failures.joined(separator: "\n"))
    }

    /// Directory listing through bad_query_list; returns [] when unreachable.
    private static func listDirectory(_ path: String) throws -> [String] {
        var cPath = path.utf8CString
        let raw = cPath.withUnsafeMutableBufferPointer { buffer in
            bad_query_list(buffer.baseAddress, 2_000_000)
        }
        guard let raw else { return [] }
        defer { free(raw) }
        return String(cString: raw)
            .split(whereSeparator: \.isNewline)
            .map(String.init)
    }

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
        try withResolvedTarget { filePath in
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
    }

    /// Writes the persisted stock bytes back over the live plist using the
    /// same verified + rollback write as apply().
    static func restoreOriginalCanvas() throws {
        guard let target = candidatePaths.first(where: {
            storedBackup(in: persistentBackupRoot(), forPath: $0.file) != nil
        }) else {
            throw RDARFixError(message:
                "No persistent canvas backup exists yet. Run the fix once first; " +
                "the backup captures the stock plist before any patch.")
        }
        guard let backup = storedBackup(in: persistentBackupRoot(), forPath: target.file) else {
            throw RDARFixError(message: "The canvas backup disappeared mid-restore.")
        }

        try BadQueryLeaseScope.withLease(forPath: target.lease) {
            try InodeWriter.writeVerifiedInPlace(backup.data, to: target.file)
        }
    }
    #endif
}
