import Foundation
import UIKit

struct RDARFixError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct RDARFix {
    static let path = "/var/preferences/com.apple.iomobilegraphicsfamily.plist"

    /// Canvas size is detected from the device's native screen bounds at
    /// runtime: a hardcoded resolution only matched one iPhone model and
    /// caused the fix to misbehave on every other device.
    static func apply() throws {
        let bounds = UIScreen.main.nativeBounds
        try apply(canvasWidth: Int(bounds.width),
                  canvasHeight: Int(bounds.height))
    }

    static func apply(canvasWidth: Int,
                      canvasHeight: Int) throws {
        try BadQueryLeaseScope.withLease(forPath: path) {
            guard let data = FileManager.default.contents(atPath: path) else {
                throw RDARFixError(message: "Plist tidak dapat dibaca di \(path).")
            }

            var format = PropertyListSerialization.PropertyListFormat.binary
            guard var plist = try? PropertyListSerialization.propertyList(
                from: data, options: [], format: &format) as? [String: Any] else {
                throw RDARFixError(message: "Isi plist bukan dictionary yang valid.")
            }

            plist["canvas_width"] = canvasWidth
            plist["canvas_height"] = canvasHeight

            guard let outData = try? PropertyListSerialization.data(
                fromPropertyList: plist, format: format, options: 0) else {
                throw RDARFixError(message: "Gagal serialisasi plist.")
            }

            try writeInPlace(outData, to: path)

            guard let verification = FileManager.default.contents(atPath: path),
                  verification == outData else {
                throw RDARFixError(message: "Verifikasi pasca-tulis gagal.")
            }
        }
    }

    /// Rewrites the existing inode so ownership, flags and xattrs survive.
    private static func writeInPlace(_ data: Data, to path: String) throws {
        let fd = open(path, O_WRONLY | O_CLOEXEC | O_NOFOLLOW)
        guard fd >= 0 else {
            throw RDARFixError(message: "Gagal membuka plist (errno=\(errno)).")
        }
        defer { close(fd) }

        guard ftruncate(fd, 0) == 0, lseek(fd, 0, SEEK_SET) == 0 else {
            throw RDARFixError(message: "Gagal reset isi file (errno=\(errno)).")
        }

        var written = 0
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            while written < data.count {
                let n = write(fd, raw.baseAddress! + written, data.count - written)
                if n <= 0 { break }
                written += n
            }
        }
        guard written == data.count, fsync(fd) == 0 else {
            throw RDARFixError(message: "Gagal menulis plist (errno=\(errno)).")
        }
    }
}
