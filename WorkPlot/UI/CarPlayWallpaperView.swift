import SwiftUI

struct CarPlayWallpaperView: View {
    @State private var supported = false
    @State private var cacheVersion = ""
    @State private var names: [String] = []
    @State private var status: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeader("Status")
                VStack(alignment: .leading, spacing: 8) {
                    Text(supported ? "CarPlay didukung" : "CarPlay tidak didukung")
                        .foregroundStyle(supported ? Theme.affirmative : Theme.caution)
                    if !cacheVersion.isEmpty {
                        Text("Cache version: \(cacheVersion)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                SectionHeader("Wallpaper tersedia")
                VStack(alignment: .leading, spacing: 8) {
                    if names.isEmpty {
                        Text("Belum ada wallpaper CarPlay tersimpan")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(names, id: \.self) { name in
                            Text(name).font(.footnote)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Color(uiColor: .tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                ActionButton(title: "Muat ulang", systemImage: "arrow.clockwise") { reload() }

                if let status {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(Theme.pagePadding)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("CarPlay Wallpaper")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reload() }
    }

    func reload() {
        supported = CarPlayManager.supportsCarPlay()
        cacheVersion = CarPlayManager.getCarPlayCacheVersion()
        names = CarPlayManager.getCarPlayWallpaperNames() ?? []
    }
}
