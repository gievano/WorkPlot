//
//  WallpaperSymlink.swift
//  WorkPlot
//
//  Adapted from Pocket Poster's SymHandler.swift (GPL-3.0).
//  The PosterBoard/CarPlay descriptors live inside another app's container,
//  outside our sandbox. After the bad_query escape (ExploitManager grants
//  filesystem access), we symlink a writable folder to that descriptors
//  directory, then move descriptor folders into it.
//
//  Source: github.com/leminlimez/Pocket-Poster
//

import Foundation

struct WallpaperSymlink {
    // MARK: URL getters

    static func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    /// Pocket Poster stashes its working files under LC_HOME_PATH when the
    /// bad_query exploit sets it; fall back to the normal Documents dir.
    static func getLCDocumentsDirectory() -> URL {
        if let lcPath = ProcessInfo.processInfo.environment["LC_HOME_PATH"] {
            return URL(fileURLWithPath: "\(lcPath)/Documents")
        }
        return getDocumentsDirectory()
    }

    static func getPosterBoardHashURL() -> URL {
        getLCDocumentsDirectory().appendingPathComponent("NuggetPosterBoardHash")
    }

    static func getCarPlayHashURL() -> URL {
        getLCDocumentsDirectory().appendingPathComponent("NuggetCarPlayWallpaperHash")
    }

    static func getSymlinkURL() -> URL {
        getLCDocumentsDirectory().appendingPathComponent(".Trash", conformingTo: .symbolicLink)
    }

    // MARK: Symlink creation

    /// Creates a symlink at `.Trash` pointing at `path` and returns that URL.
    @discardableResult
    static func createSymlink(to path: String) throws -> URL {
        let symURL = getSymlinkURL()
        cleanup()
        try FileManager.default.createSymbolicLink(
            at: symURL,
            withDestinationURL: URL(fileURLWithPath: path, isDirectory: true)
        )
        return symURL
    }

    static func createAppSymlink(for appHash: String) throws -> URL {
        try createSymlink(to: "/var/mobile/Containers/Data/Application/\(appHash)")
    }

    static func getExtensionVersion() -> String {
        // Pocket Poster uses "61" on iOS 17+. WorkPlot targets iOS 27, keep 61.
        "61"
    }

    /// Symlinks directly into a given extension's descriptors folder.
    static func createDescriptorsSymlink(appHash: String, ext: String) throws -> URL {
        let extVer = getExtensionVersion()
        let target = "\(appHash)/Library/Application Support/PRBPosterExtensionDataStore/\(extVer)/Extensions/\(ext)/descriptors"
        return try createAppSymlink(for: target)
    }

    static func cleanup() {
        try? FileManager.default.removeItem(at: getSymlinkURL())
    }
}
