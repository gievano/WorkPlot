import Foundation
import UIKit

// MARK: - Platform gating

/// Restricts a tweak to a specific device idiom. Tweaks that don't match
/// the running device's `UIUserInterfaceIdiom` are hidden from the catalog
/// entirely (see `GestaltStore`).
enum TweakPlatform: Equatable {
    case all
    case iOSOnly
    case iPadOSOnly

    func matches(_ idiom: UIUserInterfaceIdiom) -> Bool {
        switch self {
        case .all: return true
        case .iOSOnly: return idiom == .phone
        case .iPadOSOnly: return idiom == .pad
        }
    }
}

// MARK: - Categories

enum TweakCategory: String, CaseIterable, Identifiable {
    case display = "Display"
    case device = "Device"
    case system = "System"
    case liquidGlass = "Liquid Glass"
    case ipad = "iPad"
    case ai = "Intelligence"

    var id: String { rawValue }
}

// MARK: - Values

/// A plist value that can be written into CacheExtra.
enum MGValue: Equatable {
    case int(Int)
    case string(String)
    case intArray([Int])
    /// Delete the key (or subkey) from CacheExtra.
    case remove
    /// Leave whatever value is already in the plist untouched.
    case keepCurrent

    var plistObject: Any {
        switch self {
        case .int(let v): return v
        case .string(let v): return v
        case .intArray(let v): return v
        case .remove, .keepCurrent: return NSNull()
        }
    }
}

// MARK: - Modifications

struct GestaltModification: Equatable {
    let key: String
    /// When set, `value` is written into `key[subkey]` instead of `key`.
    let subkey: String?
    let value: MGValue
    /// Marks the modification driven by a `.picker` detail so only that
    /// value is swapped for the selected option.
    var isPicker: Bool = false
    /// When set, `value` is written into the `CacheData` blob at the offset
    var cacheDataKey: String? = nil
    /// Value written into CacheData when the owning tweak is disabled.
    var cacheDataDisabledValue: Int? = nil
}

// MARK: - Detail (inline editors)

enum TweakDetail: Equatable {
    case picker(options: [String])
    case textField(placeholder: String, keyboard: TextFieldKind)
}

enum TextFieldKind: Equatable {
    case plain
    case numeric
}

// MARK: - Tweak

struct Tweak: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let category: TweakCategory
    let symbol: String
    let isRisky: Bool
    /// Optional per-tweak notes shown under the row when risky.
    let notes: String?

    var isEnabled: Bool = false
    var detail: TweakDetail?
    var selectedIndex: Int = 0
    var textValue: String = ""
    /// For `.picker` details: the values that map 1:1 to `options`.
    /// Use `.remove` / `.keepCurrent` for "Default"/"Original" options.
    var pickerValues: [MGValue] = []

    /// Special flag for iPadOS: requires the CacheData binary patch.
    var requiresCacheDataPatch: Bool = false

    /// Restricts which device idiom this tweak is offered on. Defaults to
    /// `.all` (both iPhone and iPad).
    var platform: TweakPlatform = .all

    let modifications: [GestaltModification]
}
