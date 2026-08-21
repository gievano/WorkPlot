import Foundation

public final class RDARFix {
    public static let shared = RDARFix()
    private let graphicsPlistPath = "/var/preferences/com.apple.iomobilegraphicsfamily.plist"
    
    private init() {}
    
    public func applyGeometryCorrection(width: Int, height: Int) -> Result<Bool, Error> {
        do {
            var plist = (try? FileSystemAccessor.shared.readPlist(from: graphicsPlistPath)) ?? [:]
            plist["canvas_width"] = width
            plist["canvas_height"] = height
            plist["RDAR_StatusBar_Alignment_Fix"] = true
            
            try FileSystemAccessor.shared.writePlist(plist, to: graphicsPlistPath)
            ExploitManager.shared.appendLog("RDAR Fix applied successfully with resolution: \(width)x\(height)")
            return .success(true)
        } catch {
            return .failure(error)
        }
    }
}

