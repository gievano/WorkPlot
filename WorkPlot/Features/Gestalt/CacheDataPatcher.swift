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
import Darwin
import MachO

// MARK: - Offset-resolved CacheData writes

private var cacheDataOffsetCache: [String: Int] = [:]

/// Resolves the byte offset of a CacheExtra key's Int value inside the
/// `CacheData` blob by scanning libMobileGestalt's `__cstring`/`__const`
/// sections — a per-key, per-firmware replacement for Nugget's hardcoded
/// slice-1616 hack. Returns 0 when the offset can't be resolved.
func cacheDataOffset(for key: String) -> Int {
    if let cached = cacheDataOffsetCache[key] { return cached }

    let libMG = "/usr/lib/libMobileGestalt.dylib"
    dlopen(libMG, RTLD_GLOBAL)

    var header: UnsafePointer<mach_header_64>?
    for i in 0..<_dyld_image_count() {
        if String(cString: _dyld_get_image_name(i)) == libMG {
            header = unsafeBitCast(_dyld_get_image_header(i), to: UnsafePointer<mach_header_64>.self)
            break
        }
    }
    if header == nil {
        for i in 0..<_dyld_image_count() {
            let name = String(cString: _dyld_get_image_name(i))
            if name.contains("libMobileGestalt") {
                header = unsafeBitCast(_dyld_get_image_header(i), to: UnsafePointer<mach_header_64>.self)
                break
            }
        }
    }
    guard let header else { cacheDataOffsetCache[key] = 0; return 0 }

    var textSize = 0
    guard let cstring = getsectiondata(header, "__TEXT", "__cstring", &textSize) else {
        cacheDataOffsetCache[key] = 0; return 0
    }
    let cstr = cstring.withMemoryRebound(to: CChar.self, capacity: textSize) { $0 }

    var keyPtr = cstr
    while Int(keyPtr - cstr) < textSize {
        if String(cString: keyPtr) == key { break }
        keyPtr += strlen(keyPtr) + 1
    }

    var constSize = 0
    var ptr = getsectiondata(header, "__AUTH_CONST", "__const", &constSize)?
        .withMemoryRebound(to: UInt.self, capacity: constSize / 8) { $0 }
    if ptr == nil {
        ptr = getsectiondata(header, "__DATA_CONST", "__const", &constSize)?
            .withMemoryRebound(to: UInt.self, capacity: constSize / 8) { $0 }
    }
    guard let ptr else { cacheDataOffsetCache[key] = 0; return 0 }

    for i in 0..<(constSize / 8) {
        if ptr[i] == UInt(bitPattern: keyPtr) {
            let offset = Int((ptr.advanced(by: i).withMemoryRebound(to: UInt16.self, capacity: 1) { $0[0x9a / 2] }) << 3)
            cacheDataOffsetCache[key] = offset
            return offset
        }
    }

    cacheDataOffsetCache[key] = 0
    return 0
}

/// Writes a little-endian Int at the CacheData offset resolved for `key`.
func setCacheData(_ value: Int, forKey key: String, in data: inout Data) throws {
    let off = cacheDataOffset(for: key)
    guard off > 0, off + MemoryLayout<Int>.size <= data.count else {
        throw CacheDataPatchError.patternNotFound
    }

    var little = Int64(value).littleEndian
    data.withUnsafeMutableBytes { raw in
        guard let base = raw.baseAddress else { return }
        withUnsafeBytes(of: &little) { bytes in
            for (i, byte) in bytes.enumerated() {
                base.assumingMemoryBound(to: UInt8.self).advanced(by: off + i).pointee = byte
            }
        }
    }
}


enum CacheDataPatchError: LocalizedError {
    case cacheDataMissing
    case patternNotFound
    case patternAmbiguous(count: Int)
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .cacheDataMissing:
            "CacheData is missing from the plist."
        case .patternNotFound:
            "The expected byte pattern was not found in CacheData."
        case .patternAmbiguous(let count):
            String(format: "Pattern matched %d times; refusing an ambiguous patch.", count)
        case .decodeFailed:
            "CacheData could not be decoded."
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
