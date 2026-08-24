import SwiftUI

// WorkPlot visual language — refined glass. Real glassEffect on iOS 26+,
// material fallback below. Glass is reserved for focal surfaces (cards,
// buttons, sheets); scroll areas get a calm tinted backdrop + hairline
// border so content keeps contrast and hierarchy.
enum AppAccent: String, CaseIterable, Identifiable {
    case blue, mint, orange, pink, purple

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blue: "Blue"
        case .mint: "Mint"
        case .orange: "Orange"
        case .pink: "Pink"
        case .purple: "Purple"
        }
    }

    var color: Color {
        switch self {
        case .blue: .blue
        case .mint: .mint
        case .orange: .orange
        case .pink: .pink
        case .purple: .purple
        }
    }

    static var current: AppAccent {
        AppAccent(rawValue: UserDefaults.standard.string(forKey: "appAccent") ?? "orange") ?? .orange
    }
}

enum Theme {
    static var accent: Color {
        if UserDefaults.standard.bool(forKey: "useCustomColor") {
            let hue = UserDefaults.standard.double(forKey: "customColor")
            return Color(hue: hue, saturation: 0.75, brightness: 0.9)
        }
        return AppAccent.current.color
    }

    static let caution = Color(.systemOrange)
    static let destructive = Color(.systemRed)
    static let affirmative = Color(.systemGreen)

    static let pagePadding: CGFloat = 16
    static let cardRadius: CGFloat = 22
    static let cardSpacing: CGFloat = 14
    static let hairline = Color.white.opacity(0.10)
}

extension View {
    /// Glass surface for focal cards, sheets and controls. GlassEffect on
    /// iOS 26+, thin material below. A hairline overlay keeps edge contrast.
    @ViewBuilder
    func liquidGlass(cornerRadius: CGFloat = Theme.cardRadius) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    /// Glass card: padding + glass + hairline border for crisp edges.
    func wpCard() -> some View {
        self
            .padding(Theme.pagePadding)
            .liquidGlass()
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
    }

    /// Scroll surface: calm tinted backdrop + hairline frame. The screen reads
    /// as glass without slab-ing every row; cards carry the real glass.
    func wpGlassContainer() -> some View {
        self
            .scrollContentBackground(.hidden)
            .padding(Theme.pagePadding)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [Color(.systemBackground), Theme.accent.opacity(0.06)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .ignoresSafeArea()
                    RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                        .stroke(Theme.hairline, lineWidth: 1)
                        .ignoresSafeArea()
                }
            )
    }

    /// WorkPlot accent button styling.
    @ViewBuilder
    func glassAction(forceProminent: Bool = false, tint: Color = Theme.accent) -> some View {
        if forceProminent {
            self.buttonStyle(.borderedProminent).tint(tint)
        } else {
            self.buttonStyle(.bordered).tint(tint)
        }
    }
}

/// Glass container used by a few inline call sites; thin wrapper over wpCard.
struct GlassGroup<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content.wpCard()
    }
}
