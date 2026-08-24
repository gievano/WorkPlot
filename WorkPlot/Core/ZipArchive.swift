//
//  ZipArchive.swift
//  WorkPlot
//
//  Minimal ZIP reader for plain archive trees (shared with the .3105 patch
//  payload decoder). Supports stored (0) and deflate (8) entries; no
//  encryption, no ZIP64.
//

import Foundation
import Compression

struct ArchiveEntry {
    let path: String
    let isDirectory: Bool
    let compressedData: Data
    let method: UInt16
    let uncompressedSize: UInt32
}

enum ZipArchiveError: LocalizedError {
    case notAZipFile
    case corruptArchive(String)
    case unsupportedCompression(UInt16)
    case extractionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAZipFile:
            "The file is not a valid ZIP archive (signature not found)."
        case .corruptArchive(let detail):
            "Corrupt archive: \(detail)"
        case .unsupportedCompression(let method):
            "Compression method \(method) is unsupported."
        case .extractionFailed(let detail):
            "Extraction failed: \(detail)"
        }
    }
}

enum ZipArchive {

    /// Writes every regular archive entry into `directory` and returns the
    /// extracted file URLs.
    static func writeArchive(_ data: Data, to directory: URL) throws -> [URL] {
        let entries = try parseCentralDirectory(data)
        var files: [URL] = []
        for entry in entries where !entry.isDirectory {
            let relativePath = sanitize(entry.path)
            guard !relativePath.isEmpty else { continue }
            let target = directory.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(
                at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try inflate(entry).write(to: target, options: .atomic)
            files.append(target)
        }
        return files
    }

    private static func sanitize(_ path: String) -> String {
        path.replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/")
            .filter { $0 != ".." && $0 != "." }
            .joined(separator: "/")
    }

    // MARK: - ZIP parsing

    private static func parseCentralDirectory(_ data: Data) throws -> [ArchiveEntry] {
        guard data.count > 22 else { throw ZipArchiveError.notAZipFile }
        let bytes = [UInt8](data)

        // Locate the End Of Central Directory record by scanning backwards.
        var eocdOffset = -1
        let minimum = max(0, bytes.count - 66_000)
        var index = bytes.count - 22
        while index >= minimum {
            if readU32(bytes, index) == 0x06054b50 {
                eocdOffset = index
                break
            }
            index -= 1
        }
        guard eocdOffset >= 0 else { throw ZipArchiveError.notAZipFile }

        let entryCount = Int(readU16(bytes, eocdOffset + 10))
        var offset = Int(readU32(bytes, eocdOffset + 16))

        var entries: [ArchiveEntry] = []
        for _ in 0..<entryCount {
            guard offset + 46 <= bytes.count, readU32(bytes, offset) == 0x02014b50 else {
                throw ZipArchiveError.corruptArchive("central directory")
            }

            let method = readU16(bytes, offset + 10)
            let compressedSize = Int(readU32(bytes, offset + 20))
            let uncompressedSize = readU32(bytes, offset + 24)
            let nameLength = Int(readU16(bytes, offset + 28))
            let extraLength = Int(readU16(bytes, offset + 30))
            let commentLength = Int(readU16(bytes, offset + 32))
            let localHeaderOffset = Int(readU32(bytes, offset + 42))

            guard offset + 46 + nameLength <= bytes.count else {
                throw ZipArchiveError.corruptArchive("entry name")
            }
            let path = String(decoding: bytes[(offset + 46)..<(offset + 46 + nameLength)], as: UTF8.self)

            // Read the local header to find where the payload starts.
            let localOffset = localHeaderOffset
            guard localOffset + 30 <= bytes.count, readU32(bytes, localOffset) == 0x04034b50 else {
                throw ZipArchiveError.corruptArchive("local header for \(path)")
            }
            let localNameLength = Int(readU16(bytes, localOffset + 26))
            let localExtraLength = Int(readU16(bytes, localOffset + 28))
            let dataStart = localOffset + 30 + localNameLength + localExtraLength
            guard dataStart + compressedSize <= bytes.count else {
                throw ZipArchiveError.corruptArchive("payload for \(path)")
            }

            entries.append(ArchiveEntry(
                path: path,
                isDirectory: path.hasSuffix("/"),
                compressedData: data.subdata(in: dataStart..<(dataStart + compressedSize)),
                method: UInt16(truncatingIfNeeded: method),
                uncompressedSize: uncompressedSize
            ))

            offset += 46 + nameLength + extraLength + commentLength
        }
        return entries
    }

    private static func inflate(_ entry: ArchiveEntry) throws -> Data {
        if entry.isDirectory { return Data() }
        switch entry.method {
        case 0:
            return entry.compressedData
        case 8:
            return try deflateDecode(entry.compressedData, expectedSize: Int(entry.uncompressedSize))
        default:
            throw ZipArchiveError.unsupportedCompression(entry.method)
        }
    }

    /// Raw DEFLATE decode (zlib stream without header), matching ZIP method 8.
    private static func deflateDecode(_ input: Data, expectedSize: Int) throws -> Data {
        guard expectedSize > 0 else { return Data() }
        var output = Data(count: expectedSize)
        let decoded = output.withUnsafeMutableBytes { outBuffer in
            input.withUnsafeBytes { inBuffer in
                compression_decode_buffer(
                    outBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    expectedSize,
                    inBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    input.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        guard decoded == expectedSize else {
            throw ZipArchiveError.extractionFailed("Decompressed size \(decoded) != \(expectedSize).")
        }
        return output
    }

    private static func readU16(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(bytes[offset]) | (UInt32(bytes[offset + 1]) << 8)
    }

    private static func readU32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        readU16(bytes, offset) | (readU16(bytes, offset + 2) << 16)
    }
}
