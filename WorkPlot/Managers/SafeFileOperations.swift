import Foundation

enum SafeFileOperationsError: LocalizedError {
    case invalidName(String)
    case invalidDirectory(String)
    case destinationExists(String)
    case recursiveDestination
    case symbolicLinkUnsupported

    var errorDescription: String? {
        switch self {
        case .invalidName(let name): "Invalid file name: \(name)"
        case .invalidDirectory(let path): "Destination is not a directory: \(path)"
        case .destinationExists(let path): "Destination already exists: \(path)"
        case .recursiveDestination: "A folder cannot be copied or moved into itself"
        case .symbolicLinkUnsupported: "Symbolic links are not supported"
        }
    }
}

/// Transfer safety follows the staging, keep-both, recursive-destination,
/// and symlink guards used by YangJiiii/3105's GPL-3.0 FileManagerService.
enum SafeFileOperations {
    static func createFile(named rawName: String, contents: Data, in directory: URL) throws -> URL {
        let target = try destination(named: rawName, in: directory)
        try contents.write(to: target, options: .withoutOverwriting)
        return target
    }

    static func createDirectory(named rawName: String, in directory: URL) throws -> URL {
        let target = try destination(named: rawName, in: directory)
        try FileManager.default.createDirectory(
            at: target,
            withIntermediateDirectories: false
        )
        return target
    }

    static func copyItem(at source: URL, to directory: URL) throws -> URL {
        let source = source.standardizedFileURL
        let directory = directory.standardizedFileURL
        let isDirectory = try validateTransfer(source: source, destinationDirectory: directory)
        let target = try destination(
            named: source.lastPathComponent,
            in: directory,
            keepBoth: true,
            isDirectory: isDirectory
        )
        let staging = directory.appendingPathComponent(".workplot-copy-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: staging) }
        try FileManager.default.copyItem(at: source, to: staging)
        try FileManager.default.moveItem(at: staging, to: target)
        return target
    }

    static func moveItem(at source: URL, to directory: URL) throws -> URL {
        let source = source.standardizedFileURL
        let directory = directory.standardizedFileURL
        let isDirectory = try validateTransfer(source: source, destinationDirectory: directory)
        let target = try destination(
            named: source.lastPathComponent,
            in: directory,
            keepBoth: true,
            isDirectory: isDirectory
        )
        do {
            try FileManager.default.moveItem(at: source, to: target)
        } catch {
            var copiedTarget: URL?
            do {
                copiedTarget = try copyItem(at: source, to: directory)
                try FileManager.default.removeItem(at: source)
                return copiedTarget!
            } catch {
                if let copiedTarget {
                    try? FileManager.default.removeItem(at: copiedTarget)
                }
                throw error
            }
        }
        return target
    }

    private static func destination(
        named rawName: String,
        in directory: URL,
        keepBoth: Bool = false,
        isDirectory: Bool = false
    ) throws -> URL {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              name != ".",
              name != "..",
              !name.contains("/"),
              !name.contains("\\"),
              !name.unicodeScalars.contains(where: { $0.value == 0 }) else {
            throw SafeFileOperationsError.invalidName(rawName)
        }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw SafeFileOperationsError.invalidDirectory(directory.path)
        }

        let target = directory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: target.path) {
            guard keepBoth else {
                throw SafeFileOperationsError.destinationExists(target.path)
            }
            return uniqueDestination(for: target, isDirectory: isDirectory)
        }
        return target
    }

    private static func validateTransfer(source: URL, destinationDirectory: URL) throws -> Bool {
        try validateNoSymbolicLinks(in: source)
        let values = try source.resourceValues(forKeys: [.isDirectoryKey])
        let isDirectory = values.isDirectory == true
        if isDirectory {
            let sourcePath = source.path.hasSuffix("/") ? source.path : source.path + "/"
            let destinationPath = destinationDirectory.path.hasSuffix("/")
                ? destinationDirectory.path
                : destinationDirectory.path + "/"
            guard destinationDirectory.path != source.path,
                  !destinationPath.hasPrefix(sourcePath) else {
                throw SafeFileOperationsError.recursiveDestination
            }
        }
        return isDirectory
    }

    private static func validateNoSymbolicLinks(in source: URL) throws {
        let keys: Set<URLResourceKey> = [.isSymbolicLinkKey, .isDirectoryKey]
        let values = try source.resourceValues(forKeys: keys)
        guard values.isSymbolicLink != true else {
            throw SafeFileOperationsError.symbolicLinkUnsupported
        }
        guard values.isDirectory == true,
              let enumerator = FileManager.default.enumerator(
                at: source,
                includingPropertiesForKeys: Array(keys)
              ) else { return }

        while let item = enumerator.nextObject() as? URL {
            let itemValues = try item.resourceValues(forKeys: keys)
            if itemValues.isSymbolicLink == true {
                enumerator.skipDescendants()
                throw SafeFileOperationsError.symbolicLinkUnsupported
            }
        }
    }

    private static func uniqueDestination(for requested: URL, isDirectory: Bool) -> URL {
        let directory = requested.deletingLastPathComponent()
        let name = requested.lastPathComponent
        let pathExtension = isDirectory ? "" : (name as NSString).pathExtension
        let baseName = pathExtension.isEmpty
            ? name
            : (name as NSString).deletingPathExtension
        var suffix = 2
        while true {
            let candidateName = pathExtension.isEmpty
                ? "\(baseName) \(suffix)"
                : "\(baseName) \(suffix).\(pathExtension)"
            let candidate = directory.appendingPathComponent(candidateName)
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            suffix += 1
        }
    }
}
