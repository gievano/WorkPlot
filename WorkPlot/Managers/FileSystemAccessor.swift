import Foundation

public struct FileSystemAccessor {
    public static func readPlist(from path: String) -> [String: Any]? {
        guard let data = FileManager.default.contents(atPath: path),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }
        return plist
    }

    public static func writePlist(_ dictionary: [String: Any], to path: String) -> Bool {
        guard let data = try? PropertyListSerialization.data(fromPropertyList: dictionary, format: .xml, options: 0) else {
            return false
        }
        return FileManager.default.createFile(atPath: path, contents: data, attributes: nil)
    }
}
