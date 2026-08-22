import Foundation

let fileManager = FileManager.default
let directory = fileManager.temporaryDirectory
    .appendingPathComponent("inode-writer-check-\(UUID().uuidString)")
try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? fileManager.removeItem(at: directory) }

let file = directory.appendingPathComponent("settings.plist")
let original = Data("original".utf8)
let replacement = Data("replacement".utf8)
let rejected = Data("rejected".utf8)
try original.write(to: file)

let inodeBefore = try file.resourceValues(forKeys: [.fileResourceIdentifierKey])
    .fileResourceIdentifier

try InodeWriter.writeVerifiedInPlace(replacement, to: file.path)
precondition(try Data(contentsOf: file) == replacement)

do {
    try InodeWriter.writeVerifiedInPlace(rejected, to: file.path) { _ in false }
    preconditionFailure("Validation rejection must throw")
} catch {
    precondition(try Data(contentsOf: file) == replacement)
}

let inodeAfter = try file.resourceValues(forKeys: [.fileResourceIdentifierKey])
    .fileResourceIdentifier
precondition(String(describing: inodeBefore) == String(describing: inodeAfter))

print("InodeWriter check passed")
