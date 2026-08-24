//
//  WallpaperCarPlayManager.swift
//  WorkPlot
//
//  Adapted from Pocket Poster's CarPlayWallpaper+CarPlayManager.swift and
//  CPBitmapHandler.swift (GPL-3.0).
//
//  NOTE: writing .cpbitmap requires the `Dynamic` Swift package
//  (github.com/leminlimez/Dynamic). The whole CarPlay apply path is guarded
//  with `#if canImport(Dynamic)` so the app still builds without it; enabling
//  CarPlay only needs adding that package to the Xcode project.
//
//  Source: github.com/leminlimez/Pocket-Poster
//

import SwiftUI
#if canImport(Dynamic)
import Dynamic
#endif

struct CarPlayWallpaper: Identifiable {
    var id = UUID()
    var name: String
    var lightImage: UIImage
    var darkImage: UIImage
    var selectedImageDataLight: Data?
    var selectedImageDataDark: Data?
}

final class CarPlayManager {
    static func supportsCarPlay() -> Bool {
        if UIDevice.current.userInterfaceIdiom != .phone { return false }
        if #available(iOS 19, *) {
            var osVersionString = [CChar](repeating: 0, count: 16)
            var osVersionStringLen = size_t(osVersionString.count - 1)
            if sysctlbyname("kern.osversion", &osVersionString, &osVersionStringLen, nil, 0) == 0,
               let build = String(validatingUTF8: osVersionString) {
                if ["23A5260n", "23A5260u", "23A5276f", "23A5287g"].contains(build) { return true }
            }
            return false
        }
        return true
    }

    static func getCarPlayCacheVersion() -> String {
        if #available(iOS 19.0, *) { return "-12" }
        if #available(iOS 18.0, *) { return "-11" }
        return ""
    }

    static func getCarPlayWallpaperNames() -> [String]? {
        dlopen("/System/Library/PrivateFrameworks/CarPlayUIServices.framework/CarPlayUIServices", RTLD_GLOBAL)
        if #available(iOS 18.0, *) {
            guard let obj = objc_getClass("CRSUISystemWallpaper") as? NSObject else { return nil }
            if let success = obj.perform(Selector(("wallpapers"))),
               let arr = success.takeUnretainedValue() as? [NSObject] {
                return arr.compactMap { $0.perform(Selector(("wallpaperAssetCatalogName")))?.takeUnretainedValue() as? String }
            }
        } else {
            guard let obj = objc_getClass("CRSUIWallpaperPreferences") as? NSObject else { return nil }
            if let success = obj.perform(Selector(("availableWallpapers"))),
               let arr = success.takeUnretainedValue() as? [NSObject] {
                return arr.compactMap { $0.perform(Selector(("wallpaperAssetCatalogName")))?.takeUnretainedValue() as? String }
            }
        }
        return nil
    }

    static func getCarPlayPhotosURL() -> URL {
        let cppURL = WallpaperSymlink.getDocumentsDirectory().appendingPathComponent("CarPlayPhotos", conformingTo: .directory)
        try? FileManager.default.createDirectory(at: cppURL, withIntermediateDirectories: true)
        return cppURL
    }

    static func applyCarPlay(appHash: String, wallpapers: [CarPlayWallpaper]) throws {
        #if canImport(Dynamic)
        var toRemove: [URL] = []
        var activeWP: [String] = UserDefaults.standard.array(forKey: "ActiveCarPlayWallpapers") as? [String] ?? []
        let cppURL = getCarPlayPhotosURL()
        let cacheVer = getCarPlayCacheVersion()

        for wallpaper in wallpapers {
            if let data = wallpaper.selectedImageDataLight, let _ = UIImage(data: data) {
                let imgURL = WallpaperSymlink.getDocumentsDirectory()
                    .appendingPathComponent("CAR\(wallpaper.name)Dynamic-Light\(cacheVer).cpbitmap")
                UIImage(data: data)?.writeToCPBitmapFile(to: imgURL.path() as NSString)
                try? data.write(to: cppURL.appendingPathComponent("\(wallpaper.name)-Light"))
                toRemove.append(imgURL)
                if !activeWP.contains(wallpaper.name) { activeWP.append(wallpaper.name) }
            }
            if let data = wallpaper.selectedImageDataDark, let _ = UIImage(data: data) {
                let imgURL = WallpaperSymlink.getDocumentsDirectory()
                    .appendingPathComponent("CAR\(wallpaper.name)Dynamic-Dark\(cacheVer).cpbitmap")
                UIImage(data: data)?.writeToCPBitmapFile(to: imgURL.path() as NSString)
                try? data.write(to: cppURL.appendingPathComponent("\(wallpaper.name)-Dark"))
                toRemove.append(imgURL)
                if !activeWP.contains(wallpaper.name) { activeWP.append(wallpaper.name) }
            }
        }

        _ = try WallpaperSymlink.createAppSymlink(
            for: "\(appHash)/Library/Caches/MappedImageCache/com.apple.CarPlayApp.wallpaper-images"
        )
        defer { WallpaperSymlink.cleanup() }
        for imgURL in toRemove {
            try FileManager.default.trashItem(at: imgURL, resultingItemURL: nil)
        }
        UserDefaults.standard.set(activeWP, forKey: "ActiveCarPlayWallpapers")
        #else
        throw WallpaperApplyError.unexpected(
            info: "CarPlay requires the Dynamic package (github.com/leminlimez/Dynamic). Add it to the Xcode project to enable CarPlay wallpapers."
        )
        #endif
    }
}

struct CPBitmapHandler {
    #if canImport(Dynamic)
    static func resizeAndSave(image: UIImage, to url: URL, size: CGSize) throws {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let resized = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        try? FileManager.default.removeItem(at: url)
        resized.writeToCPBitmapFile(to: url.path() as NSString)
    }
    #endif
}

#if canImport(Dynamic)
extension UIImage {
    func writeToCPBitmapFile(to path: NSString) {
        Dynamic(self).writeToCPBitmapFile(path, flags: 1)
    }
}
#endif
