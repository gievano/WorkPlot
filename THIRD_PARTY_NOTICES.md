# Third-Party Notices

## bad_query (forcequitOS) — GPLv3

WorkPlot incorporates GPLv3-licensed `bad_query` source code from
[forcequitOS/bad_query](https://github.com/forcequitOS/bad_query). WorkPlot is
distributed under GPL-3.0; see [`LICENSE`](LICENSE).

## FilzaSlop / HouseArrest sandbox escape (0xjohnnydev)

The app's system-file access implements the HouseArrest (com.apple.mobile.MobileHouseArrest)
sandbox escape technique. [0xjohnnydev/FilzaSlop](https://github.com/0xjohnnydev/FilzaSlop)
is the app that demonstrated this technique end-to-end, including its
container-class location labels ([MHA-C13] System Groups and similar).
Its repository had no project-level license at the reviewed commit, so no
FilzaSlop source code was copied; the behavior was reimplemented from public
documentation of the technique. The class-13 ContainerManager route parameters
were cross-checked against the MobileHouseArrest-PoC notes (mond / 0xjohnnydev).

## 3105 (YangJiii) — GPLv3

`WorkPlot/Managers/SafeFileOperations.swift` adapts the staging-copy,
keep-both naming, recursive-destination, and symbolic-link safety behavior from
[YangJiiii/3105](https://github.com/YangJiiii/3105), specifically
`ThreeOneOSFive/helpers/FileManagerService.swift`.

3105 distributes its original code under the GNU General Public License v3.0.
WorkPlot is also distributed under GPL-3.0; see [`LICENSE`](LICENSE).

## Respring method

The WebKit-crash respring follows [rooootdev/neospring](https://github.com/rooootdev/neospring);
WebKit variant by @neonmodder123, Swift port by @skadz108.

## References without copied code

Nugget and GestaltEdit ([leminlimez](https://github.com/leminlimez)) were
consulted for MobileGestalt key semantics; Placard ([frs0n](https://github.com/frs0n/placard))
as an app-design reference. No source code was copied from these projects.
