import SwiftUI
import Foundation

nonisolated private struct SystemApp: Identifiable, Sendable {
    let name: String
    let bundleID: String

    var id: String { bundleID }
}

private enum SystemAppLauncher {
    nonisolated static func open(bundleID: String) -> Bool {
        GTLaunchApplication(bundleID)
    }

    nonisolated static func discoverAppleApps() -> [SystemApp]? {
        guard let workspaceClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
              let workspace = workspaceClass.perform(NSSelectorFromString("defaultWorkspace"))?.takeUnretainedValue() as? NSObject else {
            return nil
        }
        let selector = NSSelectorFromString("allApplications")
        let bundleSelector = NSSelectorFromString("bundleIdentifier")
        let nameSelector = NSSelectorFromString("localizedName")
        guard workspace.responds(to: selector),
              let applications = workspace.perform(selector)?.takeUnretainedValue() as? [NSObject] else {
            return nil
        }

                let discovered = applications.compactMap { application in
            guard let identifier = application.perform(bundleSelector)?.takeUnretainedValue() as? String,
                  identifier.hasPrefix("com.apple.") else {
                return nil
            }
            let shortName = String(identifier.dropFirst("com.apple.".count))
            let fallbackName = shortName.isEmpty ? identifier : shortName
            let localizedName = application.perform(nameSelector)?.takeUnretainedValue() as? String
            let displayName = localizedName.flatMap { $0.isEmpty ? nil : $0 } ?? fallbackName
            return SystemApp(name: displayName, bundleID: identifier)
        }
        .sorted { (left: SystemApp, right: SystemApp) in
            left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
        }
        return discovered.isEmpty ? nil : discovered
    }
}

struct SystemAppsView: View {
    @State private var apps: [SystemApp] = []
    @State private var isLoading = true
    @State private var query = ""
    @State private var customBundleID = ""
    @State private var errorMessage: String?

    private var filteredApps: [SystemApp] {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return apps }
        return apps.filter {
            $0.name.localizedCaseInsensitiveContains(value) ||
            $0.bundleID.localizedCaseInsensitiveContains(value)
        }
    }

    var body: some View {
        List {
            Section("HouseArrest System Apps") {
                if isLoading {
                    ProgressView("Finding apps...")
                } else if apps.isEmpty {
                    Text("No com.apple apps were found.")
                        .foregroundStyle(.secondary)
                } else if filteredApps.isEmpty {
                    ContentUnavailableView.search
                } else {
                    ForEach(filteredApps) { app in
                        Button { open(app.bundleID) } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(app.name)
                                        .font(.body.weight(.medium))
                                    Text(app.bundleID)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            } icon: {
                                Image(systemName: "app.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }

            Section {
                TextField("com.apple.example", text: $customBundleID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Open App", systemImage: "arrow.up.forward.app") {
                    open(customBundleID)
                }
                .disabled(customBundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } header: {
                Text("Custom Bundle ID")
            } footer: {
                Text("Hidden or protected apps may refuse to open. Use the app's bundle identifier.")
            }
        }
        .navigationTitle("System Apps")
        .navigationBarTitleDisplayMode(.large)
        .listStyle(.insetGrouped)
        .searchable(text: $query, prompt: "Search apps or bundle IDs")
        .task { loadApps() }
        .refreshable { loadApps() }
        .alert("Could Not Open App", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func open(_ bundleID: String) {
        let identifier = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty, !SystemAppLauncher.open(bundleID: identifier) else {
            if identifier.isEmpty { errorMessage = "Enter a bundle identifier first." }
            else { errorMessage = "The system refused to open \(identifier)." }
            return
        }
    }

    private func loadApps() {
        isLoading = true
        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try Self.findSystemApps()
                }.value
                apps = result
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    private nonisolated static func findSystemApps() throws -> [SystemApp] {
        if let discovered = SystemAppLauncher.discoverAppleApps() {
            return discovered
        }
        return try HouseArrestService.list(HouseArrestService.applicationsRoot)
            .filter { $0.isDirectory && $0.name.hasPrefix("com.apple.") }
            .map {
                let bundleID = $0.name
                let shortName = String(bundleID.dropFirst("com.apple.".count))
                return SystemApp(name: shortName.isEmpty ? bundleID : shortName, bundleID: bundleID)
            }
            .sorted { (left: SystemApp, right: SystemApp) in
                left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
            }
    }
}
