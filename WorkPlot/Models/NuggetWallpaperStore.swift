//
//  NuggetWallpaperStore.swift
//  Ketamine
//
//  Fetches the Nugget-Wallpapers catalogs (leminlimez/community "custom"
//  packs and Apple's stock collections) and resolves their relative asset
//  paths against the repo's raw content host.
//

import Foundation

struct NuggetWallpaper: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    /// Absent on most Apple entries in the source manifest — several other
    /// fields (authors, contest) are similarly optional per-source.
    var description: String?
    let url: String
    let preview: String
    var authors: String?
    var contest: String?
}

enum NuggetWallpaperSource: String, CaseIterable, Identifiable {
    case custom
    case apple

    var id: String { rawValue }

    var title: String {
        switch self {
        case .custom: return "Custom"
        case .apple: return "Apple"
        }
    }

    var manifestURL: URL {
        URL(string: NuggetWallpaperStore.repoRaw + "wallpapers-\(rawValue).json")!
    }
}

@MainActor
final class NuggetWallpaperStore: ObservableObject {

    static let shared = NuggetWallpaperStore()

    fileprivate static let repoRaw = "https://raw.githubusercontent.com/SerStars/Nugget-Wallpapers/refs/heads/main/"

    @Published private(set) var wallpapers: [NuggetWallpaperSource: [NuggetWallpaper]] = [:]
    @Published private(set) var isLoading: [NuggetWallpaperSource: Bool] = [:]
    @Published private(set) var loadError: [NuggetWallpaperSource: String] = [:]

    private init() {}

    /// Resolves a manifest-relative asset path (e.g. "wallpapers/apple/iPhone Air.tendies")
    /// to a fetchable URL on the repo's raw content host.
    func assetURL(for relativePath: String) -> URL? {
        let encoded = relativePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? relativePath
        return URL(string: encoded, relativeTo: URL(string: Self.repoRaw))?.absoluteURL
    }

    func load(_ source: NuggetWallpaperSource, force: Bool = false) async {
        if !force, wallpapers[source] != nil || isLoading[source] == true { return }
        isLoading[source] = true
        loadError[source] = nil
        defer { isLoading[source] = false }
        do {
            let (data, _) = try await URLSession.shared.data(from: source.manifestURL)
            wallpapers[source] = try JSONDecoder().decode([NuggetWallpaper].self, from: data)
        } catch {
            loadError[source] = error.localizedDescription
        }
    }
}
