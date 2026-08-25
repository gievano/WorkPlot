import Foundation
import Darwin
import MachO

/// CacheData blob patching.
///
/// libMobileGestalt's `__AUTH_CONST`/`__DATA_CONST` for the uint64 that points
/// at a key's cstring, then derive the offset of that key's Int value inside
/// the `CacheData` blob. This replaces Nugget's hardcoded slice-1616 hack with
/// a per-key, per-firmware-resolved offset. A faithful Nugget fallback is kept
/// in case the scan comes up empty.
enum CacheDataPatch {

    enum PatchError: LocalizedError {
        case tooShort
        case patternNotFound
        case offsetUnavailable
        case outOfRange(side: String)
        case invalidValue(side: String, value: Character)
        case badNeighbor(side: String)

        var errorDescription: String? {
            switch self {
            case .tooShort:
                return "CacheData is too short for the patch."
            case .patternNotFound:
                return "The patch pattern was not found in CacheData. Your device or iOS version may be unsupported."
            case .offsetUnavailable:
                return "Could not resolve the CacheData offset for this key in libMobileGestalt."
            case .outOfRange(let side):
                return "The \(side) offset is out of range for CacheData."
            case .invalidValue(let side, let value):
                return "The value at the \(side) offset (\(value)) is not 1 or 3."
            case .badNeighbor(let side):
                return "The neighbours of the \(side) offset are not zero."
            }
        }
    }

    private static var cachedOffsets: [String: Int] = [:]

    static func offset(for key: String) -> Int {
        if let cached = cachedOffsets[key] {
            return cached
        }

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
            // dyld may report the image under a resolved/symlinked path, so
            // fall back to a substring match instead of bailing out.
            for i in 0..<_dyld_image_count() {
                let name = String(cString: _dyld_get_image_name(i))
                if name.contains("libMobileGestalt") {
                    header = unsafeBitCast(_dyld_get_image_header(i), to: UnsafePointer<mach_header_64>.self)
                    break
                }
            }
        }
        guard let header else { cachedOffsets[key] = 0; return 0 }

        var textSize = 0
        guard let cstring = getsectiondata(header, "__TEXT", "__cstring", &textSize) else {
            cachedOffsets[key] = 0
            return 0
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
        guard let ptr else { cachedOffsets[key] = 0; return 0 }

        for i in 0..<(constSize / 8) {
            if ptr[i] == UInt(bitPattern: keyPtr) {
                let offset = Int((ptr.advanced(by: i).withMemoryRebound(to: UInt16.self, capacity: 1) { $0[0x9a / 2] }) << 3)
                cachedOffsets[key] = offset
                return offset
            }
        }

        cachedOffsets[key] = 0
        return 0
    }

    // MARK: - CacheData Int writes

    /// Writes a little-endian Int at the CacheData offset resolved for `key`.
    static func set(_ value: Int, forKey key: String, in data: inout Data) throws {
        let off = offset(for: key)
        guard off > 0, off + MemoryLayout<Int>.size <= data.count else {
            throw PatchError.offsetUnavailable
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

    // MARK: - iPadOS patch
    static func apply(to data: Data) throws -> Data {
        let off = offset(for: "mtrAoWJ3gsq+I90ZnQ0vQw")
        if off > 0, off + MemoryLayout<Int>.size <= data.count {
            var out = data
            try set(3, forKey: "mtrAoWJ3gsq+I90ZnQ0vQw", in: &out)
            return out
        }
        return try legacyApply(to: data)
    }

    // MARK: - Legacy Nugget fallback

    static let sliceStart = 1616
    static let sliceLength = 200

    private static func legacyApply(to data: Data) throws -> Data {
        let hex = data.map { String(format: "%02x", $0) }.joined()
        guard hex.count > sliceStart else { throw PatchError.tooShort }

        let windowStart = hex.index(hex.startIndex, offsetBy: sliceStart)
        let windowEnd = hex.index(windowStart, offsetBy: sliceLength)
        let window = String(hex[windowStart..<windowEnd])

        // Nugget regex: 0+(?:5555)*([0-9a-f]{4})
        let regex = try NSRegularExpression(pattern: "0+(?:5555)*([0-9a-f]{4})")
        let nsWindow = window as NSString
        let range = NSRange(location: 0, length: nsWindow.length)

        var offset: Int?
        regex.enumerateMatches(in: window, options: [], range: range) { match, _, _ in
            guard let match else { return }
            let cap = match.range(at: 1)
            guard cap.location != NSNotFound else { return }
            let captured = nsWindow.substring(with: cap)
            let nonZero = captured.filter { $0 != "0" }.count
            if nonZero >= 3 {
                offset = sliceStart + cap.location
            }
        }
        guard let offset else { throw PatchError.patternNotFound }

        // Extremes (hex-character offsets, matching Nugget)
        let roffset = offset + 13
        let loffset = offset - 67
        let chars = Array(hex)
        guard roffset < chars.count - 1, roffset - 1 >= 0 else {
            throw PatchError.outOfRange(side: "right")
        }
        guard loffset > 0, loffset + 1 < chars.count else {
            throw PatchError.outOfRange(side: "left")
        }

        for side in [(loffset, "left"), (roffset, "right")] {
            let idx = side.0
            let name = side.1
            let ch = chars[idx]
            guard ch == "1" || ch == "3" else {
                throw PatchError.invalidValue(side: name, value: ch)
            }
            guard chars[idx - 1] == "0", chars[idx + 1] == "0" else {
                throw PatchError.badNeighbor(side: name)
            }
        }

        // Flip the left offset nibble to 3 (the actual enable bit).
        var mutable = chars
        mutable[loffset] = "3"

        // Rebuild bytes from the hex string.
        let rebuilt = String(mutable)
        var bytes = Data()
        bytes.reserveCapacity(rebuilt.count / 2)
        var i = rebuilt.startIndex
        while i < rebuilt.endIndex {
            let next = rebuilt.index(after: i)
            if let byte = UInt8(rebuilt[i...next], radix: 16) {
                bytes.append(byte)
            }
            i = rebuilt.index(after: next)
        }
        guard bytes.count == data.count else { throw PatchError.patternNotFound }
        return bytes
    }
}
