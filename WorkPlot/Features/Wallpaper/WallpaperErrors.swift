//
//  WallpaperErrors.swift
//  WorkPlot
//
//  Adapted from Pocket Poster's Error Codes (GPL-3.0).
//  Source: github.com/leminlimez/Pocket-Poster
//

import Foundation

enum WallpaperApplyError: LocalizedError {
    case wrongAppHash
    case collectionsNeedsReset
    case unexpected(info: String)

    var errorDescription: String? {
        switch self {
        case .wrongAppHash:
            "Your app hash is incorrect. Please set it again."
        case .collectionsNeedsReset:
            "The folder is improperly set up. Please tap \"Reset Collections\" and try again."
        case .unexpected(let info):
            info
        }
    }
}

enum WallpaperAPIError: LocalizedError {
    case connectionFailed
    case repoHashError
    case unexpected(info: String)

    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            "Could not connect to server"
        case .repoHashError:
            "Unable to obtain repo hash. Maybe update to the latest version?"
        case .unexpected(let info):
            info
        }
    }
}
