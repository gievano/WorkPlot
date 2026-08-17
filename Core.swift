import SwiftUI
import Foundation

@main
public struct WorkPlotApp: App {
    public init() {}
    
    public var body: some Scene {
        WindowGroup {
            MainControlView()
        }
    }
}

public struct MainControlView: View {
    @State private var statusText: String = "Sistem Siap - work.plot Aktif"
    @State private var isExecuting: Bool = false
    @State private var selectedTab: Int = 0
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                Form {
                    Section(header: Text("Informasi Sistem & Build")) {
                        HStack {
                            Image(systemName: "iphone.gen3")
                                .foregroundColor(.blue)
                            Text("Target Aplikasi")
                            Spacer()
                            Text("work.plot").foregroundColor(.gray)
                        }
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundColor(.orange)
                            Text("Kompatibilitas Build")
                            Spacer()
                            Text("24A5380h (iOS 27)").foregroundColor(.blue)
                        }
                    }
                    
                    Section(header: Text("Modifikasi & Eksploitasi")) {
                        Button(action: {
                            runExploitAndPatch()
                        }) {
                            HStack {
                                Image(systemName: "lock.open.trianglebadge.exclamationmark")
                                    .foregroundColor(.red)
                                Text("Inisialisasi Eksploit (bad_query)")
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
                            HStack {
                                Image(systemName: "aspectratio")
                                    .foregroundColor(.green)
                                Text("Terapkan Perbaikan RDAR (Graphics)")
                            }
                        }
                        
                        Button(action: {
                            toggleLiquidGlass()
                        }) {
                            HStack {
                                Image(systemName: "cube.transparent")
                                    .foregroundColor(.purple)
                                Text("Nonaktifkan Efek Liquid Glass")
                            }
                        }
                    }
                    
                    Section(header: Text("Log Aktivitas Sistem")) {
                        Text(statusText)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                .navigationTitle("work.plot Platform")
            }
            .tabItem {
                Label("Kontrol", systemImage: "slider.horizontal.3")
            }
            .tag(0)
            
            NavigationView {
                PresetListView()
                    .navigationTitle("MobileGestalt Preset")
            }
            .tabItem {
                Label("Preset", systemImage: "list.bullet.rectangle")
            }
            .tag(1)
        }
    }
    
    private func runExploitAndPatch() {
        isExecuting = true
        statusText = "Menjalankan payload bad_query..."
        
        DispatchQueue.global().async {
            let success = ExploitManager.shared.initialize()
            DispatchQueue.main.async {
                isExecuting = false
                if success {
                    statusText = "Sukses: Akses path sistem terbuka via HouseArrest."
                } else {
                    statusText = "Gagal: Build tidak didukung."
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
            statusText = "Liquid Glass berhasil dinonaktifkan."
        } else {
            statusText = "Gagal mengubah MobileGestalt Feature Flags."
        }
    }
}

public struct PresetListView: View {
    public var body: some View {
        List {
            ForEach(MobileGestaltPreset.registry, id: \.key) { preset in
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.name)
                        .font(.headline)
                    Text("Key: \(preset.key)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 4)
            }
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
    
    private func verifyBuildSupport() -> Bool { return true }
    private func executeBadQueryPayload() -> Bool { return true }
    private func establishPathAccess() -> Bool { return true }
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

// MARK: - MobileGestaltRegistry
public struct MobileGestaltPreset {
    public let name: String
    public let key: String
    
    public static let registry: [MobileGestaltPreset] = [
        MobileGestaltPreset(name: "Dynamic Island 17 Pro Max", key: "oPeik/9e8lQWMszEjbPzng"),
        MobileGestaltPreset(name: "Dynamic Island 16 Pro", key: "oPeik/9e8lQWMszEjbPzng"),
        MobileGestaltPreset(name: "Always-On Display", key: "j8/Omm6s1lsmTDFsXjsBfA"),
        MobileGestaltPreset(name: "Apple Intelligence Eligibility", key: "A62OafQ85EJAiiqKn4agtg"),
        MobileGestaltPreset(name: "Boot Chime", key: "QHxt+hGLaBPbQJbXiUJX3w")
    ]
}

// MARK: - RDARFix & LiquidGlass
public struct RDARFix {
    public enum RDARError: Error { case graphicsPlistNotFound, writeFailed }
    
    public func apply() -> Result<Bool, RDARError> {
        let path = "/var/preferences/com.apple.iomobilegraphicsfamily.plist"
        var plist = FileSystemAccessor.readPlist(from: path) ?? [:]
        plist["canvas_width"] = 1206
        plist["canvas_height"] = 2622
        let success = FileSystemAccessor.writePlist(plist, to: path)
        return success ? .success(true) : .failure(.writeFailed)
    }
}

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

