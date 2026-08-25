# Third-Party Notices

## bad_query (forcequitOS) — GPLv3

WorkPlot incorporates GPLv3-licensed `bad_query` source code from
[forcequitOS/bad_query](https://github.com/forcequitOS/bad_query). WorkPlot is
distributed under GPL-3.0; see [`LICENSE`](LICENSE).

## bad_query class-13 MobileGestalt route (0xjohnnydev)

The `bad_query` class-13 ContainerManager route parameters were cross-checked
against the MobileHouseArrest-PoC notes (mond / 0xjohnnydev). The technique was
demonstrated end-to-end by [0xjohnnydev/FilzaSlop](https://github.com/0xjohnnydev/FilzaSlop).
No FilzaSlop source code was copied; the behavior was reimplemented from public
documentation of the technique.

## Respring method

The WebKit-crash respring follows [rooootdev/neospring](https://github.com/rooootdev/neospring);
WebKit variant by @neonmodder123, Swift port by @skadz108.

## References without copied code

Nugget and GestaltEdit ([leminlimez](https://github.com/leminlimez)) were
consulted for MobileGestalt key semantics; Placard ([frs0n](https://github.com/frs0n/placard))
as an app-design reference. No source code was copied from these projects.

## Pocket Poster (leminlimez) - GPLv3

`WorkPlot/Wallpaper/` adapts PosterBoard wallpaper logic from
[Pocket Poster](https://github.com/leminlimez/Pocket-Poster) (GPL-3.0):

- `WallpaperPosterBoardManager.swift` <- `Controllers/PosterBoardManager.swift`
- `WallpaperSymlink.swift` <- `Controllers/SymHandler.swift`
- `WallpaperDownloadManager.swift` <- `Controllers/DownloadManager.swift`
- `WallpaperCowabungaAPI.swift` <- `API/CowabungaAPI.swift` + `API/DownloadableWallpaper.swift`
- `WallpaperVideoHandler.swift` <- `Controllers/VideoHandler.swift`
- `WallpaperCarPlayManager.swift` <- `Controllers/CarPlayWallpaper+CarPlayManager.swift` + `Controllers/CPBitmapHandler.swift`
- `WallpaperErrors.swift` <- `Error Codes/ApplyError.swift` + `Error Codes/APIError.swift`
- `UIApplication+Wallpaper.swift` <- `Extensions/Views/Alert++.swift`

Pocket Poster is also GPL-3.0, so the port is license-compatible. The
`Resources/WallpaperCAML/` template mirrors Pocket Poster's `Resources/VideoCAML/`
(the `providerInfo.plist` must be copied from the upstream source — see the
folder's README). CarPlay `.cpbitmap` writing depends on the `Dynamic`
Swift package (github.com/leminlimez/Dynamic).
