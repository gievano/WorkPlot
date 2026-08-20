import Foundation

// MARK: - ExploitManager
public class ExploitManager {
    public static let shared = ExploitManager()
    
    // Explicitly targeting iOS 27.0 Developer Beta 1 through 4 builds
    private let supportedBuilds: [String] = ["24A5355q", "24A5370h", "24A5380h", "24A5390f"]
    
    public func initializeExploit() -> Bool {
        return true
    }
    
    public func validateBuild(buildId: String) -> Bool {
        return supportedBuilds.contains(buildId)
    }
    
    public func validateAccess(for path: String) -> Bool {
        return true
    }
}

// MARK: - FileSystemAccessor
public struct FileSystemAccessor {
    public static func readPlist(from path: String) -> [String: Any]? {
        guard let data = FileManager.default.contents(atPath: path),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }
        return plist
    }
    
    public static func writePlist(_ data: [String: Any], to path: String) -> Bool {
        guard let plistData = try? PropertyListSerialization.data(fromPropertyList: data, format: .xml, options: 0) else {
            return false
        }
        return FileManager.default.createFile(atPath: path, contents: plistData, attributes: nil)
    }
    
    public static func backupPlist(at path: String) -> String? {
        let timestamp = Date().timeIntervalSince1970
        let backupPath = "\(path).backup.\(timestamp)"
        do {
            try FileManager.default.copyItem(atPath: path, toPath: backupPath)
            return backupPath
        } catch {
            return nil
        }
    }
}

// MARK: - MobileGestaltPreset
public enum ValueType {
    case string, integer, boolean, data, dictionary
}

public struct MobileGestaltPreset {
    public let name: String
    public let key: String
    public let type: ValueType
    public let value: Any
    public let category: String
    
    public static func applySiriAIFlag(enable: Bool) -> Bool {
        let flagPath = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"
        guard let plist = FileSystemAccessor.readPlist(from: flagPath) else {
            return false
        }
        var modified = plist
        modified["a3n5T9sFtlyQ74NEp9ESxg"] = enable ? 2 : 0
        return FileSystemAccessor.writePlist(modified, to: flagPath)
    }
}

// MARK: - RDARFix
public struct RDARFix {
    public static func applyFix() -> Bool {
        let graphicsPath = "/var/preferences/com.apple.iomobilegraphicsfamily.plist"
        guard let plist = FileSystemAccessor.readPlist(from: graphicsPath) else {
            return false
        }
        var modified = plist
        modified["canvas_width"] = 2622
        modified["canvas_height"] = 1206
        return FileSystemAccessor.writePlist(modified, to: graphicsPath)
    }
}

// MARK: - LiquidGlassController
public struct LiquidGlassController {
    public static func disableGlobal() -> Bool {
        let flagPath = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"
        guard let plist = FileSystemAccessor.readPlist(from: flagPath) else {
            return false
        }
        var modified = plist
        modified["UIDesignRequiresCompatibility"] = true
        return FileSystemAccessor.writePlist(modified, to: flagPath)
    }
    
    public static func setTransparencyLevel(_ level: Int) -> Bool {
        let flagPath = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"
        guard let plist = FileSystemAccessor.readPlist(from: flagPath) else {
            return false
        }
        var modified = plist
        let clampedLevel = max(0, min(100, level))
        modified["LiquidGlassSlider"] = clampedLevel
        return FileSystemAccessor.writePlist(modified, to: flagPath)
    }
}

// MARK: - StagedApplyEngine
public struct StagedApplyEngine {
    public static func applyWithVerification(_ plist: [String: Any], at path: String) -> Bool {
        guard let _ = FileSystemAccessor.backupPlist(at: path) else {
            return false
        }
        
        let tempPath = "\(path).tmp"
        guard FileSystemAccessor.writePlist(plist, to: tempPath) else {
            return false
        }
        
        guard let verifiedPlist = FileSystemAccessor.readPlist(from: tempPath), !verifiedPlist.isEmpty else {
            try? FileManager.default.removeItem(atPath: tempPath)
            return false
        }
        
        do {
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem(atPath: path)
            }
            try FileManager.default.moveItem(atPath: tempPath, toPath: path)
            return true
        } catch {
            return false
        }
    }
}

public struct SpringBoardManager {
    public static func restartAfterApplyTweak() -> Bool {
        return true
    }
}

public func accessContainer(bundleIdentifier: String) -> String? {
    let containerPath = "/var/mobile/Containers/Data/Application/\(bundleIdentifier)"
    guard ExploitManager.shared.validateAccess(for: containerPath) else { return nil }
    return containerPath
}
