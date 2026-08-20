//
//  PosterBoard.swift
//  GestaltTweak
//
//  PosterBoard (tendies) engine derived from rooootdev/mond's
//  helpers/posterboard (AGPL-3.0), ported to use BadQueryLease.
//  Licensed under the MIT License.
//

import Combine
import Foundation
import ZIPFoundation

nonisolated enum pb_error: LocalizedError {
    case container_404
    case not_zip(URL)
    case no_descriptors(URL)
    case access_denied(String)

    var errorDescription: String? {
        switch self {
        case .container_404:
            return "could not find the PosterBoard container."
        case .not_zip(let url):
            return "\(url.lastPathComponent) is not a valid tendies/zip archive."
        case .no_descriptors(let url):
            return "no descriptors found in \(url.lastPathComponent)."
        case .access_denied(let path):
            return "failed to gain write access to \(path)."
        }
    }
}

enum PosterPaths {
    static var tendies: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("tendies", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

func isPBArchive(_ url: URL) -> Bool {
    switch url.pathExtension.lowercased() {
    case "tendies", "zip":
        return true
    default:
        return false
    }
}

nonisolated enum pb {
    static let pb_bid = "com.apple.PosterBoard"
    static let collections_ext = "com.apple.WallpaperKit.CollectionsPoster"
    static let photos_ext = "com.apple.PhotosUIPrivate.PhotosPosterProvider"
    static let ext_version = "61"
    static let container_roots = [
        "/var/mobile/Containers/Data/Application",
        "/var/mobile/Containers/Data/InternalDaemon",
        "/var/mobile/Containers/Data/PluginKitPlugin",
    ]

    private static let fm = FileManager.default
    private static let list_cache_lock = NSLock()
    private static var list_cache: [String: [String]] = [:]

    static func find_pb_container() throws -> URL {
        for root in container_roots {
            for child in list_containers(root) {
                let child_url = URL(fileURLWithPath: child, isDirectory: true)

                let hidden = child_url.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")
                if let id = read_meta_key(at: hidden, key: "MCMMetadataIdentifier"), id == pb_bid {
                    return child_url
                }

                let plain = child_url.appendingPathComponent("com.apple.mobile_container_manager.metadata.plist")
                if let id = read_meta_key(at: plain, key: "MCMMetadataIdentifier"), id == pb_bid {
                    return child_url
                }
            }
        }

        throw pb_error.container_404
    }

    static func list_containers(_ root: String) -> [String] {
        var norm = root
        if norm.hasPrefix("/private/") { norm.removeFirst("/private/".count - 1) }
        if norm.hasSuffix("/") { norm.removeLast() }

        list_cache_lock.lock()
        defer { list_cache_lock.unlock() }

        if let cached = list_cache[norm] {
            return cached
        }

        let list = GTListContainers(norm, 2_000_000) ?? []
        list_cache[norm] = list
        return list
    }

    static func read_meta_key(at url: URL, key: String) -> String? {
        guard let lease = try? acquire(url.path) else { return nil }
        defer { lease.invalidate() }

        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }

        return plist[key] as? String
    }

    static func poster_extensions_root(container: URL) -> URL {
        container
            .appendingPathComponent("Library")
            .appendingPathComponent("Application Support")
            .appendingPathComponent("PRBPosterExtensionDataStore")
            .appendingPathComponent(ext_version)
            .appendingPathComponent("Extensions")
    }

    static func descriptors_url(container: URL, ext: String) -> URL {
        poster_extensions_root(container: container)
            .appendingPathComponent(ext)
            .appendingPathComponent("descriptors")
    }

    static func apply(at urls: [URL]) throws -> Int {
        let container = try find_pb_container()
        var written = 0

        for url in urls {
            let unzip_dir = try unzip(url)
            defer { try? fm.removeItem(at: unzip_dir) }

            let descriptors = try find_descriptors(in: unzip_dir)
            guard !descriptors.isEmpty else { throw pb_error.no_descriptors(url) }

            for (ext, folders) in descriptors {
                for folder in folders {
                    guard folder.lastPathComponent != "__MACOSX" else { continue }
                    randomize_id(in: folder)
                    try write_descriptor(at: folder, container: container, ext: ext)
                    written += 1
                }
            }
        }

        return written
    }

    static func reset() throws {
        let container = try find_pb_container()
        let root = poster_extensions_root(container: container)

        guard let root_lease = try? acquire(root.path) else { return }
        defer { root_lease.invalidate() }

        guard fm.fileExists(atPath: root.path) else { return }

        for ext in (try? fm.contentsOfDirectory(atPath: root.path)) ?? [] {
            let desc_path = root.appendingPathComponent(ext).appendingPathComponent("descriptors")
            guard fm.fileExists(atPath: desc_path.path) else { continue }

            guard let lease = try? acquire(desc_path.path) else { continue }
            defer { lease.invalidate() }

            for item in (try? fm.contentsOfDirectory(atPath: desc_path.path)) ?? [] {
                try? fm.removeItem(at: desc_path.appendingPathComponent(item))
            }
        }
    }

    static func ensure_directory(at path: String) throws {
        if fm.fileExists(atPath: path) { return }

        let components = path.split(separator: "/").map(String.init)
        var built = ""
        var last_existing = ""
        for part in components {
            built += "/" + part
            if fm.fileExists(atPath: built) { last_existing = built }
        }

        let anchor = last_existing.isEmpty ? path : last_existing
        let lease = try acquire(anchor)
        defer { lease.invalidate() }

        try fm.createDirectory(atPath: path, withIntermediateDirectories: true)
    }

    private static func acquire(_ path: String) throws -> BadQueryLease {
        var failure: NSString?
        guard let lease = GTLeaseForPath(path, &failure) else {
            throw pb_error.access_denied((failure as String?) ?? path)
        }
        return lease
    }

    private static func unzip(_ url: URL) throws -> URL {
        guard let data = try? Data(contentsOf: url), data.count >= 4, data[0] == 0x50, data[1] == 0x4B else {
            throw pb_error.not_zip(url)
        }

        let dest = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: dest, withIntermediateDirectories: true)
        try fm.unzipItem(at: url, to: dest)

        return dest
    }

    private static func find_descriptors(in root: URL) throws -> [String: [URL]] {
        var result: [String: [URL]] = [:]

        let top = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles)

        if let container = top.first(where: { $0.lastPathComponent.lowercased() == "container" }) {
            let ext_dir = poster_extensions_root(container: container)

            if fm.fileExists(atPath: ext_dir.path) {
                for ext in try fm.contentsOfDirectory(at: ext_dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
                    let d = ext.appendingPathComponent("descriptors")
                    if fm.fileExists(atPath: d.path) {
                        result[ext.lastPathComponent, default: []].append(contentsOf: descriptor_folders(in: d))
                    }
                }

                return result
            }
        }

        for dir in top {
            switch dir.lastPathComponent.lowercased() {
            case "video-descriptor", "video-descriptors":
                result[photos_ext, default: []].append(contentsOf: descriptor_folders(in: dir))
            case "descriptor", "descriptors", "ordered-descriptor", "ordered-descriptors":
                result[collections_ext, default: []].append(contentsOf: descriptor_folders(in: dir))
            default:
                continue
            }
        }

        if !result.isEmpty {
            return result
        }

        if let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let dir as URL in enumerator {
                guard dir.lastPathComponent != "__MACOSX",
                      (try? dir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }

                if is_descriptor_container(dir) {
                    let ext = dir.lastPathComponent.lowercased().hasPrefix("video") ? photos_ext : collections_ext
                    result[ext, default: []].append(contentsOf: descriptor_folders(in: dir))
                } else if is_descriptor(dir) {
                    let ext = dir.lastPathComponent.lowercased().hasPrefix("video") ? photos_ext : collections_ext
                    result[ext, default: []].append(dir)
                }
            }
        }

        return result
    }

    private static func descriptor_folders(in dir: URL) -> [URL] {
        guard let children = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else {
            return []
        }

        return children.filter { $0.lastPathComponent != "__MACOSX" }
    }

    private static func is_descriptor_container(_ dir: URL) -> Bool {
        switch dir.lastPathComponent.lowercased() {
        case "descriptor", "descriptors", "ordered-descriptor", "ordered-descriptors",
             "video-descriptor", "video-descriptors":
            return true
        default:
            return false
        }
    }

    private static func is_descriptor(_ dir: URL) -> Bool {
        guard let children = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else {
            return false
        }

        return children.contains { $0.lastPathComponent == "com.apple.posterkit.provider.descriptor.identifier" }
    }

    private static func write_descriptor(at src: URL, container: URL, ext: String) throws {
        let dest_dir = descriptors_url(container: container, ext: ext)
        try ensure_directory(at: dest_dir.path)

        let lease = try acquire(dest_dir.path)
        defer { lease.invalidate() }

        let dest_url = dest_dir.appendingPathComponent(UUID().uuidString)
        if fm.fileExists(atPath: dest_url.path) { try? fm.removeItem(at: dest_url) }
        try fm.copyItem(at: src, to: dest_url)
    }

    private static func randomize_id(in url: URL) {
        let id = Int.random(in: 9999...99999)
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return }

        for case let file as URL in enumerator {
            switch file.lastPathComponent {
            case "com.apple.posterkit.provider.descriptor.identifier":
                try? String(id).data(using: .utf8)?.write(to: file)
            case "com.apple.posterkit.provider.contents.userInfo":
                set_plist_val(key: "wallpaperRepresentingIdentifier", value: id, at: file)
            case "Wallpaper.plist":
                set_plist_val(key: "identifier", value: id, at: file)
            default:
                break
            }
        }
    }

    private static func set_plist_val(key: String, value: Any, at file: URL) {
        guard let data = fm.contents(atPath: file.path), var plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else { return }
        plist[key] = value
        guard let updated = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) else { return }
        try? updated.write(to: file)
    }
}

// MARK: - Tendies catalog

struct tendies: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    let description: String?
    let url: String
    let preview: String
    let authors: String?
    let contest: String?

    var preview_url: URL? {
        URL(string: "https://raw.githubusercontent.com/SerStars/Nugget-Wallpapers/main/\(preview)")
    }

    var download_url: URL? {
        URL(string: "https://raw.githubusercontent.com/SerStars/Nugget-Wallpapers/main/\(url)")
    }
}

struct tendies_service {
    private let custom = URL(string: "https://raw.githubusercontent.com/SerStars/Nugget-Wallpapers/main/wallpapers-custom.json")!
    private let apple = URL(string: "https://raw.githubusercontent.com/SerStars/Nugget-Wallpapers/main/wallpapers-apple.json")!

    private func fetch(from url: URL) async throws -> [tendies] {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let response = response as? HTTPURLResponse,
              200..<300 ~= response.statusCode else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode([tendies].self, from: data)
    }

    func fetch_tendies() async throws -> [tendies] {
        async let custom = fetch(from: custom)
        async let apple = fetch(from: apple)

        let (custom_tendies, apple_tendies) = try await (custom, apple)

        return (custom_tendies + apple_tendies)
            .uniqued()
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

func download_tendies(_ wallpaper: tendies) async throws -> URL {
    guard let url = wallpaper.download_url else {
        throw URLError(.badURL)
    }

    let (data, response) = try await URLSession.shared.data(from: url)
    guard let response = response as? HTTPURLResponse,
          200..<300 ~= response.statusCode else {
        throw URLError(.badServerResponse)
    }

    let destination = PosterPaths.tendies.appendingPathComponent(url.lastPathComponent)
    try data.write(to: destination, options: .atomic)
    return destination
}

@MainActor
final class TendiesVM: ObservableObject {
    private let service = tendies_service()

    @Published var wallpapers: [tendies] = []
    @Published var query = ""
    @Published var loading = false
    @Published var error_msg: String?

    var filtered: [tendies] {
        guard !query.isEmpty else {
            return wallpapers
        }

        return wallpapers.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            ($0.description ?? "").localizedCaseInsensitiveContains(query) ||
            ($0.authors ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    func load() async {
        guard !loading else { return }

        loading = true
        error_msg = nil

        do {
            wallpapers = try await service.fetch_tendies()
        } catch {
            error_msg = error.localizedDescription
        }

        loading = false
    }
}
