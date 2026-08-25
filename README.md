<p align="center">
  <img src="docs/assets/logo.png" alt="WorkPlot" width="180">
</p>

<h1 align="center">WorkPlot</h1>

<p align="center"><strong>A MobileGestalt and system-file editor for verified iOS 27 betas, built on the bad_query sandbox escape. No jailbreak.</strong></p>

<p align="center">
  <a href="#-requirements"><img alt="Platform" src="https://img.shields.io/badge/platform-iOS%2027%20betas%201%E2%80%934-black?logo=apple&logoColor=white"></a>
  <a href="#-requirements"><img alt="Language" src="https://img.shields.io/badge/language-Swift-orange?logo=swift&logoColor=white"></a>
  <a href="#%EF%B8%8F-warning"><img alt="Status" src="https://img.shields.io/badge/status-experimental-red"></a>
  <a href="https://github.com/forcequitOS/bad_query"><img alt="bad_query" src="https://img.shields.io/badge/exploit-bad__query-purple"></a>
</p>

---

WorkPlot is a SwiftUI app that uses the `bad_query` sandbox escape from [forcequitOS](https://github.com/forcequitOS/bad_query) to write MobileGestalt values and edit system files. It is a rebrand and continuation of **Ketamine**, carrying the same tweak catalog while adding its own tools and interface options. It backs up MobileGestalt before every write, so a bad tweak can be undone. The interface follows the language you pick under Settings.

## Requirements

|               |                                                 |
| ------------- | ----------------------------------------------- |
| Devices       | iPhone and iPad                                 |
| Full features | iOS 27 (the full feature set is gated to 27)    |
| Writes        | Verified against iOS 27 developer betas 1 to 4  |
| Not supported | Other beta builds; signing that rewrites the bundle identifier |

Reads work on any iOS 27 build. Writes depend on the `bad_query` exploit, which is verified against iOS 27 developer betas 1 through 4. On a build the exploit is not verified against, the sandbox escape can fail with a kernel refusal and writes will not land. The app shows the failure instead of pretending the write worked.

## Build variants

There are two interface builds in this repo:

- **WP Old UI** is the original interface. On this build PosterBoard does not run.
- **WP New UI** is the newer interface where PosterBoard runs.

Pick the build that matches what you need. The tools and tweak catalog are the same between them.

## Differences from Ketamine

WorkPlot keeps Ketamine's tweak catalog and exploit core, then adds a few things on top:

- Light, dark, and system appearance modes (Ketamine ships one look).
- Extra tools in the same catalog: App Containers, FilePatch 3105, Device Spoof, Gestalt Field Editor, Preset Lab, Session Log, Check for Updates, CarPlay Wallpaper, and the RDAR canvas fix.
- Alternate app icons and a per-install badge so WorkPlot and Ketamine can sit side by side without confusion.
- An in-app Supported iOS note and a clearer write verification (`verified on disk` vs `write not visible on disk`).

## Features

| Feature                  | What it does                                                                                                                                       |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Gestalt tweaks**       | Toggle capabilities by category (Display, System, Device, Liquid Glass, iPad): Dynamic Island on unsupported devices, Disable Dynamic Island, Model Name, EU/iPad features, and more. Applied as one MobileGestalt write |
| **RDAR canvas fix**      | Write your panel's native size into MobileGestalt to fix the RDAR wallpaper bug, or set any width and height by hand                              |
| **Gestalt Field Editor** | Edit MobileGestalt keys directly and inspect CacheData as hex                                                                                      |
| **Preset Lab**           | Build and save MobileGestalt presets you can re-apply later                                                                                        |
| **Siri AI suite**        | Enable the new Siri AI and Apple Intelligence through the CacheData patch, with optional spoofing to iPhone 15/16/17 Pro and Pro Max                |
| **Liquid Glass**         | Turn on Apple's Liquid Glass UI effect                                                                                                             |
| **Backup and restore**   | Automatic backup before each write, JSON snapshots you can export or import, plus the RDARFix repair tool                                           |
| **File Patch Workspace** | Browse and edit system files through the HouseArrest sandbox escape, record reachable paths to an ACCESS MAP.txt in Documents, import `.3105` patch files, inspect app containers, clean per-app caches, view files as hex or SQLite tables |
| **App Containers**       | Inspect and manage app container data                                                                                                              |
| **Device Spoof**         | Spoof device identity (model and region)                                                                                                           |
| **CarPlay Wallpaper**    | Set the CarPlay wallpaper                                                                                                                          |
| **Session Log**          | View the exploit session debug logs                                                                                                               |
| **Check for Updates**    | In-app update checker                                                                                                                              |
| **Respring**             | Restart SpringBoard without a full reboot                                                                                                          |
| **Customization**        | Six languages, light/dark/system appearance, alternate app icons                                                                                   |

## Installation

WorkPlot ships as a sideloaded IPA. It will not appear on the App Store.

1. Download the unsigned IPA from a green **Build unsigned IPA** CI run (Actions tab, latest run, Artifacts section), or build it yourself:
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

The status area has two controls for the RDAR wallpaper bug. **Fix rdar** writes your panel's native size into MobileGestalt (`MainScreenCanvasSizes`). **Custom Canvas** lets you type any width and height, for example 828 x 1792 on an iPhone 11. After applying, WorkPlot reads the plist back from disk and reports `verified on disk` or `write not visible on disk - blocked by system`, so a silently dropped write does not look like success. Canvas values are read at boot, and WorkPlot cannot reboot a sandboxed device, so heavy tweaks show a restart prompt.

### Siri AI and Apple Intelligence

1. In the Siri AI screen, toggle **Enable New Siri AI (CacheData)**.
2. Pick a device spoof target if Apple Intelligence rejects your hardware.
3. Apply changes, then confirm the respring.
4. Spoofing can break Face ID until you revert it, so keep a snapshot handy.

## Warning

- This app modifies system state through a sandbox escape. Use it at your own risk.
- Device spoofing can break Face ID, FaceTime, OTA updates, and other Apple services.
- Keep a fresh backup before you experiment.
- Apple can close the `bad_query` vector in a future beta, so check the version table above before updating iOS.
- This project has no affiliation with Apple Inc.

## Troubleshooting

| Symptom                              | Fix                                                                        |
| ------------------------------------ | -------------------------------------------------------------------------- |
| Tweaks fail to apply                 | Re-grant the sandbox escape from the status area                            |
| Access reports an identity mismatch   | Re-sign without changing `com.apple.mobile.MobileHouseArrest`; avoid tools that rewrite it |
| Strange behavior after Gestalt edits | Restore your latest snapshot                                               |
| RDAR bug after edits                 | Run RDARFix or Custom Canvas. `verified on disk` means the write landed; if iOS still ignores the value, the fix cannot help on that build |
| File picker grays out my file        | Importers accept any file; ensure the shared file has the expected extension (`.tendies`, `.3105`, or a video) and that the source app allows exporting it |
| Respring does nothing                | The WebKit respring trick may be patched on your beta. The overlay recovers after ten seconds and reports the failure; restart the device manually |

## Credits

- WorkPlot is a rebrand and continuation of **Ketamine**. Respect to the Ketamine authors for the original app this is ported from.
- WorkPlot: [gievano](https://github.com/gievano), [Adnan120Hz](https://github.com/adnan120hz)

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
