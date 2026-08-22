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

## 2026-08-21 - Hapus Info.plist Redundan (Archive Gagal)

### The Change

- Menghapus `WorkPlot/Info.plist` (commit `e2985f9`, PR #12).

### The Reasoning

- Project pakai `PBXFileSystemSynchronizedRootGroup` yang otomatis meng-copy seluruh isi folder sebagai resource — termasuk `Info.plist`. Bersamaan, `GENERATE_INFOPLIST_FILE = YES` juga generate Info.plist sendiri. Dua command produce output yang sama → `error: Multiple commands produce '.../WorkPlot.app/Info.plist'`.
- Isi plist lama 100% redundan: semua key sudah dicover oleh `GENERATE_INFOPLIST_FILE` + `INFOPLIST_KEY_*` di pbxproj, jadi aman dihapus tanpa tambahan exception set di pbxproj.

### The Tech Debt

- CI runner pakai Xcode 26.6 (SDK max 26.5.99) sementara deployment target 27.0 — hanya warning, tapi perlu runner image dengan SDK iOS 27 untuk build final.
- File untracked `.tmp-pbxproj-check.txt` dan `gestaltedit-ref.pbxproj` masih ada di working tree (sengaja tidak di-commit).

## 2026-08-21 - Fix Swift Compilation Errors (PR #13)

### The Change

- Branch baru `fix/swift-compile-errors` (commit `1aa51e4`, PR #13) — 12 file berubah.
- `WorkPlotApp.swift`: hapus `public` dari struct `@main`.
- `ExploitManager.swift`: semua pemanggilan ObjC ditulis ulang mengikuti aturan import Swift — method dengan out-param `NSError **` di-import sebagai **throwing** dengan sufiks dihapus (`connectWithError:` → `connect() throws`, `saveGestalt:error:` → `saveGestalt(_:) throws`).
- `BadQueryBridge.h`: pin nama Swift eksplisit via `NS_SWIFT_NAME(lease(forPath:error:))` karena factory method ObjC (return `instancetype`) default-nya di-import sebagai initializer.
- Semua modifier `public` dihapus dari module app (satu target, tidak perlu); penyebab error "public member exposes internal type GestaltBackup".
- `restartDevice()`: ganti `Foundation.Process` (tidak tersedia di iOS) dengan `posix_spawn`.

### The Reasoning

- Error CI sebelumnya bukan satu bug tapi 5 sekaligus; akar utamanya aturan ObjC→Swift importer yang tidak intuitif (NSError** = throws + suffix stripping, factory method = initializer).
- NS_SWIFT_NAME dipakai untuk BadQueryLease supaya deterministik, tidak menebak-nebak hasil import.

### The Tech Debt

- Build tetap belum bisa diverifikasi lokal (Windows); bergantung pada CI round-trip.
- Deployment target 27.0 vs SDK runner 26.5.99 masih warning.

## 2026-08-21 - CI Green: Void-Returning Throws (PR #13)

### The Change

- Commit `97bc8a1`: perbaiki pemanggilan `connect()` dan `saveGestalt(_:)` di `ExploitManager` dari assignment nilai kembalian menjadi do/catch.

### The Reasoning

- Aturan import ObjC→Swift tingkat kedua yang terlewat: method dengan return `BOOL` **plus** out-param `NSError**` di-import sebagai throwing yang mengembalikan `()` — nilai BOOL "ditelan" jadi indikator success/failure. Jadi `sandboxGranted = try access.connect()` invalid; harus `try access.connect()` lalu anggap sukses kalau tidak throw.
- Error pertama kali baru keluar setelah batch error sebelumnya beres (compiler berhenti di error awal).

### Result

- ✅ Run [32500505536](https://github.com/gievano/work-plot2/actions/runs/32500505536): archive ✓, package IPA ✓, upload IPA ✓.

## 2026-08-21 - Fix Respring + RDAR Rewrite + UI Liquid Glass

### The Change

- Hapus `ExploitManager.restartDevice()` (`posix_spawn("/usr/sbin/reboot")`) — tidak mungkin jalan dari app sandboxed.
- Port metode respring **NeoSpring** (neonmodder123 / skadz108, jailbreak.party) ke `RespringController.swift`: WKWebView dengan payload HTML backdrop-filter + perspective + memory pressure yang membuat SpringBoard crash → respring. Dipakai juga oleh GestaltEdit & mond.
- Overlay respring global di `WorkPlotApp` via `manager.respringRequested`; bisa dipicu dari tab mana pun.
- Auto-respring 1 detik setelah Apply tweaks (tab Gestalt), RDAR Fix, dan Apply di tab Liquid Glass — pattern GestaltEdit ("automatically respring after a verified write").
- Rewrite `RDARFix.swift`: throwing API, tulis inode-preserving (`open O_WRONLY|O_NOFOLLOW` → ftruncate → write → fsync, mirroring `saveGestalt`) menggantikan `FileManager.createFile` yang replace inode (ownership jadi mobile, xattr hilang), format plist asli dipertahankan (binary vs xml), canvas configurable, verifikasi pasca-tulis.
- Ekspansi `LiquidGlassController`: enum `LiquidGlassMode`, `currentState()`, `apply(mode:sliderDisabled:)`.
- Tab baru **Liquid Glass** (`LiquidGlassView.swift`): picker Mode Render (Bawaan/Low Perf OFF/OFF... lihat kode), toggle Matikan Global, tombol Apply + Respring manual.

### The Reasoning

- Bug "hp gamau restart": memanggil binary sistem butuh root + entitlement; satu-satunya jalur respring yang proven di iOS 27 beta 1–4 tanpa jailbreak adalah crash WebKit compositing (NeoSpring).
- RDARFix lama menimpa inode sehingga ownership file berubah — pattern ini berbahaya jika disalin ke penulisan plists lain.

### The Tech Debt

- Build tetap belum terverifikasi lokal (Windows); butuh CI round-trip.
- Respring NeoSpring membuat layar hitam sesaat saat SpringBoard restart — expected behavior.

## 2026-08-21 - Feature Parity dengan GestaltEdit

### The Change

- Gap analysis GestaltEdit vs WorkPlot; 5 gap besar ditutup semua:
- `PlistValues.swift`: port `PlistValueKind`/`PlistValueInfo` — parse & encode 7 tipe nilai plist (String/Int/Float/Bool/Data Base64/Array JSON/Dict JSON), disederhanakan untuk `[String: Any]`.
- `GestaltFieldEditorView.swift` + tab **Fields**: searchable key top-level & CacheExtra, editor per tipe, tambah field (sheet), hapus via swipe.
- `GestaltArtwork.swift`: set `ArtworkDeviceSubType` (Dynamic Island picker: SE gestures s/d iPhone Air) dan `ArtworkDeviceProductDescription` (nama model) di tab Gestalt.
- `AIRegionProfile.swift`: port AI Region spoofing (LL/LL/A + regulatory model per device, fallback device spoofing product/hardware/CPU untuk device non-AI) sebagai tweak "AI Region: US (LL/A)" kategori Region baru.
- `BackupRestoreManagerView`: tombol buat backup manual, impor via fileImporter (validasi CacheExtra), ekspor via ShareLink per baris, konfirmasi sebelum restore.
- iPadOS Mode (5 capability keys + patch biner CacheData ala Nugget via `GestaltCacheDataPatch`) masuk katalog tweak dengan RISKY badge.

### The Reasoning

- Semua port langsung dari GestaltEdit (GPLv3, konsisten dengan port BadQueryBridge sebelumnya) agar perilaku proven tidak diimprovisasi ulang.
- Helper ditulis sebagai fungsi murni atas `[String: Any]` inout, bukan wrapper struct seperti GestaltEdit — WorkPlot tidak pakai ViewModel terpusat jadi lebih minim lapisan.

### The Tech Debt

- Build belum terverifikasi lokal (Windows); butuh CI round-trip.
- Fields Editor menyimpan per-edit (satu write gestalt per commit), tidak ada staging dirty-state seperti GestaltEdit.
- AI Region belum ada verifikasi semantik pasca-tulis (byte-level verify saja).

## 2026-08-22 - Siri AI Suite, Device Spoofing, PosterBoard Lab, i18n & Tema

### The Change

- Port `bad_query.c/h` dari Placard (GPLv3): tambah kemampuan `bad_query_list` (enumerasi container via `fsgetpath`) dan query class 7 dengan group identifier custom. Bridging header diperbarui.
- `PosterBoardAccess.swift`: cari container PosterBoard (`com.apple.PosterBoard`) via scan metadata MCM di `/var/mobile/Containers/Data/{Application,InternalDaemon,PluginKitPlugin}` (hash di-cache di UserDefaults), lalu tulis descriptor ke `PRBPosterExtensionDataStore/61/Extensions/com.apple.WallpaperKit.CollectionsPoster/descriptors/`.
- `TendiesPackage.swift`: ZIP reader minimal (central directory scan, stored + deflate via `compression_decode_buffer` COMPRESSION_ZLIB) untuk paket `.tendies`; validasi struktur descriptor (`versions/1/contents`, `Descriptor.plist`, atau `posterkit.descriptor.identifier`); sanitasi path anti zip-slip.
- `SiriAIModifier.swift`: automasi metode Toto — serialisasi plist ke XML (newline dibuang supaya base64 tidak terpotong wrap 76-char Apple), replace exact marker base64 CacheData, parse balik.
- `DeviceSpoofingManager.swift`: spoof penuh — 9 ProductType keys sekaligus + hardware/board model (`oYicEKzVTz4/CxxE05pEgQ`) + dua device name keys; katalog target iPhone 15 Pro s/d 17 Pro Max; deteksi target aktif.
- `AppleIntelligenceController.swift`: toggle eligibility key `A62OafQ85EJAiiqKn4agtg` on/off.
- Tab baru **Siri AI** (`SiriAITweaksView.swift`): toggle Siri AI (CacheData), picker spoof device (+ warning Face ID), toggle Apple Intelligence, satu tombol "Apply Changes" staged → backup → write verified → auto-respring.
- Tab Customization diganti jadi **PosterBoard Lab** (`PosterBoardLabView`): impor .tendies → validasi → ekstrak → install ke PosterBoard → respring.
- Field Editor: section Cache baru (CacheUUID, CacheVersion, CacheData hex dump 512 byte + base64 lengkap).
- `Localization.swift`: switcher 6 bahasa (EN/ID/ZH/JA/RU/VI) in-app + mode tampilan System/Light/Dark; gear Settings di tab Status; tab labels terlokalisasi.

### The Reasoning

- Pipeline PosterBoard disalin dari Placard karena path & struktur descriptor (`PRBPosterExtensionDataStore/61/Extensions/<provider>/descriptors/<UUID>`) tidak terdokumentasi publik — mengimprovisasi berisiko korup data wallpaper.
- Siri AI patch dilakukan di level XML string agar identik dengan metode manual Toto yang sudah terbukti, bukan patch biner heuristik seperti iPadOS CacheData.
- Staged apply: semua perubahan Siri AI/spoof/AI dikumpulkan dulu sebagai intent (nil = tidak disentuh), lalu satu kali read-modify-write — meminimalkan jumlah write ke gestalt.

### The Tech Debt

- Build belum diverifikasi (Windows); CI round-trip wajib.
- Board config iPhone 16 Pro & 15 Pro Max dipaksa pakai board generasinya (D74AP) karena mapping pasti belum dikonfirmasi user.
- Lokalisasi baru mencakup label tab, Settings, dan screen Siri AI/PosterBoard; teks di layar lain masih Indonesia.
- ZIP reader tidak mendukung ZIP64/enkripsi/data-descriptor (bit 3); paket .tendies umumnya aman tapi perlu uji lapangan.
- PosterBoard Lab belum bisa list/hapus wallpaper terpasang (Placard punya; bisa ditambah belakangan).

## 2026-08-22 - Mapping Final Spoofing, SiriMode, Lokalisasi .strings, Popup Restart

### The Change

- Merge PR #14 (Siri AI suite + PosterBoard) — CI hijau.
- `DeviceSpoofingManager`: mapping final sesuai spesifikasi terbaru — iPhone 16 Pro = `iPhone17,1`, tambah target **iPhone 16 Pro Max** (`iPhone17,2`); keduanya D74AP. Board config kini menulis **9 keys sekaligus** (bukan cuma hardware model), plus `CompatibleDeviceFallback` di dalam dict ArtworkDevice (`oPeik/9e8lQWMszEjbPzng`) diisi ProductType target.
- `AppleIntelligenceController`: toggle AI sekarang juga set/hapus **SiriMode** (`a3n5T9sFtyQ74NEp9ESxg` = 2).
- Lokalisasi migrasi ke file `WorkPlot/Resources/{en,id,zh-Hans,ja,ru,vi}.lproj/Localizable.strings`; `L10n.tr` membaca bundle .lproj dulu, fallback ke tabel in-code sampai resource terverifikasi on-device.
- Tab Siri AI: setelah Apply sukses muncul **alert "Restart Diperlukan"** dengan pilihan Respring / Nanti (tidak lagi auto-respring diam-diam) — restart memang wajib untuk mengaktifkan Siri AI baru.

### The Reasoning

- Spesifikasi mapping dikunci user setelah diskusi: 16 Pro pakai identifier real-world (iPhone17,1) dan 16 Pro Max masuk katalog.
- Popup restart eksplisit lebih jujur daripada auto-respring karena tweak CacheData Siri AI butuh restart penuh; respring NeoSpring tetap disediakan sebagai opsi cepat.

### The Tech Debt

- Tabel in-code di Localization.swift duplikat sementara dengan .strings files; hapus begitu on-device test membuktikan bundle termuat.
- CI belum lulus untuk commit ini (menunggu round-trip).

## 2026-08-22 - UX Pass: Bahasa, Alert Restart, Credits, Custom Background

### The Change

- **Bug bahasa**: retrofit tab Status/Gestalt/Liquid Glass ke `L10n.tr` (tombol aksi & section) — switcher bahasa kini mengubah lebih banyak teks, bukan cuma label slider.
- **Alert "Restart Disarankan"** menggantikan auto-respring di semua apply tweaks: Gestalt, Liquid Glass (termasuk disable global dari Status), dan RDAR Fix. Tombol alert: Respring / Nanti. Tab Siri AI tetap pakai alert "Restart Diperlukan" yang lebih tegas.
- **Respring tetap di menu utama** (tab Status) sebagai tombol refresh.
- **Credits** di tab Status: link gievano (github.com/gievano) & Adnan 120Hz (github.com/adnan120hz), plus disclaimer bahasa Inggris soal sandbox escape & bad_query.
- **Custom background**: `AppBackgroundStore` simpan gambar pilihan user (PhotosPicker) ke Documents/background.jpg; layer background di root ZStack dengan opacity 0.35; `scrollContentBackground(.hidden)` di semua List/Form utama. Menu ada di gear Settings dan tombol di tab Status.

### The Reasoning

- Auto-respring diam-diam terasa seperti tweak "gagal" kalau efek tidak muncul; alert eksplisit memberi kontrol ke user dan jujur bahwa restart penuh hasilnya maksimal.
- Background dibuat layer terpisah + opacity rendah supaya kontras teks tetap aman di light/dark mode.

### The Tech Debt

- Layar Fields/Files/Backups/PosterBoard belum sepenuhnya dilokalisasi (masih campur Indonesia); keys baru hanya di .strings files, belum masuk tabel fallback in-code.
- Background image tidak di-blur; bisa ditambahkan material effect nanti.









## 2026-08-22 — Icon Switcher, More Menu Sendiri, Tab Bar Lebih Besar
**The Change:** `Support/Info.plist` baru (GENERATE_INFOPLIST_FILE=NO di pbxproj, INFOPLIST_FILE relatif) dengan CFBundleAlternateIcons "WPCollage" -> AppIconCollage.png (placeholder 1024x1024 digenerate lokal, GANTI dengan artwork asli user). `AppIconSwitcherSheet.swift` (setAlternateIconName), tombol di gear menu. `MainDashboardView.swift`: 5 tab (Status/Gestalt/Fields/SiriAI/More) + font tab bar 13 semibold + symbol pointSize 26 via UIImage config. `MoreMenuView.swift` baru: NavigationLink baris besar (icon 30pt, teks 19pt) utk LiquidGlass/PosterBoard/Backups/Files — menggantikan "More" bawaan sistem yang Inggris & kecil.
**The Reasoning:** Info.plist ditaruh DI LUAR folder synced WorkPlot/ supaya PBXFileSystemSynchronizedRootGroup tidak menyalinnya sbg resource (hindari "Multiple commands produce"). 8 tab bikin SwiftUI jatuh ke system More yang tidak terlokalisasi; menu sendiri = kontrol bahasa + ukuran.
**The Tech Debt:** Icon alternatif masih placeholder hasil generate Windows — user harus replace WorkPlot/Resources/AppIconCollage.png dengan artwork aslinya. Keys lokalisasi belum masuk fallback in-code table (bundle .strings cukup).

## 2026-08-22 — Icon Alternatif Artwork Asli
**The Change:** Replace WorkPlot/Resources/AppIconCollage.png dari placeholder hasil generate jadi artwork asli user (WhatsApp image, center-crop persegi + resize 1024x1024 via System.Drawing).
**The Reasoning:** iOS mensyaratkan alternate icon persegi tanpa alpha; crop tengah menjaga komposisi kolase tetap utuh.
**The Tech Debt:** Sumber JPEG tidak di-commit (bukan bagian app); kalau mau ganti icon lagi tinggal replace PNG dengan nama sama.

## 2026-08-22 — README Baru
**The Change:** Rewrite README.md: logo icon utama di atas (copy AppIcon.png -> docs/assets/logo.png), badges, tabel fitur lengkap, panduan install/sideload, quick start, troubleshooting, credits, disclaimer.
**The Reasoning:** README lama cuma 20 baris dan tidak mencerminkan fitur aktual; logo dari appiconset biar identik dengan icon app.
**The Tech Debt:** Belum ada file LICENSE di repo root padahal bad_query GPLv3 - perlu ditambahkan sebelum distribusi luas.

## 2026-08-22 — README Rewrite (stop-slop pass)
**The Change:** Prose README ditulis ulang dengan aturan skill stop-slop: hapus em dash di credits, adverba ("directly"), lazy extreme ("every write"), staccato ("*Always.*"), dan kalimat dramatis. Struktur tabel/panduan dipertahankan.
**The Reasoning:** Versi pertama masih penuh pola tulisan AI; user minta gaya yang lebih manusiawi via stop-slop + humanizer.
**The Tech Debt:** Header kolom "What it does" dipertahankan sebagai label tabel (bukan kalimat), di luar scope aturan sentence-level.

## 2026-08-22 — Batch Upgrade: Icon Grid, PosterBoard Manager, Credits, Slider
**The Change:**
- PosterBoardLabView: fileImporter kini filter khusus .tendies (UTType filenameExtension), guard ekstensi ganda, section Wallpaper Terpasang dengan tombol apply/respring & remove berkonfirmasi. PosterBoardAccess dapat listInstalledWallpapers() + removeWallpaper(named:) via bad_query list/consume.
- Icon switcher jadi grid 7 pilihan (Default, Collage, Dark, Neon, Minimal, Retro, Gradient) + alert konfirmasi sebelum setAlternateIconName; 5 PNG baru digenerate; Info.plist daftar WPDark/WPNeon/WPMinimal/WPRetro/WPGradient. Entry point ditambah di menu Lainnya (gear tetap).
- CreditsView baru (Owner Adnan.120hz & Gievano, bad_query forcequitOS, MCM bug class 0xjohnnydev, special thanks Mond/GestaltEdit/Ketamine/3105/Placard/FilzaSlop) dari menu Lainnya; footer Owner di tab Status.
- Slider opasitas background nyata (0.05-1.0) di BackgroundPickerSheet dengan label 11pt sesuai spek slider kecil; AppBackground baca @AppStorage backgroundOpacity (default 0.35, perilaku lama utuh).
- 21 key lokalisasi baru x 6 bahasa.
**The Reasoning:** Spek minta slider label kecil tapi tidak ada slider eksisting; menambah slider palsu = gimmick (dilarang spek), jadi dipakai slider nyata untuk fitur background yang sudah ada. Semua upgrade incremental, tidak ada file inti ditulis ulang.
**The Tech Debt:** Icon PNG hasil generate programatik (bukan desain hand-crafted); nama wallpaper tampil sebagai UUID folder karena Descriptor.plist tidak diparsing.

## 2026-08-22 — Keputusan Icon: Tetap 7 Pilihan
**The Change:** Membatalkan penghapusan 5 icon generate-an; Info.plist kembali mendaftar 6 alternate icons + default = 7 total di grid.
**The Reasoning:** User memutuskan tetap pakai semua varian (Dark, Neon, Minimal, Retro, Gradient) selain Default dan WP Collage.
**The Tech Debt:** Tidak ada perubahan kode Swift - AppIconSwitcherSheet sudah mendaftar 7 sejak awal.

## 2026-08-22 — UI Revert ke Layout Awal, Tab Home, Hapus Menu Background
**The Change:** StatusDashboardView kembali 3 section (Informasi Sistem/Aksi/Log) - section Credits dipindah penuh ke menu Lainnya. Tombol & sheet background custom dihapus dari Aksi dan gear menu; BackgroundPickerSheet dihapus sebagai dead code (AppBackground layer tetap ada untuk background lama). Tab pertama jadi Home dengan icon house.fill. Key baru tab.home + home.info x6 bahasa.
**The Reasoning:** User minta UI balik ke tampilan awal ala tabel inset, tab awal dinamai Home, dan fitur background custom ditarik dari menu.
**The Tech Debt:** AppBackgroundStore/AppBackground masih ter-render kalau background.jpg sudah tersimpan di device tapi tidak ada cara menghapusnya via UI lagi.

## 2026-08-22 — Fix Tabel Hilang di Light Theme
**The Change:** .scrollContentBackground(.hidden) di 7 view diganti modifier kondisional workPlotScrollBackground(): background sistem list hanya disembunyikan kalau user pasang custom background image. Tanpa background, kartu grouped-table default iOS kembali tampil (fix laporan "gada shape di back textnya" di light theme).
**The Reasoning:** scrollContentBackground(.hidden) permanen bikin teks melayang tanpa bentuk kartu di light mode.
**The Tech Debt:** -
## 2026-08-22 — Hardening Batch + Revert UI ke Versi Awal + Fix Freeze PosterBoard
**The Change:** (1) LICENSE GPLv3 ditambahkan. (2) Fallback table Localization.swift disinkronkan: 28 keys baru x 6 bahasa. (3) Warning berjenjang: alert konfirmasi spoofing di SiriAITweaksView, section Danger Zone di FilePatchWorkspaceView. (4) Cek kompatibilitas build otomatis saat launch via GestaltAccess.currentOSBuild(). (5) REVERT UI: tab bar kembali ke styling standar iOS (tanpa UITabBarAppearance/bigSymbol custom), MoreMenuView balik ke Label default. (6) FIX FREEZE: parsing Descriptor.plist di listInstalledWallpapers dibuang total (NSDictionary(contentsOfFile:) di path sandbox bikin hang) - kembali ke nama folder UUID. (7) Separator Special Thanks diganti koma.
**The Reasoning:** User lapor UI jadi aneh (tab bar gedhe, spasi jadi titik) dan PosterBoard freeze setelah batch sebelumnya; diminta balik ke versi awal tanpa mengubah fitur.
**The Tech Debt:** Nama wallpaper tetap UUID; health check Gestalt & preset export/import ditunda ke batch berikutnya; filepatch.ready masih placeholder teks.

## 2026-08-22 — Bug-Fix Sweep Pra-Release
**The Change:** (1) Auto-check akses sistem 0.5 dtk setelah launch di WorkPlotApp. (2) Restore backup sukses -> respring otomatis. (3) Sweep lokalisasi total: semua teks hardcoded diganti l10n.tr (89 keys x 6 bahasa, terverifikasi lengkap & seimbang). (4) RDARFix: canvas tidak lagi hardcoded 1290x2868, ambil UIScreen.main.nativeBounds runtime. (5) Merge main ke feat/auto-release + resolusi konflik 8 file.
**The Reasoning:** Persiapan release v1.0.0 - user lapor RDARFix tidak berfungsi (hardcoded canvas hanya cocok satu model), teks campur bahasa, dan ingin UX tanpa tap manual.
**The Tech Debt:** Teks fase progres import PosterBoard ("Mencari container...") masih Indonesia; FilePatchWorkspaceView masih placeholder menunggu port metode filesystem dari IPA 3105.

## 2026-08-22 — Fix Localizable.strings Invalid (6 Bahasa)
**The Change:** Tulis ulang 3 baris per bahasa di WorkPlot/Resources/{en,id,zh-Hans,ja,ru,vi}.lproj/Localizable.strings: fields.noMatch (escape `\"%@\"` yang benar), common.accessLocked & backup.empty (kutip ganda dobel `""...""` diganti `\"...\"`). vi.lproj mojibake ikut terganti dengan konten bersih. Semua file ditulis UTF-8 tanpa BOM via script temp pwsh.
**The Reasoning:** Escape salah + kutip dobel bikin Xcode gagal validasi plist .strings. Baris ditulis ulang utuh satu baris per key (bukan patch substring) supaya deterministik; verifikasi regex ketat `^"(?:[^"\\]|\\.)*" = "(?:[^"\\]|\\.)*";$` PASS di 6 file, 113 key/file tetap, 0 kontrol char & 0 U+FFFD.
**The Tech Debt:** Indentasi baris fields.noMatch hilang (sekarang rata kolom 0) — kosmetik saja, tidak mempengaruhi kompilasi.

## 2026-08-22 - Preset Framework + Hardening Pola BadQueryLease
**The Change:** (1) PRESET: WorkPlotPreset.swift baru (PresetValue tagged Codable string/integer/floating/boolean/data-base64, WorkPlotPreset formatVersion=1, PresetStore persist JSON di Documents/Preset, 3 preset bawaan: iPhone 17 Pro Max Spoof / Dynamic Island Max / Reset Wajar). Apply engine reuse ExploitManager.readGestalt/saveGestalt sehingga backup otomatis via GestaltBackupStore tetap jalan tanpa duplikasi. PresetLabView.swift baru dari menu Lainnya (section bawaan/pengguna, badge RISKY + alert konfirmasi ala SiriAITweaksView, fileImporter .json, export share sheet). URL scheme workplot://preset?data=<base64url JSON>: CFBundleURLTypes di Support/Info.plist + .onOpenURL di WorkPlotApp dengan alert hasil import. 13 key lokalisasi x 6 bahasa (.strings + fallback table Localization.swift tersinkron). (2) LEASE: BadQueryLeaseScope.withLease helper yang membungkus acquire-defer invalidate untuk lease pendek; RDARFix direfactor memakainya (perilaku identik). Audit: GestaltAccess pegang lease panjang dengan reconnect idempotent + invalidate sebelum re-acquire (by design, tidak diubah); PosterBoardAccess pakai bad_query_release defer di semua path.
**The Reasoning:** Format preset pakai encoding bertag {kind,value} supaya Data base64 tidak ambigu dengan String. Nilai preset ditulis ke CacheExtra konsisten dengan seluruh tweak existing; device-name keys sengaja tidak di-invent mengikuti aturan DeviceSpoofingManager. Lease helper hanya dibuat setelah pola acquire/defer terbukti berulang dan dipakai RDARFix; arsitektur exploit tidak disentuh.
**The Tech Debt:** Belum bisa compile di Windows - apply engine, fileImporter security-scoped, dan URL scheme wajib diuji di device iOS 27 beta. Nama preset user disanitasi ke nama file sehingga dua nama berbeda berpotensi kolisi file (import menimpa). Share sheet belum set popover source untuk iPad.

## 2026-08-22 - Hapus Tombol "Periksa Akses Sistem" (Auto-Check Launch)
**The Change:** Hapus Button status.checkaccess dari StatusDashboardView (section Aksi). Key orphan status.checkaccess dihapus dari 6 file Localizable.strings + 6 entri fallback table Localization.swift (total 13 baris, tidak ada referensi tersisa).
**The Reasoning:** Akses sistem kini di-auto-check 0.5 dtk setelah launch oleh WorkPlotApp, jadi tombol manual redundan. checkSystemPathAccess(), log status, dan tampilan Aktif/Terkunci tidak disentuh (masih dipakai auto-check).
**The Tech Debt:** Teks common.accessLocked & backup.empty (6 bahasa) masih menyebut "tekan Periksa Akses Sistem di tab Home" yang sudah tidak ada - perlu rewording terpisah (butuh terjemahan 6 bahasa, menunggu keputusan user).

## 2026-08-22 - Fix Icon Default, Hardening RDAR/Liquid Glass, Wallpaper Tendies Bawaan
**The Change:** (1) ICON: bug utama ganti icon ketemu - memilih icon bawaan mengirim string kosong "" ke setAlternateIconName (harusnya nil) sehingga selalu error "no icon named"; rantai key plist CFBundleAlternateIcons <-> nama PNG di Resources <-> id yang dikirim UI diaudit identik semua (WPCollage/WPDark/WPNeon/WPMinimal/WPRetro/WPGradient, XML balanced). Pesan error kini diprefix label terlokalisasi (key icon.error.prefix x6 bahasa). (2) RDARFIX: alur lease -> baca plist -> tulis inode-preserving -> verifikasi diverifikasi utuh; pesan error errno kini menyertakan strerror() dan write loop retry EINTR; key canvas_width/canvas_height dipertahankan (tidak ada kontradiksi dari strings dump GestaltEdit/GestaltTweak yang memang tidak punya RDAR fix). (3) LIQUID GLASS: LiquidGlassController.apply/disableGlobal jadi throwing; ExploitManager dapat saveGestaltOrThrow (saveGestalt Bool jadi wrapper DRY); applyChanges di LiquidGlassView pindah ke background queue ala pipeline PosterBoard; gagal load state kini menampilkan pesan di List; tombol disable di dashboard pakai do/try/catch; teks hardcoded Indonesia/Inggris di view & controller dilokalisasi (19 keys baru x 6 bahasa .strings + fallback table tersinkron). Preset "Reset Wajar" tidak bentrok: sama-sama lewat read-modify-write + backup otomatis. (4) WALLPAPER TENDIES: repo Cowabunga TIDAK berisi file .tendies apa pun (verifikasi git tree API), koleksi 6 file diambil dari CAPlayground/wallpapers (GPL-3.0, total ~2.4MB): Arch_3D, Warm_Horizon, Batman, WatchOS_Reflect, iPhone_17_Purple, Apple_Intelligence; disimpan di WorkPlot/Resources/TendiesWallpapers/ + CREDITS.txt atribusi; PosterBoard Lab dapat section "Wallpaper Siap Pakai" yang list tendies dari bundle dan pasang via jalur installTendies existing (validasi ZIP -> ekstrak -> cari container -> tulis -> respring otomatis).
**The Reasoning:** setAlternateIconName("") adalah penyebab paling masuk akal dari "masih error" saat kembali ke icon default karena seluruh rantai nama sudah konsisten. Throwing API dipilih supaya penyebab gagal (baca vs backup vs tulis) sampai ke statusText user, bukan false buta. Sumber tendies dialihkan ke CAPlayground/wallpapers daripada mengarang file karena Cowabunga hanya mendistribusikan wallpaper via unduhan eksternal.
**The Tech Debt:** Semantik CacheExtra SAGvsp6O6kAQ4fEfDJpC4Q (enable vs disable LG low-performance) tidak bisa dipastikan arahnya dari string binary GestaltTweak (urutan string table tidak andal) - mapping nilai 0/1 existing dipertahankan apa adanya, wajib verifikasi visual di device; tipe value Int 0/1 vs Bool true juga belum dicek di device. Bundled tendies dicari di bundle root dulu baru subfolder TendiesWallpapers (tergantung Xcode flatten synchronized folder). Semua fitur wajib uji device iOS 27 beta.

## 2026-08-22 - 6 Tweak Baru: SiriMode, Siri di Kamera, Color Palette, Zoom 2x, Graphics Style, DeviceCapability
**The Change:** (1) F6: Managers/DeviceCapability.swift baru - deteksi hw.machine via sysctlbyname (sengaja mengabaikan ProductType hasil spoof), klasifikasi keluarga mesin iPhone + gate .iphone13OrLater (family>=14) / .iphone13OrBelow (family<=14) / .belowIPhone15 (family<=15); mapping family->marketing terdokumentasi di komentar (iPhone13,* = iPhone 12; iPhone 13 mulai iPhone14,*). GestaltTweakDefinition dapat isExperimental + deviceGate + isSupportedOnThisDevice; GestaltPresetManagerView me-render toggle disabled + caption "tidak didukung" untuk tweak yang tidak lolos gate, plus badge EXPERIMENTAL oranye. (2) F1: key a3n5T9sFtyQ74NEp9ESxg=2 (SiriMode iOS 27+) masuk katalog (kategori region) DAN toggle staged baru di SiriAITweaksView lewat SiriModeApplier.swift (enable=set 2, disable=removeValue agar kembali ke state natural). (3) F2: section eksperimental "Siri in Camera" di SiriAITweaksView - TIDAK menulis key apa pun karena tidak ada key CacheExtra terpisah yang terverifikasi; jalur terverifikasi satu-satunya adalah SiriMode + Apple Intelligence bersamaan. (4) F3: colorPaletteGraphics - CameraLiveEffectsCapability (03hWmMtMs+4nzama4/PzHQ)=1, gate iphone13OrLater, TODO comment. (5) F4: cameraZoom2x - AggregateDevicePhotoZoomFactor (JLP/IinyzetEPztvoNUNKg)=2 + RearFacingCameraMaxVideoZoomFactor (WC6wwFV23k19BlUQIAwDTg)=2, gate belowIPhone15, TODO. (6) F5: graphicsStyle - apple-graphics-performance-tier (oOV1jhJbdV3AddkcCg0AEA)=1, gate iphone13OrBelow, TODO. Semua apply tetap lewat read-modify-write ExploitManager.saveGestaltOrThrow (backup GestaltBackupStore otomatis -> tulis -> verifikasi inode-preserving) + tawaran respring existing; ~20 key lokalisasi baru x 6 bahasa (.strings UTF-8 no BOM + fallback Localization.swift).
**The Reasoning:** Riset key dilakukan via strings dump IPA pihak ketiga (%TEMP%/opencode/ipax: GestaltTweak, GestaltTweakMod, GestaltEdit - ketiganya editor generik, hanya memuat CwvKxM2cEogD3p+HYgaW0Q), daftar key resmi The Apple Wiki (raw fetch), source Nugget/Rok574-GestaltTweak via GitHub API, dan websearch komunitas. Hasil: TIDAK ADA key publik yang terverifikasi untuk Color Palette/Photographic Styles maupun Graphics Style pada iOS 27, dan tidak ada key khusus "Siri in Camera". Key F3-F5 dipilih dari key resmi terdokumentasi yang paling dekat semantiknya (live effects utk palette; zoom factor resmi utk 2x; graphics tier utk style) dan ditandai EXPERIMENTAL + TODO - bukan key karangan. Tingkat keyakinan: F1 tinggi (key diberikan user, konsisten dgn leak iOS 27 Siri mode); F4 sedang (key resmi tapi efek UI Kamera stok belum dikonfirmasi); F3/F5 rendah-sedang (kandidat plausible, wajib uji device). Gate pakai helper tunggal sesuai requirement; hw.machine dipilih agar gating tidak bisa dibohongi spoof CacheExtra.
**The Tech Debt:** F3/F4/F5 belum terverifikasi on-device - nilai & arah efek bisa perlu disesuaikan setelah uji iOS 27 beta; jika CameraLiveEffectsCapability ternyata bukan pembuka Color Palette, cari key pengganti tanpa mengubah UI. Entry siriMode di katalog dievaluasi L10n saat static init (bahasa berubah setelah launch tidak update judul tweak) - pola existing, dibiarkan. Toggle catalog tidak punya jalur off (enable-only) mengikuti konvensi katalog existing; off path hanya ada di toggle SiriAITweaksView.
## 2026-08-22 - File Browser Fungsional di FilePatchWorkspaceView (Gaya Filza Ringkas)
**The Change:** (1) SERVICE: Managers/FileBrowserService.swift baru - enum FileBrowser dengan listDirectory (bad_query_list max_inode 2M + stat/attrs + sniff header 8 byte utk klasifikasi FileKind, semua DI DALAM lease), readData/readText/readPlist, saveText staged-apply (tulis temp app sandbox -> verifikasi byte-per-byte -> InodeWriter.writeInPlace -> re-read verifikasi; gated GestaltAccess.isRunningSupportedOS ala build list 3105: 24A5355q-24A5390f), deleteItem (folder wajib kosong, cek via listDirectory dulu), renameItem (move satu direktori, tolak nama duplikat/invalid). FileBrowserError semua case ber-pesan terlokalisasi (fp.error.*). (2) REFACTOR: writeInPlace diekstrak dari RDARFix ke Managers/InodeWriter.swift (RDARFix sekarang delegasi, perilaku identik) supaya dipakai bersama editor file. (3) UI: FilePatchWorkspaceView ditulis ulang dari placeholder - layar shortcut (Preferences /var/mobile, GestaltCache systemgroup, /var/preferences, /var/jb, /var/jailbreak), navigasi breadcrumb tap + tombol naik (parent "/" kembali ke shortcut karena bad_query_list di root bakal scan seluruh inode partisi), listing background GCD + ProgressView, empty state, ikon SF Symbol per tipe (folder/plist/text/image/binary), context menu Rename/Delete per baris. Sheet: editor teks (TextEditor monospace, save wajib alert konfirmasi nama file, sukses = alert fp.save.success + reload), viewer plist (PropertyListSerialization -> XML pretty print read-only), preview image (UIImage(data:) dari data yang dibaca dalam lease - UIImage(contentsOfFile:) langsung tidak bisa karena sandbox), info binary. Banner Danger Zone + status sandbox dipertahankan; warning oranye jika OS build tidak didukung. Delete/rename/save semua alert konfirmasi menyebut nama file; tanpa silent catch (semua error ke alert). (4) L10N: 40 key fp.* + common.error + filepatch.ready (rewording) x 6 bahasa (.lproj UTF-8 no BOM, escape \", tanpa smart quotes) + fallback table Localization.swift tersinkron (termasuk common.cancel yang sebelumnya cuma ada di .lproj).
**The Reasoning:** bad_query_list bekerja via fsgetpath scan inode sehingga listing harus di background queue dan butuh lease untuk stat anak-anaknya; klasifikasi tipe dilakukan sekali saat listing (bukan saat render row) agar tidak baca file di luar lease. Root "/" sengaja tidak bisa di-list (O(2M inode)) dan dijadikan tombol kembali ke shortcut. Write gating reuse isRunningSupportedOS existing daripada menulis ulang deteksi build dari dump 3105.
**The Tech Debt:** Belum compile lokal (Windows) - wajib uji device iOS 27 beta 1-4: listing folder besar (Preferences ~ratusan entry), tulis plist teks, delete folder kosong, rename. Rename file yang punya hardlink/xattr belum diverifikasi moveItem mempertahankannya. Tidak ada copy/paste/new-file/new-folder (di luar scope batch ini). Listing root shortcut yang tidak ada (/var/jb dsb.) akan menampilkan error alert, bukan disembunyikan.

## 2026-08-22 — Fix 4 Bug: Spoof Lengkap, Restart Berjenjang, Color Palette, Siri AI
**The Change:** Lima commit (c0d781a, 7bbe0d5, 44b049e, 18ef83c, c374f46):
1. **Bug 4 - Siri AI tidak berfungsi**: toggle `siriai.modelkey` (h9jDsbgj7xIVeIQ8S3/X3Q) dan `siriai.eligibility` (A62OafQ85EJAiiqKn4agtg = 1) dari sesi sebelumnya ternyata BARU setengah jadi - state & UI ada tapi tidak pernah di-apply dan computed state-nya tidak ada (referensi simbol yang tidak terdefinisi = build break). Kini lengkap: ModelSpoofKeyApplier ikut target spoof EFEKTIF (picker ATAU nilai tertulis di device via currentTarget), AIRegionEligibilityApplier menulis key tunggal, urutan apply = spoof dulu baru toggle supaya intent user menang. Tipe SiriMode a3n5T9sFtyQ74NEp9ESxg TETAP Integer 2.
2. **Bug 1 - spoof tidak mengubah semua identifier**: riset The Apple Wiki + source Nugget (tweak_loader.py) memetakan SEMUA key identitas: 9 ProductType (ProductType utama + 6 ProductTypeDescFor* iOS 26 + SubProductType + ThinningProductType), 9 HWModel (HWModelStr, HWModelUniqueStr, 6 HWModelDescriptionFor* iOS 26 + TargetSubType oYicEKzVTz4/CxxE05pEgQ - Nugget memang menulis board config ke sini), HardwarePlatform/CPU 5pYKlGnYYBzGvAlIU8RjEQ, RegulatoryModelNumber 97JDvERpVwO+GHtthIh7hA, marketing-name + bbtR9jQx50Fv5Af/affNtA + MarketingDeviceFamilyName vme9Buk6XiWFCXoHApxNFA + MarketingProductName j9Th5smJpdztHwc+i39zIg (overwrite-if-exists), dan dict Artwork: CompatibleDeviceFallback = productType + ArtworkDeviceProductDescription = nama marketing. Nilai per device DIKOREKSI dari metadata IPSW (board lama D74AP generik SALAH): iPhone16,1=D83AP/t8130/A2848, iPhone16,2=D84AP/t8130/A2849, iPhone17,1=D93AP/t8140/A3083, iPhone17,2=D94AP/t8140/A3084, iPhone18,1=V53AP/t8150/A3256, iPhone18,2=V54AP/t8150/A3257 (V54AP pola BDID 0x0E; t8150=A19 Pro konfirm Apple Wiki). UI menampilkan ringkasan "key yang akan diubah: N" (changedKeyCount, termasuk subkey artwork) dan hw.machine asli via DeviceCapability; revert = restore backup (seluruh plist atomik).
3. **Bug 2 - restart berjenjang**: confirmationDialog 3 opsi (Respring / Restart Userspace disarankan / Full Restart) pasca-apply di SiriAI dan tab Gestalt. BATASAN JUJUR: bad_query hanya R/W file - tidak bisa spawn proses sehingga launchctl untuk restart userspace/penuh MUSTAHIL dieksekusi dari app; kedua opsi itu membuka sheet panduan manual (force-restart gesture / Shut Down dari Settings) plus penjelasan batasan di footer. Respring tetap NeoSpring WebKit.
4. **Bug 3 - Color Palette**: key lama 03hWmMtMs+4nzama4/PzHQ terkonfirmasi The Apple Wiki sebagai CameraLiveEffectsCapability (efek live KAMERA) - semantiknya memang salah sejak awal. Nugget/GestaltEdit/wiki/websearch TIDAK menemukan key terverifikasi untuk Color Palette. Toggle kini menulis SET kandidat: CameraLiveEffectsCapability=1 + apple-graphics-performance-tier oOV1jhJbdV3AddkcCg0AEA=1 (key resmi iOS 17 yang dipakai komunitas utk fitur generasi iPhone 16), deskripsi eksperimental diperbarui x6 bahasa.
5. **Hygiene**: preset bawaan iPhone 17 Pro Max ikut grup key baru (hwModelKeys V54AP + cpuKeys + regulatoryModelKeys); key apple-internal-install di preset Reset Wajar ternyata TERPOTONG sejak dibuat (EqrsVvjcYDdxHBiQ tanpa ekor mGhAWw) sehingga reset tak pernah menyentuh key asli - dilengkapi.

**The Reasoning:** Sumber mapping paling otoritatif adalah daftar key resmi The Apple Wiki (hash <-> nama) dan source Nugget karena battle-tested; board config/CPU/regulatory diverifikasi silang ke halaman perangkat IPSWDL. Urutan commit dibalik (bug 4 dulu) karena working tree berisi kode setengah jadi milik bug 4 yang mem-break build kalau commit lain masuk duluan. Untuk restart, memilih panduan manual daripada mengarang mekanisme exploit sesuai batasan requirement.

**The Tech Debt:** Keyakinan: bug 1 tinggi utk ProductType/HWModel keys (resmi), sedang utk TargetSubType/HardwarePlatform (mengikuti Nugget); bug 3 RENDAH - set kandidat belum terbukti menghasilkan efek visual apa pun, wajib uji device dan bisa jadi perlu key pengganti; bug 4 sedang - tipe Integer 2 konsisten dengan leak yang diberikan user tapi key a3n5T9sFtyQ74NEp9ESxg tidak ada di wiki/Nugget/GestaltEdit (provenance user-provided). changedKeyCount membaca plist tiap render section spoof (readGestalt per body eval) - mahal tapi konsisten dengan pola existing loadedPlist. Key l10n lama (siriai.restart.message, restart.rec.*) kini tak terpakai di view tapi dibiarkan di tabel. V54AP/t8150 untuk iPhone18,2 belum dikonfirmasi perangkat resmi (pola dari iPhone18,1=V53AP). Semua wajib uji device iOS 27 beta 1-4.

## 2026-08-22 - Finalisasi Dual-Cache dan UI English-Only
**The Change:** Melanjutkan working tree sesi agent terputus: `CacheDataPatcher` menjadi jalur bersama untuk Siri AI dan empat tweak dual-cache; mutasi dibatasi ke value `CacheData`, menolak marker hilang/duplikat/campuran, dan mendapat self-check Swift di CI. Gate Graphics Style dipersempit ke iPhone 11/12, Color Palette Legacy ditambahkan untuk iPhone 13 ke bawah, spoof selalu membawa region US/US-A, dan restart tweak berat memakai alert modal. Verifikasi tulis MobileGestalt kini menahan file descriptor sampai pengecekan selesai dan memulihkan data awal bila tulis/verifikasi gagal. Atas keputusan terbaru user, selector bahasa serta resource `id/zh-Hans/ja/ru/vi` dihapus; `L10n` kini memuat `en.lproj` secara eksplisit, seluruh key yang dipakai UI dilengkapi dalam English, dan pesan error backend yang dapat tampil ke user diseragamkan ke English. Ditambahkan `Support/check-l10n.ps1` dan `Support/check-feature.ps1` sebagai verifier permanen.
**The Reasoning:** Implementasi multi-bahasa lama punya dua sumber copy (`.strings` + tabel Swift) yang terus drift, bahkan identifier runtime seperti `english`/`indonesian` tidak cocok dengan folder `en.lproj`/`id.lproj`. English-only menghapus mismatch di akar masalah dan memangkas lebih dari seribu baris fallback duplikat. Mutasi CacheExtra dan CacheData tetap dilakukan pada dictionary in-memory yang sama sebelum satu `saveGestalt`, sehingga backup dan write tetap satu transaksi.
**The Tech Debt:** Build Xcode tidak tersedia di Windows dan harus dibuktikan lewat CI macOS pada PR. Color Palette, Graphics Style, Camera 2x, dan Legacy Palette tetap eksperimental sampai diuji langsung pada device iOS 27 beta; marker CacheData dan nilai kandidat dapat perlu kalibrasi bila hasil on-device berbeda. Tabel fallback multi-bahasa sudah dihapus permanen; penambahan bahasa di masa depan harus dimulai dari bundle resource dengan verifier mapping, bukan dictionary Swift kedua.

## 2026-08-22 - Bad Query Sideload Diagnostics, Transactional RDAR, and Safe File Operations
**The Change:** Target Debug/Release kini mempertahankan bundle identifier `com.apple.mobile.MobileHouseArrest`; bridge `bad_query` menolak signer yang me-rewrite identity dan melaporkan stage `identity`, `bridge`, `query-create`, `query`, `token`, atau `consume`. Health check memakai lease Objective-C agar detail tersebut tampil di status. RDAR tetap query `/var/preferences/...` tetapi membaca/menulis file nyata `/private/var/preferences/...`; `InodeWriter.writeVerifiedInPlace` menyimpan bytes awal, memverifikasi write, dan rollback bila gagal. File workspace mendapat helper Foundation yang diuji untuk create/copy/move/collision/name validation, wrapper lease untuk create file/folder, copy/move, import/export, serta UI search, Copy/Move lalu Paste, file importer, dan share melalui temp export. CI menambahkan executable checks untuk transactional inode writer dan safe file operations; unsigned archive dan IPA upload lulus pada run `32577467479`.
**The Reasoning:** Bundle identity adalah prasyarat ContainerManager dari kedua IPA referensi, sedangkan pemisahan query path dan real path mengikuti layout `/var` ke `/private/var`. Backup/verification/rollback dipusatkan di writer bersama supaya setiap caller tidak mengulang jalur proteksi data. Operasi file biasa dipisahkan dari bridge privat agar behavior dapat diuji langsung tanpa mock atau dependency baru.
**The Tech Debt:** Belum ada uji langsung di iPhone yang menjalankan build iOS yang didukung; hasil sideload wajib dikonfirmasi dari status `stage=...`, RDAR visual, dan operasi pada path nyata. ZIP/unzip generik belum ditambahkan karena Foundation tidak menyediakan writer ZIP publik dan repo belum punya dependency yang sesuai. Fitur root-only Filza seperti kernel exploit, terminal root, chmod/chown, package installer, dan network mounts tetap di luar scope.

**Follow-up source audit:** Repo publik `YangJiiii/3105` (GPL-3.0, commit `f1b8104`) dan `0xjohnnydev/FilzaSlop` (commit `ec490ad`) diaudit sebelum PR. `SafeFileOperations` kemudian mengadaptasi safety behavior 3105: copy ke staging sebelum commit, keep-both suffix, penolakan folder ke dalam dirinya sendiri, penolakan symbolic link, dan fallback move via copy lalu delete. Test edge-case dan unsigned IPA archive lulus pada CI run `32577861220`. FilzaSlop tidak mempunyai project-level license pada commit yang diaudit, sehingga source FilzaSlop tidak disalin; detail atribusi ada di `THIRD_PARTY_NOTICES.md`.

## 2026-08-23 - Rentang Versi BadQuery Disamakan dengan 3105

**The Change:** Minimum deployment target WorkPlot diturunkan dari iOS 27 ke iOS 16 untuk Debug/Release. Runtime gate MobileGestalt kini menerima iOS/iPadOS 17.0-17.7.x, 18.0-18.7.1, dan 26.0-26.6.1 selain build iOS/iPadOS 27 beta yang sudah diizinkan. README diperbarui dengan rentang tersebut plus catatan bahwa signing harus mempertahankan `com.apple.mobile.MobileHouseArrest`. Checker fitur sekarang mengunci floor iOS 16 dan rentang versi baru.

**The Reasoning:** Build lama tidak bisa dipakai pada iOS 17/18/26 karena dipasang dengan minimum iOS 27 dan langsung menolak versi runtime. IPA referensi 3105 memakai minimum iOS 16 dan rentang lebar tersebut. Audit binary juga membuktikan fitur filesystem luas pada 3105 memakai stage kernel R/W terpisah (`KernelExploit`, `kexploit_opa334`), bukan bad_query saja, sehingga stage itu tidak disalin ke WorkPlot.

**The Tech Debt:** Perlu uji sideload perangkat fisik pada minimal satu build iOS 17/18/26 dan satu build iOS 27 karena ketersediaan private API bisa berbeda per build. Paritas penuh dengan 3105 tetap tidak mungkin hanya melalui bad_query: cleaner/patch/wallpaper berbasis file bisa diarahkan lewat File Workspace atau batch berikutnya, sedangkan kemampuan root/kernel tetap di luar scope.

## 2026-08-23 - Sprint 1: Dual-Method Exploit (CMG Fallback) + Perbaikan Kunci MGKeys

**The Change:**
1. **CMG fallback** (`CmgBridge.{h,m}` baru): port langsung resep `rooootdev/mond` `cmg.swift` — class 13, transient NO, xpc_array group `systemgroup.com.apple.mobilegestaltcache`, platform 2, flags `(1<<32)|(1<<39)`, part 3, lalu `container_object_sandbox_extension_activate(result, YES)` + `container_object_get_path`. Tidak ada konsumsi token; aktivasi berlaku proses-wide.
2. **GestaltAccess dual-method**: `connectWithError:` kini mencoba bad_query dulu, gagal → fallback CMG; properti baru `activeMethod` (`bad_query`/`cmg`). OS gate jadi **iOS/iPadOS 27-only** via `VersionIsVerifiedIOS27Beta` (6 build dev/public beta; PB2 = 24A5390f sama dengan dev beta 4).
3. **BadQueryBridge identity non-fatal**: mismatch bundle id tidak lagi memblokir query — dicatat sebagai note diagnostik `stage=identity` yang menempel pada pesan kegagalan berikutnya (bukti: MobileHouseArrest-PoC menyatakan rute class-13 tak butuh identity itu; GestaltEdit resmi ship dengan bundle id sendiri).
4. **ExploitManager**: preflight `/var/preferences` dihapus dari connect (penyebab utama gagal saat signer menulis ulang bundle id — probe fatal memblokir fallback); publish `exploitMethod` + `showsSigningHint`; auto-capture "Stock Snapshot" pada connect sukses pertama; SessionLogger hook.
5. **Bugfix kunci MGKeys**: SiriMode typo `a3n5T9sFtyQ74NEp9ESxg` -> `a3n5T9sFtlyQ74NEp9ESxg` (4 file); disableParallax kini menulis key asli `mmu76v66k1dAtghToInT8g`, bukan plaintext `UIParallaxCapability`.
6. **RDAR hardening R1-R4**: backup persisten `Documents/RDAR Backups/` (tidak pernah ditimpa), idempotensi `.alreadyFixed`, harness `Support/RDARFixCheck.swift` masuk CI, pesan error jujur untuk path yang tak tercakup CMG; tombol Restore Original Canvas + Revert to Stock Snapshot di Backup manager; baris Method + signing hint di Dashboard; Session Log viewer (ring buffer 300) di More menu.
7. `check-feature.ps1` ditulis ulang: gate 27-only, asersi simbol CMG, larang referensi bundle id di CmgBridge.m, kunci SiriMode/parallax bener, F2 surface. Kedua checker lokal hijau.

**The Reasoning:** CMG dipilih sebagai fallback karena bekerja persis pada rentang build yang didukung (27 beta 1-4) tanpa syarat identitas sideload - melengkapi bad_query yang butuh `com.apple.mobile.MobileHouseArrest`. Urutan bad_query dulu tetap dipertahankan karena cakupan path traversalnya lebih luas. Identitas diturunkan menjadi diagnostik setelah audit PoC membuktikan pengecekan lama terlalu galak dan jadi penyebab utama kegagalan user. Rentang versi dipangkas ke 27-only sesuai keputusan scope sprint ini.

**The Tech Debt:** CMG hanya membuka container MobileGestaltCache sehingga fitur non-Gestalt tetap butuh bad_query. Tidak ada kompilasi iOS lokal (Windows): verifikasi bergantung checker lokal + CI xcodebuild + uji perangkat fisik user. Path hasil `container_object_get_path` diasumsikan `<container>/Library/Caches/com.apple.MobileGestalt.plist`; kalau formatnya beda di device, satu-satunya titik penyesuaian adalah `cmgPlistPath` di GestaltAccess.m. DEVLOG lama masih memuat key typo sebagai histori (biarkan). id.lproj belum ada.
