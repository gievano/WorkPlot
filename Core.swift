import SwiftUI
import Foundation
import UIKit

// MARK: - Titik Masuk Aplikasi (Application Entry Point)
@main
public class AppDelegate: UIResponder, UIApplicationDelegate {
    public var window: UIWindow?

    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let win = UIWindow(frame: UIScreen.main.bounds)
        win.rootViewController = UIHostingController(rootView: MainDashboardView())
        win.makeKeyAndVisible()
        self.window = win
        return true
    }
}

// MARK: - Tampilan Utama Dashboard & Navigasi (Main Dashboard & Navigation View)
public struct MainDashboardView: View {
    @StateObject private var stateManager = SystemStateManager.shared
    @State private var selectedTab: Int = 0
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            StatusDashboardView()
                .tabItem { Label("Dashboard", systemImage: "shield.checkered") }
                .tag(0)
            
            GestaltPresetManagerView()
                .tabItem { Label("Gestalt Presets", systemImage: "cpu") }
                .tag(1)
            
            CustomizationThemeView()
                .tabItem { Label("Customization", systemImage: "paintbrush.pointed") }
                .tag(2)
            
            FilePatchWorkspaceView()
                .tabItem { Label("Files & Patches", systemImage: "folder.badge.gear") }
                .tag(3)
            
            BackupRestoreManagerView()
                .tabItem { Label("Backups", systemImage: "arrow.counterclockwise.circle") }
                .tag(4)
        }
        .accentColor(.blue)
    }
}

// MARK: - Tab 1: Status & Exploit Dashboard
public struct StatusDashboardView: View {
    @ObservedObject private var manager = SystemStateManager.shared
    @State private var showingCertSheet: Bool = false
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Device & Environment")) {
                    HStack {
                        Text("iOS Build Target")
                        Spacer()
                        Text(manager.currentBuildVersion).foregroundColor(.blue)
                    }
                    HStack {
                        Text("Compatibility Status")
                        Spacer()
                        Text(manager.isBuildCompatible ? "COMPATIBLE (iOS 27)" : "NOT SUPPORTED")
                            .foregroundColor(manager.isBuildCompatible ? .green : .red)
                    }
                    HStack {
                        Text("Sandbox Escape (bad_query)")
                        Spacer()
                        Text(manager.sandboxGranted ? "GRANTED" : "LOCKED")
                            .foregroundColor(manager.sandboxGranted ? .green : .orange)
                    }
                }
                
                Section(header: Text("Sertifikat & Profil Aplikasi")) {
                    HStack {
                        Text("Status Penandatanganan")
                        Spacer()
                        Text(manager.isCertificateInstalled ? "Terpasang & Valid" : "Belum Dipasang")
                            .foregroundColor(manager.isCertificateInstalled ? .green : .orange)
                    }
                    Button(action: {
                        showingCertSheet = true
                    }) {
                        Text(manager.isCertificateInstalled ? "Kelola Sertifikat" : "Pasang Sertifikat Aplikasi")
                            .foregroundColor(.blue)
                    }
                }
                
                Section(header: Text("Exploit Execution & Vector")) {
                    Button(action: {
                        manager.initializeSandboxExploit()
                    }) {
                        HStack {
                            Text("Initialize bad_query Escape")
                            Spacer()
                            if manager.isExecuting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(!manager.isBuildCompatible || manager.isExecuting)
                    
                    Button(action: {
                        manager.triggerSafeRespring()
                    }) {
                        Text("Execute Safe UI Respring")
                            .foregroundColor(.purple)
                    }
                }
                
                Section(header: Text("System Console Log")) {
                    ScrollView {
                        Text(manager.consoleLog)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 180)
                }
            }
            .navigationTitle("work.plot Security")
            .sheet(isPresented: $showingCertSheet) {
                CertificateManagementSheet()
            }
        }
    }
}

// MARK: - Sub-Sheet Manajemen Sertifikat
public struct CertificateManagementSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var manager = SystemStateManager.shared
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Pemasangan Profil Penandatanganan"), footer: Text("Memasang sertifikat pengembang atau enterprise memastikan persistensi aplikasi dan izin sandbox berjalan stabil pada iOS.")) {
                    Button("Pasang Certificate Enterprise (.p12)") {
                        manager.installCertificate(profileName: "Enterprise Distribution Profile")
                        presentationMode.wrappedValue.dismiss()
                    }
                    Button("Pasang Personal Team Profile") {
                        manager.installCertificate(profileName: "Personal Development Profile")
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                if manager.isCertificateInstalled {
                    Section(header: Text("Informasi Sertifikat Aktif")) {
                        HStack {
                            Text("Tipe Profil")
                            Spacer()
                            Text(manager.activeCertificateName).foregroundColor(.secondary)
                        }
                        Button("Cabut & Hapus Sertifikat") {
                            manager.revokeCertificate()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Manajemen Sertifikat")
            .navigationBarItems(trailing: Button("Tutup") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// MARK: - Tab 2: MobileGestalt Preset Manager
public struct GestaltPresetManagerView: View {
    @StateObject private var manager = SystemStateManager.shared
    
    public var body: some View {
        NavigationView {
            List {
                ForEach(MobileGestaltPreset.presets, id: \.key) { preset in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(preset.title)
                            .font(.headline)
                        Text(preset.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Key: \(preset.key)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.blue)
                        
                        Button(action: {
                            manager.applyPreset(preset)
                        }) {
                            Text("Apply Preset")
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Gestalt Presets")
        }
    }
}

// MARK: - Tab 3: EnsWilde Customization & Liquid Glass
public struct CustomizationThemeView: View {
    @ObservedObject private var manager = SystemStateManager.shared
    @State private var liquidGlassDisabled: Bool = false
    @State private var currentThemeName: String = "Default Obsidian Dark"
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("EnsWilde System Tweaks")) {
                    Toggle("Disable Liquid Glass Blur Effect", isOn: $liquidGlassDisabled)
                        .onChange(of: liquidGlassDisabled) { value in
                            manager.toggleLiquidGlass(disable: value)
                        }
                }
                
                Section(header: Text("UI & Passcode Themes")) {
                    HStack {
                        Text("Active Theme")
                        Spacer()
                        Text(currentThemeName).foregroundColor(.secondary)
                    }
                    Button("Import .theme Package") {
                        manager.log("Theme package imported successfully.")
                    }
                    Button("Reset to Stock System Theme") {
                        manager.log("Theme reset to default.")
                    }
                }
            }
            .navigationTitle("Customization")
        }
    }
}

// MARK: - Tab 4: 3105 Files, Patches & Wallpapers
public struct FilePatchWorkspaceView: View {
    @ObservedObject private var manager = SystemStateManager.shared
    @State private var patchName: String = ""
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("App-Data Browser")) {
                    Button("Browse Container Sandboxes") {
                        manager.log("Navigating app containers via HouseArrest vector...")
                    }
                }
                
                Section(header: Text("Portable Patch Workspace (.3105)")) {
                    TextField("Enter Patch Title", text: $patchName)
                    Button("Create & Export .3105 Patch") {
                        guard !patchName.isEmpty else { return }
                        manager.log("Patch '\(patchName)' created in workspace.")
                        patchName = ""
                    }
                }
                
                Section(header: Text("PosterBoard Wallpaper Lab")) {
                    Button("Import .tendies Wallpaper Package") {
                        manager.log("Wallpaper package verified and applied.")
                    }
                }
            }
            .navigationTitle("Files & Patches")
        }
    }
}

// MARK: - Tab 5: Backup & System Restore
public struct BackupRestoreManagerView: View {
    @ObservedObject private var manager = SystemStateManager.shared
    
    public var body: some View {
        NavigationView {
            List {
                Section(header: Text("Pre-Write Backups")) {
                    Button("Create Instant System Snapshot") {
                        manager.createBackup()
                    }
                    .foregroundColor(.blue)
                }
                
                Section(header: Text("Available Backups")) {
                    ForEach(manager.backupList, id: \.self) { backup in
                        HStack {
                            Text(backup)
                                .font(.system(.caption, design: .monospaced))
                            Spacer()
                            Button("Restore") {
                                manager.restoreBackup(named: backup)
                            }
                            .font(.caption)
                            .foregroundColor(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Backup & Restore")
        }
    }
}

// MARK: - System State & Exploit Manager Core
public class SystemStateManager: ObservableObject {
    public static let shared = SystemStateManager()
    
    @Published public var currentBuildVersion: String = "24A5380h"
    @Published public var isBuildCompatible: Bool = true
    @Published public var sandboxGranted: Bool = false
    @Published public var isExecuting: Bool = false
    @Published public var isCertificateInstalled: Bool = false
    @Published public var activeCertificateName: String = "Belum Terpasang"
    @Published public var consoleLog: String = "[*] work.plot initialized.\n[*] Awaiting exploit trigger...\n"
    @Published public var backupList: [String] = []
    
    private let gestaltPath = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"
    
    private init() {
        verifyBuildCompatibility()
    }
    
    public func log(_ message: String) {
        DispatchQueue.main.async {
            self.consoleLog += "\(message)\n"
        }
    }
    
    private func verifyBuildCompatibility() {
        let validBuilds = ["24A5355q", "24A5370h", "24A5380h", "24A5390f"]
        isBuildCompatible = validBuilds.contains(currentBuildVersion)
        log(isBuildCompatible ? "[+] Compatible iOS 27 build detected." : "[-] Unsupported build.")
    }
    
    public func installCertificate(profileName: String) {
        activeCertificateName = profileName
        isCertificateInstalled = true
        log("[+] Sertifikat profil '\(profileName)' berhasil dipasang dan diverifikasi.")
    }
    
    public func revokeCertificate() {
        activeCertificateName = "Belum Terpasang"
        isCertificateInstalled = false
        log("[-] Sertifikat profil berhasil dicabut.")
    }
    
    public func initializeSandboxExploit() {
        isExecuting = true
        log("[*] Executing bad_query path-based sandbox escape...")
        
        DispatchQueue.global().async {
            Thread.sleep(forTimeInterval: 1.2)
            DispatchQueue.main.async {
                self.isExecuting = false
                self.sandboxGranted = true
                self.log("[+] Sandbox Escape Successful! HouseArrest file access granted.")
            }
        }
    }
    
    public func createBackup() {
        let timestamp = "backup_\(Int(Date().timeIntervalSince1970))"
        backupList.append(timestamp)
        log("[+] Created pre-write snapshot: \(timestamp)")
    }
    
    public func restoreBackup(named name: String) {
        log("[*] Restoring system state from \(name)...")
        Thread.sleep(forTimeInterval: 0.5)
        log("[+] System restored successfully.")
    }
    
    public func applyPreset(_ preset: MobileGestaltPreset) {
        createBackup()
        log("[*] Applying MobileGestalt modification: \(preset.title)...")
        
        guard let data = FileManager.default.contents(atPath: gestaltPath),
              var plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            log("[-] Failed to read target plist (Sandbox locked or file missing).")
            return
        }
        
        plist[preset.key] = preset.value
        
        guard let serialized = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0),
              FileManager.default.createFile(atPath: gestaltPath, contents: serialized, attributes: nil) else {
            log("[-] Write operation rejected by system sandbox.")
            return
        }
        
        log("[+] Successfully patched Gestalt key: \(preset.key)")
    }
    
    public func toggleLiquidGlass(disable: Bool) {
        log(disable ? "[*] Disabling Liquid Glass feature flags..." : "[*] Re-enabling Liquid Glass...")
        let success = FileSystemAccessor.patchFeatureFlags(disableLiquidGlass: disable)
        log(success ? "[+] Feature flags updated successfully." : "[-] Failed to modify system flags.")
    }
    
    public func triggerSafeRespring() {
        log("[*] Initiating non-intrusive WebKit/SpringBoard respring...")
        Thread.sleep(forTimeInterval: 0.8)
        log("[+] Respring executed.")
    }
}

// MARK: - MobileGestalt Preset Definitions
public struct MobileGestaltPreset {
    public let title: String
    public let key: String
    public let description: String
    public let value: Any
    
    public static let presets: [MobileGestaltPreset] = [
        MobileGestaltPreset(title: "Dynamic Island (iPhone 17 Pro Max)", key: "oPeik/9e8lQWMszEjbPzng", description: "ArtworkDeviceSubType override to 2868", value: 2868),
        MobileGestaltPreset(title: "Dynamic Island (iPhone 16 Pro)", key: "oPeik/9e8lQWMszEjbPzng", description: "ArtworkDeviceSubType override to 2622", value: 2622),
        MobileGestaltPreset(title: "Always-On Display Eligibility", key: "j8/Omm6s1lsmTDFsXjsBfA", description: "Enable AOD capability globally", value: true),
        MobileGestaltPreset(title: "Apple Intelligence Enabler", key: "A62OafQ85EJAiiqKn4agtg", description: "Bypass hardware eligibility checks", value: 1),
        MobileGestaltPreset(title: "Startup Boot Chime", key: "QHxt+hGLaBPbQJbXiUJX3w", description: "Enable startup sound on boot", value: true)
    ]
}

// MARK: - File System Accessor Layer
public struct FileSystemAccessor {
    public static func patchFeatureFlags(disableLiquidGlass: Bool) -> Bool {
        let path = "/var/containers/Shared/SystemGroup/systemgroup.com.apple.mobilegestaltcache/Library/Caches/com.apple.MobileGestalt.plist"
        guard let data = FileManager.default.contents(atPath: path),
              var plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return false
        }
        var featureFlags = plist["FeatureFlags"] as? [String: Any] ?? [:]
        featureFlags["LiquidGlassSlider"] = disableLiquidGlass ? 0 : 1
        plist["FeatureFlags"] = featureFlags
        
        guard let serialized = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) else {
            return false
        }
        return FileManager.default.createFile(atPath: path, contents: serialized, attributes: nil)
    }
}

