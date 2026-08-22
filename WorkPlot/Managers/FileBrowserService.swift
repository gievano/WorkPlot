//
//  FileBrowserService.swift
//  WorkPlot
//
//  Filza-style file operations on top of bad_query: directory listing,
//  read, staged inode-preserving write, delete and rename. Every mutating
//  call acquires a short-lived sandbox lease via BadQueryLeaseScope.
//

import Foundation

struct FileEntry: Identifiable {
    let name: String
    let path: String
    let isDirectory: Bool
    let size: Int64
    let modificationDate: Date?
    let kind: FileKind

    var id: String { path }
}

enum FileKind {
    case directory, plist, text, image, binary

    /// Classification runs while the caller holds a bad_query lease so the
    /// 8-byte header sniff is allowed to touch the file.
    static func of(path: String, isDirectory: Bool, header: Data?) -> FileKind {
        if isDirectory { return .directory }
        switch (path as NSString).pathExtension.lowercased() {
        case "plist", "mobileconfig": return .plist
        case "png", "jpg", "jpeg", "gif", "heic", "heif", "webp", "bmp", "tiff", "ico":
            return .image
        case "txt", "log", "conf", "json", "xml", "strings", "sh", "profile":
            return .text
        default: break
        }
        guard let header, !header.isEmpty else { return .binary }
        if header.starts(with: [0x62, 0x70, 0x6C, 0x69, 0x73, 0x74]) { return .plist } // "bplist"
        if header.starts(with: Data("<?xml".utf8)) { return .plist }
        return looksLikeText(header) ? .text : .binary
    }

    static func looksLikeText(_ sample: Data) -> Bool {
        !sample.contains(0)
    }
}

enum FileBrowserError: LocalizedError {
    case listingFailed(String)
    case readFailed(String)
    case writeFailed(String)
    case verifyFailed(String)
    case deleteFailed(String)
    case renameFailed(String)
    case plistParseFailed(String)
    case folderNotEmpty(String)
    case nameInvalid(String)
    case osUnsupported(String)

    var errorDescription: String? {
        let l10n = L10n.shared
        switch self {
        case .listingFailed(let d):
            return "\(l10n.tr("fp.error.list")) \(d)"
        case .readFailed(let d):
            return "\(l10n.tr("fp.error.read")) \(d)"
        case .writeFailed(let d):
            return "\(l10n.tr("fp.error.write")) \(d)"
        case .verifyFailed(let d):
            return "\(l10n.tr("fp.error.verify")) \(d)"
        case .deleteFailed(let d):
            return "\(l10n.tr("fp.error.delete")) \(d)"
        case .renameFailed(let d):
            return "\(l10n.tr("fp.error.rename")) \(d)"
        case .plistParseFailed(let d):
            return "\(l10n.tr("fp.error.plist")) \(d)"
        case .folderNotEmpty(let d):
            return "\(l10n.tr("fp.error.notempty")) \(d)"
        case .nameInvalid(let d):
            return "\(l10n.tr("fp.error.name")) \(d)"
        case .osUnsupported(let build):
            return String(format: l10n.tr("fp.oswarning"), build.isEmpty ? "?" : build)
        }
    }
}

struct FileQuickLocation: Identifiable {
    let labelKey: String
    let path: String
    var id: String { path }
}

enum FileBrowser {
    /// Quick-jump locations rendered at the browser root. Paths are shown
    /// as-is; entries whose target cannot be listed surface the error.
    static let shortcuts: [FileQuickLocation] = [
        FileQuickLocation(labelKey: "fp.shortcut.preferences", path: "/var/mobile/Library/Preferences"),
        FileQuickLocation(labelKey: "fp.shortcut.gestaltcache", path: "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches"),
        FileQuickLocation(labelKey: "fp.shortcut.varprefs", path: "/var/preferences"),
        FileQuickLocation(labelKey: "fp.shortcut.jb", path: "/var/jb"),
        FileQuickLocation(labelKey: "fp.shortcut.jailbreak", path: "/var/jailbreak")
    ]

    // MARK: - Listing

    static func listDirectory(_ directoryPath: String) throws -> [FileEntry] {
        let normalized = normalize(directoryPath)
        return try BadQueryLeaseScope.withLease(forPath: normalized) {
            let names = try rawList(normalized)
            let fileManager = FileManager.default
            return names.map { name in
                let child = childPath(normalized, name)
                var isDir: ObjCBool = false
                let exists = fileManager.fileExists(atPath: child, isDirectory: &isDir)
                let attrs = try? fileManager.attributesOfItem(atPath: child)
                return FileEntry(
                    name: name,
                    path: child,
                    isDirectory: exists && isDir.boolValue,
                    size: attrs?[.size] as? Int64 ?? 0,
                    modificationDate: attrs?[.modificationDate] as? Date,
                    kind: FileKind.of(path: child,
                                      isDirectory: exists && isDir.boolValue,
                                      header: sniffHeader(child))
                )
            }
            .sorted {
                if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }
    }

    private static func sniffHeader(_ path: String) -> Data? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        return try? handle.read(upToCount: 8)
    }

    private static func rawList(_ path: String) throws -> [String] {
        var cPath = path.utf8CString
        let raw = cPath.withUnsafeMutableBufferPointer { buffer in
            bad_query_list(buffer.baseAddress, 2_000_000)
        }
        guard let raw else { throw FileBrowserError.listingFailed("bad_query_list nil") }
        defer { free(raw) }
        return String(cString: raw)
            .split(separator: "\n")
            .map(String.init)
            .map { $0.hasPrefix("\(path)/") ? String($0.dropFirst(path.count + 1)) : $0 }
    }

    // MARK: - Read

    static func readData(at path: String) throws -> Data {
        try BadQueryLeaseScope.withLease(forPath: path) {
            let fileManager = FileManager.default
            guard fileManager.fileExists(atPath: path) else {
                throw FileBrowserError.readFailed(path)
            }
            return fileManager.contents(atPath: path) ?? Data()
        }
    }

    static func readText(at path: String) throws -> String {
        let data = try readData(at: path)
        guard let text = String(data: data, encoding: .utf8), FileKind.looksLikeText(data) else {
            throw FileBrowserError.readFailed(L10n.shared.tr("fp.error.binarytext"))
        }
        return text
    }

    static func readPlist(at path: String) throws -> Any {
        let data = try readData(at: path)
        var format = PropertyListSerialization.PropertyListFormat.binary
        do {
            return try PropertyListSerialization.propertyList(from: data, options: [], format: &format)
        } catch {
            throw FileBrowserError.plistParseFailed(error.localizedDescription)
        }
    }

    // MARK: - Write (staged apply)

    /// Staged-apply write: serialize to a temp copy inside the app sandbox,
    /// verify it byte-for-byte, then rewrite the live inode in place and
    /// re-read for confirmation. Requires a supported iOS 27 beta build.
    static func saveText(_ text: String, to path: String) throws {
        try ensureSupportedOSForWrite()
        let newData = Data(text.utf8)

        let stagedURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("workplot-staged-\(UUID().uuidString)")
        try newData.write(to: stagedURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: stagedURL) }

        guard FileManager.default.contents(atPath: stagedURL.path) == newData else {
            throw FileBrowserError.verifyFailed("staging")
        }

        try BadQueryLeaseScope.withLease(forPath: path) {
            try InodeWriter.writeInPlace(newData, to: path)

            guard FileManager.default.contents(atPath: path) == newData else {
                throw FileBrowserError.verifyFailed(path)
            }
        }
    }

    // MARK: - Delete / Rename

    static func deleteItem(at path: String, isDirectory: Bool) throws {
        if isDirectory {
            // Safety net: only empty folders may be removed from the UI.
            let children = try listDirectory(path)
            if !children.isEmpty {
                throw FileBrowserError.folderNotEmpty(path)
            }
        }
        try BadQueryLeaseScope.withLease(forPath: path) {
            do {
                try FileManager.default.removeItem(atPath: path)
            } catch {
                throw FileBrowserError.deleteFailed(error.localizedDescription)
            }
        }
    }

    static func renameItem(at path: String, to newName: String) throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("/"), trimmed != ".", trimmed != ".." else {
            throw FileBrowserError.nameInvalid(newName)
        }
        let parent = (path as NSString).deletingLastPathComponent
        let target = childPath(parent, trimmed)

        try BadQueryLeaseScope.withLease(forPath: parent) {
            guard !FileManager.default.fileExists(atPath: target) else {
                throw FileBrowserError.renameFailed(L10n.shared.tr("fp.error.exists"))
            }
            do {
                try FileManager.default.moveItem(atPath: path, toPath: target)
            } catch {
                throw FileBrowserError.renameFailed(error.localizedDescription)
            }
        }
    }

    // MARK: - Helpers

    /// 3105-style gating: writes only proceed on an iOS 27 developer beta
    /// build the exploit chain is verified against (beta 1-4).
    static func ensureSupportedOSForWrite() throws {
        #if !targetEnvironment(simulator)
        if !GestaltAccess.isRunningSupportedOS() {
            throw FileBrowserError.osUnsupported(GestaltAccess.currentOSBuild())
        }
        #endif
    }

    static func normalize(_ path: String) -> String {
        var trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.count > 1 && trimmed.hasSuffix("/") {
            trimmed = String(trimmed.dropLast())
        }
        return trimmed.isEmpty ? "/" : trimmed
    }

    static func childPath(_ directory: String, _ name: String) -> String {
        directory.hasSuffix("/") ? directory + name : directory + "/" + name
    }

    static func parentPath(of path: String) -> String {
        let parent = (path as NSString).deletingLastPathComponent
        return parent.isEmpty ? "/" : parent
    }
}
