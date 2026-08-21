import SwiftUI
import PhotosUI

/// Persists the user-chosen background image (Documents/background.jpg) and
/// exposes it to the root view for the app-wide backdrop layer.
final class AppBackgroundStore: ObservableObject {
    static let shared = AppBackgroundStore()

    @Published var image: UIImage?

    private static let fileName = "background.jpg"

    private init() { load() }

    func setImage(_ newImage: UIImage?) {
        image = newImage
        let url = Self.fileURL()
        guard let newImage, let data = newImage.jpegData(compressionQuality: 0.85) else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        try? data.write(to: url, options: .atomic)
    }

    private func load() {
        let url = Self.fileURL()
        guard let data = try? Data(contentsOf: url) else { return }
        image = UIImage(data: data)
    }

    private static func fileURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }
}

struct AppBackground: View {
    @ObservedObject private var store = AppBackgroundStore.shared

    var body: some View {
        ZStack {
            if let image = store.image {
                GeometryReader { geo in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .opacity(0.35)
                }
                .ignoresSafeArea()
            }
        }
    }
}

/// Sheet hosting the photo picker plus a reset option.
struct BackgroundPickerSheet: View {
    @ObservedObject private var store = AppBackgroundStore.shared
    @State private var selectedItem: PhotosPickerItem?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label(L10n.shared.tr("bg.pick"), systemImage: "photo.on.rectangle")
                    }
                    if store.image != nil {
                        Button(role: .destructive) {
                            store.setImage(nil)
                        } label: {
                            Label(L10n.shared.tr("bg.reset"), systemImage: "trash")
                        }
                    }
                }
                if let image = store.image {
                    Section(header: Text("Preview")) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .clipped()
                            .cornerRadius(8)
                    }
                }
            }
            .navigationTitle("Background")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
            .onChange(of: selectedItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        await MainActor.run { store.setImage(uiImage) }
                    }
                }
            }
        }
    }
}
