# Changelog

All notable changes to WorkPlot. Newest first.

## 2026-08-26

### Changed
- 🛠️ Every screen is now English only, and status/error messages render properly instead of placeholder strings like "Common Failprefix".
- 📱 Device Spoof: tapping the card expands the wheel picker inline, matching the subtype tweak configuration style.
- 🧾 Credits trimmed: dropped the 3105 entry after its feature was removed; FilzaSlop is now credited as class-13 research only.

### Removed
- 🔥 File Patch Workspace, App Containers, per-app cache cleaner, `.3105` patch importer, and hex/SQLite viewers - the underlying file-access path never worked reliably on device (#72).

## 2026-08-25

### Changed
- 🎨 Accent color now drives the app tint across views; display grid gap fixed by merging tool tiles into tweak rows.
- 🖥️ Device Spoof picker restyled as an inline wheel, consistent with subtype tweaks.
- 📖 README restyled: centered header with logo and badges, simplified install steps via iLoader, compatibility table.

## 2026-08-24

### Fixed
- 🐛 UI freezes when applying RDAR / Custom Canvas / Disable Liquid Glass (heavy work moved off the main thread).
- 🔒 Missing sandbox lease caused EPERM failures on Dynamic Island and Liquid Glass writes.
- 🔄 Respring now shows the overlay immediately and arms the crash after apply completes.
