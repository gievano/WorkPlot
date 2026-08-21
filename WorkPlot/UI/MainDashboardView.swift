import SwiftUI

struct MainDashboardView: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system.rawValue

    init() {
        let appearance = UITabBarAppearance()
        let item = UITabBarItemAppearance()
        let font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        item.normal.titleTextAttributes = [.font: font]
        item.selected.titleTextAttributes = [.font: font]
        appearance.stackedLayoutAppearance = item
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        ZStack {
            AppBackground()
            TabView {
                StatusDashboardView().tabItem { tabLabel(l10n.tr("tab.home"), "house.fill") }
                GestaltPresetManagerView().tabItem { tabLabel(l10n.tr("tab.gestalt"), "cpu") }
                GestaltFieldEditorView().tabItem { tabLabel(l10n.tr("tab.fields"), "list.bullet.rectangle") }
                SiriAITweaksView().tabItem { tabLabel(l10n.tr("tab.siriai"), "waveform") }
                MoreMenuView().tabItem { tabLabel(l10n.tr("tab.more"), "ellipsis.circle.fill") }
            }
        }
        .preferredColorScheme(AppearanceMode(rawValue: appearanceMode)?.colorScheme)
    }

    private func tabLabel(_ title: String, _ systemImage: String) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(uiImage: Self.bigSymbol(systemImage))
        }
    }

    static func bigSymbol(_ name: String, size: CGFloat = 26) -> UIImage {
        let config = UIImage.SymbolConfiguration(pointSize: size, weight: .semibold)
        return UIImage(systemName: name, withConfiguration: config) ?? UIImage()
    }
}
