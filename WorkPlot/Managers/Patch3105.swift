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
            payload = envelope.payload
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

    /// Best-effort decryption for the documented PBKDF2 envelope. CryptoKit
    /// offers AES-GCM (no AES-KW), so the content key is unwrapped as a GCM
    /// sealed box keyed by the password-derived secret; anything else fails
    /// with one honest error instead of guessing further.
    private static func decrypt(envelope: Envelope, password: String) throws -> Data {
        guard let salt = envelope.salt else {
            throw Patch3105Error.missingField("kdfSalt")
        }
        guard let wrapped = envelope.wrappedKey, !wrapped.isEmpty else {
            throw Patch3105Error.missingField("wrappedContentKey")
        }

        let derivedKey = SymmetricKey(data: pbkdf2SHA256(password: password, salt: salt, iterations: envelope.iterations))

        guard let contentKey = try? AES.GCM.open(AES.GCM.SealedBox(combined: wrapped), using: derivedKey) else {
            throw Patch3105Error.wrongPasswordOrUnsupportedScheme
        }

        do {
            return try AES.GCM.open(AES.GCM.SealedBox(combined: envelope.payload), using: SymmetricKey(data: contentKey))
        } catch {
            throw Patch3105Error.wrongPasswordOrUnsupportedScheme
        }
    }

    private static func pbkdf2SHA256(password: String, salt: Data, iterations: Int) -> Data {
        var derived = Data(repeating: 0, count: 32)
        let passwordBytes = Array(password.utf8)
        derived.withUnsafeMutableBytes { derivedBuffer in
            salt.withUnsafeBytes { saltBuffer in
                _ = CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordBytes.map { CChar(bitPattern: $0) }, passwordBytes.count,
                    saltBuffer.bindMemory(to: UInt8.self).baseAddress, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    derivedBuffer.bindMemory(to: UInt8.self).baseAddress, 32
                )
            }
        }
        return derived
    }

    // MARK: - Payload decoding

    /// Accepts {"rules": [...]} plists (or a bare array). Each rule carries
    /// bundleID, path, and replacement bytes under "data"/"content"/
    /// "replacement". Anything else is reported verbatim for iteration.
    private static func decodeRules(from payload: Data) throws -> [(rule: PatchPackageRule, bytes: Data)] {
        guard let obj = try? PropertyListSerialization.propertyList(from: payload, options: [], format: nil) else {
            throw Patch3105Error.payloadUnsupported("payload is not a property list")
        }

        let rawRules: [[String: Any]]
        if let dict = obj as? [String: Any], let list = dict["rules"] as? [[String: Any]] {
            rawRules = list
        } else if let list = obj as? [[String: Any]] {
            rawRules = list
        } else if let dict = obj as? [String: Any], dict.keys.contains("replacements") {
            throw Patch3105Error.payloadUnsupported("replacements dictionary layout")
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
        return result
    }
}
