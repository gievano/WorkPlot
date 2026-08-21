import Foundation

public struct RDARFix {
    public static func apply() -> Bool {
        let path = "/var/preferences/com.apple.iomobilegraphicsfamily.plist"
        guard var plist = FileSystemAccessor.readPlist(from: path) else { return false }
        plist["canvas_width"] = 1290
        plist["canvas_height"] = 2868
        return FileSystemAccessor.writePlist(plist, to: path)
    }
}
