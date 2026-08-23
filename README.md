<p align="center">
  <img src="docs/assets/logo.png" alt="WorkPlot" width="180">
</p>

<h1 align="center">WorkPlot</h1>

<p align="center"><strong>Modify MobileGestalt on verified iOS/iPadOS 27 betas via bad_query with a CMG fallback. No jailbreak.</strong></p>

<p align="center">
  <a href="#-features"><img alt="Platform" src="https://img.shields.io/badge/platform-iOS%2027%20betas%201%E2%80%934-black?logo=apple&logoColor=white"></a>
  <a href="#-features"><img alt="Language" src="https://img.shields.io/badge/language-Swift-orange?logo=swift&logoColor=white"></a>
  <a href="#%EF%B8%8F-warning"><img alt="Status" src="https://img.shields.io/badge/status-experimental-red"></a>
  <a href="https://github.com/forcequitOS/bad_query"><img alt="bad_query" src="https://img.shields.io/badge/exploit-bad__query-purple"></a>
</p>

---

WorkPlot is a SwiftUI app built on the `bad_query` sandbox escape from [forcequitOS](https://github.com/forcequitOS/bad_query). It writes to MobileGestalt and system plists on the verified iOS/iPadOS builds below, so you can change your device identity, enable Apple Intelligence, and unlock hidden features through a regular app UI. The app backs up MobileGestalt before each write.

## Languages

English · Bahasa Indonesia · 中文 · 日本語 · Русский · Tiếng Việt

Switch them in-app under the gear icon. The whole UI follows your choice.

## Features

| Feature                  | What it does                                                                                                                                       |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Status Dashboard**     | Grant the `bad_query` sandbox escape, watch exploit status, trigger a respring                                                                     |
| **Gestalt Presets**      | Dynamic Island on unsupported devices, custom Model Name, one-tap presets                                                                          |
| **Field Editor**         | Edit MobileGestalt keys by hand and inspect CacheData as hex                                                                                       |
| **Siri AI Suite**        | Enable the new Siri AI and Apple Intelligence through the CacheData patch (Toto method), with optional spoofing to iPhone 15/16/17 Pro and Pro Max |
| **Liquid Glass**         | Turn on Apple's Liquid Glass UI effect                                                                                                             |
| **PosterBoard Lab**      | Import `.tendies` wallpapers into PosterBoard, browse the online Nugget-Wallpapers catalog, and track/remove everything you installed                |
| **Backup & Restore**     | Automatic backup before each write, JSON snapshots you can export or import, plus the RDARFix repair tool                                          |
| **File Patch Workspace** | Browse and patch system files through the sandbox escape, inspect app containers, clean per-app caches, view files as hex or SQLite tables          |
| **Patch Packages**       | Bundle replacement rules (bundle ID + path) into a folder package with password protection and verified rollback                                   |
| **Customization**        | Six languages, light/dark/system appearance, alternate app icons, in-app update checker                                                            |

## Installation

WorkPlot ships as a sideloaded IPA. It will not appear on the App Store.

1. Download the unsigned IPA from a green **Build unsigned IPA** CI run (Actions tab, latest run, Artifacts section), or build it yourself:
   ```bash
   xcodebuild -project WorkPlot/WorkPlot.xcodeproj -scheme WorkPlot archive
   ```
2. Sign and install it while preserving `com.apple.mobile.MobileHouseArrest`; enterprise-signing tools such as eSign are supported.
3. Trust your developer certificate under Settings → General → VPN & Device Management.

### Requirements

|               |                                                 |
| ------------- | ----------------------------------------------- |
| Devices       | iPhone and iPad                                 |
| Supported     | Verified iOS/iPadOS 27 developer/public betas 1–4 (dual-method: bad_query + CMG) |
| Not supported | Other beta builds; signing that rewrites the bundle identifier |

## Quick Start

1. Open WorkPlot, go to the **Status** tab, and grant the sandbox escape.
2. Open **Backups** and create your first snapshot before touching anything.
3. Apply a tweak. You will see a "Restart Recommended" alert; respring whenever it suits you.
4. If something misbehaves, restore the snapshot from **Backups**, then report the bug.

### Enabling Siri AI and Apple Intelligence

1. In the **Siri AI** tab, toggle **Enable New Siri AI (CacheData)**.
2. Pick a device spoof target if Apple Intelligence rejects your hardware.
3. Tap **Apply Changes**, then confirm the respring in the "Restart Required" popup.
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
| Tweaks fail to apply                 | Re-grant the sandbox escape on the Status tab                              |
| Access reports an identity mismatch   | Re-sign without changing `com.apple.mobile.MobileHouseArrest`; avoid tools that rewrite it |
| Strange behavior after Gestalt edits | Restore your latest snapshot in Backups                                    |
| RDAR bug after edits                 | Run the built-in RDARFix repair tool                                       |
| Respring loop                        | The failsafe overlay recovers the app; after a reboot, restore your backup |

## Credits

- WorkPlot: [gievano](https://github.com/gievano), [Adnan120Hz](https://github.com/adnan120hz)
- Contributions and testing: [Adnan120Hz](https://github.com/adnan120hz), [gievano](https://github.com/gievano)
- Sandbox escape: [forcequitOS/bad_query](https://github.com/forcequitOS/bad_query)
- Inspiration and reference implementations: Placard and GestaltEdit

This project incorporates GPLv3-licensed `bad_query` source code.
