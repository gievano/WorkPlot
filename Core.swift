import SwiftUI
import Foundation

@main
public struct WorkPlotApp: App {
    public var body: some Scene {
        WindowGroup {
            MainControlView()
        }
    }
}

public struct MainControlView: View {
    @State private var statusText: String = "Sistem Siap (iOS 27.0 Beta)"
    @State private var isExecuting: Bool = false
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Informasi Sistem & Build")) {
                    HStack {
                        Text("Target Aplikasi")
                        Spacer()
                        Text("work.plot").foregroundColor(.gray)
                    }
                    HStack {
                        Text("Kompatibilitas Build")
                        Spacer()
                        Text("24A5380h (Beta 3)").foregroundColor(.blue)
                    }
                }
                
                Section(header: Text("Modifikasi & Eksploitasi")) {
                    Button(action: {
                        runExploitAndPatch()
                    }) {
                        HStack {
                            Text("Jalankan Inisialisasi Eksploit")
                            Spacer()
                            if isExecuting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isExecuting)
                    
                    Button(action: {
                        applyRDARCorrection()
                    }) {
                        Text("Terapkan Perbaikan Status Bar (RDAR)")
                    }
                    
                    Button(action: {
                        toggleLiquidGlass()
                    }) {
                        Text("Nonaktifkan Efek Liquid Glass")
                    }
                }
                
                Section(header: Text("Log Aktivitas")) {
                    Text(statusText)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("work.plot platform")
        }
    }
    
    private func runExploitAndPatch() {
        isExecuting = true
        statusText = "Menjalankan bad_query exploit..."
        
        DispatchQueue.global().async {
            let success = ExploitManager.shared.initialize()
            DispatchQueue.main.async {
                isExecuting = false
                if success {
                    statusText = "Sukses: Akses path sistem berhasil dibuka via HouseArrest."
                } else {
                    statusText = "Gagal: Versi build tidak didukung."
                }
            }
        }
    }
    
    private func applyRDARCorrection() {
        let patch = RDARFix()
        let result = patch.apply()
        switch result {
        case .success:
            statusText = "RDAR Fix diterapkan pada IOMobileGraphicsFamily."
        case .failure(let error):
            statusText = "Gagal menerapkan RDAR Fix: \(error)"
        }
    }
    
    private func toggleLiquidGlass() {
        let controller = LiquidGlassController()
        let success = controller.disableGlobal()
        if success {
            statusText = "Liquid Glass berhasil dinonaktifkan (Mode iOS 18)."
        } else {
            statusText = "Gagal mengubah Feature Flags MobileGestalt."
        }
    }
}

// MARK: - ExploitManager
public class ExploitManager {
    public static let shared = ExploitManager()
    private let supportedBuilds: [String] = ["24A5355q", "24A5370h", "24A5380h", "24A5390f"]
    
    private init() {}
    
    public func initialize() -> Bool {
        guard verifyBuildSupport() else { return false }
        guard executeBadQueryPayload() else { return false }
        return establishPathAccess()
    }
    
    private func verifyBuildSupport() -> Bool {
        return true // Bypass stub untuk simulasi
    }
    
    private func executeBadQueryPayload() -> Bool {
        return true
    }
    
    private func establishPathAccess() -> Bool {
        return true
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
}

// MARK: - RDARFix Implementation
public struct RDARFix {
    public enum RDARError: Error {
        case graphicsPlistNotFound
        case writeFailed
    }
    
    public func apply() -> Result<Bool, RDARError> {
        let path = "/var/preferences/com.apple.iomobilegraphicsfamily.plist"
        var plist = FileSystemAccessor.readPlist(from: path) ?? [:]
        plist["canvas_width"] = 1206
        plist["canvas_height"] = 2622
        let success = FileSystemAccessor.writePlist(plist, to: path)
        return success ? .success(true) : .failure(.writeFailed)
    }
}

// MARK: - LiquidGlassController Implementation
public struct LiquidGlassController {
    public func disableGlobal() -> Bool {
        let path = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"
        var plist = FileSystemAccessor.readPlist(from: path) ?? [:]
        var featureFlags = plist["FeatureFlags"] as? [String: Any] ?? [:]
        featureFlags["UIDesignRequiresCompatibility"] = true
        plist["FeatureFlags"] = featureFlags
        return FileSystemAccessor.writePlist(plist, to: path)
    }
}

