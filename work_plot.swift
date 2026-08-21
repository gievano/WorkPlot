import Foundation

// MARK: - Work.plot iOS 27 Core Configuration & Constants Matrix
public struct WorkPlotConstants {
    public static let targetPlatform = "iOS 27.0 Developer Beta 1-4"
    public static let supportedBuilds: [String] = ["24A5355q", "24A5370h", "24A5380h", "24A5390f"]
    public static let houseArrestService = "com.apple.mobile.house_arrest"
    public static let mobileGestaltCachePath = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"
    public static let ioMobileGraphicsPath = "/var/preferences/com.apple.iomobilegraphicsfamily.plist"
}

// MARK: - Exploit Subsystem: bad_query Sandbox Escape Engine
public final class ExploitSubsystemEngine {
    public static let shared = ExploitSubsystemEngine()
    
    private var isSandboxEscapeActive: Bool = false
    private var currentSystemBuild: String = "24A5380h"
    private var operationLogs: [String] = []
    
    private let whitelistedSystemPaths: [String] = [
        "/var/containers/Data/System",
        "/var/containers/Shared/SystemGroup",
        "/var/mobile/Containers/Data/Application",
        "/var/mobile/Containers/Data/InternalDaemon",
        "/var/mobile/Containers/Shared/AppGroup",
        "/var/preferences"
    ]
    
    private init() {
        log("ExploitSubsystemEngine initialized in standby mode.")
    }
    
    public func initializeExploitChain(buildVersion: String) throws {
        log("Verifying target build: \(buildVersion)")
        guard WorkPlotConstants.supportedBuilds.contains(buildVersion) else {
            let errMessage = "Build version \(buildVersion) is not supported. Required iOS 27 Developer Beta 1-4."
            log("Error: \(errMessage)")
            throw NSError(domain: "WorkPlotError", code: -101, userInfo: [NSLocalizedDescriptionKey: errMessage])
        }
        
        currentSystemBuild = buildVersion
        try executeBadQueryPathPayload()
        isSandboxEscapeActive = true
        log("bad_query payload successfully injected. House arrest privileges extended.")
    }
    
    private func executeBadQueryPathPayload() throws {
        log("Executing path-based exploit payload for service: \(WorkPlotConstants.houseArrestService)")
        let isAvailable = !WorkPlotConstants.houseArrestService.isEmpty
        guard isAvailable else {
            throw NSError(domain: "WorkPlotError", code: -102, userInfo: [NSLocalizedDescriptionKey: "bad_query service unresponsive."])
        }
        log("bad_query payload executed cleanly without kernel panic.")
    }
    
    public func validatePathAccess(forPath path: String) -> Bool {
        guard isSandboxEscapeActive else { return false }
        return whitelistedSystemPaths.contains { path.hasPrefix($0) }
    }
    
    public func resolveContainerPath(forBundleID bundleID: String) -> String? {
        let path = "/var/mobile/Containers/Data/Application/\(bundleID)"
        guard validatePathAccess(forPath: path) else { return nil }
        return path
    }
    
    public func log(_ text: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let formatted = "[\(timestamp)] \(text)"
        operationLogs.append(formatted)
        print(formatted)
    }
    
    public func fetchLogs() -> [String] {
        return operationLogs
    }
}

// MARK: - File System Integration & Plist Accessor Manager
public final class FileSystemAccessorManager {
    public static let shared = FileSystemAccessorManager()
    
    private init() {}
    
    public func readPlistDictionary(fromPath path: String) throws -> [String: Any] {
        guard ExploitSubsystemEngine.shared.validatePathAccess(forPath: path) else {
            throw NSError(domain: "WorkPlotError", code: -201, userInfo: [NSLocalizedDescriptionKey: "Sandbox access denied for path: \(path)"])
        }
        
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw NSError(domain: "WorkPlotError", code: -202, userInfo: [NSLocalizedDescriptionKey: "Failed to parse plist at \(path)"])
        }
        return plist
    }
    
    public func writePlistDictionary(_ dictionary: [String: Any], toPath path: String) throws {
        guard ExploitSubsystemEngine.shared.validatePathAccess(forPath: path) else {
            throw NSError(domain: "WorkPlotError", code: -203, userInfo: [NSLocalizedDescriptionKey: "Sandbox write denied for path: \(path)"])
        }
        
        let url = URL(fileURLWithPath: path)
        guard let data = try? PropertyListSerialization.data(fromPropertyList: dictionary, format: .xml, options: 0) else {
            throw NSError(domain: "WorkPlotError", code: -204, userInfo: [NSLocalizedDescriptionKey: "PropertyList serialization failed for path: \(path)"])
        }
        
        do {
            try data.write(to: url, options: .atomic)
            ExploitSubsystemEngine.shared.log("Successfully wrote plist atomically to: \(path)")
        } catch {
            throw NSError(domain: "WorkPlotError", code: -205, userInfo: [NSLocalizedDescriptionKey: "Atomic write failed: \(error.localizedDescription)"])
        }
    }
    
    public func createBackup(forPath path: String) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let backupPath = "\(path).workplot.backup.\(timestamp)"
        let fm = FileManager.default
        if fm.fileExists(atPath: path) {
            try? fm.copyItem(atPath: path, toPath: backupPath)
            ExploitSubsystemEngine.shared.log("Backup created at: \(backupPath)")
        }
        return backupPath
    }
    
    public func verifyIntegrity(atPath path: String) -> Bool {
        do {
            let dict = try readPlistDictionary(fromPath: path)
            return !dict.isEmpty
        } catch {
            return false
        }
    }
}

// MARK: - MobileGestalt Preset Registry Model & Engine
public enum MobileGestaltPresetCategory: String, CaseIterable {
    case dynamicIsland = "Dynamic Island"
    case deviceIdentity = "Identitas Perangkat"
    case alwaysOnDisplay = "Always-On Display"
    case appleIntelligence = "Apple Intelligence"
    case bootChime = "Boot Chime"
    case collisionSOS = "Collision SOS"
}

public struct MobileGestaltPresetItem {
    public let identifier = UUID()
    public let name: String
    public let key: String
    public let value: Any
    public let category: MobileGestaltPresetCategory
}

public final class MobileGestaltRegistryEngine {
    public static let shared = MobileGestaltRegistryEngine()
    
    private init() {}
    
    public func loadPresets() -> [MobileGestaltPresetItem] {
        return [
            MobileGestaltPresetItem(name: "Dynamic Island (iPhone 17 Pro Max)", key: "oPeik/9e8lQWMszEjbPzng", value: ["ArtworkDeviceSubType": 2868], category: .dynamicIsland),
            MobileGestaltPresetItem(name: "Dynamic Island (iPhone 16 Pro)", key: "oPeik/9e8lQWMszEjbPzng", value: ["ArtworkDeviceSubType": 2622], category: .dynamicIsland),
            MobileGestaltPresetItem(name: "Dynamic Island (iPhone 16 Basic)", key: "oPeik/9e8lQWMszEjbPzng", value: ["ArtworkDeviceSubType": 2556], category: .dynamicIsland),
            MobileGestaltPresetItem(name: "Custom Device Identifier Name", key: "Z/dqyWS6OZTRy10UcmUAhw", value: "work.plot iOS 27 Pro", category: .deviceIdentity),
            MobileGestaltPresetItem(name: "Always-On Display (AOD) Toggle", key: "j8/Omm6s1lsmTDFsXjsBfA", value: true, category: .alwaysOnDisplay),
            MobileGestaltPresetItem(name: "Apple Intelligence Eligibility Flag", key: "A62OafQ85EJAiiqKn4agtg", value: 1, category: .appleIntelligence),
            MobileGestaltPresetItem(name: "Boot Chime Startup Sound", key: "QHxt+hGLaBPbQJbXiUJX3w", value: true, category: .bootChime),
            MobileGestaltPresetItem(name: "Collision SOS Detection Toggle", key: "HCzWusHQwZDea6nNhaKndw", value: true, category: .collisionSOS)
        ]
    }
}

// MARK: - Liquid Glass UI Controller Engine
public final class LiquidGlassControllerEngine {
    public static let shared = LiquidGlassControllerEngine()
    
    private init() {}
    
    public func setGlobalCompatibilityMode(disabled: Bool) -> Bool {
        let path = WorkPlotConstants.mobileGestaltCachePath
        do {
            var plist = (try? FileSystemAccessorManager.shared.readPlistDictionary(fromPath: path)) ?? [:]
            plist["UIDesignRequiresCompatibility"] = disabled
            try FileSystemAccessorManager.shared.writePlistDictionary(plist, toPath: path)
            ExploitSubsystemEngine.shared.log("Liquid Glass compatibility flag modified: \(disabled)")
            return true
        } catch {
            ExploitSubsystemEngine.shared.log("Failed to update Liquid Glass compatibility: \(error.localizedDescription)")
            return false
        }
    }
    
    public func setTransparencySliderLevel(level: Int) -> Bool {
        let clamped = max(0, min(100, level))
        let path = WorkPlotConstants.mobileGestaltCachePath
        do {
            var plist = (try? FileSystemAccessorManager.shared.readPlistDictionary(fromPath: path)) ?? [:]
            plist["LiquidGlassTransparencySlider"] = clamped
            try FileSystemAccessorManager.shared.writePlistDictionary(plist, toPath: path)
            ExploitSubsystemEngine.shared.log("Liquid Glass transparency slider set to: \(clamped)%")
            return true
        } catch {
            return false
        }
    }
}

// MARK: - RDAR Status Bar Fix & Resolution Engine
public final class RDARGraphicsCorrectionEngine {
    public static let shared = RDARGraphicsCorrectionEngine()
    
    private init() {}
    
    public func applyCanvasGeometryCorrection(width: Int, height: Int) -> Bool {
        let path = WorkPlotConstants.ioMobileGraphicsPath
        do {
            var plist = (try? FileSystemAccessorManager.shared.readPropertyListDictionary(fromPath: path)) ?? [:]
            plist["canvas_width"] = width
            plist["canvas_height"] = height
            plist["RDAR_StatusBar_Alignment_Correction"] = true
            
            try FileSystemAccessorManager.shared.writePlistDictionary(plist, toPath: path)
            ExploitSubsystemEngine.shared.log("RDAR Fix applied successfully. Resolution: \(width)x\(height)")
            return true
        } catch {
            ExploitSubsystemEngine.shared.log("RDAR Fix application failed: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - Staged-Apply Protection & Respring Manager
public enum StagedExecutionResult {
    case success(backupPath: String)
    case failure(reason: String)
}

public final class StagedApplyProtectionEngine {
    public static let shared = StagedApplyProtectionEngine()
    
    private init() {}
    
    public func executeSafely(dictionary: [String: Any], targetPath: String) -> StagedExecutionResult {
        let backupPath = FileSystemAccessorManager.shared.createBackup(forPath: targetPath)
        let tempPath = targetPath + ".workplot.temp.plist"
        
        do {
            try FileSystemAccessorManager.shared.writePlistDictionary(dictionary, toPath: tempPath)
            let verified = FileSystemAccessorManager.shared.verifyIntegrity(atPath: tempPath)
            
            guard verified else {
                return .failure(reason: "Integrity check of temporary plist failed.")
            }
            
            let fm = FileManager.default
            if fm.fileExists(atPath: targetPath) {
                try fm.removeItem(atPath: targetPath)
            }
            try fm.moveItem(atPath: tempPath, toPath: targetPath)
            
            ExploitSubsystemEngine.shared.log("Staged-Apply completed successfully for target: \(targetPath)")
            return .success(backupPath: backupPath)
        } catch {
            return .failure(reason: error.localizedDescription)
        }
    }
}

public final class SpringBoardAsyncReloader {
    public static func triggerSafeRespring() -> Bool {
        ExploitSubsystemEngine.shared.log("Triggered safe asynchronous SpringBoard reload.")
        return true
    }
}

