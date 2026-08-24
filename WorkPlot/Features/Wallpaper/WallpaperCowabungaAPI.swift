//
//  WallpaperCowabungaAPI.swift
//  WorkPlot
//
//  Adapted from Pocket Poster's CowabungaAPI.swift + DownloadableWallpaper.swift (GPL-3.0).
//  Fetches the community wallpaper catalogue from SerStars/nugget-wallpapers.
//
//  Source: github.com/leminlimez/Pocket-Poster
//

import UIKit

enum WallpaperFilterType: String, CaseIterable {
    case random = "Random"
    case newest = "Newest"
    case oldest = "Oldest"
}

final class WallpaperCowabungaAPI: ObservableObject {
    static let shared = WallpaperCowabungaAPI()

    var serverURL = ""
    var session = URLSession.shared

    func fetchWallpapers(type: DownloadableWallpaper.WallpaperType) async throws -> [DownloadableWallpaper] {
        let request = URLRequest(url: .init(string: serverURL + "wallpapers-\(type.rawValue).json")!)
        let (data, response) = try await session.data(for: request) as! (Data, HTTPURLResponse)
        guard response.statusCode == 200 else { throw WallpaperAPIError.connectionFailed }
        let wallpapers = try JSONDecoder().decode([DownloadableWallpaper].self, from: data)
        for i in wallpapers.indices { wallpapers[i].type = type }
        return wallpapers
    }

    func filterWallpapers(_ wallpapers: [DownloadableWallpaper], _ filterType: WallpaperFilterType) -> [DownloadableWallpaper] {
        var filtered = wallpapers
        if filterType == .newest { filtered = filtered.reversed() }
        else if filterType == .random { filtered = filtered.shuffled() }
        return filtered
    }

    func getCommitHash() async throws -> String {
        let request = URLRequest(url: .init(string: serverURL + "https://api.github.com/repos/SerStars/nugget-wallpapers/commits/main")!)
        let (data, response) = try await session.data(for: request) as! (Data, HTTPURLResponse)
        guard response.statusCode == 200 else { throw WallpaperAPIError.connectionFailed }
        guard let repoinfo = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let hash = repoinfo["sha"] as? String else { throw WallpaperAPIError.repoHashError }
        return hash
    }

    func getDownloadURLForWallpaper(_ wallpaper: DownloadableWallpaper) -> URL {
        wallpaper.url.hasPrefix("https://")
            ? URL(string: wallpaper.url)!
            : URL(string: serverURL + wallpaper.url)!
    }

    func getPreviewURLForWallpaper(_ wallpaper: DownloadableWallpaper) -> URL {
        URL(string: serverURL + wallpaper.preview)!
    }

    init() {
        Task {
            do {
                let hash = try await getCommitHash()
                serverURL = "https://raw.githubusercontent.com/SerStars/nugget-wallpapers/\(hash)/"
            } catch {
                await UIApplication.shared.alert(body: error.localizedDescription)
            }
        }
    }
}

final class DownloadableWallpaper: Identifiable, Codable {
    var name: String
    var description: String?
    var url: String
    var preview: String
    var authors: String?
    var type: WallpaperType?

    init(name: String, description: String?, authors: String?, preview: String, url: String, version: String) {
        self.name = name
        self.description = description
        self.authors = authors
        self.preview = preview
        self.url = url
    }

    enum WallpaperType: String, Codable {
        case custom, apple, template
    }

    func previewIsGif() -> Bool { preview.hasSuffix(".gif") }
}
