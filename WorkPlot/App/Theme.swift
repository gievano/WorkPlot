import SwiftUI

enum AppAccent: String, CaseIterable, Identifiable {
    case blue
    case indigo
    case teal
    case orange
    case pink

    var id: String { rawValue }

    var name: String {
        switch self {
        case .blue: return "Blue"
        case .indigo: return "Indigo"
        case .teal: return "Teal"
        case .orange: return "Orange"
        case .pink: return "Pink"
        }
    }

    var color: Color {
        switch self {
        case .blue: return .blue
        case .indigo: return .indigo
        case .teal: return .teal
        case .orange: return .orange
        case .pink: return .pink
        }
    }

    static var current: AppAccent {
        AppAccent(rawValue: UserDefaults.standard.string(forKey: "accentColor") ?? "blue") ?? .blue
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

    static let pagePadding: CGFloat = 20
    static let cardRadius: CGFloat = 24
}

extension View {
    @ViewBuilder
    func liquidGlass(cornerRadius: CGFloat = Theme.cardRadius) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, *) {
            glassEffect(Glass.regular, in: shape)
        } else {
            background(.thinMaterial, in: shape)
        }
    }

    @ViewBuilder
    func glassAction(prominent: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            if prominent {
                buttonStyle(.glassProminent)
            } else {
                buttonStyle(.glass)
            }
        } else if prominent {
            buttonStyle(.borderedProminent)
        } else {
            buttonStyle(.bordered)
        }
    }
}

struct GlassGroup<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}
