import SwiftUI

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
    @AppStorage("backgroundOpacity") private var backgroundOpacity = 0.35

    var body: some View {
        ZStack {
            if let image = store.image {
                GeometryReader { geo in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .opacity(backgroundOpacity)
                }
                .ignoresSafeArea()
            }
        }
    }
}

