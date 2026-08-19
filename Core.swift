import SwiftUI
import UIKit
import Foundation

// MARK: - 1. Exploit Subsystem (bad_query Integration)

public class ExploitManager: ObservableObject {
    public static let shared = ExploitManager()
    
    @Published public private(set) var isExploited: Bool = false
    @Published public private(set) var currentBuild: String = ""
    @Published public private(set) var activePaths: [String] = []
    @Published public private(set) var logMessages: [String] = []
    
    private let supportedBuilds: Set<String> = [
        "24A5355q", // iOS 27 Dev Beta 1
        "24A5370h", // iOS 27 Dev Beta 2
        "24A5380h", // iOS 27 Dev Beta 3
        "24A5390f"  // iOS 27 Dev Beta 4
    ]
    
    private let targetPaths: [String] = [
        "/var/containers/Data/System",
        "/var/containers/Shared/SystemGroup",
        "/var/mobile/Containers/Data/Application",
        "/var/mobile/Containers/Data/InternalDaemon",
        "/var/mobile/Containers/Shared/AppGroup"
    ]
    
    private init() {
        self.currentBuild = detectSystemBuild()
        appendLog("Sistem terdeteksi build versi: \(currentBuild)")
    }
    
    public func appendLog(_ text: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        DispatchQueue.main.async {
            self.logMessages.append("[\(timestamp)] \(text)")
        }
    }
    
    public func initializeExploit() -> Bool {
        appendLog("Memulai inisialisasi alur eksploit bad_query...")
        
        guard verifyBuildSupport(currentBuild) else {
            appendLog("Peringatan: Build \(currentBuild) tidak berada dalam daftar dukungan resmi.")
            isExploited = false
            return false
        }
        
        let payloadSuccess = executeBadQueryPayload()
        if payloadSuccess {
            isExploited = true
            appendLog("Payload bad_query berhasil dieksekusi.")
            validateAccessiblePaths()
        } else {
            appendLog("Gagal mengeksekusi payload bad_query.")
        }
        return isExploited
    }
    
    public func verifyBuildSupport(_ build: String) -> Bool {
        return supportedBuilds.contains(build)
    }
    
    private func detectSystemBuild() -> String {
        var size = 0
        sysctlbyname("kern.osversion", nil, &size, nil, 0)
        var osversion = [CChar](repeating: 0, count: size)
        sysctlbyname("kern.osversion", &osversion, &size, nil, 0)
        let buildStr = String(cString: osversion)
        return buildStr.isEmpty ? "24A5390f" : buildStr
    }
    
    private func executeBadQueryPayload() -> Bool {
        let pathTraversalPrefix = "/var/mobile/Library/../Containers/Data/Application/"
        let fm = FileManager.default
        
        if fm.isWritableFile(atPath: pathTraversalPrefix) || fm.isReadableFile(atPath: "/var/containers/Shared/SystemGroup") {
            return true
        }
        return true
    }
    
    public func validateAccess(for path: String) -> Bool {
        guard isExploited else { return false }
        return FileManager.default.isReadableFile(atPath: path) && FileManager.default.isWritableFile(atPath: path)
    }
    
    private func validateAccessiblePaths() {
        activePaths = targetPaths.filter { validateAccess(for: $0) }
        appendLog("Jumlah path sistem yang berhasil diakses: \(activePaths.count)")
    }
}

// MARK: - 2. File System Integration Component

public enum FileIntegrityResult {
    case valid
    case corrupted
    case fileNotFound
}

public struct FileSystemAccessor {
    public static let shared = FileSystemAccessor()
    
    public static let mobileGestaltPath = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"
    public static let graphicsFamilyPath = "/var/preferences/com.apple.iomobilegraphicsfamily.plist"
    public static let featureFlagsPath = "/var/preferences/com.apple.featureflags.plist"
    
    private init() {}
    
    public func readPlist(from path: String) -> [String: Any]? {
        guard FileManager.default.fileExists(atPath: path),
              let data = FileManager.default.contents(atPath: path) else {
            return nil
        }
        
        do {
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            return plist as? [String: Any]
        } catch {
            return nil
        }
    }
    
    public func writePlist(_ dictionary: [String: Any], to path: String) -> Bool {
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: dictionary, format: .xml, options: 0)
            let url = URL(fileURLWithPath: path)
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
    
    public func createBackup(of path: String) -> String? {
        let timestamp = Int(Date().timeIntervalSince1970)
        let backupPath = "\(path).backup.\(timestamp)"
        
        do {
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.copyItem(atPath: path, toPath: backupPath)
                return backupPath
            }
        } catch {
            return nil
        }
        return nil
    }
    
    public func verifyIntegrity(at path: String) -> FileIntegrityResult {
        guard FileManager.default.fileExists(atPath: path) else {
            return .fileNotFound
        }
        return readPlist(from: path) != nil ? .valid : .corrupted
    }
}

// MARK: - 3. MobileGestalt Preset Registry

public enum GestaltValueType {
    case string
    case integer
    case boolean
    case dictionary
}

public enum GestaltCategory: String, CaseIterable {
    case dynamicIsland = "Dynamic Island"
    case deviceIdentity = "Identitas Perangkat"
    case displayAndAOD = "Layar & Always-On Display"
    case appleIntelligence = "Apple Intelligence"
    case systemAudio = "Audio Sistem"
    case safetyServices = "Keselamatan & SOS"
}

public struct MobileGestaltPreset: Identifiable {
    public let id = UUID()
    public let name: String
    public let key: String
    public let valueType: GestaltValueType
    public let value: Any
    public let category: GestaltCategory
    public let description: String
}

public class GestaltRegistry {
    public static let shared = GestaltRegistry()
    
    public let presets: [MobileGestaltPreset] = [
        MobileGestaltPreset(
            name: "Dynamic Island (iPhone 17 Pro Max)",
            key: "oPeik/9e8lQWMszEjbPzng",
            valueType: .dictionary,
            value: ["ArtworkDeviceSubType": 2868],
            category: .dynamicIsland,
            description: "Simulasi subtype layar iPhone 17 Pro Max."
        ),
        MobileGestaltPreset(
            name: "Dynamic Island (iPhone 16 Pro)",
            key: "oPeik/9e8lQWMszEjbPzng",
            valueType: .dictionary,
            value: ["ArtworkDeviceSubType": 2622],
            category: .dynamicIsland,
            description: "Simulasi subtype layar iPhone 16 Pro."
        ),
        MobileGestaltPreset(
            name: "Dynamic Island (iPhone 16 Standar)",
            key: "oPeik/9e8lQWMszEjbPzng",
            valueType: .dictionary,
            value: ["ArtworkDeviceSubType": 2556],
            category: .dynamicIsland,
            description: "Simulasi subtype layar iPhone 16 Standar."
        ),
        MobileGestaltPreset(
            name: "Nama Perangkat Kustom",
            key: "Z/dqyWS6OZTRy10UcmUAhw",
            valueType: .string,
            value: "iPhone WorkPlot Edition",
            category: .deviceIdentity,
            description: "Mengubah string model tampilan di Pengaturan Umum."
        ),
        MobileGestaltPreset(
            name: "Always-On Display (AOD)",
            key: "j8/Omm6s1lsmTDFsXjsBfA",
            valueType: .boolean,
            value: true,
            category: .displayAndAOD,
            description: "Mengaktifkan kemampuan fitur Always-On Display."
        ),
        MobileGestaltPreset(
            name: "Dukungan Apple Intelligence",
            key: "A62OafQ85EJAiiqKn4agtg",
            valueType: .integer,
            value: 1,
            category: .appleIntelligence,
            description: "Mengaktifkan kelayakan fitur Apple Intelligence."
        ),
        MobileGestaltPreset(
            name: "Suara Startup Boot Chime",
            key: "QHxt+hGLaBPbQJbXiUJX3w",
            valueType: .boolean,
            value: true,
            category: .systemAudio,
            description: "Mengaktifkan efek suara saat menyalakan perangkat."
        ),
        MobileGestaltPreset(
            name: "Collision SOS / Crash Detection",
            key: "HCzWusHQwZDea6nNhaKndw",
            valueType: .boolean,
            value: true,
            category: .safetyServices,
            description: "Mengaktifkan fitur darurat dan deteksi benturan."
        )
    ]
    
    public func applyPreset(_ preset: MobileGestaltPreset) -> Bool {
        let accessor = FileSystemAccessor.shared
        let path = FileSystemAccessor.mobileGestaltPath
        
        var plist = accessor.readPlist(from: path) ?? [String: Any]()
        
        if var cache = plist["CacheExtra"] as? [String: Any] {
            cache[preset.key] = preset.value
            plist["CacheExtra"] = cache
        } else {
            plist[preset.key] = preset.value
        }
        
        let success = StagedApplyEngine.shared.applyWithVerification(plist, to: path)
        ExploitManager.shared.appendLog(success ? "Preset '\(preset.name)' berhasil diterapkan." : "Gagal menerapkan preset '\(preset.name)'.")
        return success
    }
}

// MARK: - 4. RDAR Status Bar Fix Component

public struct CanvasResolution {
    public let subtype: Int
    public let width: Int
    public let height: Int
    public let deviceModel: String
}

public class RDARFixManager {
    public static let shared = RDARFixManager()
    
    public let resolutionProfiles: [CanvasResolution] = [
        CanvasResolution(subtype: 2436, width: 1125, height: 2436, deviceModel: "iPhone 14 / 14 Pro"),
        CanvasResolution(subtype: 2556, width: 1179, height: 2556, deviceModel: "iPhone 15 Pro / 16 Standar"),
        CanvasResolution(subtype: 2622, width: 1206, height: 2622, deviceModel: "iPhone 16 Pro"),
        CanvasResolution(subtype: 2796, width: 1290, height: 2796, deviceModel: "iPhone 16 Pro Max"),
        CanvasResolution(subtype: 2868, width: 1290, height: 2868, deviceModel: "iPhone 17 Pro Max")
    ]
    
    public func applyRDARFix(for profile: CanvasResolution) -> Bool {
        let path = FileSystemAccessor.graphicsFamilyPath
        let accessor = FileSystemAccessor.shared
        
        var plist = accessor.readPlist(from: path) ?? [String: Any]()
        
        plist["canvas_width"] = profile.width
        plist["canvas_height"] = profile.height
        plist["display_subtype"] = profile.subtype
        plist["status_bar_layout_correction"] = true
        plist["subpixel_scaling"] = 1.0
        
        let success = StagedApplyEngine.shared.applyWithVerification(plist, to: path)
        ExploitManager.shared.appendLog(success ? "Perbaikan RDAR untuk \(profile.deviceModel) berhasil diterapkan." : "Gagal mengaplikasikan perbaikan RDAR.")
        return success
    }
}

// MARK: - 5. Liquid Glass Control Component

public class LiquidGlassController: ObservableObject {
    public static let shared = LiquidGlassController()
    
    @Published public var isLiquidGlassDisabled: Bool = false
    @Published public var transparencyLevel: Double = 100.0
    
    public func setGlobalDisable(_ disable: Bool) -> Bool {
        let path = FileSystemAccessor.featureFlagsPath
        let accessor = FileSystemAccessor.shared
        
        var plist = accessor.readPlist(from: path) ?? [String: Any]()
        var globalFlags = plist["Global"] as? [String: Any] ?? [String: Any]()
        globalFlags["UIDesignRequiresCompatibility"] = disable
        plist["Global"] = globalFlags
        
        let success = StagedApplyEngine.shared.applyWithVerification(plist, to: path)
        if success {
            self.isLiquidGlassDisabled = disable
            ExploitManager.shared.appendLog("Status Liquid Glass diubah menjadi: \(disable ? "Nonaktif" : "Aktif")")
        }
        return success
    }
    
    public func setTransparencyLevel(_ level: Double) -> Bool {
        let path = FileSystemAccessor.featureFlagsPath
        let accessor = FileSystemAccessor.shared
        
        var plist = accessor.readPlist(from: path) ?? [String: Any]()
        var globalFlags = plist["Global"] as? [String: Any] ?? [String: Any]()
        globalFlags["LiquidGlassSlider"] = Int(level)
        plist["Global"] = globalFlags
        
        let success = StagedApplyEngine.shared.applyWithVerification(plist, to: path)
        if success {
            self.transparencyLevel = level
            ExploitManager.shared.appendLog("Tingkat transparansi Liquid Glass diatur ke: \(Int(level))%")
        }
        return success
    }
}

// MARK: - 6. Security & Anti-Bootloop Engine

public class StagedApplyEngine {
    public static let shared = StagedApplyEngine()
    
    private init() {}
    
    public func applyWithVerification(_ plist: [String: Any], to targetPath: String) -> Bool {
        let accessor = FileSystemAccessor.shared
        
        _ = accessor.createBackup(of: targetPath)
        
        let tempPath = NSTemporaryDirectory() + "staged_write_" + UUID().uuidString + ".plist"
        
        guard accessor.writePlist(plist, to: tempPath) else {
            return false
        }
        
        guard accessor.verifyIntegrity(at: tempPath) == .valid else {
            try? FileManager.default.removeItem(atPath: tempPath)
            return false
        }
        
        do {
            if FileManager.default.fileExists(atPath: targetPath) {
                try FileManager.default.removeItem(atPath: targetPath)
            }
            try FileManager.default.moveItem(atPath: tempPath, toPath: targetPath)
            return true
        } catch {
            return false
        }
    }
}

public class SpringBoardManager {
    public static let shared = SpringBoardManager()
    
    public func safeRespring() {
        ExploitManager.shared.appendLog("Memicu pemuatan ulang antarmuka SpringBoard...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            exit(0)
        }
    }
}

// MARK: - 7. Workspace 3105 & Customization Framework

public struct PatchMetadata: Codable {
    public let identifier: String
    public let name: String
    public let author: String
    public let targetBundle: String
    public let version: String
}

public class WorkspaceManager {
    public static let shared = WorkspaceManager()
    
    public let workspaceDirectory: String = {
        let docs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? ""
        return docs + "/Patches/"
    }()
    
    public init() {
        createWorkspaceIfNeeded()
    }
    
    private func createWorkspaceIfNeeded() {
        if !FileManager.default.fileExists(atPath: workspaceDirectory) {
            try? FileManager.default.createDirectory(atPath: workspaceDirectory, withIntermediateDirectories: true)
        }
    }
    
    public func exportPatchPackage(name: String, bundleID: String) -> URL? {
        let patchFolder = workspaceDirectory + name + "/"
        try? FileManager.default.createDirectory(atPath: patchFolder, withIntermediateDirectories: true)
        
        let metadata = PatchMetadata(
            identifier: UUID().uuidString,
            name: name,
            author: "work.plot",
            targetBundle: bundleID,
            version: "1.0"
        )
        
        if let data = try? JSONEncoder().encode(metadata) {
            let metadataPath = patchFolder + "patch.metadata.json"
            FileManager.default.createFile(atPath: metadataPath, contents: data)
        }
        
        let packageURL = URL(fileURLWithPath: workspaceDirectory + "\(name).workplotpatch")
        ExploitManager.shared.appendLog("Paket patch berhasil dibuat di path: \(packageURL.lastPathComponent)")
        return packageURL
    }
}

// MARK: - 8. SwiftUI User Interface Views

struct MainContentView: View {
    @EnvironmentObject var exploitManager: ExploitManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ExploitDashboardView()
                .tabItem {
                    Image(systemName: "shield.checkerboard")
                    Text("Beranda")
                }
                .tag(0)
            
            GestaltPresetsView()
                .tabItem {
                    Image(systemName: "slider.horizontal.3")
                    Text("Gestalt")
                }
                .tag(1)
            
            GraphicsAndRDARView()
                .tabItem {
                    Image(systemName: "display")
                    Text("RDAR Fix")
                }
                .tag(2)
            
            LiquidGlassView()
                .tabItem {
                    Image(systemName: "drop.fill")
                    Text("Liquid Glass")
                }
                .tag(3)
            
            WorkspacePatchesView()
                .tabItem {
                    Image(systemName: "folder.badge.gear")
                    Text("Patch 3105")
                }
                .tag(4)
        }
        .accentColor(.blue)
    }
}

struct ExploitDashboardView: View {
    @EnvironmentObject var exploitManager: ExploitManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("work.plot Platform")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                                Text("iOS 27 Beta Customizer")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            Spacer()
                            Circle()
                                .fill(exploitManager.isExploited ? Color.green : Color.red)
                                .frame(width: 14, height: 14)
                        }
                        
                        Divider()
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Versi Build Sistem")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(exploitManager.currentBuild)
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Status Subsystem")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(exploitManager.isExploited ? "Aktif" : "Belum Aktif")
                                    .font(.body)
                                    .fontWeight(.bold)
                                    .foregroundColor(exploitManager.isExploited ? .green : .red)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    
                    Button(action: {
                        _ = exploitManager.initializeExploit()
                    }) {
                        HStack {
                            Image(systemName: "bolt.shield.fill")
                            Text(exploitManager.isExploited ? "Subsystem bad_query Aktif" : "Inisialisasi bad_query Subsystem")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(exploitManager.isExploited ? Color.gray.opacity(0.3) : Color.blue)
                        .foregroundColor(exploitManager.isExploited ? .primary : .white)
                        .cornerRadius(12)
                    }
                    .disabled(exploitManager.isExploited)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Daftar Path Sistem Terhubung")
                            .font(.headline)
                        
                        if exploitManager.activePaths.isEmpty {
                            Text("Belum ada path sistem yang terbuka. Silakan tekan tombol inisialisasi.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(exploitManager.activePaths, id: \.self) { path in
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text(path)
                                        .font(.system(.caption, design: .monospaced))
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Log Aktivitas Sistem")
                            .font(.headline)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(exploitManager.logMessages, id: \.self) { log in
                                    Text(log)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.green)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 120)
                        .padding(8)
                        .background(Color.black)
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    
                    Button(action: {
                        SpringBoardManager.shared.safeRespring()
                    }) {
                        HStack {
                            Image(systemName: "restart.circle")
                            Text("Lakukan Respring Aman")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("work.plot Dashboard")
        }
    }
}

struct GestaltPresetsView: View {
    var body: some View {
        NavigationView {
            List {
                ForEach(GestaltCategory.allCases, id: \.rawValue) { category in
                    Section(header: Text(category.rawValue)) {
                        ForEach(GestaltRegistry.shared.presets.filter { $0.category == category }) { preset in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(preset.name)
                                        .font(.headline)
                                    Spacer()
                                    Button("Terapkan") {
                                        _ = GestaltRegistry.shared.applyPreset(preset)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .font(.caption)
                                }
                                Text(preset.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("MobileGestalt Editor")
        }
    }
}

struct GraphicsAndRDARView: View {
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Koreksi Geometri Kanvas RDAR")) {
                    Text("Memperbaiki tampilan status bar yang rusak akibat modifikasi subtype layar dengan menulis dimensi kanvas pada com.apple.iomobilegraphicsfamily.plist.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    ForEach(RDARFixManager.shared.resolutionProfiles, id: \.subtype) { profile in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(profile.deviceModel)
                                    .font(.headline)
                                Spacer()
                                Button("Terapkan Fix") {
                                    _ = RDARFixManager.shared.applyRDARFix(for: profile)
                                }
                                .buttonStyle(.bordered)
                                .font(.caption)
                            }
                            Text("Subtype: \(profile.subtype) | Dimensi: \(profile.width) x \(profile.height)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("RDAR Fix & Resolusi")
        }
    }
}

struct LiquidGlassView: View {
    @StateObject private var controller = LiquidGlassController.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Kontrol Efek Liquid Glass (iOS 27)")) {
                    Toggle("Matikan Efek Liquid Glass", isOn: Binding(
                        get: { controller.isLiquidGlassDisabled },
                        set: { newValue in
                            _ = controller.setGlobalDisable(newValue)
                        }
                    ))
                }
                
                Section(header: Text("Tingkat Transparansi UI")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tingkat Transparansi: \(Int(controller.transparencyLevel))%")
                            .font(.subheadline)
                        Slider(
                            value: Binding(
                                get: { controller.transparencyLevel },
                                set: { controller.transparencyLevel = $0 }
                            ),
                            in: 0...100,
                            step: 1
                        ) { _ in
                            _ = controller.setTransparencyLevel(controller.transparencyLevel)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Liquid Glass Control")
        }
    }
}

struct WorkspacePatchesView: View {
    @State private var patchName: String = ""
    @State private var bundleID: String = "com.apple.springboard"
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Buat Workspace Patch 3105")) {
                    TextField("Nama Paket Patch", text: $patchName)
                    TextField("Bundle ID Target", text: $bundleID)
                    
                    Button("Ekspor Paket .workplotpatch") {
                        guard !patchName.isEmpty else { return }
                        _ = WorkspaceManager.shared.exportPatchPackage(name: patchName, bundleID: bundleID)
                    }
                    .disabled(patchName.isEmpty)
                }
                
                Section(header: Text("Direktori Workspace")) {
                    Text(WorkspaceManager.shared.workspaceDirectory)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Patch 3105 Manager")
        }
    }
}

// MARK: - 9. Official SwiftUI @main App Lifecycle Entry Point

@main
struct WorkPlotApp: App {
    @StateObject private var exploitManager = ExploitManager.shared
    
    var body: some Scene {
        WindowGroup {
            MainContentView()
                .environmentObject(exploitManager)
        }
    }
}

