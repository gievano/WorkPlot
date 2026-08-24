//
//  WallpaperPosterBoardManager.swift
//  WorkPlot
//
//  Adapted from Pocket Poster's PosterBoardManager.swift (GPL-3.0).
//  Imports .tendies packages, extracts PosterBoard descriptors, randomizes
//  their ids, and applies them by symlinking into the PosterBoard app
//  container (requires the bad_query escape to be active).
//
//  Source: github.com/leminlimez/Pocket-Poster
//

import Foundation
import UIKit

final class WallpaperPosterBoardManager: ObservableObject {
    static let ShortcutURL = "https://www.icloud.com/shortcuts/a28d2c02ca11453cb5b8f91c12cfa692"
    static let WallpapersURL = "https://cowabun.ga/wallpapers"
    static let MaxTendies = 10
    static let shared = WallpaperPosterBoardManager()

    @Published var selectedTendies: [URL] = []
    @Published var videos: [LoadInfo] = []

    func getTendiesStoreURL() -> URL {
        let url = WallpaperSymlink.getDocumentsDirectory()
            .appendingPathComponent("KFC Bucket", conformingTo: .directory)
        if !FileManager.default.fileExists(atPath: url.path()) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    func openPosterBoard() -> Bool {
        guard let obj = objc_getClass("LSApplicationWorkspace") as? NSObject else { return false }
        let workspace = obj.perform(Selector(("defaultWorkspace")))?.takeUnretainedValue() as? NSObject
        return workspace?.perform(Selector(("openApplicationWithBundleID:")), with: "com.apple.PosterBoard") != nil
    }

    func runShortcut(named name: String) {
        guard let url = URL(string: "shortcuts://run-shortcut?name=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")
        else { return }
        UIApplication.shared.open(url)
    }

    // MARK: Unzip

    /// Extracts a .tendies (zip) into a fresh temp directory and returns it.
    private func unzipFile(at url: URL) throws -> URL {
        let fileName = url.deletingPathExtension().lastPathComponent
        let normalized = fileName.replacingOccurrences(of: "[ \\%20]", with: "_", options: .regularExpression)
        let fileData = try Data(contentsOf: url)

        let base = WallpaperSymlink.getDocumentsDirectory()
            .appendingPathComponent("UnzipItems", conformingTo: .directory)
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let destination = base.appendingPathComponent(normalized)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        // WorkPlot's ZipArchive handles stored + deflate entries.
        _ = try ZipArchive.writeArchive(fileData, to: destination)
        return destination
    }

    // MARK: Descriptor extraction

    /// Maps each PosterBoard extension id to the folder holding its descriptors.
    func getDescriptorsFromTendie(_ url: URL) throws -> [String: [URL]]? {
        for dir in try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            let fileName = dir.lastPathComponent.lowercased()
            if fileName == "container" {
                let extDir = dir.appendingPathComponent("Library/Application Support/PRBPosterExtensionDataStore/61/Extensions")
                var retList: [String: [URL]] = [:]
                for ext in try FileManager.default.contentsOfDirectory(at: extDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
                    retList[ext.lastPathComponent] = [ext.appendingPathComponent("descriptors")]
                }
                return retList
            } else if ["descriptor", "descriptors", "ordered-descriptor", "ordered-descriptors"].contains(fileName) {
                return ["com.apple.WallpaperKit.CollectionsPoster": [dir]]
            } else if ["video-descriptor", "video-descriptors"].contains(fileName) {
                return ["com.apple.PhotosUIPrivate.PhotosPosterProvider": [dir]]
            }
        }
        return nil
    }

    // MARK: Id randomization

    func randomizeWallpaperId(url: URL) throws {
        let randomizedID = Int.random(in: 9999...99999)
        var files: [URL] = []
        if let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            for case let fileURL as URL in enumerator {
                if (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true {
                    files.append(fileURL)
                }
            }
        }

        func setPlistValue(file: String, key: String, value: Any) {
            guard let plistData = FileManager.default.contents(atPath: file),
                  var plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any]
            else { return }
            plist[key] = value
            guard let updated = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) else { return }
            try? updated.write(to: URL(fileURLWithPath: file))
        }

        for file in files {
            switch file.lastPathComponent {
            case "com.apple.posterkit.provider.descriptor.identifier":
                try String(randomizedID).data(using: .utf8)?.write(to: file)
            case "com.apple.posterkit.provider.contents.userInfo":
                setPlistValue(file: file.path(), key: "wallpaperRepresentingIdentifier", value: randomizedID)
            case "Wallpaper.plist":
                setPlistValue(file: file.path(), key: "identifier", value: randomizedID)
            default:
                continue
            }
        }
    }

    // MARK: Apply

    /// Applies all selected tendies + generated videos to PosterBoard.
    /// `appHash` is the PosterBoard container hash (from Nugget).
    func applyTendies(appHash: String) throws {
        var extList: [String: [URL]] = [:]

        if !videos.isEmpty {
            extList["com.apple.WallpaperKit.CollectionsPoster"] = []
            for video in videos {
                if case let .loaded(movie) = video.loadState {
                    do {
                        let newVideo = try WallpaperVideoHandler.createCaml(from: movie.url, autoReverses: video.autoReverses)
                        extList["com.apple.WallpaperKit.CollectionsPoster"]?.append(newVideo)
                    } catch {
                        print(error.localizedDescription)
                    }
                }
            }
        }

        UIApplication.shared.change(title: "Applying Wallpapers...", body: "Extracting tendies...")
        for url in selectedTendies {
            let unzippedDir = try unzipFile(at: url)
            guard let descriptors = try getDescriptorsFromTendie(unzippedDir) else { continue }
            extList.merge(descriptors) { $0 + $1 }
        }

        defer { WallpaperSymlink.cleanup() }

        for (ext, descriptorsList) in extList {
            _ = try WallpaperSymlink.createDescriptorsSymlink(appHash: appHash, ext: ext)
            for descriptors in descriptorsList {
                for descr in try FileManager.default.contentsOfDirectory(at: descriptors, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
                    if descr.lastPathComponent != "__MACOSX" {
                        try randomizeWallpaperId(url: descr)
                        let newURL = WallpaperSymlink.getDocumentsDirectory().appendingPathComponent(UUID().uuidString, conformingTo: .directory)
                        try FileManager.default.moveItem(at: descr, to: newURL)
                        try FileManager.default.trashItem(at: newURL, resultingItemURL: nil)
                    }
                }
            }
            WallpaperSymlink.cleanup()
        }

        for url in selectedTendies {
            try? FileManager.default.removeItem(at: WallpaperSymlink.getDocumentsDirectory().appendingPathComponent("UnzipItems", conformingTo: .directory))
            try? FileManager.default.removeItem(at: WallpaperSymlink.getDocumentsDirectory().appendingPathComponent(url.lastPathComponent))
            try? FileManager.default.removeItem(at: WallpaperSymlink.getDocumentsDirectory().appendingPathComponent(url.deletingPathExtension().lastPathComponent))
        }
    }

    static func clearCache() throws {
        WallpaperSymlink.cleanup()
        let docDir = WallpaperSymlink.getDocumentsDirectory()
        for file in try FileManager.default.contentsOfDirectory(at: docDir, includingPropertiesForKeys: nil) {
            if file.lastPathComponent != "CarPlayPhotos" {
                try FileManager.default.removeItem(at: file)
            }
        }
    }
}
