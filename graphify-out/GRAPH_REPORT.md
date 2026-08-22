# Graph Report - .  (2026-08-22)

## Corpus Check
- 59 files · ~176,097 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 600 nodes · 1144 edges · 37 communities (33 shown, 4 thin omitted)
- Extraction: 92% EXTRACTED · 8% INFERRED · 0% AMBIGUOUS · INFERRED: 97 edges (avg confidence: 0.81)
- Token cost: 6,800 input · 2,400 output

## Community Hubs (Navigation)
- Codable & Serialization
- App Background & View Modifiers
- Apple Intelligence Controller
- Exploit Manager Core
- SwiftUI App Shell
- Observable Stores & Assets
- PosterBoard Access
- Icon Switcher UI
- Tendies Package Compression
- bad_query Bridge
- AI Region Profile
- Liquid Glass Controller
- ObjC Lease Bridge
- Gestalt Tweak IDs
- Lease Scope Hardening
- Credits View
- CI & Docs Narrative
- Dynamic Island Artwork
- Preset Manager View
- Tweak Categories
- Artwork Setter API
- Gestalt Tweak Catalog
- Collage Icon Visuals
- Release Pipeline
- Project Logo Brand
- Tendies Wallpaper Sources
- Gradient Icon Visuals
- Retro Icon Visuals
- Main Icon Visuals
- Neon Icon Visuals
- Siri AI Suite Concepts
- Dark Icon Visuals
- Minimal Icon Visuals
- MobileGestalt & RDARFix
- Fork PR Safety Skills
- File Patching Skills
- Foundation Strings

## God Nodes (most connected - your core abstractions)
1. `GestaltTweakID` - 29 edges
2. `WorkPlotPreset` - 25 edges
3. `PlistValueKind` - 21 edges
4. `PresetValue` - 20 edges
5. `ExploitManager` - 19 edges
6. `SiriAITweaksView` - 19 edges
7. `GestaltBackup` - 18 edges
8. `GestaltFieldEditorView` - 17 edges
9. `LiquidGlassMode` - 16 edges
10. `AppLanguage` - 15 edges

## Surprising Connections (you probably didn't know these)
- `build job (WorkPlot-IPA artifact)` --references--> `WorkPlot`  [EXTRACTED]
  .github/workflows/main.yml → README.md
- `README humanizer rewrite` --references--> `WorkPlot`  [EXTRACTED]
  docs/DEVLOG-DOCS.md → README.md
- `Binary string adjacency heuristic limitation` --conceptually_related_to--> `Apple Intelligence`  [INFERRED]
  skill-observations/log.md → README.md
- `ExploitManager` --calls--> `+shared`  [EXTRACTED]
  WorkPlot/Managers/ExploitManager.swift → WorkPlot/Exploit/GestaltAccess.h
- `.wallpaperList` --references--> `ExploitManager`  [INFERRED]
  WorkPlot/UI/CustomizationThemeView.swift → WorkPlot/Managers/ExploitManager.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **WorkPlot CI/CD pipeline: build once, publish stable + rolling releases** — _github_workflows_main_build_job, _github_workflows_main_release_job, _github_workflows_main_latest_release_job [INFERRED]
- **GPL-3.0 tendies wallpaper distribution into PosterBoard Lab** — readme_posterboard_lab, readme_tendies_wallpapers, workplot_resources_tendieswallpapers_credits_caplayground_wallpapers, workplot_resources_tendieswallpapers_credits_gpl_3_0 [INFERRED]

## Communities (37 total, 4 thin omitted)

### Community 0 - "Codable & Serialization"
Cohesion: 0.06
Nodes (43): Codable, CodingKey, Decoder, Double, Encoder, LocalizedError, URL, GestaltCacheDataPatchError (+35 more)

### Community 1 - "App Background & View Modifiers"
Cohesion: 0.10
Nodes (26): Content, ViewModifier, Void, AppBackground, .body, ConditionalListBackground, View, AddCacheExtraFieldView (+18 more)

### Community 2 - "Apple Intelligence Controller"
Cohesion: 0.07
Nodes (33): AppleIntelligenceController, Any, Bool, String, DeviceSpoofingError, .errorDescription, missingCacheExtra, DeviceSpoofingManager (+25 more)

### Community 3 - "Exploit Manager Core"
Cohesion: 0.12
Nodes (19): Date, ExploitManager, ExploitManagerError, .errorDescription, Any, Bool, Data, String (+11 more)

### Community 4 - "SwiftUI App Shell"
Cohesion: 0.08
Nodes (19): App, Scene, SwiftUI, UIActivityViewController, UIViewControllerRepresentable, UIViewRepresentable, UniformTypeIdentifiers, WebKit (+11 more)

### Community 5 - "Observable Stores & Assets"
Cohesion: 0.08
Nodes (25): CaseIterable, ColorScheme, ObservableObject, UIImage, AppBackgroundStore, URL, AppearanceMode, .colorScheme (+17 more)

### Community 6 - "PosterBoard Access"
Cohesion: 0.14
Nodes (17): PosterBoardAccess, .isAvailable, PosterBoardError, containerNotFound, .errorDescription, listFailed, unsupportedSystem, writeFailed (+9 more)

### Community 7 - "Icon Switcher UI"
Cohesion: 0.13
Nodes (19): Binding, Color, AppIcon, .all, AppIconSwitcherSheet, .body, String, FilePatchWorkspaceView (+11 more)

### Community 8 - "Tendies Package Compression"
Cohesion: 0.15
Nodes (18): Compression, UInt16, UInt32, UInt8, Bool, Data, Int, String (+10 more)

### Community 9 - "bad_query Bridge"
Cohesion: 0.12
Nodes (17): String, PlistValueError, .errorDescription, invalid, PlistValueInfo, PlistValueKind, array, boolean (+9 more)

### Community 10 - "AI Region Profile"
Cohesion: 0.13
Nodes (15): Equatable, Foundation, AIRegionApplier, AIRegionConfiguration, .requiresDeviceSpoofing, AIRegionKeys, AIRegionProfile, .machineIdentifier (+7 more)

### Community 11 - "Liquid Glass Controller"
Cohesion: 0.11
Nodes (19): LiquidGlassController, LiquidGlassError, .errorDescription, LiquidGlassMode, .cacheExtraValue, .descriptionKey, .id, .label (+11 more)

### Community 12 - "ObjC Lease Bridge"
Cohesion: 0.12
Nodes (17): NSPropertyListFormat, BadQueryLease, -dealloc, -invalidate, +leaseForPatherror, NSObject, NSString, GestaltAccess (+9 more)

### Community 13 - "Gestalt Tweak IDs"
Cohesion: 0.09
Nodes (22): GestaltTweakID, actionButton, aiRegionUS, alwaysOnDisplay, alwaysOnDisplayVibrancy, bootChime, cameraButton, chargeLimit (+14 more)

### Community 14 - "Lease Scope Hardening"
Cohesion: 0.14
Nodes (14): UIKit, BadQueryLeaseError, acquisitionFailed, .errorDescription, BadQueryLeaseScope, String, T, RDARFix (+6 more)

### Community 15 - "Credits View"
Cohesion: 0.30
Nodes (7): CreditsLink, CreditsView, .body, .placeholderAvatar, .projects, String, URL

### Community 16 - "CI & Docs Narrative"
Cohesion: 0.20
Nodes (10): build job (WorkPlot-IPA artifact), Build unsigned IPA workflow, README humanizer rewrite, Static README badges, bad_query sandbox escape, GestaltEdit, Placard, WorkPlot (+2 more)

### Community 17 - "Dynamic Island Artwork"
Cohesion: 0.22
Nodes (8): Hashable, Identifiable, DynamicIslandOption, .id, GestaltArtworkError, artworkDictionaryMissing, .errorDescription, Int

### Community 18 - "Preset Manager View"
Cohesion: 0.28
Nodes (6): Set, GestaltPresetManagerView, .body, .stagedChangeCount, Bool, Int

### Community 19 - "Tweak Categories"
Cohesion: 0.25
Nodes (8): GestaltTweakCategory, display, hardware, .id, internalFeatures, ipad, .label, region

### Community 20 - "Artwork Setter API"
Cohesion: 0.62
Nodes (3): GestaltArtwork, Any, String

### Community 21 - "Gestalt Tweak Catalog"
Cohesion: 0.43
Nodes (4): GestaltCacheDataPatch, GestaltTweakCatalog, GestaltTweakDefinition, Any

### Community 22 - "Collage Icon Visuals"
Cohesion: 0.47
Nodes (5): Developer/tinkering motifs: gears, lightning bolt, wrench, code braces, padlock, Radial collage of iPhones showing varied app screens, Jailbreak/tweak ecosystem theme (Sileo, CrackToolz-style references on device screens), Clean light-blue/white glossy 3D style with rounded app-icon squircle frame, WorkPlot branding (WP monogram logo)

### Community 23 - "Release Pipeline"
Cohesion: 0.50
Nodes (5): latest-release job (rolling), release job (stable, v* tags), softprops/action-gh-release@v2, Stable release v1.0.0, Rolling release 'latest'

### Community 24 - "Project Logo Brand"
Cohesion: 0.60
Nodes (5): Brand Identity of work-plot2 Project, Color Palette: Violet/Purple Gradient with Deep Indigo Base, Project Logo: 3D Glass Jar with Purple Potion Orb, Motif: Liquid Drop Contained in Glass Vessel (Potion/Plot-in-a-Jar), Visual Style: Photorealistic 3D Glass Render (Glassmorphism)

### Community 25 - "Tendies Wallpaper Sources"
Cohesion: 0.40
Nodes (5): PosterBoard Lab, .tendies wallpapers, CAPlayground/wallpapers, leminlimez/Cowabunga, GPL-3.0 license

### Community 26 - "Gradient Icon Visuals"
Cohesion: 0.60
Nodes (5): WorkPlot App Icon (Gradient), Bold White Sans-Serif Typography, Minimalist Modern Brand Identity, WP Monogram Lettermark, Warm Red-to-Orange Diagonal Gradient Style

### Community 27 - "Retro Icon Visuals"
Cohesion: 0.60
Nodes (5): WorkPlot Retro App Icon, Brown/Earth-Tone Color Palette, Circular Badge Motif, Retro Brand Identity Concept, Retro WP Monogram Design

### Community 28 - "Main Icon Visuals"
Cohesion: 0.50
Nodes (4): Glass Jar Container Motif (plot/vessel metaphor), WorkPlot App Icon (glass jar with purple orb), Purple/Indigo Color Palette, 3D Glassmorphism Visual Style

### Community 29 - "Neon Icon Visuals"
Cohesion: 0.67
Nodes (4): AppIconNeon - WorkPlot app icon, WorkPlot brand identity (dark, high-energy, modern gaming/tech aesthetic), Neon / synthwave visual style (magenta + electric green on dark background), "WP" monogram motif (WorkPlot initials) in bold italic green letters over a magenta circle outline

### Community 30 - "Siri AI Suite Concepts"
Cohesion: 0.67
Nodes (3): Apple Intelligence, Siri AI Suite, Binary string adjacency heuristic limitation

### Community 31 - "Dark Icon Visuals"
Cohesion: 1.00
Nodes (3): Dark Theme Visual Style (near-black gradient background, high-contrast white glyph), WorkPlot Dark App Icon, WP Monogram (bold sans-serif white lettering)

### Community 32 - "Minimal Icon Visuals"
Cohesion: 1.00
Nodes (3): AppIconMinimal.png - WorkPlot app icon, Minimalist black-and-white visual style, WP monogram - bold black sans-serif lettermark

## Knowledge Gaps
- **138 isolated node(s):** `.machineIdentifier`, `.requiresDeviceSpoofing`, `AIRegionKeys`, `.body`, `.errorDescription` (+133 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Foundation` connect `AI Region Profile` to `Codable & Serialization`, `Apple Intelligence Controller`, `Exploit Manager Core`, `PosterBoard Access`, `Tendies Package Compression`, `bad_query Bridge`, `Liquid Glass Controller`, `Lease Scope Hardening`, `Dynamic Island Artwork`, `Gestalt Tweak Catalog`?**
  _High betweenness centrality (0.104) - this node is a cross-community bridge._
- **Why does `View` connect `App Background & View Modifiers` to `Apple Intelligence Controller`, `Exploit Manager Core`, `SwiftUI App Shell`, `PosterBoard Access`, `Icon Switcher UI`, `Liquid Glass Controller`, `Credits View`, `Preset Manager View`?**
  _High betweenness centrality (0.085) - this node is a cross-community bridge._
- **Why does `ExploitManager` connect `Exploit Manager Core` to `Observable Stores & Assets`, `PosterBoard Access`, `AI Region Profile`, `ObjC Lease Bridge`, `Lease Scope Hardening`?**
  _High betweenness centrality (0.083) - this node is a cross-community bridge._
- **What connects `.machineIdentifier`, `.requiresDeviceSpoofing`, `AIRegionKeys` to the rest of the system?**
  _138 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Codable & Serialization` be split into smaller, more focused modules?**
  _Cohesion score 0.06019871420222092 - nodes in this community are weakly interconnected._
- **Should `App Background & View Modifiers` be split into smaller, more focused modules?**
  _Cohesion score 0.09855072463768116 - nodes in this community are weakly interconnected._
- **Should `Apple Intelligence Controller` be split into smaller, more focused modules?**
  _Cohesion score 0.0696969696969697 - nodes in this community are weakly interconnected._