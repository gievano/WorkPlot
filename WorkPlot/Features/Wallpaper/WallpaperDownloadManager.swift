//
//  WallpaperDownloadManager.swift
//  WorkPlot
//
//  Adapted from Pocket Poster's DownloadManager.swift (GPL-3.0).
//  Downloads .tendies files from the Cowabunga catalogue into the local store.
//
//  Source: github.com/leminlimez/Pocket-Poster
//

import Foundation
import UIKit

final class WallpaperDownloadManager: ObservableObject {
    static let shared = WallpaperDownloadManager()
    static let exploreLink = "https://cowabun.ga/wallpapers?pocketposter=true"

    @Published var downloadURL: String?

    func getWallpaperName(from url: String) -> String {
        String(url.split(separator: "/").last ?? "Unknown")
    }

    func startTendiesDownload(for url: URL) {
        if !url.absoluteString.hasSuffix(".tendies") {
            UIApplication.shared.alert(body: "Only .tendies files can be downloaded!")
        } else if PosterBoardManager.shared.selectedTendies.count >= PosterBoardManager.MaxTendies {
            UIApplication.shared.alert(title: "Max Tendies Reached", body: "Only \(PosterBoardManager.MaxTendies) descriptors can be applied.")
        } else {
            DispatchQueue.main.async {
                self.downloadURL = url.absoluteString.replacingOccurrences(of: "pocketposter://download?url=", with: "")
                UIApplication.shared.confirmAlert(
                    title: "Download Tendies File",
                    body: "Would you like to download the file \(self.getWallpaperName(from: self.downloadURL ?? "/Unknown"))?",
                    onOK: { self.downloadWallpaper() }
                )
            }
        }
    }

    func downloadWallpaper() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        UIApplication.shared.alert(
            title: "Downloading \(getWallpaperName(from: downloadURL ?? "/Unknown"))...",
            body: "Please wait"
        )

        Task {
            do {
                let newURL = try await download(from: downloadURL!)
                DispatchQueue.main.async {
                    PosterBoardManager.shared.selectedTendies.append(newURL)
                    Haptic.shared.notify(.success)
                    UIApplication.shared.dismissAlert()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        UIApplication.shared.alert(title: "Successfully downloaded wallpaper!", body: "Your downloaded .tendies will be on the Home page.")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    Haptic.shared.notify(.error)
                    UIApplication.shared.dismissAlert()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        UIApplication.shared.alert(title: "Could not download wallpaper!", body: error.localizedDescription)
                    }
                }
            }
        }
    }

    func download(from urlString: String) async throws -> URL {
        guard let url = URL(string: urlString) else { throw URLError(.unknown) }
        let request = URLRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request) as! (Data, HTTPURLResponse)
        guard response.statusCode == 200 else { throw URLError(.cannotConnectToHost) }
        let newURL = PosterBoardManager.shared.getTendiesStoreURL()
            .appendingPathComponent(getWallpaperName(from: urlString))
        try data.write(to: newURL)
        return newURL
    }

    /// Copies an imported (security-scoped) .tendies into the local store.
    /// Removes any existing copy first so re-importing the same file works
    /// (WorkPlot does the same in `importTendies`).
    func copyTendies(from url: URL) throws -> URL {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let storeURL = PosterBoardManager.shared.getTendiesStoreURL()
        let newURL = storeURL.appendingPathComponent(url.lastPathComponent)
        if FileManager.default.fileExists(atPath: newURL.path) {
            try FileManager.default.removeItem(at: newURL)
        }
        try FileManager.default.copyItem(at: url, to: newURL)
        return newURL
    }
}
