//
//  Localization.swift
//  WorkPlot
//
//  English UI copy and appearance preference.
//

import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var labelKey: String {
        switch self {
        case .system: "appearance.system"
        case .light: "appearance.light"
        case .dark: "appearance.dark"
        }
    }
}

final class L10n: ObservableObject {
    static let shared = L10n()

    private static let englishBundle: Bundle = {
        guard let path = Bundle.main.path(forResource: "en", ofType: "lproj") else {
            return .main
        }
        return Bundle(path: path) ?? .main
    }()

    private init() {}

    func tr(_ key: String) -> String {
        Self.englishBundle.localizedString(forKey: key, value: key, table: nil)
    }

    var failPrefix: String {
        String(format: tr("common.failPrefix"), "")
    }
}
