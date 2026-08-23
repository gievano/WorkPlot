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
    /// All known quick-jump locations, labeled by their MHA container class
    /// the way FilzaSlop presents them. ContainerManager policy makes many of
    /// them unreachable depending on the OS build, so the browser renders
    /// only the ones that pass a live listing probe; fresh probes are written
    /// to an ACCESS MAP.txt in Documents like FilzaSlop does.
    static let allShortcuts: [FileQuickLocation] = [
        FileQuickLocation(labelKey: "fp.shortcut.gestaltcache", path: "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches"),
        FileQuickLocation(labelKey: "fp.shortcut.mhaC13", path: "/var/containers/Shared/SystemGroup"),
        FileQuickLocation(labelKey: "fp.shortcut.mhaC12", path: "/var/containers/Data/System"),
        FileQuickLocation(labelKey: "fp.shortcut.mhaC2", path: "/var/mobile/Containers/Data/Application"),
        FileQuickLocation(labelKey: "fp.shortcut.mhaC7", path: "/var/mobile/Containers/Shared/AppGroup"),
        FileQuickLocation(labelKey: "fp.shortcut.mhaC10", path: "/var/mobile/Containers/Data/InternalDaemon"),
        FileQuickLocation(labelKey: "fp.shortcut.mhaC14", path: "/var/mobile/Containers/Data/PluginKitPlugin"),
        FileQuickLocation(labelKey: "fp.shortcut.preferences", path: "/var/mobile/Library/Preferences"),
        FileQuickLocation(labelKey: "fp.shortcut.varprefs", path: "/var/preferences"),
        FileQuickLocation(labelKey: "fp.shortcut.jb", path: "/var/jb"),
        FileQuickLocation(labelKey: "fp.shortcut.jailbreak", path: "/var/jailbreak")
    ]

    /// Set by the last fresh probe so the UI can mention the access map.
    private(set) static var lastProbeWroteAccessMap = false

    private static var reachabilityCacheKey: String {
        // ponytail: keyed per OS build; a new beta re-probes automatically.
        let build = GestaltAccess.currentOSBuild()
        return "FileBrowserReachableShortcutPaths:\(build.isEmpty ? "unknown" : build)"
    }

    /// Shortcut entries whose directories passed a live listing probe.
    /// Runs off the main thread from the caller; results persist per OS
    /// build so later launches skip re-probing unless nothing was reachable.
    static func reachableShortcuts() -> [FileQuickLocation] {
        if let cached = UserDefaults.standard.stringArray(forKey: reachabilityCacheKey),
           !cached.isEmpty {
            lastProbeWroteAccessMap = false
            let allowed = Set(cached)
            return allShortcuts.filter { allowed.contains($0.path) }
        }

        var reachable: [String] = []
        var mapLines: [String] = ["WorkPlot Access Map - \(Date())", ""]
        for location in allShortcuts {
            if let count = try? rawList(normalize(location.path)) {
                reachable.append(location.path)
                mapLines.append("OK       \(location.path) (\(count.count) entries)")
            } else {
                mapLines.append("BLOCKED  \(location.path)")
            }
        }
        if !reachable.isEmpty {
            UserDefaults.standard.set(reachable, forKey: reachabilityCacheKey)
        }
        writeAccessMap(mapLines)
        // Nothing probed OK (or a transient failure): fall back to the
        // container trees the exploit is documented to cover rather than
        // showing an empty screen.
        let fallback = Set([
            "/var/containers/Shared/SystemGroup",
            "/var/containers/Data/System"
        ])
        return allShortcuts.filter { fallback.contains($0.path) || reachable.contains($0.path) }
    }

    /// Mirrors FilzaSlop's ACCESS MAP.txt: a plain-text record of what this
    /// device allowed, dropped in Documents where Files app can open it.
    private static func writeAccessMap(_ lines: [String]) {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ACCESS MAP.txt")
        do {
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            lastProbeWroteAccessMap = true
        } catch {
            lastProbeWroteAccessMap = false
        }
    }

    /// Cheap reachability probe: a successful directory listing means the
    /// tree is inside ContainerManager's policy for this build.
    static func canList(_ path: String) -> Bool {
        (try? rawList(normalize(path))) != nil
    }

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
            try InodeWriter.writeVerifiedInPlace(newData, to: path)
        }
    }

    // MARK: - File operations

    static func createFile(named name: String, in directoryPath: String) throws {
        try ensureSupportedOSForWrite()
        try BadQueryLeaseScope.withLease(forPath: directoryPath) {
            _ = try SafeFileOperations.createFile(
                named: name,
                contents: Data(),
                in: URL(fileURLWithPath: directoryPath)
            )
        }
    }

    static func createDirectory(named name: String, in directoryPath: String) throws {
        try ensureSupportedOSForWrite()
        try BadQueryLeaseScope.withLease(forPath: directoryPath) {
            _ = try SafeFileOperations.createDirectory(
                named: name,
                in: URL(fileURLWithPath: directoryPath)
            )
        }
    }

    static func copyItem(at sourcePath: String, to directoryPath: String) throws {
        try ensureSupportedOSForWrite()
        try withSourceAndDestinationLease(sourcePath: sourcePath, directoryPath: directoryPath) {
            _ = try SafeFileOperations.copyItem(
                at: URL(fileURLWithPath: sourcePath),
                to: URL(fileURLWithPath: directoryPath)
            )
        }
    }

    static func moveItem(at sourcePath: String, to directoryPath: String) throws {
        try ensureSupportedOSForWrite()
        try withSourceAndDestinationLease(sourcePath: sourcePath, directoryPath: directoryPath) {
            _ = try SafeFileOperations.moveItem(
                at: URL(fileURLWithPath: sourcePath),
                to: URL(fileURLWithPath: directoryPath)
            )
        }
    }

    static func importItem(from sourceURL: URL, to directoryPath: String) throws {
        try ensureSupportedOSForWrite()
        try BadQueryLeaseScope.withLease(forPath: directoryPath) {
            _ = try SafeFileOperations.copyItem(
                at: sourceURL,
                to: URL(fileURLWithPath: directoryPath)
            )
        }
    }

    static func exportItem(at sourcePath: String) throws -> URL {
        let exportDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("workplot-export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: exportDirectory, withIntermediateDirectories: false)
        do {
            return try BadQueryLeaseScope.withLease(forPath: sourcePath) {
                try SafeFileOperations.copyItem(
                    at: URL(fileURLWithPath: sourcePath),
                    to: exportDirectory
                )
            }
        } catch {
            try? FileManager.default.removeItem(at: exportDirectory)
            throw error
        }
    }

    static func deleteItem(at path: String, isDirectory: Bool) throws {
        try ensureSupportedOSForWrite()
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
        try ensureSupportedOSForWrite()
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

    private static func withSourceAndDestinationLease<T>(
        sourcePath: String,
        directoryPath: String,
        _ operation: () throws -> T
    ) throws -> T {
        try BadQueryLeaseScope.withLease(forPath: sourcePath) {
            try BadQueryLeaseScope.withLease(forPath: directoryPath, operation)
        }
    }
}
