//
//  UpdaterService.swift
//  WorkPlot
//
//  Checks the GitHub releases feed for a newer tagged version.
//

import Foundation

enum UpdaterService {
    static let currentVersion: String =
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"

    enum UpdateError: LocalizedError {
        case badURL
        case httpStatus(Int)
        case badPayload

        var errorDescription: String? {
            switch self {
            case .badURL:
                return "Invalid release URL."
            case .httpStatus(let code):
                return "GitHub returned HTTP \(code)."
            case .badPayload:
                return "Release response could not be decoded."
            }
        }
    }

    private static let releaseURLString =
        "https://api.github.com/repos/gievano/apps-adnan-gievano/releases/latest"

    static func latestRelease() async throws -> (tag: String, url: URL) {
        guard let url = URL(string: releaseURLString) else {
            throw UpdateError.badURL
        }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UpdateError.httpStatus(-1)
        }
        guard http.statusCode == 200 else {
            throw UpdateError.httpStatus(http.statusCode)
        }

        struct Payload: Decodable {
            let tag_name: String
            let html_url: String
        }

        guard let payload = try? JSONDecoder().decode(Payload.self, from: data),
              let releaseURL = URL(string: payload.html_url) else {
            throw UpdateError.badPayload
        }
        return (tag: payload.tag_name, url: releaseURL)
    }

    /// ponytail: numeric dot-component compare only; pre-release suffixes are ignored
    static func isNewer(_ tag: String) -> Bool {
        func numbers(_ version: String) -> [Int] {
            let core = version.dropFirst(version.hasPrefix("v") ? 1 : 0)
                .split(separator: "-").first.map(String.init) ?? version
            return core.split(separator: ".").map { Int($0) ?? 0 }
        }
        let candidate = numbers(tag)
        let current = numbers(currentVersion)
        for index in 0..<max(candidate.count, current.count) {
            let left = index < candidate.count ? candidate[index] : 0
            let right = index < current.count ? current[index] : 0
            if left != right { return left > right }
        }
        return false
    }
}
