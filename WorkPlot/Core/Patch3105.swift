//
//  Patch3105.swift
//  WorkPlot
//
//  Native importer for .3105 patch packages: a "3105PATCH\0" magic header
//  followed by a binary plist envelope (schemaVersion, optional PBKDF2 key
//  wrapping, encrypted payload). Password prompts happen in-app at import
//  time - the caller never stores it. The decrypted payload must decode to
//  a plist carrying patch rules; other payload shapes fail explicitly.
//

import CommonCrypto
import CryptoKit
import Foundation

enum Patch3105Error: LocalizedError {
    case badMagic
    case truncated
    case unsupportedSchema(Int)
    case missingField(String)
    case wrongPasswordOrUnsupportedScheme
    case payloadUnsupported(String)
    case noRules

    var errorDescription: String? {
        switch self {
        case .badMagic:
            "Not a .3105 package (magic header mismatch)."
        case .truncated:
            "The .3105 package is truncated or corrupt."
        case .unsupportedSchema(let version):
            "Unsupported .3105 schema version \(version)."
        case .missingField(let field):
            "The .3105 envelope is missing \(field)."
        case .wrongPasswordOrUnsupportedScheme:
            "Wrong password, or this package uses an encryption scheme WorkPlot cannot open yet."
        case .payloadUnsupported(let detail):
            "The decrypted patch payload uses an unsupported layout: \(detail)"
        case .noRules:
            "The package contains no patch rules."
        }
    }
}

enum Patch3105 {

    static let magic = Data("3105PATCH\0".utf8)

    struct Envelope {
        let schemaVersion: Int
        let packageID: String
        let isProtected: Bool
        let salt: Data?
        let iterations: Int
        let wrappedKey: Data?
        /// Plaintext content key carried by unprotected packages.
        let contentKey: Data?
        let fingerprint: Data?
        let payload: Data
    }

    /// Reads the header + envelope plist without touching crypto, so the UI
    /// can decide whether a password prompt is needed before applying.
    static func parseEnvelope(_ data: Data) throws -> Envelope {
        guard data.starts(with: magic) else { throw Patch3105Error.badMagic }
        let plistData = data.dropFirst(magic.count)
        guard let obj = try? PropertyListSerialization.propertyList(
            from: plistData, options: [], format: nil) as? [String: Any] else {
            throw Patch3105Error.truncated
        }

        let schema = obj["schemaVersion"] as? Int ?? 1
        guard schema == 1 else { throw Patch3105Error.unsupportedSchema(schema) }

        let isProtected = obj["isPasswordProtected"] as? Bool ?? false
        let payload = obj["encryptedPayload"] as? Data
            ?? obj["payload"] as? Data
            ?? obj["plainPayload"] as? Data
        guard let payload, !payload.isEmpty else {
            throw Patch3105Error.missingField("encryptedPayload")
        }

        return Envelope(
            schemaVersion: schema,
            packageID: obj["packageID"] as? String ?? UUID().uuidString,
            isProtected: isProtected,
            salt: obj["kdfSalt"] as? Data,
            iterations: obj["kdfIterations"] as? Int ?? 250_000,
            wrappedKey: obj["wrappedContentKey"] as? Data,
            contentKey: obj["contentKey"] as? Data,
            fingerprint: obj["keyFingerprint"] as? Data,
            payload: payload
        )
    }

    /// Full pipeline: decrypt (when protected), decode rules, back up stock
    /// bytes once per target, then rewrite each target inode inside a lease.
    /// Runs its own background work? No - the caller dispatches; this stays
    /// synchronous and thread-agnostic like FileBrowser operations.
    static func apply(packageData: Data, password: String?) throws -> Int {
        try FileBrowser.ensureSupportedOSForWrite()
        let envelope = try parseEnvelope(packageData)
        let payload: Data
        if envelope.isProtected {
            guard let password, !password.isEmpty else {
                throw Patch3105Error.wrongPasswordOrUnsupportedScheme
            }
            payload = try decrypt(envelope: envelope, password: password)
        } else {
            payload = try plainPayload(envelope)
        }

        let rules = try decodeRules(from: payload)
        guard !rules.isEmpty else { throw Patch3105Error.noRules }

        var roots: [String: String] = [:]
        var failures: [String] = []
        for (rule, bytes) in rules {
            do {
                let targetPath = try PatchPackageStore.resolveTargetPath(rule, roots: &roots)
                let originalsRoot = try PatchPackageStore.originalsDirectory(packageID: envelope.packageID)
                let originalFile = originalsRoot.appendingPathComponent(
                    rule.bundleID + rule.path.replacingOccurrences(of: "/", with: "_"))
                if !FileManager.default.fileExists(atPath: originalFile.path) {
                    let stockBytes = try FileBrowser.readData(at: targetPath)
                    try PatchPackageStore.ensureParentDirectory(of: originalFile)
                    try stockBytes.write(to: originalFile, options: .atomic)
                }
                try BadQueryLeaseScope.withLease(forPath: targetPath) {
                    try InodeWriter.writeVerifiedInPlace(bytes, to: targetPath)
                }
            } catch {
                failures.append("\(rule.bundleID)\(rule.path): \(error.localizedDescription)")
            }
        }

        SessionLogger.shared.log(
            ".3105 patch \(envelope.packageID) applied (\(rules.count - failures.count)/\(rules.count) rules)")
        if !failures.isEmpty {
            throw PatchPackageError.partialFailure(envelope.packageID, failures)
        }
        return rules.count
    }

    /// True when the package will ask for a password before applying.
    static func requiresPassword(_ data: Data) -> Bool {
        (try? parseEnvelope(data))?.isProtected ?? false
    }

    // MARK: - Crypto

    /// Unprotected packages either carry a plaintext contentKey (payload is
    /// still AES-GCM sealed) or ship the payload completely unencrypted.
    private static func plainPayload(_ envelope: Envelope) throws -> Data {
        if let contentKey = envelope.contentKey, !contentKey.isEmpty {
            do {
                return try AES.GCM.open(
                    AES.GCM.SealedBox(combined: envelope.payload),
                    using: SymmetricKey(data: contentKey))
            } catch {
                throw Patch3105Error.wrongPasswordOrUnsupportedScheme
            }
        }
        return envelope.payload
    }

    /// Best-effort decryption for the documented PBKDF2 envelope. The binary
    /// of the reference app links CCKeyDerivationPBKDF + CryptoKit AES.GCM,
    /// but the KDF hash variant is not documented - try SHA256 then SHA512
    /// and fail with one honest error instead of guessing further.
    private static func decrypt(envelope: Envelope, password: String) throws -> Data {
        guard let salt = envelope.salt else {
            throw Patch3105Error.missingField("kdfSalt")
        }
        guard let wrapped = envelope.wrappedKey, !wrapped.isEmpty else {
            throw Patch3105Error.missingField("wrappedContentKey")
        }

        let algorithms: [CCPseudoRandomAlgorithm] = [
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
            CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512)
        ]
        for algorithm in algorithms {
            let derived = pbkdf2(password: password,
                                 salt: salt,
                                 iterations: envelope.iterations,
                                 algorithm: algorithm)
            guard let contentKey = try? AES.GCM.open(
                AES.GCM.SealedBox(combined: wrapped),
                using: SymmetricKey(data: derived)) else { continue }
            if let payload = try? AES.GCM.open(
                AES.GCM.SealedBox(combined: envelope.payload),
                using: SymmetricKey(data: contentKey)) {
                return payload
            }
        }
        throw Patch3105Error.wrongPasswordOrUnsupportedScheme
    }

    private static func pbkdf2(password: String,
                               salt: Data,
                               iterations: Int,
                               algorithm: CCPseudoRandomAlgorithm) -> Data {
        var derived = Data(repeating: 0, count: 32)
        let passwordBytes = Array(password.utf8)
        derived.withUnsafeMutableBytes { derivedBuffer in
            salt.withUnsafeBytes { saltBuffer in
                _ = CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBytes.map { CChar(bitPattern: $0) }, passwordBytes.count,
                    saltBuffer.bindMemory(to: UInt8.self).baseAddress, salt.count,
                    algorithm,
                    UInt32(iterations),
                    derivedBuffer.bindMemory(to: UInt8.self).baseAddress, 32
                )
            }
        }
        return derived
    }

    // MARK: - Payload decoding

    /// The decrypted payload is the project's bundle tree. Two layouts are
    /// accepted, mirroring what the reference app exports:
    /// 1. A ZIP archive whose top-level folders are bundle IDs and whose
    ///    remaining path components are container-relative targets (an
    ///    optional manifest declares the same mapping explicitly).
    /// 2. A plist {"rules": [{bundleID, path, data|content|replacement}]}.
    private static func decodeRules(from payload: Data) throws -> [(rule: PatchPackageRule, bytes: Data)] {
        if payload.starts(with: [0x50, 0x4B]) {
            return try decodeZipTree(payload)
        }
        guard let obj = try? PropertyListSerialization.propertyList(from: payload, options: [], format: nil) else {
            throw Patch3105Error.payloadUnsupported("payload is not a property list or ZIP archive")
        }

        let rawRules: [[String: Any]]
        if let dict = obj as? [String: Any], let list = dict["rules"] as? [[String: Any]] {
            rawRules = list
        } else if let list = obj as? [[String: Any]] {
            rawRules = list
        } else {
            throw Patch3105Error.payloadUnsupported("no recognizable rules array")
        }

        var result: [(PatchPackageRule, Data)] = []
        for raw in rawRules {
            guard let bundleID = raw["bundleID"] as? String,
                  let path = raw["path"] as? String else { continue }
            let bytes: Data?
            if let data = raw["data"] as? Data {
                bytes = data
            } else if let string = raw["content"] as? String ?? raw["replacement"] as? String {
                bytes = Data(string.utf8)
            } else {
                continue
            }
            guard let bytes, !bytes.isEmpty else { continue }
            result.append((PatchPackageRule(bundleID: bundleID, path: path), bytes))
        }
        SessionLogger.shared.log(".3105 payload decoded as plist rules (\(result.count))")
        return result
    }

    private static func decodeZipTree(_ payload: Data) throws -> [(rule: PatchPackageRule, bytes: Data)] {
        let workspace = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkPlot-Patch-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: workspace) }
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)

        let files = try ZipArchive.writeArchive(payload, to: workspace)
        guard !files.isEmpty else { throw Patch3105Error.noRules }
        SessionLogger.shared.log(".3105 payload decoded as zip tree (\(files.count) files)")

        // An explicit manifest maps files to targets when present.
        let manifestNames = ["manifest.json", "manifest.plist", "rules.plist", "project.json", "project.plist"]
        if let manifestURL = files.first(where: { manifestNames.contains($0.lastPathComponent.lowercased()) }) {
            if let rules = decodeManifestRules(manifestURL, workspace: workspace), !rules.isEmpty {
                SessionLogger.shared.log(".3105 manifest found: \(rules.count) rules")
                return rules
            }
        }

        // Otherwise infer: <bundleID>/<container-relative path>.
        var result: [(PatchPackageRule, Data)] = []
        for file in files where !manifestNames.contains(file.lastPathComponent.lowercased()) {
            let relative = file.path.dropFirst(workspace.path.count + 1)
            var components = relative.split(separator: "/")
            guard components.count >= 2 else { continue }
            let bundleID = String(components.removeFirst())
            let targetPath = "/" + components.joined(separator: "/")
            guard let bytes = try? Data(contentsOf: file), !bytes.isEmpty else { continue }
            result.append((PatchPackageRule(bundleID: bundleID, path: targetPath), bytes))
        }
        return result
    }

    /// Manifest formats: {"rules": [{"bundleID", "path", optional "file"}]}
    /// (JSON or plist). File references resolve relative to the manifest.
    private static func decodeManifestRules(_ manifestURL: URL, workspace: URL) -> [(rule: PatchPackageRule, bytes: Data)]? {
        guard let data = try? Data(contentsOf: manifestURL) else { return nil }
        let obj: [String: Any]?
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            obj = json
        } else if let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
            obj = plist
        } else {
            return nil
        }
        guard let list = obj?["rules"] as? [[String: Any]] else { return nil }

        let manifestDirectory = manifestURL.deletingLastPathComponent()
        var result: [(PatchPackageRule, Data)] = []
        for raw in list {
            guard let bundleID = raw["bundleID"] as? String,
                  let path = raw["path"] as? String else { continue }
            let bytes: Data?
            if let reference = raw["file"] as? String ?? raw["source"] as? String {
                bytes = try? Data(contentsOf: manifestDirectory.appendingPathComponent(reference))
            } else if let inline = raw["data"] as? Data {
                bytes = inline
            } else if let string = raw["content"] as? String {
                bytes = Data(string.utf8)
            } else {
                // Fall back to the same tree location inside the archive.
                bytes = try? Data(contentsOf: workspace
                    .appendingPathComponent(bundleID)
                    .appendingPathComponent(path.hasPrefix("/") ? String(path.dropFirst()) : path))
            }
            guard let bytes, !bytes.isEmpty else { continue }
            result.append((PatchPackageRule(bundleID: bundleID, path: path), bytes))
        }
        return result.isEmpty ? nil : result
    }
}
