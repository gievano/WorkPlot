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

            try InodeWriter.writeInPlace(outData, to: path)

            guard let verification = FileManager.default.contents(atPath: path),
                  verification == outData else {
                throw RDARFixError(message: "Verifikasi pasca-tulis gagal.")
            }
        }
    }
}
