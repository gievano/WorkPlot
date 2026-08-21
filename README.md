<p align="center">
  <img src="docs/assets/logo.png" alt="WorkPlot" width="180" border-radius="20%">
</p>

<h1 align="center">WorkPlot</h1>

<p align="center">
  <strong>Modify MobileGestalt on iOS 27 Developer Beta 1–4 — no jailbreak required.</strong>
</p>

<p align="center">
  <a href="#-features"><img alt="Platform" src="https://img.shields.io/badge/platform-iOS%2027%20beta%201%E2%80%934-black?logo=apple&logoColor=white"></a>
  <a href="#-features"><img alt="Language" src="https://img.shields.io/badge/language-Swift-orange?logo=swift&logoColor=white"></a>
  <a href="#️-warning"><img alt="Status" src="https://img.shields.io/badge/status-experimental-red"></a>
  <a href="https://github.com/forcequitOS/bad_query"><img alt="bad_query" src="https://img.shields.io/badge/exploit-bad__query-purple"></a>
</p>

---

WorkPlot is a SwiftUI app that uses the **`bad_query`** sandbox escape ([forcequitOS/bad_query](https://github.com/forcequitOS/bad_query)) to write directly to **MobileGestalt** and system plists on iOS 27.0 developer betas — unlocking hidden features, spoofing your device model, enabling Apple Intelligence, and more, all from a friendly UI with automatic backups.

## 🌐 Languages

English · Bahasa Indonesia · 中文 · 日本語 · Русский · Tiếng Việt

Switch in-app: **gear icon → Language**. The entire UI follows instantly.

## ✨ Features

| Feature | What it does |
|---|---|
| 🛡️ **Status Dashboard** | Grant the `bad_query` sandbox escape, monitor exploit status, manual respring |
| 🧬 **Gestalt Presets** | Dynamic Island for any device, custom Model Name, and more — presets applied with one tap |
| 🔬 **Field Editor** | Edit *any* MobileGestalt key manually, inspect CacheData as hex |
| 🤖 **Siri AI Suite** | Enable the new Siri AI + Apple Intelligence via CacheData patch (Toto method), optional device spoofing to iPhone 15/16/17 Pro & Pro Max |
| 💧 **Liquid Glass** | Turn on Apple's new Liquid Glass UI effect |
| 🖼️ **PosterBoard Lab** | Import `.tendies` wallpapers straight into PosterBoard |
| 💾 **Backup & Restore** | Automatic inode-preserving backup before every write; export/import JSON snapshots; RDARFix repair tool |
| 📁 **File Patch Workspace** | Browse and patch system files via the sandbox escape |
| ⚙️ **Customization** | 6 languages, light/dark/system appearance, custom background image, alternate app icons |

## 📲 Installation

> WorkPlot is sideload-only. It will never be on the App Store.

1. Grab the unsigned IPA from a green **Build unsigned IPA** CI run (Actions → latest run → Artifacts), or build it yourself:
   ```bash
   xcodebuild -project WorkPlot/WorkPlot.xcodeproj -scheme WorkPlot archive
   ```
2. Sideload with your favorite tool: **AltStore**, **Sideloadly**, or **TrollStore**.
3. Trust the developer certificate in **Settings → General → VPN & Device Management**.

### Requirements

| | |
|---|---|
| Device | iPhone / iPad |
| iOS | 27.0 Developer Beta **1–4** or Public Beta 1–2 |
| Not supported | iOS ≤ 26.x, Dev Beta ≥ 5, Public Beta ≥ 3 |

## 🚀 Quick Start

1. Open WorkPlot → **Status** tab → tap to grant the sandbox escape (`bad_query`).
2. Go to **Backups** and create your first backup. *Always.*
3. Apply any tweak you like. After applying, you'll get a **"Restart Recommended"** alert — respring when convenient.
4. Enjoy. If anything looks wrong, restore from **Backups** first, ask questions later.

### Enabling Siri AI / Apple Intelligence

1. **Siri AI** tab → toggle **Enable New Siri AI (CacheData)**.
2. *(Optional)* pick a device spoof target — needed if Apple Intelligence checks your hardware.
3. Tap **Apply Changes** → a **"Restart Required"** popup appears → respring.
4. ⚠️ Spoofing may break Face ID until reverted.

## ⚠️ Warning

- This app **modifies system state** using a sandbox escape. You use it **entirely at your own risk**.
- Device spoofing can break Face ID, FaceTime, OTA updates, or other Apple services.
- Always keep a fresh backup before experimenting.
- Apple can close the `bad_query` vector in any future beta — pinned to beta ranges above.
- Not affiliated with or endorsed by Apple Inc.

## 🛠 Troubleshooting

| Symptom | Fix |
|---|---|
| App won't apply tweaks | Re-grant the sandbox escape from the Status tab |
| Weird behavior after Gestalt edits | Restore your latest snapshot in **Backups** |
| Stuck RDAR bug after edits | Run the built-in **RDARFix** repair tool |
| Boot loop | Respring failsafe overlay handles it; worst case restore backup after reboot |

## 🙏 Credits

- [gievano](https://github.com/gievano) — WorkPlot
- [Adnan120Hz](https://github.com/adnan120hz) — contributions & testing
- [forcequitOS/bad_query](https://github.com/forcequitOS/bad_query) — sandbox escape
- [Placard](https://github.com/Placard-App) & [GestaltEdit](https://github.com/) — inspiration & reference implementations

This project incorporates GPLv3-licensed `bad_query` source code.
