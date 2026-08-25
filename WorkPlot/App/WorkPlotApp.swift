import SwiftUI
import UIKit

@main
struct WorkPlotApp: App {
    @StateObject private var store = GestaltStore()

    init() {
        PosterBoardView.swizzleOnce
    }
    @AppStorage("accentColor") private var accentColor = AppAccent.blue.rawValue
    @AppStorage("customColor") private var customColor: Double = 0
    @AppStorage("useCustomColor") private var useCustomColor = false
    @AppStorage("appearanceScheme") private var appearanceScheme = 0

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(appearanceScheme == 1 ? .light : appearanceScheme == 2 ? .dark : nil)
                .tint(useCustomColor
                      ? Color(hue: customColor, saturation: 0.75, brightness: 0.9)
                      : (AppAccent(rawValue: accentColor)?.color ?? .blue))
        }
    }
}
