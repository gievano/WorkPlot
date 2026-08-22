import Foundation

enum SafeFileOperationsError: LocalizedError {
    case invalidName(String)
    case invalidDirectory(String)
    case destinationExists(String)

    var errorDescription: String? {
        switch self {
        case .invalidName(let name): "Invalid file name: \(name)"
        case .invalidDirectory(let path): "Destination is not a directory: \(path)"
        case .destinationExists(let path): "Destination already exists: \(path)"
        }
    }
}

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
        let target = try destination(named: source.lastPathComponent, in: directory)
        try FileManager.default.copyItem(at: source, to: target)
        return target
    }

    static func moveItem(at source: URL, to directory: URL) throws -> URL {
        let target = try destination(named: source.lastPathComponent, in: directory)
        try FileManager.default.moveItem(at: source, to: target)
        return target
    }

    private static func destination(named rawName: String, in directory: URL) throws -> URL {
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
        guard !FileManager.default.fileExists(atPath: target.path) else {
            throw SafeFileOperationsError.destinationExists(target.path)
        }
        return target
    }
}
