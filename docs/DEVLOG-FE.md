# DEVLOG — Frontend/iOS

## 2026-08-21

### The Change

- Restructured WorkPlot into an Xcode app target with SwiftUI entry point and five dashboard screens.
- Split system access, exploit state, Liquid Glass, and RDAR actions into dedicated managers.
- Added a shared IPA build workflow and a valid `project.pbxproj` plus shared scheme.

### The Reasoning

- The single prototype Swift file did not provide the Xcode target structure required by GitHub Actions.

### The Tech Debt

- The iOS 27 deployment target requires a CI runner image whose Xcode SDK supports that beta.
- System-path writes remain conceptual until the sandbox-access path is implemented on-device.

## 2026-08-21 — Debug Pass

### The Change

- Separated project-level and target-level Xcode configurations into distinct objects.
- Registered `AppIcon` through the target asset-catalog setting.
- Replaced the false-success exploit action with an honest system-path access check.
- Surfaced success/failure results from RDAR and Liquid Glass actions in dashboard status text.
- Added a universal 1024x1024 tweak-themed AppIcon using an abstract shield/WP mark instead of a chart motif.

### The Reasoning

- Sharing configuration objects between project and target scopes makes later Xcode edits ambiguous.
- UI previously froze during execution and always claimed success even when file operations were impossible.

### The Tech Debt

- `xcodebuild` could not run locally on Windows; macOS CI remains required for build/IPA verification.
- Gestalt, Customization, Files, and Backups screens remain placeholder views.

## 2026-08-21 — CI & Icon Fixes

### The Change

- Regenerated `AppIcon.png` as a full-square RGB image (liquid-glass droplet, indigo→violet) — the previous version was clipped to a rounded square with transparent corners, which iOS rejects.
- Added an Xcode-selection step to `.github/workflows/main.yml` that picks the newest installed `/Applications/Xcode*.app` and logs the iPhoneOS SDK version before building.

### The Reasoning

- App icons must be opaque full-bleed squares; actool composites alpha onto black and validation can fail.
- `macos-latest` runners ship an unpredictable default Xcode; without pinning, the iOS 27.0 deployment target may not resolve to a matching SDK and `xcodebuild` fails.

### The Tech Debt

- The wildcard "latest Xcode" pick is best-effort; if Apple renames beta images the sort may select a non-iOS-27 SDK — check the SDK log line if builds fail.
- IPA remains unsigned; sideloading still requires TrollStore or a re-sign step.
