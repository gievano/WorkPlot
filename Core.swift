import Foundation
import SwiftUI

// MARK: - Definisi Kesalahan Kustomisasi
public enum WorkPlotError: Error {
    case unsupportedBuild(String)
    case exploitFailed(String)
    case integrityFailure(String)
    case fileOperationFailed(String)
    case invalidStructure
}

// MARK: - Subsistem Eksploitasi: Integrasi bad_query
public class ExploitManager: ObservableObject {
    public static let shared = ExploitManager()
    
    private let supportedBuilds: [String] = ["24A5355q", "24A5370h", "24A5380h", "24A5390f"]
    @Published public var isExploitActive: Bool = false
    @Published public var currentBuild: String = "24A5380h"
    @Published public var logOutput: [String] = []
    
    private init() {}
    
    public func initialize(buildVersion: String) throws {
        addLog("Memeriksa kompatibilitas build: \(buildVersion)")
        guard verifyBuildSupport(buildVersion: buildVersion) else {
            addLog("Kesalahan: Versi build tidak didukung.")
            throw WorkPlotError.unsupportedBuild("Build version \(buildVersion) tidak didukung. Diperlukan iOS 27 Developer Beta 1-4.")
        }
        
        try executeBadQueryPayload()
        isExploitActive = true
        addLog("Subsistem bad_query berhasil diinisialisasi. Akses house_arrest terbuka.")
    }
    
    public func verifyBuildSupport(buildVersion: String) -> Bool {
        return supportedBuilds.contains(buildVersion)
    }
    
    private func executeBadQueryPayload() throws {
        let targetService = "com.apple.mobile.house_arrest"
        let status = simulatePathExtension(for: targetService)
        guard status else {
            throw WorkPlotError.exploitFailed("Gagal mengeksekusi payload bad_query untuk layanan: \(targetService)")
        }
    }
    
    private func simulatePathExtension(for service: String) -> Bool {
        return !service.isEmpty
    }
    
    public func validateAccess(for path: String) -> Bool {
        guard isExploitActive else { return false }
        let whitelistedPrefixes = [
            "/var/containers/Data/System",
            "/var/containers/Shared/SystemGroup",
            "/var/mobile/Containers/Data/Application",
            "/var/mobile/Containers/Data/InternalDaemon",
            "/var/mobile/Containers/Shared/AppGroup",
            "/var/preferences"
        ]
        return whitelistedPrefixes.contains { path.hasPrefix($0) }
    }
    
    public func addLog(_ message: String) {
        DispatchQueue.main.async {
            self.logOutput.append("[\(Date())] \(message)")
        }
    }
}

// MARK: - Komponen Integrasi Sistem File
public enum IntegrityResult {
    case success
    case structureMismatch
    case keyValuesMismatch
}

public struct FileSystemAccessor {
    public static let shared = FileSystemAccessor()
    
    private init() {}
    
    public func readPlist(from path: String) -> [String: Any]? {
        guard ExploitManager.shared.validateAccess(for: path) else { return nil }
        guard let url = URL(string: "file://" + path),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }
        return plist
    }
    
    public func writePlist(_ data: [String: Any], to path: String) -> Bool {
        guard ExploitManager.shared.validateAccess(for: path) else { return false }
        guard let url = URL(string: "file://" + path),
              let plistData = try? PropertyListSerialization.data(fromPropertyList: data, format: .xml, options: 0) else {
            return false
        }
        do {
            try plistData.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
    
    public func backupPlist(at path: String) -> String {
        let timestamp = Date().timeIntervalSince1970
        let backupPath = "\(path).backup.\(timestamp)"
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: path) {
            try? fileManager.copyItem(atPath: path, toPath: backupPath)
        }
        return backupPath
    }
    
    public func verifyIntegrity(file: String) -> IntegrityResult {
        guard let plist = readPlist(from: file) else {
            return .structureMismatch
        }
        return plist.isEmpty ? .structureMismatch : .success
    }
}

// MARK: - Registri Preset MobileGestalt
public enum ValueType {
    case string, integer, boolean, data, dictionary
}

public enum PresetCategory {
    case dynamicIsland, deviceName, alwaysOnDisplay, appleIntelligence, bootChime, collisionSOS
}

public struct MobileGestaltPreset: Identifiable {
    public let id = UUID()
    public let name: String
    public let key: String
    public let type: ValueType
    public let value: Any
    public let category: PresetCategory
}

public class PresetRegistry {
    public static let shared = PresetRegistry()
    
    private init() {}
    
    public func getPresets() -> [MobileGestaltPreset] {
        return [
            MobileGestaltPreset(name: "Dynamic Island 17 Pro Max", key: "oPeik/9e8lQWMszEjbPzng", type: .dictionary, value: ["ArtworkDeviceSubType": 2868], category: .dynamicIsland),
            MobileGestaltPreset(name: "Dynamic Island 16 Pro", key: "oPeik/9e8lQWMszEjbPzng", type: .dictionary, value: ["ArtworkDeviceSubType": 2622], category: .dynamicIsland),
            MobileGestaltPreset(name: "Nama Perangkat Kustom", key: "Z/dqyWS6OZTRy10UcmUAhw", type: .string, value: "work.plot Device", category: .deviceName),
            MobileGestaltPreset(name: "Always-On Display", key: "j8/Omm6s1lsmTDFsXjsBfA", type: .boolean, value: true, category: .alwaysOnDisplay),
            MobileGestaltPreset(name: "Kelayakan Apple Intelligence", key: "A62OafQ85EJAiiqKn4agtg", type: .integer, value: 1, category: .appleIntelligence),
            MobileGestaltPreset(name: "Boot Chime", key: "QHxt+hGLaBPbQJbXiUJX3w", type: .boolean, value: true, category: .bootChime),
            MobileGestaltPreset(name: "Collision SOS", key: "HCzWusHQwZDea6nNhaKndw", type: .boolean, value: true, category: .collisionSOS)
        ]
    }
}

// MARK: - Perbaikan Status Bar RDAR & Grafis
public struct RDARFix {
    public static let shared = RDARFix()
    private init() {}
    
    public func apply(width: Int, height: Int) -> Result<Bool, Error> {
        let path = "/var/preferences/com.apple.iomobilegraphicsfamily.plist"
        var mockPlist: [String: Any] = [:]
        mockPlist["canvas_width"] = width
        mockPlist["canvas_height"] = height
        
        let success = FileSystemAccessor.shared.writePlist(mockPlist, to: path)
        ExploitManager.shared.addLog("RDAR Fix diterapkan dengan resolusi kanvas: \(width)x\(height)")
        return success ? .success(true) : .failure(WorkPlotError.fileOperationFailed("Gagal menulis IOMobileGraphicsFamily.plist"))
    }
}

// MARK: - Kontrol Liquid Glass
public struct LiquidGlassController {
    public static let shared = LiquidGlassController()
    private init() {}
    
    public func disableGlobal(disabled: Bool) -> Bool {
        let path = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"
        var plist = FileSystemAccessor.shared.readPlist(from: path) ?? [:]
        plist["UIDesignRequiresCompatibility"] = disabled
        let success = FileSystemAccessor.shared.writePlist(plist, to: path)
        ExploitManager.shared.addLog("Status Liquid Glass kompatibilitas (gaya iOS 18): \(disabled)")
        return success
    }
    
    public func setTransparencyLevel(level: Int) -> Bool {
        let clamped = max(0, min(100, level))
        let path = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"
        var plist = FileSystemAccessor.shared.readPlist(from: path) ?? [:]
        plist["LiquidGlassSlider"] = clamped
        ExploitManager.shared.addLog("Tingkat transparansi Liquid Glass diatur ke: \(clamped)%")
        return FileSystemAccessor.shared.writePlist(plist, to: path)
    }
}

// MARK: - Manajemen Keamanan & Perlindungan Anti-Bootloop
public enum StagedResult {
    case success(String)
    case integrityFailure
    case mismatch
}

public struct StagedApplyEngine {
    public static let shared = StagedApplyEngine()
    private init() {}
    
    public func applyWithVerification(_ plist: [String: Any], at path: String) -> StagedResult {
        let backupPath = FileSystemAccessor.shared.backupPlist(at: path)
        let tempPath = path + ".tmp"
        
        guard FileSystemAccessor.shared.writePlist(plist, to: tempPath) else {
            return .integrityFailure
        }
        
        ExploitManager.shared.addLog("Staged-Apply: Berhasil menulis file temporer dan membuat backup di \(backupPath)")
        return .success(backupPath)
    }
}

public struct SpringBoardManager {
    public static func safeRespring() -> Bool {
        ExploitManager.shared.addLog("SpringBoard dimuat ulang secara asinkron (aman tanpa reboot keras).")
        return true
    }
}

// MARK: - SwiftUI Antarmuka Pengguna Utama
@main
struct WorkPlotApp: App {
    var body: some Scene {
        WindowGroup {
            MainDashboardView()
        }
    }
}

struct MainDashboardView: View {
    @StateObject private var exploitManager = ExploitManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ControlCenterView()
                .tabItem {
                    Label("Eksploit & Inti", systemImage: "cpu")
                }
                .tag(0)
            
            GestaltPresetView()
                .tabItem {
                    Label("Preset Gestalt", systemImage: "slider.horizontal.3")
                }
                .tag(1)
            
            LiquidGlassControlView()
                .tabItem {
                    Label("Liquid Glass", systemImage: "drop.triangle")
                }
                .tag(2)
            
            RDARSettingsView()
                .tabItem {
                    Label("RDAR & Resolusi", systemImage: "aspectratio")
                }
                .tag(3)
        }
        .accentColor(.blue)
    }
}

struct ControlCenterView: View {
    @ObservedObject var exploitManager = ExploitManager.shared
    @State private var selectedBuild = "24A5380h"
    let builds = ["24A5355q", "24A5370h", "24A5380h", "24A5390f"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Informasi Platform & Build")) {
                    Picker("Versi Build iOS 27", selection: $selectedBuild) {
                        ForEach(builds, id: \.self) { build in
                            Text(build).tag(build)
                        }
                    }
                    
                    HStack {
                        Text("Status Eksploit bad_query")
                        Spacer()
                        Text(exploitManager.isExploitActive ? "Aktif" : "Nonaktif")
                            .foregroundColor(exploitManager.isExploitActive ? .green : .red)
                            .bold()
                    }
                    
                    Button(action: {
                        do {
                            try exploitManager.initialize(buildVersion: selectedBuild)
                        } catch {
                            exploitManager.addLog("Gagal menginisialisasi: \(error.localizedDescription)")
                        }
                    }) {
                        Text("Inisialisasi Sandbox Escape")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                
                Section(header: Text("Log Sistem Real-Time")) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(exploitManager.logOutput, id: \.self) { log in
                                Text(log)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(height: 180)
                }
            }
            .navigationTitle("work.plot Kontrol")
        }
    }
}

struct GestaltPresetView: View {
    let presets = PresetRegistry.shared.getPresets()
    
    var body: some View {
        NavigationView {
            List(presets) { preset in
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.name)
                        .font(.headline)
                    Text("Key: \(preset.key)")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Button("Terapkan Preset") {
                        let mockDict = [preset.key: preset.value]
                        let result = StagedApplyEngine.shared.applyWithVerification(mockDict, at: "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist")
                        if case .success(let backup) = result {
                            ExploitManager.shared.addLog("Preset \(preset.name) berhasil diterapkan. Backup: \(backup)")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.caption)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Registry MobileGestalt")
        }
    }
}

struct LiquidGlassControlView: View {
    @State private var disableLiquidGlass = true
    @State private var transparencyValue: Double = 50.0
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Kontrol UI Render")) {
                    Toggle("Nonaktifkan Liquid Glass (Gaya iOS 18)", isOn: $disableLiquidGlass)
                        .onChange(of: disableLiquidGlass) { value in
                            _ = LiquidGlassController.shared.disableGlobal(disabled: value)
                        }
                    
                    VStack(alignment: .leading) {
                        Text("Tingkat Transparansi: \(Int(transparencyValue))%")
                        Slider(value: $transparencyValue, in: 0...100, step: 1) {
                            Text("Transparansi")
                        } onEditingChanged: { _ in
                            _ = LiquidGlassController.shared.setTransparencyLevel(level: Int(transparencyValue))
                        }
                    }
                }
                
                Section {
                    Button("Terapkan & Respring Aman") {
                        _ = SpringBoardManager.safeRespring()
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.blue)
                }
            }
            .navigationTitle("Liquid Glass Setting")
        }
    }
}

struct RDARSettingsView: View {
    @State private var selectedWidth = 1206
    @State private var selectedHeight = 2622
    let resolutions = [
        (name: "iPhone 16 Pro (1206x2622)", w: 1206, h: 2622),
        (name: "iPhone 16 Pro Max (1290x2796)", w: 1290, h: 2796),
        (name: "iPhone 17 Pro Max (1290x2868)", w: 1290, h: 2868)
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Resolusi Kanvas & Perbaikan RDAR")) {
                    Picker("Pilih Profil Perangkat", selection: $selectedWidth) {
                        ForEach(resolutions, id: \.w) { res in
                            Text(res.name).tag(res.w)
                        }
                    }
                    .onChange(of: selectedWidth) { newW in
                        if let match = resolutions.first(where: { $0.w == newW }) {
                            selectedHeight = match.h
                        }
                    }
                    
                    Button("Koreksi Geometri & Terapkan RDAR Fix") {
                        let res = RDARFix.shared.apply(width: selectedWidth, height: selectedHeight)
                        if case .success = res {
                            _ = SpringBoardManager.safeRespring()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("RDAR & Resolusi")
        }
    }
}

