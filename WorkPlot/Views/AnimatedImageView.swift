//
//  AnimatedImageView.swift
//  WorkPlot
//
//  Lightweight GIF/PNG remote preview: decodes ImageIO frame sequences into a
//  UIImage animation so wallpaper previews play inline without a third-party
//  image library.
//

import SwiftUI
import ImageIO

enum AnimatedImageDecoder {
    static func decode(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return UIImage(data: data)
        }
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 1 else { return UIImage(data: data) }

        var frames: [UIImage] = []
        var duration: Double = 0
        for index in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(UIImage(cgImage: cgImage))
            duration += frameDelay(source: source, index: index)
        }
        guard !frames.isEmpty else { return nil }
        return UIImage.animatedImage(with: frames, duration: duration > 0 ? duration : Double(frames.count) * 0.1)
    }

    private static func frameDelay(source: CGImageSource, index: Int) -> Double {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
              let gifProperties = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any] else {
            return 0.1
        }
        let delay = (gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
            ?? (gifProperties[kCGImagePropertyGIFDelayTime] as? Double)
            ?? 0.1
        return delay < 0.02 ? 0.1 : delay
    }
}

private final class ImagePreviewCache {
    static let shared = ImagePreviewCache()
    private let cache = NSCache<NSURL, UIImage>()
    func image(for url: URL) -> UIImage? { cache.object(forKey: url as NSURL) }
    func store(_ image: UIImage, for url: URL) { cache.setObject(image, forKey: url as NSURL) }
}

private struct AnimatedImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        guard uiView.image !== image else { return }
        uiView.image = image
        if image.images != nil {
            uiView.startAnimating()
        } else {
            uiView.stopAnimating()
        }
    }

    /// Without this, SwiftUI sizes the representable to the UIImageView's
    /// intrinsic content size — the raw image's pixel dimensions at scale
    /// 1.0 — which is far larger than the card it's meant to fill, so the
    /// preview overflows its box instead of being cropped to it. Taking
    /// whatever size is proposed lets scaleAspectFill + clipsToBounds do
    /// the cropping inside the card's actual bounds instead.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIImageView, context: Context) -> CGSize? {
        proposal.replacingUnspecifiedDimensions()
    }
}

/// Fetches and renders a remote image, animating it inline when it decodes
/// to multiple frames (GIF), while showing static images (PNG/JPG) as-is.
struct RemoteAnimatedImage: View {
    let url: URL?

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            Color(uiColor: .tertiarySystemFill)
            if let image {
                AnimatedImageView(image: image)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if failed {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        image = nil
        failed = false
        guard let url else { failed = true; return }
        if let cached = ImagePreviewCache.shared.image(for: url) {
            image = cached
            return
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let decoded = AnimatedImageDecoder.decode(data) else {
                failed = true
                return
            }
            ImagePreviewCache.shared.store(decoded, for: url)
            image = decoded
        } catch is CancellationError {
            // View disappeared before the fetch finished; nothing to show.
        } catch {
            failed = true
        }
    }
}
