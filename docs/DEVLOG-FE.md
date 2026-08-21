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

## 2026-08-21 — BadQuery Exploit Port

### The Change

- Ported `BadQueryBridge.h/.m` and `GestaltAccess.h/.m` from GestaltEdit (GPLv3) into `WorkPlot/Exploit/`.
- Added `WorkPlot-Bridging-Header.h` and wired it via `SWIFT_OBJC_BRIDGING_HEADER` in both Debug and Release configurations.
- Rewired `ExploitManager.swift` from naive `FileManager.isWritableFile` to proper `GestaltAccess.connectWithError()` with OS build whitelist check.
- Rewired `LiquidGlassController.swift` to read/write through ExploitManager (bad_query) instead of direct FileManager.
- Rewired `RDARFix.swift` to use `BadQueryLease` directly for its non-Gestalt path.
- Updated `StatusDashboardView.swift` to display actual OS build from `sysctl` instead of hardcoded string.
- Added `.gitignore` for temp clone and Xcode user data.

### The Reasoning

- Without bad_query, the app cannot escape the iOS sandbox. FileManager calls to system paths always fail on stock iOS.
- GestaltEdit's implementation is battle-tested: path traversal via ContainerManager private API, sandbox extension token acquisition, atomic write with rollback, post-write verification.
- OS build whitelist prevents accidental writes on unsupported builds that could brick the device.

### The Tech Debt

- Build not verified locally (Windows); requires macOS CI with iOS 27 SDK.
- Gestalt, Customization, Files, Backups tabs remain placeholder views.
- No backup system yet — writes are destructive without restore capability.

## 2026-08-21 — Backup System

### The Change

- Added `GestaltBackupStore.swift` — creates timestamped plist backups in Documents/MobileGestalt Backups, lists/deletes them.
- Wired `ExploitManager.saveGestalt()` to auto-backup the current plist before every write.
- Added `restore()` and `delete()` to ExploitManager for backup management.
- Rebuilt `BackupRestoreManagerView` from placeholder to functional list: shows name/date/size, tap to restore, swipe to delete, EditButton.

### The Reasoning

- Every MobileGestalt write is potentially destructive. Auto-backup before write is the minimum safety net.
- Restore also auto-backups the current state first, so you can always undo a restore.

### The Tech Debt

- No import/export yet (share sheet / file picker).
- No confirmation dialog before restore.

## 2026-08-21 — Preset Catalog & Gestalt UI

### The Change

- Added `GestaltTweaks.swift` — 17 tweak definitions across 4 categories (Display, Hardware, iPad, Internal), ported from GestaltEdit/Nugget.
- Rebuilt `GestaltPresetManagerView` from placeholder to functional: category sections, toggles with detail text, RISKY badge, mutual exclusion for Liquid Glass ON/OFF, Apply button with count.
- Added `respring()` to ExploitManager (killall SpringBoard) and Respring button in Status tab.
- Registered both files in project.pbxproj.

### The Reasoning

- Presets cover the most common MobileGestalt tweaks without requiring users to know CacheExtra key names.
- Mutual exclusion prevents conflicting Liquid Glass values.
- RISKY badge warns users about potentially destabilizing tweaks (AOD burn-in, internal features).

### The Tech Debt

- Dynamic Island subtype picker, model name editor, AI region spoofing, and iPadOS CacheData binary patch not yet implemented.
- Field editor (search & edit any key by hand) not yet implemented.

## 2026-08-21 - CI Target Alignment

### The Change

- Restored the iOS deployment target to `27.0` in both project configurations.
- Aligned `Info.plist` with the target bundle identifier `com.workplot.app`.
- Pinned the workflow to Xcode 26.6 and verified the iPhoneOS SDK is `27.0`.
- Enabled the iOS build workflow for pull requests targeting `main`.

### The Reasoning

- The project had drifted to iOS 26.5 while the app requires iOS 27 beta APIs.
- Selecting the newest runner Xcode was nondeterministic and could select an SDK without iOS 27 support.

### The Tech Debt

- GitHub-hosted runner availability for Xcode 26.6 must be confirmed; the workflow now reports this directly instead of falling through to compiler errors.

## 2026-08-21 - Fix GitHub Actions Xcode Selection Error

### The Change

- Removed invalid step `Select Xcode 26.6 (iOS 27 SDK)` from `.github/workflows/main.yml`.

### The Reasoning

- Xcode 26.6 / iOS SDK 27.0 path does not exist on GitHub-hosted `macos-latest` runners, causing job execution failure at step 2.
- Using default Xcode bundled in `macos-latest` allows `xcodebuild` to execute properly.

### The Tech Debt

- None.


## 2026-08-21 - Align CI Workflow with GestaltEdit Pattern

### The Change

- Updated `.github/workflows/main.yml` to use `xcodebuild archive` with `-destination "generic/platform=iOS"` into `$RUNNER_TEMP`.
- Extracted `.app` from `.xcarchive/Products/Applications/` into `Payload/` and zipped it to `$RUNNER_TEMP/WorkPlot.ipa`.

### The Reasoning

- Follows the exact build and packaging workflow pattern used in `frs0n/GestaltEdit`.

### The Tech Debt

- None.

