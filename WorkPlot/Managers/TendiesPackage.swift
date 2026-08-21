//
//  TendiesPackage.swift
//  WorkPlot
//
//  Minimal ZIP reader for .tendies wallpaper packages (PocketPoster format).
//  Supports stored (0) and deflate (8) entries; no encryption, no ZIP64.
//

import Foundation
import Compression

struct TendiesEntry {
    let path: String
    let isDirectory: Bool
    let compressedData: Data
    let method: UInt16
    let uncompressedSize: UInt32
}

enum TendiesError: LocalizedError {
    case notAZipFile
    case corruptArchive(String)
    case unsupportedCompression(UInt16)
    case missingDescriptorStructure
    case extractionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAZipFile:
            "File bukan paket .tendies yang valid (signature ZIP tidak ditemukan)."
        case .corruptArchive(let detail):
            "Arsip rusak: \(detail)"
        case .unsupportedCompression(let method):
            "Metode kompresi \(method) tidak didukung."
        case .missingDescriptorStructure:
            "Paket tidak ber struktur descriptor PosterBoard (butuh versions/1/contents atau Descriptor.plist)."
        case .extractionFailed(let detail):
            "Gagal ekstrak: \(detail)"
        }
    }
}

enum TendiesPackage {

    /// Validates that the data is a ZIP archive containing a PosterBoard
    /// descriptor tree (`versions/1/contents/*.wallpaper` or `Descriptor.plist`).
    static func validate(_ data: Data) throws {
        let entries = try parseCentralDirectory(data)
        guard hasDescriptorStructure(entries) else {
            throw TendiesError.missingDescriptorStructure
        }
    }

    /// Extracts the archive into a fresh workspace directory and returns the
    /// URL of each top-level descriptor folder, ready for PosterBoard install.
    static func extract(_ data: Data) throws -> [URL] {
        try validate(data)

        let workspace = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkPlot-Tendies-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)

        let entries = try parseCentralDirectory(data)
        var roots = Set<String>()

        for entry in entries where !entry.isDirectory {
            let relativePath = sanitize(entry.path)
            guard !relativePath.isEmpty else { continue }

            let target = workspace.appendingPathComponent(relativePath)
            let parent = target.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

            let contents = try inflate(entry)
            try contents.write(to: target, options: .atomic)

            // Track the top-level component as a candidate descriptor root.
            let components = relativePath.split(separator: "/")
            if components.count > 1 {
                roots.insert(String(components[0]))
            }
        }

        guard !roots.isEmpty else { throw TendiesError.missingDescriptorStructure }

        return roots.sorted().map { workspace.appendingPathComponent($0, isDirectory: true) }
    }

    // MARK: - Structure checks

    private static func hasDescriptorStructure(_ entries: [TendiesEntry]) -> Bool {
        entries.contains { entry in
            let p = entry.path.lowercased()
            return p.contains("versions/1/contents")
                || p.hasSuffix("descriptor.plist")
                || p.contains("com.apple.posterkit.provider.descriptor.identifier")
        }
    }

    private static func sanitize(_ path: String) -> String {
        path.replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/")
            .filter { $0 != ".." && $0 != "." }
            .joined(separator: "/")
    }

    // MARK: - ZIP parsing

    private static func parseCentralDirectory(_ data: Data) throws -> [TendiesEntry] {
        guard data.count > 22 else { throw TendiesError.notAZipFile }
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
        guard eocdOffset >= 0 else { throw TendiesError.notAZipFile }

        let entryCount = Int(readU16(bytes, eocdOffset + 10))
        var offset = Int(readU32(bytes, eocdOffset + 16))

        var entries: [TendiesEntry] = []
        for _ in 0..<entryCount {
            guard offset + 46 <= bytes.count, readU32(bytes, offset) == 0x02014b50 else {
                throw TendiesError.corruptArchive("central directory")
            }

            let method = readU16(bytes, offset + 10)
            let compressedSize = Int(readU32(bytes, offset + 20))
            let uncompressedSize = readU32(bytes, offset + 24)
            let nameLength = Int(readU16(bytes, offset + 28))
            let extraLength = Int(readU16(bytes, offset + 30))
            let commentLength = Int(readU16(bytes, offset + 32))
            let localHeaderOffset = Int(readU32(bytes, offset + 42))

            guard offset + 46 + nameLength <= bytes.count else {
                throw TendiesError.corruptArchive("entry name")
            }
            let path = String(decoding: bytes[(offset + 46)..<(offset + 46 + nameLength)], as: UTF8.self)

            // Read the local header to find where the payload starts.
            let localOffset = localHeaderOffset
            guard localOffset + 30 <= bytes.count, readU32(bytes, localOffset) == 0x04034b50 else {
                throw TendiesError.corruptArchive("local header untuk \(path)")
            }
            let localNameLength = Int(readU16(bytes, localOffset + 26))
            let localExtraLength = Int(readU16(bytes, localOffset + 28))
            let dataStart = localOffset + 30 + localNameLength + localExtraLength
            guard dataStart + compressedSize <= bytes.count else {
                throw TendiesError.corruptArchive("payload untuk \(path)")
            }

            entries.append(TendiesEntry(
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

    private static func inflate(_ entry: TendiesEntry) throws -> Data {
        if entry.isDirectory { return Data() }
        switch entry.method {
        case 0:
            return entry.compressedData
        case 8:
            return try deflateDecode(entry.compressedData, expectedSize: Int(entry.uncompressedSize))
        default:
            throw TendiesError.unsupportedCompression(entry.method)
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
            throw TendiesError.extractionFailed("ukuran dekompresi \(decoded) != \(expectedSize).")
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
