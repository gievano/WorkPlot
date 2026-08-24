//
//  RDARFixCheck.swift
//  WorkPlot
//
//  macOS-only logic harness for RDARFix. Compiled together with
//  WorkPlot/Managers/RDARFix.swift by CI:
//    xcrun swiftc WorkPlot/Managers/RDARFix.swift Support/RDARFixCheck.swift -o rdarfix-check
//  Exits non-zero when any pure-logic invariant fails.
//

import Foundation

@main
enum RDARFixCheck {
    static func main() {
        exit(run())
    }

    static func run() -> Int32 {
        do {
            try checkSanitizedBackupName()
            try checkIdempotencyDetection()
            try checkBackupRoundTrip()
            try checkKnownGoodCanvases()
        } catch {
            print("RDARFix check FAILED: \(error)")
            return 1
        }
        print("RDARFix check passed")
        return 0
    }

    struct CheckFailed: Error {
        let reason: String
    }

    private static func expect(_ condition: Bool, _ reason: String) throws {
        guard condition else { throw CheckFailed(reason: reason) }
    }

    private static let targetPath = "/private/var/preferences/com.apple.iomobilegraphicsfamily.plist"

    private static func checkSanitizedBackupName() throws {
        try expect(
            RDARFix.sanitizedBackupName(forPath: targetPath)
                == "_private_var_preferences_com.apple.iomobilegraphicsfamily.plist",
            "system path must sanitize deterministically")
        try expect(RDARFix.sanitizedBackupName(forPath: "") == "backup",
               "empty path must fall back to a usable name")
        try expect(RDARFix.sanitizedBackupName(forPath: "..") == "backup",
               "'..' must not survive sanitization as a traversal name")
        try expect(RDARFix.sanitizedBackupName(forPath: "a b:c/d") == "a_b_c_d",
               "unsafe characters must each map to '_'")
    }

    private static func plistData(_ dictionary: [String: Any]) throws -> Data {
        try PropertyListSerialization.data(fromPropertyList: dictionary,
                                           format: .binary, options: 0)
    }

    private static func checkIdempotencyDetection() throws {
        let original = try plistData(["canvas_width": 100,
                                      "canvas_height": 50,
                                      "unrelated_key": "keep me"])

        try expect(!RDARFix.plistIsAlreadyFixed(original, canvasWidth: 100, canvasHeight: 51),
               "mismatched height must not count as fixed")
        try expect(!RDARFix.plistIsAlreadyFixed(original, canvasWidth: 101, canvasHeight: 50),
               "mismatched width must not count as fixed")

        let patched = try RDARFix.patchedPlistData(original, canvasWidth: 390, canvasHeight: 844)
        try expect(RDARFix.plistIsAlreadyFixed(patched, canvasWidth: 390, canvasHeight: 844),
               "patched plist must detect as already fixed")

        let reparsed = try PropertyListSerialization.propertyList(
            from: patched, options: [], format: nil) as? [String: Any]
        try expect(reparsed?["unrelated_key"] as? String == "keep me",
               "patching must preserve unrelated plist keys")

        try expect(!RDARFix.plistIsAlreadyFixed(Data("not a plist".utf8),
                                            canvasWidth: 390, canvasHeight: 844),
               "unparseable data must count as not fixed")
    }

    private static func checkKnownGoodCanvases() throws {
        // Every iPhone that can run iOS 27 must resolve without falling back
        // to the untrustworthy UIScreen bounds.
        for machine in ["iPhone12,1", "iPhone14,5", "iPhone16,2", "iPhone18,1"] {
            try expect(RDARFix.knownGoodNativeCanvas(machine: machine) != nil,
                       "\(machine) must have a known-good canvas")
        }
        try expect(RDARFix.knownGoodNativeCanvases.count >= 30,
                   "known-good table must cover every shipping iPhone")
        for (machine, size) in RDARFix.knownGoodNativeCanvases {
            try expect(machine.hasPrefix("iPhone"), "unexpected key \(machine)")
            try expect(size.width > 400 && size.height > size.width * 3 / 2 && size.height < 4000,
                       "canvas \(machine) \(size) is not a plausible portrait panel")
        }
    }

    private static func checkBackupRoundTrip() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("rdar-fix-check-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        let stock = Data(("stock-" + String(repeating: "x", count: 64)).utf8)

        let createdFirst = try RDARFix.createPersistentBackupIfMissing(
            originalData: stock, forPath: targetPath, in: root,
            now: Date(timeIntervalSince1970: 1_700_000_000), appVersion: "1.0.test")
        try expect(createdFirst, "first backup must be created")

        let createdSecond = try RDARFix.createPersistentBackupIfMissing(
            originalData: Data("PATCHED-NOT-STOCK".utf8), forPath: targetPath, in: root,
            now: Date(), appVersion: "9.9")
        try expect(!createdSecond, "second backup attempt must be skipped (idempotent)")

        guard let bundle = RDARFix.storedBackup(in: root, forPath: targetPath) else {
            throw CheckFailed(reason: "backup must be readable after creation")
        }
        try expect(bundle.data == stock,
               "round-trip bytes must stay identical to the stock content")
        try expect(bundle.metadata.originalPath == targetPath,
               "metadata must record the original path")
        try expect(bundle.metadata.byteCount == stock.count,
               "metadata must record the byte size")
        try expect(bundle.metadata.appVersion == "1.0.test",
               "metadata must record the app version")
        try expect(bundle.metadata.backedUpAt == Date(timeIntervalSince1970: 1_700_000_000),
               "metadata must record the backup date")

        // A sidecar lost mid-crash is rebuilt from context without touching bytes.
        try fileManager.removeItem(at: RDARFix.backupURLs(in: root, forPath: targetPath).metadata)
        _ = try RDARFix.createPersistentBackupIfMissing(
            originalData: stock, forPath: targetPath, in: root,
            now: Date(), appVersion: "1.0.test")
        try expect(RDARFix.storedBackup(in: root, forPath: targetPath)?.data == stock,
               "sidecar rebuild must preserve the original stock bytes")

        // Metadata pointing at another origin must never be served back.
        let wrong = RDARFix.BackupMetadata(originalPath: "/other/path",
                                           backedUpAt: Date(),
                                           byteCount: stock.count,
                                           appVersion: "1.0.test")
        try JSONEncoder().encode(wrong)
            .write(to: RDARFix.backupURLs(in: root, forPath: targetPath).metadata)
        try expect(RDARFix.storedBackup(in: root, forPath: targetPath) == nil,
               "mismatched metadata origin must invalidate the backup")
    }
}
