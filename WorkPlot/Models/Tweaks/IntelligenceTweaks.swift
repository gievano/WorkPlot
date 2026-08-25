import Foundation

/// Intelligence category tweaks.
///
/// Apple Intelligence eligibility is handled by `GestaltStore.applyAIRegion()`
/// (see `SiriAISetupView`) rather than the generic tweak/modification list —
/// it needs to branch on the device's current identity at apply time, which
/// the declarative `Tweak` model doesn't support. This category is
/// intentionally empty.
enum IntelligenceTweaks {
    static let all: [Tweak] = []
}
