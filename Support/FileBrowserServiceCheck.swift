import Foundation

@main
enum FileBrowserServiceCheck {
    static func main() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("safe-file-operations-check-\(UUID().uuidString)")
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: root) }

        let source = root.appendingPathComponent("source")
        let copied = root.appendingPathComponent("copied")
        let moved = root.appendingPathComponent("moved")
        let exported = root.appendingPathComponent("exported")
        for directory in [source, copied, moved, exported] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let folder = try SafeFileOperations.createDirectory(named: "Folder", in: source)
        precondition(fileManager.fileExists(atPath: folder.path))

        let contents = Data("hello".utf8)
        let file = try SafeFileOperations.createFile(named: "note.txt", contents: contents, in: source)
        let createdContents = try Data(contentsOf: file)
        precondition(createdContents == contents)

        let copiedFile = try SafeFileOperations.copyItem(at: file, to: copied)
        let copiedContents = try Data(contentsOf: copiedFile)
        precondition(copiedContents == contents)

        let movedFile = try SafeFileOperations.moveItem(at: copiedFile, to: moved)
        precondition(!fileManager.fileExists(atPath: copiedFile.path))
        let movedContents = try Data(contentsOf: movedFile)
        precondition(movedContents == contents)

        let exportedFile = try SafeFileOperations.copyItem(at: movedFile, to: exported)
        let exportedContents = try Data(contentsOf: exportedFile)
        precondition(exportedContents == contents)

        do {
            _ = try SafeFileOperations.createFile(named: "../escape", contents: Data(), in: source)
            preconditionFailure("Unsafe names must be rejected")
        } catch {}

        do {
            _ = try SafeFileOperations.copyItem(at: movedFile, to: exported)
            preconditionFailure("Existing destinations must not be overwritten")
        } catch {}

        print("Safe file operations check passed")
    }
}
