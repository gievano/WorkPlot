import SwiftUI

// WorkPlot visual language — mirrors Ketamine's clean glass system but with
// its own accent palette and names. Real glassEffect on iOS 26+, material
// fallback below (kept so older SDKs/Xcode still build).
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
    static var accent: Color { AppAccent.current.color }

    static let caution = Color(.systemOrange)
    static let destructive = Color(.systemRed)
    static let affirmative = Color(.systemGreen)

    static let pagePadding: CGFloat = 20
    static let cardRadius: CGFloat = 24
}

extension View {
    /// Glass surface for cards, sheets and controls. GlassEffect on iOS 26+,
    /// thin material below.
    @ViewBuilder
    func liquidGlass(cornerRadius: CGFloat = Theme.cardRadius) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.thinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    /// Floats a glass surface behind its children with standard page padding.
    @ViewBuilder
    func glassGroup() -> some View {
        self.padding(Theme.pagePadding).liquidGlass()
    }

    /// WorkPlot accent button styling.
    @ViewBuilder
    func glassAction(forceProminent: Bool = false) -> some View {
        if forceProminent {
            self.buttonStyle(.borderedProminent)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    /// Floating glass card wrapper for List/Form/Group screens: hides the
    /// default scroll background, insets, and applies liquidGlass.
    func wpGlassContainer() -> some View {
        self
            .scrollContentBackground(.hidden)
            .padding(Theme.pagePadding)
            .liquidGlass(cornerRadius: Theme.cardRadius)
    }
}

/// Glass container that mirrors Ketamine's GlassGroup but uses the WorkPlot
/// fallback-aware liquidGlass so it builds everywhere.
struct GlassGroup<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(Theme.pagePadding)
            .liquidGlass()
    }
}
