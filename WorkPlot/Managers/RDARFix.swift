import Foundation
import UIKit

struct RDARFixError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

struct RDARFix {
    static let leasePath = "/var/preferences/com.apple.iomobilegraphicsfamily.plist"
    static let filePath = "/private/var/preferences/com.apple.iomobilegraphicsfamily.plist"

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
        try BadQueryLeaseScope.withLease(forPath: leasePath) {
            guard let data = FileManager.default.contents(atPath: filePath) else {
                throw RDARFixError(message: "The plist at \(filePath) could not be read.")
            }

            var format = PropertyListSerialization.PropertyListFormat.binary
            guard var plist = try? PropertyListSerialization.propertyList(
                from: data, options: [], format: &format) as? [String: Any] else {
                throw RDARFixError(message: "The plist contents are not a valid dictionary.")
            }

            plist["canvas_width"] = canvasWidth
            plist["canvas_height"] = canvasHeight

            guard let outData = try? PropertyListSerialization.data(
                fromPropertyList: plist, format: format, options: 0) else {
                throw RDARFixError(message: "Failed to serialize the plist.")
            }

            try InodeWriter.writeVerifiedInPlace(outData, to: filePath)
        }
    }
}
