import Foundation

private struct CheckFailure: Error, CustomStringConvertible {
    let description: String
}

// Minimal localization stub for compiling the production patcher in isolation.
final class L10n {
    static let shared = L10n()
    func tr(_ key: String) -> String { key }
}

@main
enum CacheDataPatcherCheck {
    static func main() throws {
        let original = try decoded(CacheDataPatcher.originalMarker)
        var plist: [String: Any] = [
            "CacheData": original,
            "Multiline": "first line\nsecond line"
        ]

        try require(CacheDataPatcher.state(of: plist) == .off, "initial state must be off")
        try require(try CacheDataPatcher.setEnabled(true, to: &plist), "first enable must change data")
        try require(CacheDataPatcher.state(of: plist) == .on, "enabled state must be on")
        try require(plist["Multiline"] as? String == "first line\nsecond line", "unrelated multiline value changed")
        try require(try !CacheDataPatcher.setEnabled(true, to: &plist), "second enable must be idempotent")
        try require(try CacheDataPatcher.setEnabled(false, to: &plist), "disable must change data")
        try require(plist["CacheData"] as? Data == original, "enable-disable must round-trip")

        var missing: [String: Any] = [:]
        do {
            _ = try CacheDataPatcher.setEnabled(true, to: &missing)
            throw CheckFailure(description: "missing CacheData must throw")
        } catch CacheDataPatchError.cacheDataMissing {}

        var ambiguous: [String: Any] = [
            "CacheData": try decoded(CacheDataPatcher.originalMarker + CacheDataPatcher.originalMarker)
        ]
        do {
            _ = try CacheDataPatcher.setEnabled(true, to: &ambiguous)
            throw CheckFailure(description: "ambiguous marker must throw")
        } catch CacheDataPatchError.patternAmbiguous(let count) {
            try require(count == 2, "ambiguous marker count must be 2")
        }

        var mixed: [String: Any] = [
            "CacheData": try decoded(CacheDataPatcher.originalMarker + CacheDataPatcher.replacementMarker)
        ]
        try require(CacheDataPatcher.state(of: mixed) == .unknown, "mixed markers must have unknown state")
        do {
            _ = try CacheDataPatcher.setEnabled(true, to: &mixed)
            throw CheckFailure(description: "mixed markers must throw")
        } catch CacheDataPatchError.patternAmbiguous(let count) {
            try require(count == 2, "mixed marker count must be 2")
        }

        print("CacheDataPatcher OK: scoped mutation, idempotency, round-trip, missing and ambiguous guards.")
    }

    private static func decoded(_ base64: String) throws -> Data {
        guard let data = Data(base64Encoded: base64) else {
            throw CheckFailure(description: "invalid test base64")
        }
        return data
    }

    private static func require(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        if try !condition() { throw CheckFailure(description: message) }
    }
}
