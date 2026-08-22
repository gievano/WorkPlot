//
//  CacheDataPatcher.swift
//  WorkPlot
//
//  Binary patch of the top-level MobileGestalt "CacheData" blob, shared by
//  every dual-cache feature (Siri AI mode, 2x camera zoom, color palette,
//  graphics style, legacy palette). The marker is a base64 fragment of the
//  CacheData value, so only that Data value is encoded, patched, and decoded.
//  Other plist fields are never serialized or rewritten by this helper.
//
//  Hard rules (owner spec):
//   - exactly one known marker (OFF or ON) must exist, otherwise fail loudly
//     WITHOUT writing anything;
//   - zero hits + target already present = requested state already applied,
//     an idempotent no-op so sequential applies never error out;
//   - more than one hit means an ambiguous/corrupt cache - refuse to touch.
//

import Foundation

enum CacheDataPatchError: LocalizedError {
    case cacheDataMissing
    case patternNotFound
    case patternAmbiguous(count: Int)
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .cacheDataMissing:
            L10n.shared.tr("cachedata.error.missing")
        case .patternNotFound:
            L10n.shared.tr("cachedata.error.notfound")
        case .patternAmbiguous(let count):
            String(format: L10n.shared.tr("cachedata.error.ambiguous"), count)
        case .decodeFailed:
            L10n.shared.tr("cachedata.error.decode")
        }
    }
}

enum CacheDataPatcher {

    /// Base64 prefix of CacheData inside the XML serialization while the
    /// graphics/Siri capability flag is OFF (single flipped byte at index 29
    /// once enabled: 0x41 'A' -> 0x67 'g').
    static let originalMarker =
        "AAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    static let replacementMarker =
        "AAAAAAAAAAAAAAAAAAEAAAAAAAAAAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"

    enum State: Equatable {
        case off, on, unknown
    }

    static func state(of plist: [String: Any]) -> State {
        guard let cacheData = plist["CacheData"] as? Data else { return .unknown }
        let encoded = cacheData.base64EncodedString()
        let offCount = occurrences(of: originalMarker, in: encoded).count
        let onCount = occurrences(of: replacementMarker, in: encoded).count
        guard offCount + onCount == 1 else { return .unknown }
        return onCount == 1 ? .on : .off
    }

    /// Enables (or disables) the cached capability flag in one pass.
    /// Returns true when the XML actually changed, false when the plist was
    /// already in the requested state.
    @discardableResult
    static func setEnabled(_ enabled: Bool, to plist: inout [String: Any]) throws -> Bool {
        guard let cacheData = plist["CacheData"] as? Data else {
            throw CacheDataPatchError.cacheDataMissing
        }
        var encoded = cacheData.base64EncodedString()

        let offHits = occurrences(of: originalMarker, in: encoded)
        let onHits = occurrences(of: replacementMarker, in: encoded)
        let totalHits = offHits.count + onHits.count
        guard totalHits > 0 else { throw CacheDataPatchError.patternNotFound }
        guard totalHits == 1 else {
            throw CacheDataPatchError.patternAmbiguous(count: totalHits)
        }

        let sourceHits = enabled ? offHits : onHits
        let targetHits = enabled ? onHits : offHits
        if sourceHits.isEmpty {
            // Idempotent: another feature/tap already applied this state.
            guard targetHits.count == 1 else { throw CacheDataPatchError.patternNotFound }
            return false
        }
        let target = enabled ? replacementMarker : originalMarker
        encoded.replaceSubrange(sourceHits[0], with: target)

        guard let patchedData = Data(base64Encoded: encoded) else {
            throw CacheDataPatchError.decodeFailed
        }
        plist["CacheData"] = patchedData
        return true
    }

    /// Convenience for dual-cache tweaks that can only turn the flag ON.
    @discardableResult
    static func applyCapabilityFlag(to plist: inout [String: Any]) throws -> Bool {
        try setEnabled(true, to: &plist)
    }

    /// Non-overlapping match ranges so an ambiguous blob can be detected
    /// before anything is replaced.
    private static func occurrences(of needle: String, in haystack: String) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var cursor = haystack.startIndex
        while let range = haystack.range(of: needle, range: cursor..<haystack.endIndex) {
            ranges.append(range)
            cursor = range.upperBound
        }
        return ranges
    }
}
