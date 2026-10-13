<div align="center">

<img src="docs/assets/logo.png" alt="WorkPlot app icon" width="128" height="128">

# WorkPlot

**On-device MobileGestalt editor for iOS 27 — no PC required**

<p>
  <a href="https://github.com/forcequitOS/bad_query"><img src="https://img.shields.io/badge/exploit-bad__query-purple?style=flat-square" alt="bad_query"></a>
  <img src="https://img.shields.io/badge/platform-iOS%2027%20betas%201%E2%80%934-black?style=flat-square&logo=apple&logoColor=white" alt="Platform">
  <img src="https://img.shields.io/badge/language-Swift-orange?style=flat-square&logo=swift&logoColor=white" alt="Language">
  <img src="https://img.shields.io/badge/status-experimental-red?style=flat-square" alt="Status">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPLv3-6E56CF?style=flat-square" alt="GPLv3"></a>
</p>

<a href="https://github.com/gievano/WorkPlot/releases/latest"><b>Download IPA</b></a> ·
<a href="#requirements">Requirements</a> ·
<a href="#install">Install</a> ·
<a href="#credits">Credits</a>

</div>

> [!WARNING]
> WorkPlot modifies system state through a sandbox escape. It can break system features and may require restoring the device. Keep a backup before you experiment. Use at your own risk.

WorkPlot edits MobileGestalt values and system files on iOS 27 betas without a jailbreak. It builds on the `bad_query` sandbox escape and ships a full MobileGestalt tweak catalog plus its own tools. Every write is backed up first, so a bad tweak can be undone.

## What's new

WorkPlot keeps the original catalog and exploit core, and adds:

- Light, dark, and system appearance modes.
- Extra tools in the same catalog: Device Spoof, Gestalt Field Editor, Preset Lab, Session Log, and Check for Updates.
- Alternate app icons and a per-install badge so two installs can run side by side.
- Write verification: the app reads the plist back and reports "verified on disk" or "write not visible on disk" instead of pretending the write worked.

## Features

- 📱 Runs entirely on iPhone and iPad — no PC required
- 🛠️ **Gestalt tweaks** — toggle capabilities by category (Display, System, Device, Liquid Glass, iPad), cover Dynamic Island on unsupported devices, Model Name, EU and iPad features, all as one MobileGestalt write
- 🖼️ **PosterBoard** — Tendies wallpaper collections
- 🔎 **Gestalt Field Editor** — edit MobileGestalt keys directly and inspect CacheData as hex
- 🧪 **Preset Lab** — build and save MobileGestalt presets to re-apply later
- 🧠 **Siri AI suite** — enable the new Siri AI and Apple Intelligence through the CacheData patch, with optional spoofing to iPhone 15/16/17 Pro and Pro Max
- 💎 **Liquid Glass** — turn on Apple's Liquid Glass UI effect
- 🛡️ **Backup and restore** — automatic backup before each write, JSON snapshots you can export or import
- 🕵️ **Device Spoof** — spoof device identity (model and region)
- 📜 **Session Log** — view the exploit session debug logs
- 🔄 **Check for Updates** — in-app update checker
- 🔁 **Respring** — restart SpringBoard without a full reboot
- 🎨 **Customization** — light/dark/system appearance, and alternate app icons

## Requirements

WorkPlot runs on iPhone and iPad. Reads work on any iOS 27 build. Writes depend on the `bad_query` exploit, which is verified against iOS 27 developer betas 1 through 4. On a build the exploit is not verified against, the sandbox escape can fail with a kernel refusal and writes will not land. The app shows the failure instead of pretending the write worked.

There are two interface builds in this repo. **WP Old UI** is the original interface where PosterBoard does not run. **WP New UI** is the newer interface where PosterBoard runs. The tools and tweak catalog are the same between them.

## Compatibility

| iOS Version              | MobileGestalt Editing | PosterBoard    |
| ------------------------ | --------------------- | -------------- |
| iOS 18.x and earlier     | ❌ Unsupported        | ❌ Unsupported |
| iOS 26.0 – 26.6          | ❌ Unsupported        | ✅ Supported   |
| iOS 27.0 Beta 1 – Beta 4 | ✅ Supported          | ✅ Supported   |
| Later versions           | ❌ Patched            | ❌ Unsupported |

## Install

1. Download `WorkPlot.ipa` from [Releases](https://github.com/gievano/WorkPlot/releases/latest).
2. Install [iLoader](https://github.com/nab138/iloader), connect your device, and sign in with your Apple ID (used only for local signing).
3. Import the IPA to sign and install it, then trust the certificate under Settings → General → VPN & Device Management.

## Quick start

1. Open WorkPlot and grant the sandbox escape from the status area.
2. Open Backups and make a snapshot before changing anything.
3. Toggle a tweak or open a tool, then apply. The app prompts for a respring when one is needed.
4. If something breaks, restore the snapshot and report the issue.

### Siri AI and Apple Intelligence

1. In the Siri AI screen, toggle **Enable New Siri AI (CacheData)**.
2. Pick a device spoof target if Apple Intelligence rejects your hardware.
3. Apply changes, then confirm the respring.
4. Spoofing can break Face ID until you revert it, so keep a snapshot handy.

## Troubleshooting

| Symptom                              | Fix                                                                                                                                                |
| ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| Tweaks fail to apply                 | Re-grant the sandbox escape from the status area                                                                                                   |
| Strange behavior after Gestalt edits | Restore your latest snapshot                                                                                                                       |
| Strange behavior after Gestalt edits | Restore your latest snapshot
| Respring does nothing                | The WebKit respring trick may be patched on your beta. The overlay recovers after ten seconds and reports the failure; restart the device manually |

## Credits

WorkPlot is a rebrand and continuation of an earlier MobileGestalt editor.

**Base app**

- **Ketamine by Nouvborne** — the original MobileGestalt editor and tweak catalog this app is ported from. [Repo](https://github.com/Nouvborne/Ketamine) · [GitHub](https://github.com/Nouvborne)

**Exploit and techniques**

- `bad_query` sandbox escape: [forcequitOS/bad_query](https://github.com/forcequitOS/bad_query) (GPLv3, incorporated)
- `bad_query` class-13 MobileGestalt route: parameters cross-checked against the MobileHouseArrest-PoC notes (mond / 0xjohnnydev); demonstrated end-to-end by [0xjohnnydev/FilzaSlop](https://github.com/0xjohnnydev/FilzaSlop)
- Respring method: [rooootdev/neospring](https://github.com/rooootdev/neospring); WebKit variant by @neonmodder123, Swift port by @skadz108
- MobileGestalt tweak semantics: [leminlimez/Nugget](https://github.com/leminlimez/Nugget) and [GestaltEdit](https://github.com/leminlimez/GestaltEdit)

**Reference apps**

- [frs0n/placard](https://github.com/frs0n/placard)

**Individuals:** Mond, Ketamine, Toto.
**Beta Tester**
@LsNguyen
@arya
Full attribution and licenses: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). WorkPlot incorporates GPLv3-licensed `bad_query` source code.

## License

WorkPlot is distributed under the [GPLv3 license](LICENSE).

## Disclaimer

This project has no affiliation with Apple Inc. It modifies system state and may break your device. Use it at your own risk.
