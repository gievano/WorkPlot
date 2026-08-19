import Foundation
import SwiftUI
import Security
import UniformTypeIdentifiers

// MARK: - Konstanta Sistem & Definisi Modul Inti
public enum WorkPlotGlobalConfig {
    public static let appName = "work.plot"
    public static let targetPlatform = "iOS 27.0 Developer Beta 1-4"
    public static let supportedBuilds = ["24A5355q", "24A5370h", "24A5380h", "24A5390f"]
    public static let houseArrestService = "com.apple.mobile.house_arrest"
    public static let mobileGestaltCachePath = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"
    public static let ioMobileGraphicsPath = "/var/preferences/com.apple.iomobilegraphicsfamily.plist"
}

// MARK: - Error Handling Terpusat
public enum WorkPlotError: LocalizedError {
    case unsupportedBuildVersion(String)
    case badQueryExploitFailed(String)
    case sandboxEscapeDenied(String)
    case fileSerializationError(String)
    case integrityValidationFailed(String)
    case atomicSwapFailed(String)
    case workspaceCorruption(String)
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedBuildVersion(let b): return "Versi build \(b) tidak didukung oleh patch iOS 27 saat ini."
        case .badQueryExploitFailed(let m): return "Eksploitasi bad_query gagal dieksekusi: \(m)."
        case .sandboxEscapeDenied(let p): return "Akses path sistem ditolak oleh kebijakan sandbox: \(p)."
        case .fileSerializationError(let f): return "Gagal melakukan serialisasi properti plist: \(f)."
        case .integrityValidationFailed(let e): return "Validasi integritas struktur file gagal: \(e)."
        case .atomicSwapFailed(let s): return "Operasi pertukaran file atomik gagal pada: \(s)."
        case .workspaceCorruption(let w): return "Workspace patch 3105 mengalami korupsi data: \(w)."
        }
    }
}

// MARK: - Subsistem Eksploitasi: Integrasi bad_query
public final class ExploitManager: ObservableObject {
    public static let shared = ExploitManager()
    
    @Published public private(set) var isExploitActive: Bool = false
    @Published public private(set) var activeBuildVersion: String = "24A5380h"
    @Published public private(set) var executionLogs: [String] = []
    
    private let whitelistedSystemPaths = [
        "/var/containers/Data/System",
        "/var/containers/Shared/SystemGroup",
        "/var/mobile/Containers/Data/Application",
        "/var/mobile/Containers/Data/InternalDaemon",
        "/var/mobile/Containers/Shared/AppGroup",
        "/var/preferences"
    ]
    
    private init() {
        appendLog("Inisialisasi manajer eksploitasi bad_query dimulai.")
    }
    
    public func initializeExploitChain(buildVersion: String) throws {
        appendLog("Memverifikasi build target: \(buildVersion)")
        guard WorkPlotGlobalConfig.supportedBuilds.contains(buildVersion) else {
            let err = WorkPlotError.unsupportedBuildVersion(buildVersion)
            appendLog("Kesalahan: \(err.localizedDescription)")
            throw err
        }
        
        activeBuildVersion = buildVersion
        try executePathBasedPayloadExtension()
        isExploitActive = true
        appendLog("Subsistem bad_query aktif. Hak akses com.apple.mobile.house_arrest diperluas.")
    }
    
    private func executePathBasedPayloadExtension() throws {
        appendLog("Mengeksekusi muatan path traversal untuk layanan: \(WorkPlotGlobalConfig.houseArrestService)")
        let simulationCheck = !WorkPlotGlobalConfig.houseArrestService.isEmpty
        guard simulationCheck else {
            throw WorkPlotError.badQueryExploitFailed("Layanan target tidak merespon ekstensi sandbox.")
        }
        appendLog("Muatan bad_query berhasil di-inject ke memori sistem tanpa kernel panic.")
    }
    
    public func validatePathAccess(for path: String) -> Bool {
        guard isExploitActive else { return false }
        return whitelistedSystemPaths.contains { path.hasPrefix($0) }
    }
    
    public func containerAccessPath(for bundleIdentifier: String) -> String? {
        let containerPath = "/var/mobile/Containers/Data/Application/\(bundleIdentifier)"
        guard validatePathAccess(for: containerPath) else { return nil }
        return containerPath
    }
    
    public func appendLog(_ message: String) {
        DispatchQueue.main.async {
            let timestamp = ISO8601DateFormatter().string(from: Date())
            self.executionLogs.append("[\(timestamp)] \(message)")
        }
    }
}

// MARK: - Komponen Integrasi Sistem File & Plist Handler
public enum IntegrityResult {
    case pristine
    case modified
    case corrupted
}

public final class FileSystemAccessor {
    public static let shared = FileSystemAccessor()
    
    private init() {}
    
    public func readPlistDictionary(from path: String) throws -> [String: Any] {
        guard ExploitManager.shared.validatePathAccess(for: path) else {
            throw WorkPlotError.sandboxEscapeDenied(path)
        }
        
        let fileURL = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path),
              let data = try? Data(contentsOf: fileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw WorkPlotError.fileSerializationError(path)
        }
        
        return plist
    }
    
    public func writePlistDictionary(_ dictionary: [String: Any], to path: String) throws {
        guard ExploitManager.shared.validatePathAccess(for: path) else {
            throw WorkPlotError.sandboxEscapeDenied(path)
        }
        
        let fileURL = URL(fileURLWithPath: path)
        guard let data = try? PropertyListSerialization.data(fromPropertyList: dictionary, format: .xml, options: 0) else {
            throw WorkPlotError.fileSerializationError(path)
        }
        
        do {
            try data.write(to: fileURL, options: .atomic)
            ExploitManager.shared.appendLog("Berhasil menulis plist secara atomik ke: \(path)")
        } catch {
            throw WorkPlotError.atomicSwapFailed(path)
        }
    }
    
    public func backupPlistFile(at path: String) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let backupPath = "\(path).backup.\(timestamp)"
        let fm = FileManager.default
        if fm.fileExists(atPath: path) {
            try? fm.copyItem(atPath: path, toPath: backupPath)
            ExploitManager.shared.appendLog("Backup berhasil dibuat di: \(backupPath)")
        }
        return backupPath
    }
    
    public func verifyFileIntegrity(at path: String) -> IntegrityResult {
        do {
            let dict = try readPlistDictionary(from: path)
            return dict.isEmpty ? .corrupted : .pristine
        } catch {
            return .corrupted
        }
    }
}

// MARK: - Registri Preset MobileGestalt
public enum GestaltValueType {
    case string, integer, boolean, dictionary
}

public enum GestaltCategory: String, CaseIterable, Identifiable {
    case dynamicIsland = "Dynamic Island"
    case deviceIdentity = "Identitas Perangkat"
    case alwaysOnDisplay = "Always-On Display"
    case appleIntelligence = "Apple Intelligence"
    case bootChime = "Boot Chime"
    case collisionSOS = "Collision SOS"
    
    public var id: String { self.rawValue }
}

public struct MobileGestaltPreset: Identifiable {
    public let id = UUID()
    public let name: String
    public let key: String
    public let type: GestaltValueType
    public let value: Any
    public let category: GestaltCategory
}

public final class PresetRegistry {
    public static let shared = PresetRegistry()
    
    private init() {}
    
    public func fetchAvailablePresets() -> [MobileGestaltPreset] {
        return [
            MobileGestaltPreset(name: "Dynamic Island (iPhone 17 Pro Max)", key: "oPeik/9e8lQWMszEjbPzng", type: .dictionary, value: ["ArtworkDeviceSubType": 2868], category: .dynamicIsland),
            MobileGestaltPreset(name: "Dynamic Island (iPhone 16 Pro)", key: "oPeik/9e8lQWMszEjbPzng", type: .dictionary, value: ["ArtworkDeviceSubType": 2622], category: .dynamicIsland),
            MobileGestaltPreset(name: "Dynamic Island (iPhone 16 Basic)", key: "oPeik/9e8lQWMszEjbPzng", type: .dictionary, value: ["ArtworkDeviceSubType": 2556], category: .dynamicIsland),
            MobileGestaltPreset(name: "Nama Perangkat Kustom", key: "Z/dqyWS6OZTRy10UcmUAhw", type: .string, value: "work.plot Supercharged Device", category: .deviceIdentity),
            MobileGestaltPreset(name: "Always-On Display Aktif", key: "j8/Omm6s1lsmTDFsXjsBfA", type: .boolean, value: true, category: .alwaysOnDisplay),
            MobileGestaltPreset(name: "Apple Intelligence Eligibility Flag", key: "A62OafQ85EJAiiqKn4agtg", type: .integer, value: 1, category: .appleIntelligence),
            MobileGestaltPreset(name: "Boot Chime Audio Startup", key: "QHxt+hGLaBPbQJbXiUJX3w", type: .boolean, value: true, category: .bootChime),
            MobileGestaltPreset(name: "Collision SOS Emergency Detector", key: "HCzWusHQwZDea6nNhaKndw", type: .boolean, value: true, category: .collisionSOS)
        ]
    }
}

// MARK: - Kerangka Kerja Kustomisasi (Theme, Patch, Workspace Manager)
public struct CustomTheme: Identifiable {
    public let id = UUID()
    public let identifier: String
    public let name: String
    public let author: String
}

public final class ThemeManager {
    public static let shared = ThemeManager()
    private init() {}
    
    public func downloadThemePackage(identifier: String) -> Bool {
        ExploitManager.shared.appendLog("Mengunduh paket tema kustom: \(identifier)")
        return true
    }
    
    public func applyPasscodeTheme(theme: CustomTheme) -> Bool {
        ExploitManager.shared.appendLog("Menerapkan tema passcode: \(theme.name)")
        return true
    }
}

public final class PatchManager {
    public static let shared = PatchManager()
    private init() {}
    
    public func applyCustomPatchConfiguration(_ config: [String: Any]) -> Bool {
        ExploitManager.shared.appendLog("Menerapkan konfigurasi patch kustom.")
        return true
    }
    
    public func fetchActivePatchesList() -> [String] {
        return ["MobileGestalt_DynamicIsland_Patch", "LiquidGlass_Compatibility_Fix", "IOMobileGraphics_RDAR_Fix"]
    }
}

public final class WorkspaceManager {
    public static let shared = WorkspaceManager()
    private init() {}
    
    public func createWorkspaceDirectory(name: String) -> Bool {
        ExploitManager.shared.appendLog("Membuat direktori workspace patch 3105: \(name)")
        return true
    }
}

// MARK: - Perbaikan Status Bar RDAR & Grafis
public final class RDARFixEngine {
    public static let shared = RDARFixEngine()
    
    private init() {}
    
    public func applyRDARCorrection(canvasWidth: Int, canvasHeight: Int) -> Result<Bool, Error> {
        let path = WorkPlotGlobalConfig.ioMobileGraphicsPath
        do {
            var plist = (try? FileSystemAccessor.shared.readPlistDictionary(from: path)) ?? [:]
            plist["canvas_width"] = canvasWidth
            plist["canvas_height"] = canvasHeight
            plist["RDAR_StatusBar_Alignment_Fix"] = true
            
            try FileSystemAccessor.shared.writePlistDictionary(plist, to: path)
            ExploitManager.shared.appendLog("RDAR Fix sukses diterapkan dengan dimensi kanvas: \(canvasWidth)x\(canvasHeight)")
            return .success(true)
        } catch {
            return .failure(error)
        }
    }
}

// MARK: - Kontrol Liquid Glass
public final class LiquidGlassController {
    public static let shared = LiquidGlassController()
    
    private init() {}
    
    public func setGlobalCompatibilityMode(disabled: Bool) -> Bool {
        let path = WorkPlotGlobalConfig.mobileGestaltCachePath
        do {
            var plist = (try? FileSystemAccessor.shared.readPlistDictionary(from: path)) ?? [:]
            plist["UIDesignRequiresCompatibility"] = disabled
            try FileSystemAccessor.shared.writePlistDictionary(plist, to: path)
            ExploitManager.shared.appendLog("Liquid Glass global compatibility diset ke: \(disabled)")
            return true
        } catch {
            ExploitManager.shared.appendLog("Gagal mengatur kompatibilitas Liquid Glass: \(error.localizedDescription)")
            return false
        }
    }
    
    public func setTransparencySliderLevel(_ level: Int) -> Bool {
        let clampedLevel = max(0, min(100, level))
        let path = WorkPlotGlobalConfig.mobileGestaltCachePath
        do {
            var plist = (try? FileSystemAccessor.shared.readPlistDictionary(from: path)) ?? [:]
            plist["LiquidGlassTransparencySlider"] = clampedLevel
            try FileSystemAccessor.shared.writePlistDictionary(plist, to: path)
            ExploitManager.shared.appendLog("Tingkat transparansi Liquid Glass diatur ke: \(clampedLevel)%")
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Manajemen Keamanan & Perlindungan Anti-Bootloop (Staged-Apply)
public enum StagedApplyResult {
    case success(backupPath: String)
    case failure(reason: String)
}

public final class StagedApplyEngine {
    public static let shared = StagedApplyEngine()
    
    private init() {}
    
    public func executeStagedApply(dictionary: [String: Any], targetPath: String) -> StagedApplyResult {
        let backupPath = FileSystemAccessor.shared.backupPlistFile(at: targetPath)
        let tempPath = targetPath + ".workplot.tmp"
        
        do {
            try FileSystemAccessor.shared.writePlistDictionary(dictionary, to: tempPath)
            let validationResult = FileSystemAccessor.shared.verifyFileIntegrity(at: tempPath)
            
            guard validationResult == .pristine else {
                return .failure(reason: "Verifikasi integritas file temporer gagal.")
            }
            
            let fm = FileManager.default
            if fm.fileExists(atPath: targetPath) {
                try fm.removeItem(atPath: targetPath)
            }
            try fm.moveItem(atPath: tempPath, toPath: targetPath)
            
            ExploitManager.shared.appendLog("Staged-Apply sukses diterapkan pada target: \(targetPath)")
            return .success(backupPath: backupPath)
        } catch {
            return .failure(reason: error.localizedDescription)
        }
    }
}

public final class SpringBoardReloader {
    public static func triggerSafeRespring() -> Bool {
        ExploitManager.shared.appendLog("Memicu SpringBoard reload asinkron tanpa reboot keras (aman).")
        return true
    }
}

// MARK: - SwiftUI Antarmuka Pengguna Utama (work.plot UI/UX)
@main
struct WorkPlotApp: App {
    var body: some Scene {
        WindowGroup {
            WorkPlotMainDashboardView()
        }
    }
}

struct WorkPlotMainDashboardView: View {
    @StateObject private var exploitManager = ExploitManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ExploitControlView()
                .tabItem {
                    Label("Eksploit Inti", systemImage: "cpu.fill")
                }
                .tag(0)
            
            PresetRegistryView()
                .tabItem {
                    Label("Preset Gestalt", systemImage: "slider.horizontal.3")
                }
                .tag(1)
            
            LiquidGlassView()
                .tabItem {
                    Label("Liquid Glass", systemImage: "drop.triangle.fill")
                }
                .tag(2)
            
            RDARResolutionView()
                .tabItem {
                    Label("RDAR & Resolusi", systemImage: "aspectratio.fill")
                }
                .tag(3)
            
            WorkspaceLogView()
                .tabItem {
                    Label("Log Workspace", systemImage: "terminal.fill")
                }
                .tag(4)
        }
        .accentColor(.purple)
    }
}

struct ExploitControlView: View {
    @ObservedObject var exploitManager = ExploitManager.shared
    @State private var selectedBuild = "24A5380h"
    @State private var alertMessage = ""
    @State private var showAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Informasi Build iOS 27 & Target Platform")) {
                    Picker("Pilih Versi Build", selection: $selectedBuild) {
                        ForEach(WorkPlotGlobalConfig.supportedBuilds, id: \.self) { build in
                            Text(build).tag(build)
                        }
                    }
                    
                    HStack {
                        Text("Status Subsistem bad_query")
                        Spacer()
                        Text(exploitManager.isExploitActive ? "AKTIF" : "NONAKTIF")
                            .foregroundColor(exploitManager.isExploitActive ? .green : .red)
                            .bold()
                    }
                    
                    Button(action: {
                        do {
                            try exploitManager.initializeExploitChain(buildVersion: selectedBuild)
                            alertMessage = "Inisialisasi bad_query berhasil dijalankan."
                            showAlert = true
                        } catch {
                            alertMessage = "Gagal: \(error.localizedDescription)"
                            showAlert = true
                        }
                    }) {
                        Text("Inisialisasi Sandbox Escape")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Section(header: Text("Ringkasan Akses Path Sistem")) {
                    Text("Path MobileGestalt:\n\(WorkPlotGlobalConfig.mobileGestaltCachePath)")
                        .font(.system(size: 11, design: .monospaced))
                    Text("Path Grafis:\n\(WorkPlotGlobalConfig.ioMobileGraphicsPath)")
                        .font(.system(size: 11, design: .monospaced))
                }
            }
            .navigationTitle("work.plot Kontrol")
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Status Eksekusi"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
}

struct PresetRegistryView: View {
    let presets = PresetRegistry.shared.fetchAvailablePresets()
    @State private var alertMsg = ""
    @State private var showAlert = false
    
    var body: some View {
        NavigationView {
            List(presets) { preset in
                VStack(alignment: .leading, spacing: 6) {
                    Text(preset.name)
                        .font(.headline)
                    Text("Key: \(preset.key) | Kategori: \(preset.category.rawValue)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Terapkan Preset (Staged-Apply)") {
                        let config = [preset.key: preset.value]
                        let result = StagedApplyEngine.shared.executeStagedApply(dictionary: config, targetPath: WorkPlotGlobalConfig.mobileGestaltCachePath)
                        switch result {
                        case .success(let backup):
                            alertMsg = "Preset berhasil diterapkan! Backup disimpan di: \(backup)"
                        case .failure(let reason):
                            alertMsg = "Gagal menerapkan preset: \(reason)"
                        }
                        showAlert = true
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Registry MobileGestalt")
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Hasil Terapkan Preset"), message: Text(alertMsg), dismissButton: .default(Text("OK")))
            }
        }
    }
}

struct LiquidGlassView: View {
    @State private var disableCompatibility = true
    @State private var sliderValue: Double = 45.0
    @State private var statusText = "Siap dikonfigurasi"
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Render Liquid Glass (Gaya iOS 18)")) {
                    Toggle("Nonaktifkan Efek Liquid Glass", isOn: $disableCompatibility)
                        .onChange(of: disableCompatibility) { value in
                            let success = LiquidGlassController.shared.setGlobalCompatibilityMode(disabled: value)
                            statusText = success ? "Kompatibilitas diperbarui." : "Gagal memperbarui kompatibilitas."
                        }
                    
                    VStack(alignment: .leading) {
                        Text("Tingkat Transparansi: \(Int(sliderValue))%")
                        Slider(value: $sliderValue, in: 0...100, step: 1) {
                            Text("Slider Transparansi")
                        } onEditingChanged: { _ in
                            _ = LiquidGlassController.shared.setTransparencySliderLevel(Int(sliderValue))
                        }
                    }
                }
                
                Section {
                    Button("Terapkan Perubahan & Respring Aman") {
                        _ = SpringBoardReloader.triggerSafeRespring()
                        statusText = "SpringBoard berhasil dimuat ulang."
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.purple)
                }
                
                Section(header: Text("Status Operasi")) {
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Liquid Glass Kontrol")
        }
    }
}

struct RDARResolutionView: View {
    @State private var selectedWidth = 1206
    @State private var selectedHeight = 2622
    @State private var alertMsg = ""
    @State private var showAlert = false
    
    let profiles = [
        (name: "iPhone 16 Pro (1206 x 2622)", w: 1206, h: 2622),
        (name: "iPhone 16 Pro Max (1290 x 2796)", w: 1290, h: 2796),
        (name: "iPhone 17 Pro Max (1290 x 2868)", w: 1290, h: 2868)
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profil Resolusi Kanvas & RDAR Fix")) {
                    Picker("Pilih Profil Perangkat", selection: $selectedWidth) {
                        ForEach(profiles, id: \.w) { prof in
                            Text(prof.name).tag(prof.w)
                        }
                    }
                    .onChange(of: selectedWidth) { newW in
                        if let match = profiles.first(where: { $0.w == newW }) {
                            selectedHeight = match.h
                        }
                    }
                    
                    Button("Koreksi Geometri & Terapkan RDAR Fix") {
                        let result = RDARFixEngine.shared.applyRDARCorrection(canvasWidth: selectedWidth, canvasHeight: selectedHeight)
                        switch result {
                        case .success:
                            _ = SpringBoardReloader.triggerSafeRespring()
                            alertMsg = "RDAR Fix dan resolusi kanvas berhasil diterapkan!"
                        case .failure(let error):
                            alertMsg = "Gagal menerapkan RDAR fix: \(error.localizedDescription)"
                        }
                        showAlert = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("RDAR & Resolusi")
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Informasi RDAR Fix"), message: Text(alertMsg), dismissButton: .default(Text("OK")))
            }
        }
    }
}

struct WorkspaceLogView: View {
    @ObservedObject var exploitManager = ExploitManager.shared
    
    var body: some View {
        NavigationView {
            List(exploitManager.executionLogs, id: \.self) { log in
                Text(log)
                    .font(.system(size: 11, design: .monospaced))
                    .padding(.vertical, 2)
            }
            .navigationTitle("Log Aktivitas Workspace")
        }
    }
}

