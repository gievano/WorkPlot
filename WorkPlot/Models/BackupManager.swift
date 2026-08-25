import Foundation
import CryptoKit

/// Stores a pristine copy of the live MobileGestalt plist so every change can
/// be reversed exactly, even binary patches. The backup is created once from
/// the untouched file on the first apply and is never overwritten, so
/// "Restore" always returns the device to its factory MobileGestalt state.
final class BackupManager {

    struct BackupInfo {
        let createdAt: Date
        let byteCount: Int
        let sha256: String
    }

    enum BackupError: LocalizedError {
        case writeFailed
        case readFailed
        case invalidFile
        case none

        var errorDescription: String? {
            switch self {
            case .writeFailed: return "Could not write the backup file."
            case .readFailed: return "Could not read the backup file."
            case .invalidFile: return "That file isn't a valid MobileGestalt plist."
            case .none: return nil
            }
        }
    }

    private let fileManager = FileManager.default

    private var backupDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("WorkPlot/Backup", isDirectory: true)
    }

    private var backupURL: URL { backupDirectory.appendingPathComponent("com.apple.MobileGestalt.plist") }
    private var metaURL: URL { backupDirectory.appendingPathComponent("backup.json") }

    /// The pristine backup file itself, for exporting out of the app.
    var fileURL: URL { backupURL }

    var hasBackup: Bool {
        fileManager.fileExists(atPath: backupURL.path)
    }

    var info: BackupInfo? {
        guard hasBackup else { return nil }
        let attrs = try? fileManager.attributesOfItem(atPath: backupURL.path)
        let date = attrs?[.creationDate] as? Date
        let size = attrs?[.size] as? Int ?? 0
        let digest = (try? Data(contentsOf: backupURL)).map { Self.sha256($0) } ?? ""
        return BackupInfo(createdAt: date ?? Date(), byteCount: size, sha256: digest)
    }

    /// Creates the pristine backup from `data` only if none exists yet.
    @discardableResult
    func ensureBackup(from data: Data) throws -> BackupInfo {
        if hasBackup, let info {
            return info
        }
        try fileManager.createDirectory(at: backupDirectory,
                                        withIntermediateDirectories: true)
        guard (try? data.write(to: backupURL, options: .withoutOverwriting)) != nil else {
            throw BackupError.writeFailed
        }
        let meta: [String: Any] = [
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "byteCount": data.count,
            "sha256": Self.sha256(data)
        ]
        let metaData = try JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted])
        try? metaData.write(to: metaURL)
        return BackupInfo(createdAt: Date(), byteCount: data.count, sha256: Self.sha256(data))
    }

    /// Overwrites the stored backup with externally supplied data (e.g. a
    /// file the user previously exported), regardless of whether one
    /// already exists. Used by Settings > Backup > Import.
    func importBackup(from data: Data) throws {
        guard (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) != nil else {
            throw BackupError.invalidFile
        }
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        do {
            try data.write(to: backupURL, options: .atomic)
        } catch {
            throw BackupError.writeFailed
        }
        let meta: [String: Any] = [
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "byteCount": data.count,
            "sha256": Self.sha256(data)
        ]
        if let metaData = try? JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted]) {
            try? metaData.write(to: metaURL)
        }
    }

    /// The pristine, unmodified bytes for a full restore.
    func restoreData() throws -> Data {
        guard hasBackup else { throw BackupError.readFailed }
        return try Data(contentsOf: backupURL)
    }

    func verify(_ data: Data) -> Bool {
        guard let original = try? restoreData() else { return false }
        return original == data
    }

    static func sha256(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
