import SwiftUI

struct CarPlayWallpaperView: View {
    @State private var supported = false
    @State private var cacheVersion = ""
    @State private var names: [String] = []
    @State private var status: String?

    var body: some View {
        Form {
            Section {
                Text(supported ? "CarPlay didukung" : "CarPlay tidak didukung")
                    .foregroundStyle(supported ? .green : .red)
                if !cacheVersion.isEmpty {
                    Text("Cache version: \(cacheVersion)")
                }
            } header: { Text("Status") }

            Section {
                if names.isEmpty {
                    Text("Belum ada wallpaper CarPlay tersimpan")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(names, id: \.self) { Text($0) }
                }
            } header: { Text("Wallpaper tersedia") }

            Section {
                Button("Muat ulang") { reload() }
            }
            if let status {
                Section { Text(status).font(.footnote) }
            }
        }
        .navigationTitle("CarPlay Wallpaper")
        .onAppear { reload() }
    }

    func reload() {
        supported = CarPlayManager.supportsCarPlay()
        cacheVersion = CarPlayManager.getCarPlayCacheVersion()
        names = CarPlayManager.getCarPlayWallpaperNames() ?? []
    }
}
