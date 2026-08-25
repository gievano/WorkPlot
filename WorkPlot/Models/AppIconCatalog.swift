//
//  AppIconCatalog.swift
//  Ketamine
//
//  Alternate icons are data-driven so adding one never touches Swift: drop
//  its `<id>.appiconset` + `<id>Preview.imageset` into Assets.xcassets,
//  register `<id>` under Info.plist's CFBundleAlternateIcons, and add a row
//  to Resources/AppIcons.json. scripts/add_app_icon.py does all of that from
//  one source image.
//

import Foundation

struct AppIconOption: Identifiable, Hashable {
    /// Matches both the alternate icon name registered in Info.plist and the
    /// `.appiconset` name in Assets.xcassets.
    let id: String
    let title: String
    let creator: String
    /// True for icons that stay out of the picker until some in-app easter
    /// egg unlocks them (see `AppIconCatalog.unlock(_:)`). Absent in the JSON
    /// for ordinary icons, so decoding falls back to `false`.
    var hidden: Bool = false

    /// The `.imageset` used for the in-app picker thumbnail — `.appiconset`
    /// entries aren't addressable as a normal SwiftUI `Image`, so every
    /// alternate icon carries a same-named `<id>Preview.imageset` copy.
    var previewImageName: String { id + "Preview" }
}

extension AppIconOption: Codable {
    private enum CodingKeys: String, CodingKey { case id, title, creator, hidden }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        creator = try container.decode(String.self, forKey: .creator)
        hidden = try container.decodeIfPresent(Bool.self, forKey: .hidden) ?? false
    }
}

enum AppIconCatalog {
    /// The app's primary icon. Not part of the JSON manifest since it maps to
    /// `AppIcon.appiconset` / `Logo.imageset` directly rather than the
    /// `<id>` / `<id>Preview` convention scripted alternates follow, and
    /// `setAlternateIconName(nil)` — not its id — is what restores it.
    static let standard = AppIconOption(id: "AppIcon", title: "Standard", creator: "Nouvborne")

    static let alternates: [AppIconOption] = {
        guard let url = Bundle.main.url(forResource: "AppIcons", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let options = try? JSONDecoder().decode([AppIconOption].self, from: data) else {
            return []
        }
        return options
    }()

    static var all: [AppIconOption] { [standard] + alternates }

    /// Icons offered in the picker: everything not `hidden`, plus any
    /// `hidden` icon that's already been unlocked.
    static var visible: [AppIconOption] {
        all.filter { !$0.hidden || isUnlocked($0.id) }
    }

    static func option(forStoredID id: String) -> AppIconOption {
        all.first { $0.id == id } ?? standard
    }

    // MARK: - Unlocking hidden icons

    private static func unlockDefaultsKey(_ id: String) -> String { "iconUnlocked.\(id)" }

    static func isUnlocked(_ id: String) -> Bool {
        UserDefaults.standard.bool(forKey: unlockDefaultsKey(id))
    }

    /// Idempotent — safe to call every time an unlock gesture fires; callers
    /// that need to know whether this was the *first* unlock (e.g. to show a
    /// one-time toast) should check `isUnlocked(_:)` before calling this.
    static func unlock(_ id: String) {
        UserDefaults.standard.set(true, forKey: unlockDefaultsKey(id))
    }
}

extension AppIconOption {
    /// `nil` restores the primary icon; anything else is passed straight to
    /// `UIApplication.setAlternateIconName`.
    var alternateIconName: String? {
        self.id == AppIconCatalog.standard.id ? nil : id
    }
}
