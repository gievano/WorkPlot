# WorkPlot

On-Device MobileGestalt Editor for iOS

WorkPlot edits MobileGestalt values and system files on iOS 27 betas without a jailbreak. It builds on the bad_query sandbox escape and carries over Ketamine's tweak catalog while adding its own tools. Every write is backed up first, so a bad tweak can be undone.

> [!WARNING]
> This app modifies system state through a sandbox escape. Use it at your own risk. Keep a backup before you experiment.

## Screenshot

![WorkPlot](docs/assets/screenshot.png)

## What's new since Ketamine

WorkPlot keeps Ketamine's catalog and exploit core, then adds:

- Light, dark, and system appearance modes (Ketamine ships one look).
- Extra tools in the same catalog: App Containers, FilePatch 3105, Device Spoof, Gestalt Field Editor, Preset Lab, Session Log, Check for Updates, CarPlay Wallpaper, and the RDAR canvas fix.
- Alternate app icons and a per-install badge so WorkPlot and Ketamine can sit side by side.
- A clearer write check: the app reads the plist back and reports "verified on disk" or "write not visible on disk" instead of pretending the write worked.

## Features

- ✅ **Gestalt tweaks** — toggle capabilities by category (Display, System, Device, Liquid Glass, iPad): Dynamic Island on unsupported devices, Model Name, EU and iPad features, and more, applied as one MobileGestalt write.
- 🖼️ **RDAR canvas fix** — write your panel's native size into MobileGestalt to fix the RDAR wallpaper bug, or set any width and height by hand.
- 🔧 **Gestalt Field Editor** — edit MobileGestalt keys directly and inspect CacheData as hex.
- 🧪 **Preset Lab** — build and save MobileGestalt presets to re-apply later.
- 🧠 **Siri AI suite** — enable the new Siri AI and Apple Intelligence through the CacheData patch, with optional spoofing to iPhone 15/16/17 Pro and Pro Max.
- 💎 **Liquid Glass** — turn on Apple's Liquid Glass UI effect.
- 💾 **Backup and restore** — automatic backup before each write, JSON snapshots you can export or import, plus the RDARFix repair tool.
- 📁 **File Patch Workspace** — browse and edit system files through the HouseArrest sandbox escape, record reachable paths to an ACCESS MAP.txt in Documents, import .3105 patch files, inspect app containers, clean per-app caches, view files as hex or SQLite tables.
- 📦 **App Containers** — inspect and manage app container data.
- 🔀 **Device Spoof** — spoof device identity (model and region).
- 🚗 **CarPlay Wallpaper** — set the CarPlay wallpaper.
- 📜 **Session Log** — view the exploit session debug logs.
- 🔄 **Check for Updates** — in-app update checker.
- ♻️ **Respring** — restart SpringBoard without a full reboot.
- 🌐 **Customization** — six languages, light/dark/system appearance, alternate app icons.

## Requirements

WorkPlot runs on iPhone and iPad. Reads work on any iOS 27 build. Writes depend on the bad_query exploit, which is verified against iOS 27 developer betas 1 through 4. On a build the exploit is not verified against, the sandbox escape can fail with a kernel refusal and writes will not land. The app shows the failure instead of pretending the write worked.

| Build | Full features | Writes verified |
| ----- | ------------ | --------------- |
| iOS 27 developer betas 1 to 4 | Yes | Yes |
| Other iOS 27 builds | Reads only | No |
| Signing that rewrites the bundle identifier | No | No |

There are two interface builds in this repo. WP Old UI is the original interface where PosterBoard does not run. WP New UI is the newer interface where PosterBoard runs. The tools and tweak catalog are the same between them.

## Installation

WorkPlot ships as a sideloaded IPA. It will not appear on the App Store.

1. Download the unsigned IPA from a green "Build unsigned IPA" CI run (Actions tab, latest run, Artifacts section), or build it yourself:
   ```bash
   xcodebuild -project WorkPlot/WorkPlot.xcodeproj -scheme WorkPlot archive
   ```
2. Install through **TrollStore** (recommended; it keeps `com.apple.mobile.MobileHouseArrest` untouched). Enterprise tools such as eSign also work, but only if they preserve the original bundle identifier.
3. Trust your developer certificate under Settings, then General, then VPN and Device Management.

## Quick start

1. Open WorkPlot and grant the sandbox escape from the status area.
2. Open Backups and make a snapshot before changing anything.
3. Toggle a tweak or open a tool, then apply. The app prompts for a respring when one is needed.
4. If something breaks, restore the snapshot and report the issue.

### RDAR canvas fix

The status area has two controls for the RDAR wallpaper bug. **Fix rdar** writes your panel's native size into MobileGestalt (`MainScreenCanvasSizes`). **Custom Canvas** lets you type any width and height, for example 828 x 1792 on an iPhone 11. After applying, WorkPlot reads the plist back from disk and reports "verified on disk" or "write not visible on disk - blocked by system", so a silently dropped write does not look like success. Canvas values are read at boot, and WorkPlot cannot reboot a sandboxed device, so heavy tweaks show a restart prompt.

### Siri AI and Apple Intelligence

1. In the Siri AI screen, toggle **Enable New Siri AI (CacheData)**.
2. Pick a device spoof target if Apple Intelligence rejects your hardware.
3. Apply changes, then confirm the respring.
4. Spoofing can break Face ID until you revert it, so keep a snapshot handy.

## Troubleshooting

| Symptom | Fix |
| ------- | --- |
| Tweaks fail to apply | Re-grant the sandbox escape from the status area |
| Access reports an identity mismatch | Re-sign without changing `com.apple.mobile.MobileHouseArrest`; avoid tools that rewrite it |
| Strange behavior after Gestalt edits | Restore your latest snapshot |
| RDAR bug after edits | Run RDARFix or Custom Canvas. "verified on disk" means the write landed; if iOS still ignores the value, the fix cannot help on that build |
| File picker grays out my file | Importers accept any file; ensure the shared file has the expected extension (`.tendies`, `.3105`, or a video) and that the source app allows exporting it |
| Respring does nothing | The WebKit respring trick may be patched on your beta. The overlay recovers after ten seconds and reports the failure; restart the device manually |

## Credits

WorkPlot is a rebrand and continuation of **Ketamine**. Respect to the Ketamine authors for the original app this is ported from.

**Exploit and techniques**

- `bad_query` sandbox escape: [forcequitOS/bad_query](https://github.com/forcequitOS/bad_query) (GPLv3, incorporated)
- HouseArrest sandbox escape: demonstrated by [0xjohnnydev/FilzaSlop](https://github.com/0xjohnnydev/FilzaSlop); class-13 route groundwork in the MobileHouseArrest-PoC notes (mond / 0xjohnnydev)
- Respring method: [rooootdev/neospring](https://github.com/rooootdev/neospring); WebKit variant by @neonmodder123, Swift port by @skadz108
- MobileGestalt tweak semantics: [leminlimez/Nugget](https://github.com/leminlimez/Nugget) and [GestaltEdit](https://github.com/leminlimez/GestaltEdit)

**Reference apps**

- [YangJiiii/3105](https://github.com/YangJiiii/3105) (GPLv3, safe file operations adapted)
- [frs0n/placard](https://github.com/frs0n/placard)

**Individuals:** Mond, Ketamine, Toto.

Full attribution and licenses: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). WorkPlot incorporates GPLv3-licensed `bad_query` source code.

## Licence

WorkPlot is distributed under the GPLv3 licence. See [LICENSE](LICENSE) for the full text.

## Disclaimer

This project has no affiliation with Apple Inc. It modifies system state and may break your device. Use it at your own risk.
