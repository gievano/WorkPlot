import Foundation

struct RDARFixError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct RDARFix {
    static let path = "/var/preferences/com.apple.iomobilegraphicsfamily.plist"
    static let defaultCanvasWidth = 1290
    static let defaultCanvasHeight = 2868

    static func apply(canvasWidth: Int = defaultCanvasWidth,
                      canvasHeight: Int = defaultCanvasHeight) throws {
        var leaseError: NSString? = nil
        guard let lease = BadQueryLease.lease(forPath: path, error: &leaseError) else {
            throw RDARFixError(message: "bad_query gagal: \(leaseError ?? "tidak diketahui")")
        }
        defer { lease.invalidate() }

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
