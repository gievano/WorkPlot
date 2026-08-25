import Foundation
import UIKit

/// All tweaks in this app rely exclusively on the MobileGestalt cache —
/// the same keys Nugget writes. Keys are written under `CacheExtra`.
///
/// Individual tweaks live in `Models/Tweaks/*.swift`, one file per
/// `TweakCategory`. This just aggregates and applies platform gating.
enum TweakCatalog {

    /// Every defined tweak, unfiltered.
    static let all: [Tweak] =
        DisplayTweaks.all +
        DeviceTweaks.all +
        SystemTweaks.all +
        LiquidGlassTweaks.all +
        IPadTweaks.all +
        IntelligenceTweaks.all

    /// Tweaks whose `platform` gate matches the running device's idiom.
    /// This is what `GestaltStore` loads — a tweak gated to `.iOSOnly`
    /// simply doesn't exist for an iPad user, and vice versa.
    static func available(for idiom: UIUserInterfaceIdiom = UIDevice.current.userInterfaceIdiom) -> [Tweak] {
        all.filter { $0.platform.matches(idiom) }
    }
}
