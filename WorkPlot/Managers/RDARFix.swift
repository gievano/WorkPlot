import Foundation

public struct RDARFix {
    public static func apply() -> Bool {
        let path = "/var/preferences/com.apple.iomobilegraphicsfamily.plist"
        var error: NSString? = nil
        guard let lease = BadQueryLease.lease(forPath: path, error: &error) else { return false }
        defer { lease.invalidate() }

        guard let data = FileManager.default.contents(atPath: path),
              var plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else { return false }
        plist["canvas_width"] = 1290
        plist["canvas_height"] = 2868
        guard let outData = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) else { return false }
        return FileManager.default.createFile(atPath: path, contents: outData, attributes: nil)
    }
}
