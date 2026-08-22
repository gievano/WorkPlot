//
//  WallpaperCatalogService.swift
//  WorkPlot
//
//  Fetches the online wallpaper catalog (SerStars/Nugget-Wallpapers), then
//  downloads .tendies archives and extracts their PosterBoard descriptor
//  folders for installation via PosterBoardAccess.
//

import Foundation
import ZIPFoundation

enum CatalogKind: String, CaseIterable, Identifiable {
    case custom, apple

    var id: String { rawValue }

    var fileName: String { "wallpapers-\(rawValue).json" }
}

struct CatalogEntry: Identifiable, Decodable {
    let id: Int
    let name: String
    let description: String?
    let url: String
    let preview: String?
    let authors: String?
}

enum CatalogError: LocalizedError {
    case badURL
    case containerFormat
    case missingDescriptors

    var errorDescription: String? {
        switch self {
        case .badURL:
            "The catalog URL is invalid."
        case .containerFormat:
            "This wallpaper uses the unsupported container format."
        case .missingDescriptors:
            "The downloaded archive contains no descriptor folders."
        }
    }
}

enum WallpaperCatalogService {
    static let catalogBase = "https://raw.githubusercontent.com/SerStars/Nugget-Wallpapers/main/"

    static func fetchCatalog(kind: CatalogKind) async throws -> [CatalogEntry] {
        guard let url = URL(string: catalogBase + kind.fileName) else {
            throw CatalogError.badURL
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([CatalogEntry].self, from: data)
    }

    static func previewURL(for entry: CatalogEntry) -> URL? {
        entry.preview.flatMap { URL(string: catalogBase + $0) }
    }

    /// Downloads the entry's .tendies ZIP into a unique temp folder, unzips it,
    /// and returns the descriptor child folders. The temp tree is removed when
    /// this function exits; callers must copy out what they install.
    static func downloadAndExtract(entry: CatalogEntry) async throws -> [URL] {
        guard let remote = URL(string: catalogBase + entry.url) else {
            throw CatalogError.badURL
        }
        let (data, _) = try await URLSession.shared.data(from: remote)

        let workDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDirectory) }

        let archive = workDirectory.appendingPathComponent("\(entry.id).tendies")
        try data.write(to: archive)

        let unzipped = workDirectory.appendingPathComponent("extracted", isDirectory: true)
        try FileManager.default.unzipItem(at: archive, to: unzipped)

        let contents = try FileManager.default.contentsOfDirectory(
            at: unzipped,
            includingPropertiesForKeys: [.isDirectoryKey]
        )

        for folder in contents where ["descriptor", "descriptors"].contains(folder.lastPathComponent) {
            let children = try FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.isDirectoryKey]
            )
            let descriptorFolders = children.filter {
                (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
            }
            if !descriptorFolders.isEmpty {
                return descriptorFolders
            }
        }

        if contents.contains(where: { $0.lastPathComponent == "container" }) {
            throw CatalogError.containerFormat
        }
        throw CatalogError.missingDescriptors
    }

    @discardableResult
    static func install(descriptorFolders: [URL], name: String) throws -> [String] {
        let appHash = try PosterBoardAccess.findPosterBoardHash()
        let written = try PosterBoardAccess.writeDescriptors(appHash: appHash, descriptorFolders: descriptorFolders)
        SessionLogger.shared.log("catalog install ok: \(name) (\(written.count) descriptors)")
        return written
    }
}
