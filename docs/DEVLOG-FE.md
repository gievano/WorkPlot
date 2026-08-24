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

## 2026-08-23 - Loop CI Malam: Compile Fixes + PR #27 Merged

**The Change:** Tiga iterasi compile-fix setelah push Sprint 1: (1) 18 panggilan `expect` di `Support/RDARFixCheck.swift` ditambah `try` (helper-nya throws; Windows tak bisa compile Swift sehingga tertangkap pertama kali di runner macOS); (2) `SessionLogger.log` -> `SessionLogger.shared.log` dan property ObjC `activeMethod` diekspos ke Swift tanpa kurung (`ExploitManager.swift`, `BackupRestoreManagerView.swift`); (3) komentar header `CmgBridge.m` yang menempel pada deklarasi `kCmgOperationFlags` dipisah (menyebabkan undeclared identifier) + redeclare `activeMethod` readwrite di class extension `GestaltAccess.m`. Semua checker lokal tetap hijau tiap iterasi.

**The Reasoning:** Tanpa compiler lokal, siklus fix didorong penuh oleh log CI (gh run view --log-failed); assertion `check-feature.ps1` ikut disesuaikan saat pola kode berubah (kurung activeMethod). PR #27 di-squash-merge ke main (`dc0f573`) setelah build + RDAR harness hijau dan artifact `WorkPlot-IPA` terverifikasi ada.

**The Tech Debt:** Device test user masih pending (ikuti testing-plans/workplot-sprint-1.md). Asumsi path CMG `<container>/Library/Caches/com.apple.MobileGestalt.plist` belum terbukti di perangkat fisik - satu titik penyesuaian jika format get_path berbeda.

## 2026-08-23 - Wallpaper Journal: Undo Instal Wallpaper PosterBoard

**The Change:** File baru `WorkPlot/Managers/WallpaperJournal.swift` - singleton UserDefaults-backed (key `WorkPlotAddedWallpaperDescriptors`) berisi `addedDescriptors` (urutan tetap, unik), `record`, `remove`, `removeAll`. `PosterBoardAccess.writeDescriptors` kini `@discardableResult -> [String]`: mengumpulkan nama UUID folder yang dibuat lalu memanggil `WallpaperJournal.shared.record(...)` hanya setelah seluruh loop copy sukses; perilaku consume/release/createDirectory tidak diubah. `CustomizationThemeView` (PosterBoardLabView) dapat Section "Install Journal" (`wpj.title`) tepat setelah section wallpaper installed: baris count (`wpj.countLabel`, icon `list.badge.rectangle`) atau teks kosong (`wpj.empty`), plus tombol reset destruktif (`wpj.reset`, icon `trash`) dengan confirmation alert (`wpj.resetConfirm` %d). Reset jalan di background queue: `try? removeWallpaper(named:)` per nama, journal hanya dibersihkan untuk yang sukses (removeAll kalau semua sukses), log SessionLogger "wallpaper journal reset: N removed", status `wpj.removedOk` %d di main thread. Count journal di-refresh lewat `reloadInstalled()` sehingga ter-update saat onAppear, selesai install, dan selesai reset. Checker check-feature + check-l10n hijau; key wpj.* sudah tersedia sebelumnya, tidak ada key baru.

**The Reasoning:** Journal menyimpan array nama descriptor folder (bukan mapping ke file tendies asal) karena itu satu-satunya identitas stabil yang dimiliki WorkPlot atas folder yang ia tulis ke PosterBoard. `record()` dipanggil setelah loop penuh agar partial failure tidak tercatat sebagai instal lengkap. Section menempel pada gating existing view (hanya tampil saat `manager.sandboxGranted && PosterBoardAccess.isAvailable`) tanpa gate tambahan, mengikuti pola list/font/borderless button yang sudah ada.

**The Tech Debt:** Tidak ada compiler Swift lokal (Windows) sehingga verifikasi bergantung checker lokal + CI xcodebuild; unit test kecil untuk WallpaperJournal belum ada karena dilarang membuat file di luar whitelist work order ini. Descriptor yang dihapus manual lewat File Workspace akan tertinggal di journal - reset tetap aman karena hanya yang sukses terhapus yang dibersihkan.

## 2026-08-23 (malam) - RDAR Multi-Candidate + Audit Siri + Sprint 2 Batch

**The Change:**
1. **RDAR fix path resolver**: query lama ditolak ContainerManager karena target tidak ada - nama file yang benar terdokumentasi adalah com.apple.iokit.IOMobileGraphicsFamily.plist (huruf besar IOKit) di /var/mobile/Library/Preferences (BetterRes/misakaX/FixRDAR4XR11). Kini 3 kandidat diprobe berurutan via lease masing-masing; kandidat pertama yang bisa dibaca dipakai; error gabungan merangkum semua kegagalan. restoreOriginalCanvas memakai backup milik kandidat yang ada.
2. **Audit statis rantai Siri AI** (agent): bersih tanpa perubahan - marker CacheData tervalidasi beda tepat 1 char index 29 A->g, saveGestaltOrThrow tepat 1x, key SiriMode benar.
3. **F3 wallpaper install journal**: WallpaperJournal.swift baru (UserDefaults); PosterBoardAccess.writeDescriptors mencatat nama UUID descriptor yang dibuat; CustomizationThemeView dapat Section Install Journal dengan reset additive-only (hapus hanya yang dicatat WorkPlot).
4. **F4 patch packages**: PatchPackageStore.swift + PatchPackageManagerView.swift baru (folder Documents/Patch Packages: manifest.json + replacements/<bundleID><path>; apply = resolve container via MCM metadata scan -> backup stock idempotent -> lease + InodeWriter; rollback restore originals; password SHA256 CryptoKit; import folder via fileImporter). Link di More menu.
5. Strings: +20 key (wpj.*, pp.*).

**The Reasoning:** ContainerManager menolak query untuk file yang tidak exist, sehingga probing kandidat adalah cara paling murah menemukan lokasi yang benar per build tanpa asumsi keras. Patch package sengaja pakai folder+manifest.json alih-alih ZIP agar tidak menambah dependency; rollback idempotent mengikuti pola backup-pertama-stock seperti RDAR.

**The Tech Debt:** Belum ada bukti device bahwa salah satu kandidat RDAR benar-benar exist di iOS 27 beta user (kalau ketiganya gagal, langkah berikutnya: discovery dinamis /var/containers/Data/System ala FilzaSlop). Rollback package belum menghapus originals. Katalog online wallpaper (Nugget-Wallpapers JSON) ditunda ke sesi berikutnya.

## 2026-08-23 (dini hari) - Merge PR #28 & #29, Guard Traversal

**The Change:** PR #28 (RDAR multi-candidate + wallpaper journal + patch packages) dan #29 (guard ".." pada rule path manifest) squash-merged ke main; kedua CI hijau dengan artifact WorkPlot-IPA. Branch feat di-realign ke origin/main via reset --hard setelah tiap squash-merge untuk menghindari konflik historis berulang.

**The Reasoning:** Squash-merge meninggalkan histori branch yang tumpang tindih dengan main sehingga PR berikutnya selalu CONFLICTING; pola realign setelah merge menyelesaikan itu permanen. Guard traversal ditambahkan setelah review mandiri kode agen: rule.path "/../../x" lolos validasi lama dan bisa keluar container/originals.

**The Tech Debt:** Katalog online Nugget-Wallpapers (F3b) belum dikerjakan; Sprint 3 (App Containers root discovery ala FilzaSlop, hex/sqlite viewer, cache cleaner, onboarding+update checker) masih pending. Semua fitur malam ini butuh validasi device user: RDAR harus mencari plist di salah satu 3 kandidat; patch package end-to-end; journal reset.

## 2026-08-23 - Wallpaper Catalog Online (F3b, Nugget-Wallpapers)

**The Change:** File baru `WorkPlot/Managers/WallpaperCatalogService.swift` - `CatalogKind` (.custom/.apple -> wallpapers-<kind>.json), `CatalogEntry: Decodable`, `WallpaperCatalogService` static-only: `fetchCatalog(kind:)` (URLSession async), `previewURL(for:)`, `downloadAndExtract(entry:)` (unduh .tendies ke folder tmp unik -> `FileManager.unzipItem` via ZIPFoundation SPM -> kembalikan folder anak dari subfolder "descriptor"/"descriptors"; format "container" ditolak dengan error eksplisit; tmp dibersihkan via defer), dan `install(descriptorFolders:name:)` (findPosterBoardHash + writeDescriptors; journal tercatat otomatis di writeDescriptors; log SessionLogger sukses). File baru `WorkPlot/UI/WallpaperCatalogView.swift` - NavigationStack + List + workPlotScrollBackground(), segmented Picker Community/Apple (cache per kind via `.task(id:)`, tanpa refetch), AsyncImage preview h=120 scaledToFit cornerRadius, nama + description lineLimit(2) + caption "by %@", tombol Install per baris yang disabled saat gate `manager.sandboxGranted && PosterBoardAccess.isAvailable` gagal atau sedang ada instalasi berjalan; state installing = ProgressView + cat.installing; sukses -> statusText cat.appliedOk + respringRequested; gagal unduh/instal -> alert cat.downloadFail dengan localizedDescription + log SessionLogger. Fetch katalog gagal -> pesan cat.catalogFail + tombol retry (common.retry). `CustomizationThemeView` hanya dapat 11 baris: @State isShowingCatalog + Button Label cat.openCatalog icon sparkles (di section labHeader, dekat import tendies) + .sheet membuka WallpaperCatalogView. Checker check-feature + check-l10n hijau; semua key cat.* sudah tersedia sebelumnya - nol key Localizable baru.

**The Reasoning:** Sheet alih-alih NavigationLink karena PosterBoardLabView masih NavigationView iOS-klasik; menumpuk NavigationStack di dalam push NavigationView menghasilkan double nav bar. Gate install diperiksa ulang di view (bukan hanya menyembunyikan list) supaya tombol tetap terlihat tapi nonaktif saat sandbox/bad_query tidak siap. ZIPFoundation hanya diimport di service file sesuai batasan work order.

**The Tech Debt:** Tidak ada compiler Swift lokal (Windows) sehingga verifikasi bergantung checker statis + CI xcodebuild; decode JSON dan unzip belum diuji runtime. Cache katalog in-memory per sesi saja (tidak persist). Preview gif dimuat penuh oleh AsyncImage tanpa downsampling - kalau berat, ganti ke thumbnail generator.

## 2026-08-23 - App Containers & Cache Cleaner

### The Change

- Added `WorkPlot/Managers/AppContainerScanner.swift`: scans the three MCM data-container roots via bad_query_list, reads MCMMetadataIdentifier from each container metadata plist through consume/release, measures Library/Caches (+ SplashBoard/Snapshots) size under lease, wipes Caches contents best-effort inside BadQueryLeaseScope, logs to SessionLogger.
- Added `WorkPlot/UI/AppContainersView.swift`: gated list of containers (bundleID monospaced, path caption truncated middle), searchable by bundleID, rows NavigationLink to CacheCleanerView, toolbar clean-all menu with progress state.
- Added `WorkPlot/UI/CacheCleanerView.swift`: per-app cache size (ByteCountFormatter), destructive confirm + clean, refresh after wipe, statusText feedback.

### The Reasoning

- Mirrored PatchPackageStore's private scan/consume helpers locally instead of exposing them (parallel-agent ownership boundaries).
- `cleanCache` returns freed bytes as @discardableResult so clean-all can summarize totals without re-scanning; signature stays compatible with a void call site.
- Unreachable scan roots are skipped unless nothing lists at all, so partial results still render on device.
- Only existing ac.*/cc.* keys used (plus pre-existing home.locked/common.failPrefix); zero Localizable additions.

### The Tech Debt

- cacheBytes treats unreadable directories as 0 bytes (marked with ponytail comment); exact per-dir error reporting only if ever needed.
- SplashBoard/Snapshots are counted but not deleted; wire deletion later if desired.
- Wiring pending (other agents): FilePatchWorkspaceView/MoreMenuView shortcuts should point at AppContainersView(); files are auto-included via PBXFileSystemSynchronizedRootGroup so no pbxproj edit was needed.

## 2026-08-23 - Hex/SQLite Viewers + Update Checker (F5b/F6)

### The Change

- Added `FileHexViewerSheet.swift`: first-4KB hex dump (offset / 16-byte hex / ASCII gutter), monospaced 11pt, bidirectional scroll, copy-to-pasteboard via UIPasteboard.
- Added `FileSqliteViewerSheet.swift` + `SQLiteDatabase` helper: db copied to tmp then opened `sqlite3_open_v2` READONLY; table list from sqlite_master, per-table SELECT limited to 200 rows via localized `sqlite.selectFirst`, NULL-safe column text.
- Added `UpdaterService.swift`: GitHub releases/latest fetch (Accept: application/vnd.github+json), honest HTTP/payload errors, numeric-only semver compare (`isNewer`).
- Added `UpdateCheckerSheet.swift`: check -> loading -> newer tag (+openURL) / up-to-date / failure with retry.

### The Reasoning

- Each SQLite operation copies-reads-closes-deletes in one scoped call (`withReadOnlyCopy`) so no handle or tmp file can outlive the sheet and no shared OpaquePointer crosses views; pushed row view reopens its own connection.
- No new Localizable keys were added (constraint); the hex "first 4 KB" note is a plain English literal, which check-l10n permits.

### The Tech Debt

- `FileBrowser.readData` reads whole files into memory before the 4KB slice; fine for prefs-scale files, needs offset-based reads if huge binaries are browsed.
- Hex grid scrolls both axes on narrow iPhones (16 bytes/line mandated by spec).

## 2026-08-23 - Batch F3b/F5/F6: Katalog Online, Containers, Viewers, Updater

**The Change:** (1) F3b katalog online Nugget-Wallpapers (WallpaperCatalogService + WallpaperCatalogView; download .tendies -> unzip ZIPFoundation -> descriptor folders -> writeDescriptors; journal otomatis tercatat). (2) Dependency SPM pertama: ZIPFoundation 0.9.x via XCRemoteSwiftPackageReference di pbxproj (dibutuhkan untuk unzip .tendies). (3) F5a AppContainerScanner (MCM metadata scan 3 root) + AppContainersView + CacheCleanerView (clean isi Library/Caches dalam lease). (4) F5b FileHexViewerSheet (4KB dump) + FileSqliteViewerSheet (SQLite3 readonly copy-to-tmp). (5) F6 UpdaterService + UpdateCheckerSheet (GitHub releases latest). Wiring manual gue: routing viewer .binary -> sqlite/hex, Hex View di context menu, NavigationLink AppContainersView di shortcut Files + More menu, tombol Update Checker di More menu, tombol Browse Online Catalog di CustomizationThemeView.

**The Reasoning:** ZIPFoundation dipilih daripada menulis parser ZIP sendiri (battle-tested, MIT, satu produk dependency). SQLite viewer bekerja pada salinan tmp supaya lease sandbox tidak perlu hidup selama sesi baca. Container scanner memakai pola MCM metadata yang sama dengan PatchPackageStore agar konsisten.

**The Tech Debt:** Descriptor ID internal wallpaper katalog belum dirandomisasi ulang (folder-level UUID saja) - potensi tabrakan ID kalau install wallpaper yang sama dua kali; ikuti pola randomize Nugget kalau jadi masalah. SplashBoard/Snapshots dihitung tapi belum dihapus oleh cleaner.

## 2026-08-23 (pagi) - Sprint 2/3 Selesai: PR #30 Merged

**The Change:** PR #30 squash-merged (4985e97): katalog online Nugget-Wallpapers, App Containers + Cache Cleaner, hex/sqlite viewer, update checker. Dua iterasi compile-fix (label argument SQLiteError x3, Int32->Int reserveCapacity). README tabel fitur disinkronkan.

**The Reasoning:** Wiring routing viewer & menu dikerjakan terpusat oleh satu tangan setelah 3 agent selesai supaya tidak ada konflik file; ZIPFoundation jadi dependency SPM pertama karena menulis parser ZIP sendiri bukan trade yang masuk akal.

**The Tech Debt:** Onboarding wizard ditunda (nilai rendah vs risiko). Descriptor ID katalog belum dirandomisasi ulang penuh (folder-level saja). Semua fitur batch ini belum teruji device - prioritas tes user: RDAR resolver, patch package, katalog install, cache cleaner.

## 2026-08-23 (pagi II) - PR #31: Laporan Device User Round 1

**The Change:** (1) RDAR: 3 kandidat statis ditolak di device user; tambah probe dinamis /var/containers/Data/System/*/Library/Preferences/com.apple.iokit.IOMobileGraphicsFamily.plist (daemon containers iOS 27). (2) PosterBoard: generasi PRBPosterExtensionDataStore tidak lagi hardcode 61 - dideteksi live dari device; scan hash +root Data/System. (3) Patch package: Create Sample Package + footer format + scan +Data/System.

**The Reasoning:** Pola kegagalan yang sama (stage=query rejected) pada semua path non-container menunjukkan policy allowlist ContainerManager hanya membuka pohon container; daemon prefs yang dipindah ke Data/System adalah satu-satunya harapan RDAR tanpa jailbreak. PosterBoard gagal kemungkinan besar karena generasi store berubah di iOS 27.

**The Tech Debt:** Toggle Internal Storage (LBJfwOEzExRxzlAnSuI7eg=InternalBuild) SUDAH ada sejak awal di katalog internalFeatures - perlu dokumentasi urutan pakai untuk user. Kalau probe Data/System pun gagal semua, RDAR resmi impossible via bad_query pada build tsb dan tombolnya harus jadi unavailable-state.

## 2026-08-23 - PR #32: RDAR via MobileGestalt (Celah Baru)

**The Change:** Tweak "RDAR Canvas Fix (Gestalt)" di kategori Display: menulis key MainScreenCanvasSizes (ybGkijAwLTwevankfVzsDQ, ada sejak iOS 10) ke CacheExtra memakai native bounds device. Format adaptif: value existing dipertahankan bentuknya (Data >= 8 byte -> overwrite 8 byte pertama; [Int]/[UInt32] -> ganti dua elemen pertama); tanpa value existing -> blob 8-byte LE width+height. Wiring di GestaltPresetManagerView.applySelected() ala AIRegionApplier.

**The Reasoning:** Dimensi canvas dilayani lewat MobileGestalt, bukan hanya plist grafis yang diblok policy ContainerManager. Jalur gestaltcache/CMG terbukti jalan di device user, jadi ini satu-satunya vektor RDAR yang tidak melawan allowlist. Komentar iOS 10.0+ di MGKeys adalah availability floor (key kumulatif), bukan batas atas - preseden: key iPad Mode iOS 7.0+ tetap bekerja.

**The Tech Debt:** Format internal MainScreenCanvasSizes belum terverifikasi trace device (asumsi 8-byte LE pair mengikuti tooling komunitas). Kalau IOMobileFramebuffer berhenti membaca key ini di iOS 27 beta, toggle tetap aman ditulis tapi efek kosong - tandanya fallback ke unavailable-state untuk kedua pendekatan.

## 2026-08-23 (siang) - PR #33: Path Absolut + Dashboard RDAR Satu-Tap

**The Change:** (1) bad_query_list ternyata mengembalikan path ABSOLUT anak direktori; loop probe Data/System membangun path dobel sehingga seluruh sweep salah alamat (terbongkar dari laporan error user). Kini path dipakai langsung. (2) Tombol Fix rdar di dashboard kini menulis MainScreenCanvasSizes via saveGestaltOrThrow - satu tap tanpa probing, karena plist grafis terbukti tidak ada dan tidak reachable di build ini; pesan fallback probe mengarahkan user ke tweak Gestalt. (3) Digest error dibatasi 6 entri.

**The Reasoning:** Laporan device membuktikan file com.apple.iokit.IOMobileGraphicsFamily.plist tidak ada di lokasi manapun yang reachable - itu file override opsional yang hanya ada bila dibuat. Satu-satunya vektor hidup adalah MobileGestalt; dashboard harus memakainya langsung daripada menjalankan sweep yang pasti gagal.

**The Tech Debt:** Efek nyata MainScreenCanvasSizes di iOS 27 beta belum terkonfirmasi device (menunggu tes user). AppContainerScanner/cache cleaner kemungkinan besar juga kena bug path absolut yang sama - AUDIT DAN FIX DI BATCH BERIKUTNYA.

## 2026-08-23 (sore) - PR #35: File Browser Dinamis ala Filza

**The Change:** Shortcut statis diganti sistem reachability dinamis: 11 kandidat lokasi (SystemGroup, Data/System, Application, InternalDaemon, PluginKit, AppGroup + legacy Preferences/jb) diprobe sekali via bad_query_list; hanya yang lolos tampil di UI, hasilnya di-cache per instalasi (UserDefaults). Kalau probe gagal semua, fallback ke dua pohon container terdokumentasi agar layar tidak kosong. Probing jalan di background queue dengan ProgressView "fp.scanning".

**The Reasoning:** Laporan device: 4 dari 5 shortcut lama (Preferences/varprefs/jb/jailbreak) ditolak policy sehingga setiap tap menghasilkan error stage=query. Filza menampilkan hanya mount yang accessible - pola sama diterapkan di sini supaya tidak ada tombol yang pasti gagal.

**The Tech Debt:** Reachability di-cache tanpa TTL; kalau Apple membuka pohon baru di beta berikutnya, user perlu reinstall/clear data untuk re-probe (atau kita tambah tombol re-scan nanti).

## 2026-08-23 (malam) - PR #36: MHA Labels, ACCESS MAP, Filter Picker, Custom Canvas

**The Change:** (1) Shortcut file browser berlabel container class MHA ([MHA-C13] dst) mengikuti model FilzaSlop; probe pertama menulis Documents/ACCESS MAP.txt (OK/BLOCKED + jumlah entri), cache reachability berkunci build OS. (2) UTI com.workplot.tendies & com.workplot.patch3105 didaftarkan di Info.plist (UTImportedTypeDeclarations) + FileTypes.swift bersama - PosterBoard kini hanya menerima .tendies, menu Patch hanya .3105; picker mengabukan format lain. (3) Custom Canvas di dashboard: input WxH bebas via rute gestalt. (4) applyCanvas di StatusDashboardView kini membaca balik plist dari disk dan membandingkan byte pertama CGSize; status "verified on disk" vs "not visible on disk - blocked by system".

**The Reasoning:** Laporan device: RDAR apply sukses di log tapi efek nihil. Karena tidak ada error, satu-satunya cara membedakan "tulisannya ditolak diam-diam" vs "OS mengabaikan key" adalah verifikasi baca-balik. Custom canvas sekaligus jadi alat tes: nilai aneh (999x999) yang tetap nihil setelah reboot = mekanisme memang diabaikan build ini.

**The Tech Debt:** BackupRestoreManagerView masih pakai .data untuk import backup gestalt (dikecualikan user). Kalau mekanisme gestalt terbukti mati di build ini, tombol rdar harus jadi unavailable-state jujur.

## 2026-08-23 (malam) - PR #37: Regresi stage=token + Pocket Poster tricks

**The Change:** (1) Menghapus seluruh mekanisme probe reachability di FileBrowser (reachableShortcuts/canList/writeAccessMap/cache) - registry kembali statis penuh dengan label MHA. (2) Picker PosterBoard menerima [.tendies, .zip]. (3) TendiesPackage.randomizeIdentifiers(in:) mengacak identifier wallpaper sebelum install; PosterBoard dibuka otomatis via LSApplicationWorkspace setelah sukses. (4) README disinkronkan (fitur baru, troubleshooting, kredit neospring/FilzaSlop/3105).

**The Reasoning:** Laporan device build 3759eea: browsing file gagal "bad_query stage=token did not receive a sandbox token" dan App Containers hang scanning. Pola waktunya cocok dengan probe 11 path saat tab Files dibuka - containermanagerd tampaknya menolak penerbitan token untuk proses setelah ledakan query itu (probe bare rawList lolos karena tidak butuh token). Pelajaran: jangan hammer CMG; listing statis + error per-tap lebih aman. Trik randomizeWallpaperId dan openPosterBoard diport dari leminlimez/Pocket-Poster (GPL-3.0).

**The Tech Debt:** File .3105 ternyata format terenkripsi (header 3105PATCH\0 + plist berisi PBKDF2 250k iterasi, wrappedContentKey, encryptedPayload) - applier butuh password dari pemilik package sebelum bisa dibangun. Patch Packages (.wplot folder) dipertahankan sebagai satu-satunya mekanisme patch yang berfungsi sampai .3105 native siap.

## 2026-08-23 (malam) - PR #38: Patch Native .3105

**The Change:** Patch3105.swift baru: parse magic "3105PATCH\0" + plist envelope (schemaVersion, kdfSalt, kdfIterations=250000, wrappedContentKey, keyFingerprint, encryptedPayload). Package terproteksi memunculkan SecureField password di dalam app; dekripsi best-effort PBKDF2-HMAC-SHA256 + AES-GCM via CryptoKit/CommonCrypto; rules dibaca dari payload plist {"rules":[{bundleID,path,data|content}]}; apply lewat PatchPackageStore.resolveTargetPath + lease + InodeWriter dengan backup originals di Documents/Patch Packages/<packageID>/originals/. PatchPackageManagerView dan seluruh alur folder .wplot dihapus; menu Patch Packages keluar dari More. Tab Files kini hanya menerima .3105 dan tiap import langsung jadi patch flow.

**The Reasoning:** User melarang menanyakan password secara manual dan ingin fitur patch khusus format .3105. Skema enkripsi resmi tidak tersedia publik sehingga crypto dikodekan best-effort dengan failure tunggal yang jujur ("wrong password / unsupported scheme") supaya tes device menghasilkan sinyal iterasi berikutnya.

**The Tech Debt:** (1) Jika GCM ternyata bukan skema wrap-nya (mis. AES-KW RFC3394), butuh implementasi KW manual atau spec asli. (2) Rollback UI untuk originals .3105 belum ada - data sudah tersimpan rapi per packageID. (3) Payload berbentuk ZIP ditolak eksplisit untuk saat ini.

## 2026-08-23 (malam) - PR #39: Bedah Binary 3105 Asli

**The Change:** User menyediakan IPA asli app 3105 (3105-unsigned.ipa); binary-nya dibedah via strings dump. Konfirmasi: crypto patch memakai CCKeyDerivationPBKDF + CryptoKit AES.GCM (sesuai implementasi #38), sistem patch berbasis project workspace dengan rules {bundleID, relative path, replacement file}, dan payload .3105 diekspor sebagai bundle tree. Patch3105 kini mendukung tiga layout payload: ZIP tree (folder top-level = bundle ID, manifest opsional), plist rules array, dan contentKey polos untuk package tanpa password; KDF mencoba SHA256 lalu SHA512. Sisi wallpaper: writeDescriptors memverifikasi jumlah descriptor dari disk + mencatat store generation & path ke SessionLogger; pesan purna-instal mengikuti panduan resmi 3105 untuk iOS 27.

**The Reasoning:** Laporan user: wallpaper tidak muncul di Collections dan .3105 masih gagal. String milik 3105 sendiri mengungkap dua hal kunci: store generation PosterBoard tidak boleh diasumsikan (sudah kita tangani liveGeneration), dan iOS 27 mensyaratkan Collections wallpaper dipasang lebih dulu plus refresh lewat app switcher - sesuatu yang tidak bisa diselesaikan kode saja, sehingga dikomunikasikan lewat UI guide.

**The Tech Debt:** (1) check-feature/check-l10n lokal tidak mengkompilasi Swift, jadi syntax error lolos sampai CI - CI adalah gerbang kompilasi sesungguhnya, tiga kali push perbaikan tipe/syntax diperlukan. (2) Skema wrap kunci masih best-effort; error device akan menentukan iterasi. (3) Rollback UI .3105 belum ada.

## 2026-08-23 (malam) - Perapian Tab Siri AI: Jalur Baru vs Lama Terpisah

**The Change:** Tab Siri AI direstrukturisasi jadi 5 blok: Status read-only (chip Siri AI CacheData / Apple Intelligence / spoof aktif), Siri AI (iOS 27) satu toggle metode baru (patch CacheData Toto + flag a3n5T9sFtlyQ74NEp9ESxg digabung di sini), Apple Intelligence (Legacy) toggle eligibility-only yang otomatis memilih target spoof terbaru saat dinyalakan, Device Spoof (Advanced) dengan picker + hitungan key, dan Apply. Duplikat dihapus: tweak .siriMode di tab Gestalt (tak punya jalur revert), section "Siri Mode" standalone, toggle Eligibility & Model Key, file SiriAIExtraToggles.swift (AIRegionEligibilityApplier + ModelSpoofKeyApplier). AppleIntelligenceController kini murni eligibility (tidak lagi menyusup menulis flag mode). Warning spoof diperluas (Face ID/FaceTime/OTA + catatan backup otomatis) dan tampil untuk semua apply yang menyentuh identitas model. Strings EN baru untuk status/section; 10+ key yatim dibuang.

**The Reasoning:** Provenance scan binary empat IPA referensi (3105, GestaltEdit, GestaltTweak, mond): eligibility A62Oaf... dan ProductType h9jDsb... ada di 3/3 tool komunitas (proven), sedangkan flag a3n5T... nol dari empat (terlemah). Kombinasi itu memotivasi model mental user yang eksplisit: Apple Intelligence = jalur lama (key eligibility), Siri AI = jalur baru (CacheData patch, versi upgrade). Auto-spoof saat Apple Intelligence dinyalakan adalah permintaan user langsung ("kalau aktifin apple intelligence aktifin juga mode spoofing") dan selalu lewat warning penuh karena menulis identitas model berisiko Face ID.

**The Tech Debt:** (1) Build diverifikasi via CI round-trip - Windows tidak bisa kompilasi Swift, review manual + grep sweep adalah gerbang lokal. (2) Flag a3n5T... tetap ditulis bersama toggle Siri AI walau tak ada di tool referensi; kalau device membuktikan tak berguna, cukup hapus satu baris di applyChanges. (3) Status chip membaca plist dari disk setiap render (pola pre-existing loadedPlist), belum di-cache.

## 2026-08-23 (malam) - Custom Canvas: Jalur Graphics Plist Klasik Ke-Expose

**The Change:** Status Dashboard section Custom Canvas kini punya dua tombol: Apply Custom Canvas (Gestalt, existing) dan Apply via Graphics Plist (Classic) baru - memanggil RDARFix.apply(canvasWidth:canvasHeight:) yang selama ini orphan (tidak pernah dipanggil UI mana pun): probe 3 lokasi IOMobileGraphicsFamily.plist + fallback kontainer /var/containers/Data/System, backup stock permanen, patch canvas_width/canvas_height, tulis terverifikasi InodeWriter. Hasil .applied -> prompt restart penuh; .alreadyFixed -> status jujur; gagal dijangkau -> pesan probe lengkap. Strings EN baru (applyPlist/plistApplied/plistAlready).

**The Reasoning:** Laporan device user: canvas lewat Gestalt tertulis verified on disk tapi RDAR + zoom tetap setelah restart penuh - beta build yang dipakai mengabaikan MainScreenCanvasSizes dari CacheExtra. Jalur plist klasik adalah metrik yang dipakai komunitas sejak era BetterRes/misakaX/FixRDAR4XR11 dan prasyaratnya (bad_query aktif) terpenuhi di setup user tersebut. Mesin sudah ada sejak awal, hanya tidak ke-wire ke UI.

**The Tech Debt:** (1) Build diverifikasi via CI round-trip (Windows tak bisa kompilasi Swift). (2) Efektivitas jalur plist pada iOS 27 beta tiap build belum terbukti - kalau semua lokasi unreachable, pesan probe yang muncul adalah sinyalnya. (3) Tombol Fix RDAR auto-detect masih menulis nativeBounds yang berpotensi terpolusi saat render zoomed - pertimbangkan tabel resolusi per-model di iterasi berikut.

## 2026-08-23 - Removal: Fitur PosterBoard/tendies Dihapus Seluruhnya

**The Change:** Fitur wallpaper PosterBoard dicabut end-to-end. (1) Infrastruktur ZIP generik dipindah dari TendiesPackage.swift ke Managers/ZipArchive.swift baru (TendiesPackage→ZipArchive, TendiesEntry→ArchiveEntry, TendiesError→ZipArchiveError; hanya writeArchive + parser internal yang dibawa, validate/extract/randomizeIdentifiers ikut mati bersama fitur); Patch3105.decodeZipTree kini memanggil ZipArchive.writeArchive. (2) File dihapus: CustomizationThemeView, WallpaperCatalogView, PosterBoardAccess, WallpaperCatalogService, WallpaperJournal, folder Resources/TendiesWallpapers (7 file). (3) Wiring: UTType.tendies keluar dari FileTypes, NavigationLink PosterBoard Lab keluar dari MoreMenuView, deklarasi com.workplot.tendies keluar dari Info.plist, seluruh referensi ZIPFoundation (package dep + build phase) keluar dari project.pbxproj. (4) Localizable.strings: tab.posterboard, posterboard.import, pb.* (kecuali pb.apply untuk BackupRestoreManagerView), wpj.*, cat.*, plus komentar section terkait — 423→388 key. (5) README: baris fitur PosterBoard Lab dihapus, troubleshooting file picker kini hanya menyebut .3105.

**The Reasoning:** Work order presisi dari user: fitur depend ke akses PosterBoard yang tidak bisa diverifikasi, jadi dicabut utuh tanpa meninggalkan jalur setengah hidup. Mesin ZIP tetap disimpan karena decoder payload .3105 butuh writeArchive untuk ZIP tree — pemisahan nama generik mencegah coupling semantik "tendies" di kode patch. check-l10n dijalankan dua kali (baseline sebelum edit + final): baseline juga mengonfirmasi kegagalan pre-existing check-feature.ps1 pada asersi SiriMode MGKeys (GestaltTweaks/AppleIntelligenceController tidak memuat key a3n5T... sama sekali) sehingga kegagalan itu bukan regresi removal ini.

**The Tech Debt:** (1) Build tetap terverifikasi hanya via CI round-trip — verifikasi lokal berbasis grep + script statis, tidak kompilasi Swift. (2) check-feature.ps1 masih merah karena asersi SiriMode MGKeys pre-existing (di luar scope work order ini, dibiarkan apa adanya). (3) Error message deflateDecode diterjemahkan ke EN saat migrasi (sebelumnya campur ID) sesuai aturan UI copy English.

## 2026-08-23 (malam) - Fix: Kegagalan Patch CacheData Tidak Lagi Membatalkan Apply Gestalt

**The Change:** Laporan user: Color Palette, Legacy Color Palette, dan Camera 2x Zoom tidak bisa di-apply. Akar masalah: ketiganya satu-satunya tweak dengan requiresCacheDataFlag=true; saat CacheDataPatcher.applyCapabilityFlag melempar error (marker CacheData tidak dikenali di build device), blok catch applySelected membatalkan SELURUH transaksi sebelum satu byte pun ditulis. Kini kegagalan flip flag ditangkap terpisah: nilai CacheExtra tetap ditulis dan disimpan, status menambah notice jujur (gestalt.cacheFlag.skipped), dan detail error masuk Session Log.

**The Reasoning:** Abort total melanggar least-surprise - nilai CacheExtra yang valid ikut dibuang hanya karena satu langkah eksperimental gagal. Degradasi + pelaporan menjaga integritas data (backup otomatis tetap jalan) tanpa mematikan sinyal diagnostik.

**The Tech Debt:** Marker CacheData yang tak dikenali pada build tertentu berarti fitur dual-cache kemungkinan tidak aktif walau apply sukses - butuh riset offset per-build bila ingin benar-benar hidup.

## 2026-08-23 (malam) - Fix Import Backup, Keyboard Dismiss, Canvas Satu Tombol, Audit Alur Siri vs Referensi

**The Change:** (1) fileImporter backup pakai [.data] yang membuat file .plist ter-gray-out di document picker - kini [propertyList, xmlPropertyList, binaryPropertyList, data]; validasi isi (dict + CacheExtra) tidak berubah. (2) .scrollDismissesKeyboard(.immediately) dipasang di semua layar ber-input teks: Status Dashboard, Gestalt tweaks, Field Editor, File Patch Workspace - keyboard bisa ditutup geser setelah mengetik (kasus width/height). (3) Custom Canvas kini SATU tombol: applyCanvasEveryRoute menulis dua jalur sekaligus (Gestalt MainScreenCanvasSizes dengan verify-on-disk + IOMobileGraphicsFamily.plist klasik), status multi-baris jujur per jalur, satu baris Session Log; 2 tombol lama dan 3 key strings yatim dihapus; tombol one-tap Fix RDAR dialihkan ke fungsi superset ini. (4) Audit alur Siri terhadap metode manual komunitas (FilzaSlop+GestaltEdit): marker CacheData OFF/ON WorkPlot byte-identical (68 char) dengan instruksi manual; step ProductType h9jDsb=AI-device tercakup spoof picker (target iPhone 17 Pro = iPhone18,1); step eligibility A62Oaf...=1 = toggle Apple Intelligence; trik Charge Limit milik UI GestaltEdit tidak relevan.

**The Reasoning:** User melaporkan import plist tak bisa diseleksi, keyboard menutupi setelah input width/height, dan kebingungan dua tombol canvas. Satu tombol dual-route memberi peluang sukses maksimal tanpa memaksa user pilih mekanisme; hasil per jalur tetap dilaporkan apa adanya karena build tertentu mengabaikan salah satunya.

**The Tech Debt:** Efektivitas jalur graphics plist per build masih butuh konfirmasi device; Display Zoom Larger mengubah render buffer (750x1624) dan belum ditangani khusus.

## 2026-08-23 (malam) - Restart Flow Dua Tombol Jujur + Klarifikasi Bug Apply Color Palette

**The Change:** Alert pasca-apply heavy tweak kini 2 tombol: Respring (aksi nyata via WebKit crash + recovery timer 10 detik) dan Restart Steps (sheet panduan gabungan userspace 3 langkah + full restart 4 langkah). Sebelumnya 3 tombol - dua di antaranya (Restart Userspace/Full) hanya membuka panduan sehingga terkesan "restart tidak jalan"; label baru menegaskan itu panduan karena sandbox memang tidak bisa spawn launchctl. RestartAction enum, sheet item-binding, dan 2 key strings lama dihapus; key baru restart.action.guide. check-feature.ps1 assertion diperbarui: wajib ada respring + guide, dilarang mengandung launchctl.

**The Reasoning:** Keluhan user "tombol kedua restart gak jalan" adalah ekspektasi vs label: app secara teknis tidak bisa reboot device dari sandbox (bad_query read/write only). Solusi jujur = namakan aksinya apa adanya, bukan pura-pura eksekusi.

**The Tech Debt:** Color Palette (varian graphics) tetap terkunci deviceGate iphone13OrLater di iPhone 11 - by design; Legacy Palette & Graphics Style sekarang apply sukses dengan notice bila marker CacheData tak dikenali (fix PR #42). User wajib pakai IPA build terbaru untuk merasakan perbaikan tersebut.

## 2026-08-23 (malam) - Fitur Baru: Disable Dynamic Island (iPhone 14 Pro ke Atas)

**The Change:** Tweak baru "Disable Dynamic Island" di tab Gestalt (kategori Display): menulis kunci capability yang sama dengan toggle enable (YlEtTtHlNesRBMal1CqRaA) bernilai 0 sehingga SpringBoard memperlakukan device sebagai tanpa island - cutout depan fallback jadi pill polos. Entri katalog baru gated .iphone14ProOrLater (case gate baru: hw.machine family >= 15, yaitu iPhone15,* = 14 Pro s/d seri terbaru; device notch family <= 14 otomatis disembunyikan + caption unsupported). Ditandai EXPERIMENTAL dan wajib respring. Binding toggle kini saling-mengeksklusikan pasangan enable/disable Dynamic Island (pola yang sudah ada untuk Liquid Glass on/off) agar dua nilai bertentangan tidak pernah ter-staged bersamaan - Set iteration membuat hasilnya nondeterministic bila dibiarkan.

**The Reasoning:** Ikut pola pasangan ON/OFF yang sudah terbukti di kodebase (lglowon/lglowoff: kunci sama, entri katalog terpisah) - nol file baru, nol jalur apply baru, semua lewat read-modify-write Gestalt yang sudah ada. Gate berbasis hw.machine asli (bukan CacheExtra terspoof) sesuai desain DeviceCapability.

**The Tech Debt:** Efek visual disable perlu konfirmasi device (14 Pro+) - bila build iOS tertentu mengabaikan nilai 0, opsi lanjutan adalah riset flip flag CacheData arah turun (CacheDataPatcher saat ini hanya flip naik ke 3); rollback tetap aman via Revert to stock.

## 2026-08-23 (malam) - Remove Island Pill (Notch Device) + Fix RDAR Known-Good Table

**The Change:** Laporan user iPhone 11: enable Dynamic Island memunculkan pil hitam nyangkut; pilih subtype (mis. "16 Pro") malah memicu RDAR dan tidak bisa difix kecuali restore backup. Akar masalah teridentifikasi di kode sendiri: nilai ArtworkDeviceSubType yang ditulis picker adalah TINGGI LAYAR device island (2436/2556/2622/dst) - menulis 2622 di device setinggi 1792 merusak komposisi tampilan. Empat perbaikan: (1) Tweak baru "Remove Island Pill" gated .belowIPhone14Pro (case gate baru, family <= 14): tulis capability YlEtTtHlNesRBMal1CqRaA=0 + strip ArtworkDeviceSubType via GestaltArtwork.removeDynamicIslandSubtype; mutual exclusion dengan toggle enable/disable island diperluas jadi trio. (2) Picker subtype diberi caption peringatan oranye di device tanpa island bawaan. (3) Fix RDAR tidak lagi percaya UIScreen.nativeBounds (saat RDAR aktif dia melaporkan canvas yang RUSAK; Display Zoom melaporkan buffer zoomed 750x1624): tabel known-good 28 model berdasarkan hw.machine di RDARFix.knownGoodNativeCanvases, fallback nativeBounds hanya untuk model tak dikenal dengan catatan jujur; overload Gestalt-tab ikut pakai tabel. (4) Diagnostik jujur: status menegaskan full restart wajib (respring tidak cukup untuk canvas), error graphics-plist kini dilaporkan detailnya (sebelumnya digest probe dibuang), SessionLogger juga append ke file session.log di Application Support (log RAM-only mati tepat saat reboot dibutuhkan), baris gagal kini oranye.

**The Reasoning:** Spesifikasi lama melarang tabel device karena percaya nativeBounds - asumsi itu persis yang membuat tombol buta dalam keadaan rusak yang mau difix-nya (input self-referential). User eksplisit memilih arah known-good table. Pil fake island pada notch device adalah artefak capability=1; mematikannya + membersihkan subtype mengembalikan perilaku stok tanpa harus restore seluruh plist.

**The Tech Debt:** Nilai stok ArtworkDeviceSubType per model tidak disnapshot (strip key = arah revert yang benar utk subtype hasil picker ini); efektivitas pil hilang per build iOS perlu konfirmasi device; session.log belum ada rotasi ukuran.

## 2026-08-23 (malam) - Perbaikan Kredit & Atribusi + Status Jujur Tweak Eksperimental

**The Change:** Kritik eksternal: (1) kredit campur aduk - 0xjohnnydev dan FilzaSlop tercatat sebagai DUA entri terpisah di CreditsView padahal satu orang/satu repo; metode respring (neospring/neonmodder123/skadz108) hanya dikredit di README tanpa link; Nugget/GestaltEdit/MobileHouseArrest-PoC tidak dicatat. (2) Terminologi tiga nama untuk satu hal: FilzaSlop = HouseArrest = sandbox escape. Perbaikan: CreditsView kini satu entri "FilzaSlop (HouseArrest sandbox escape)" plus entri baru MobileHouseArrest-PoC, Nugget & GestaltEdit, 3105 (GPLv3), neospring respring; daftar thanks tinggal individu (Mond/Ketamine/Toto); README Credits direstrukturisasi per kategori; THIRD_PARTY_NOTICES.md diperluas (bad_query GPLv3 incorporated, hubungan FilzaSlop/HouseArrest dijelaskan eksplisit, PoC cross-check, references-without-copied-code); README feature table memakai istilah "HouseArrest sandbox escape" konsisten. (3) Keluhan "tweak nulis key yang gak ada tapi tetap bisa dinyalakan": semua tweak eksperimental kini menyatakan status verifikasinya secara eksplisit di detail text - Disable Dynamic Island ("not yet independently verified"), Remove Island Pill ("not yet verified on every iOS build"), RDAR Canvas Fix Gestalt ("effectiveness per iOS build is not yet device-verified"); Color Palette/Legacy/GraphicsStyle/Zoom2x sudah jujur sebelumnya.

**The Reasoning:** Atribusi ganda membahayakan kepatuhan lisensi (GPL-3.0 project wajib atribusi bersih) dan membingungkan asal teknik. Satu istilah teknis (HouseArrest) dengan kredit demonstrator (FilzaSlop) memisahkan nama teknik dari nama app - mengikuti konvensi komunitas.

**The Tech Debt:** URL MobileHouseArrest-PoC memakai path 0xjohnnydev sesuai komentar kode sendiri sementara checker menyebut mond - kepemilikan repo perlu diverifikasi manual; ide emulasi/partial-restore dari kritikus ditunda (YAGNI, butuh bukti manfaat).

## 2026-08-23 (malam) - Hide Dynamic Island Completely (SpringBoard Flag) + Kredit Tester Beta

**The Change:** Laporan user: toggle Disable Dynamic Island gak jalan. Riset (Nugget release notes v7.2 + issue #1020 + source tweak_loader.py) membuktikan hipotesis: key MobileGestalt YlEtTtHlNesRBMal1CqRaA itu ENABLE-ONLY - nilai 0 = "hardware yang memutuskan" = island tetap nyala di device bawaan. Solusi baru mengikuti metode resmi Nugget >=7.2/EnsWilde: menulis bool SBSuppressDynamicIslandCompletely ke com.apple.springboard.plist lewat SpringBoardPlist.swift (file baru; probe 3 path statis + sweep container /var/containers/Data/System cap 64; PropertyListSerialization roundtrip preserve-format binary; tulis via InodeWriter.writeVerifiedInPlace yang sudah snapshot+rollback). Dua entri katalog pasangan Hide/Restore Dynamic Island (values kosong - apply-nya special-case di GestaltPresetManagerView seperti aiRegionUS, status per-path jujur di-append ke statusText), mutual exclusion dengan toggle enable island dan sesama pasangan. Kredit: baris ganda Johnny (FilzaSlop + MobileHouseArrest-PoC) digabung jadi satu entri, PoC dipindah ke detail text; section baru "Beta Testers" dengan entri nguyenls3005-cell (avatar GitHub otomatis) + tap memunculkan confirmationDialog pilih TikTok (@lsnguyyniu) atau GitHub.

**The Reasoning:** Mematikan island di device native lewat Gestalt mustahil secara desain (flag enable-only); daripada menambah key spekulatif (pola yang dikritik komunitas), diadopsi mekanisme terdokumentasi yang menyasar plist SpringBoard langsung - jalur tulis file non-Gestalt sudah teruji lewat rute RDAR graphics-plist.

**The Tech Debt:** Efektivitas suppress per build iOS perlu konfirmasi device (14 Pro+ untuk kasus asli user); Live Activities ikut hilang saat suppressed (perilaku Nugget yang sama); slot kredit tester beta sengaja dibuat extensibel (array testers) - nama tester tambahan tinggal ditambah tanpa ubah layout.

## 2026-08-23 (malam) - Audit Anti-Gimmick: Liquid Glass Pakai Metode Asli, Tweak Island Mati Dihapus

**The Change:** Riset paralel (web + audit kode) memverifikasi seluruh katalog fitur. Temuan: (1) tombol Disable Liquid Glass terbukti gimmick - menghapus key yang arahnya tak terverifikasi dan MENEMUKAN key top-level FeatureFlags.LiquidGlassSlider yang tidak dibaca komponen iOS mana pun, sambil menampilkan status "Liquid Glass disabled." yang overclaim. Ditulis ulang mengikuti metote terdokumentasi Nugget >=7.2/EnsWilde: menulis com.apple.SwiftUI.DisableSolarium=true + SolariumForceFallback=true ke semua copy .GlobalPreferences.plist yang terjangkau (Managed Preferences + mobile Library Preferences, PropertyListSerialization preserve-format), plus IsSolariumLowPerformanceDevice=1 di Gestalt untuk fallback renderer; key palsu LiquidGlassSlider kini DIBERSIHKAN dari plist user saat apply apa pun (undo kekacauan build lama). Status per-path jujur + caption baru menyatakan efek bergantung build iOS. (2) Tweak Disable Dynamic Island (14 Pro+) dan Remove Island Pill (notch) DIHAPUS sebagai no-op terkonfirmasi: key capability YlEt... itu enable-only (nilai 0 = hardware default = island tetap); keduanya sudah digantikan penuh oleh pasangan Hide/Restore Dynamic Island berbasis flag SpringBoard. Enum case, entri katalog, special-case apply, mutual exclusion, fungsi GestaltArtwork.removeDynamicIslandSubtype, dan 6 key strings ikut dibersihkan. (3) LiquidGlassView: toggle slider global (bagian dari gimmick) dihapus; layar tinggal pemilih render mode.

**The Reasoning:** Permintaan eksplisit user: tidak boleh ada fitur gimmick. Prinsip yang dipakai: fitur yang mekanismenya terbukti tidak ada = hapus, jangan pertahankan dengan label experimental; satu-satunya cara menghormati standar itu adalah mengadopsi metode komunitas terdokumentasi (Nugget/EnsWilde/PoomSmart-MGKeys) alih-alih key spekulatif.

**The Tech Debt:** Efek visual Solarium keys terbatas pada build tertentu (26.x; 26.5 sebagian sub-toggle no-op; iOS 27 belum ada jalur non-jailbreak) - caption UI sudah jujur soal ini; preset "Reset Wajar" masih menulis SAGvsp=0 (arah tak terverifikasi) - kandidat pembersihan berikutnya.

## 2026-08-24 - RDAR Tabel Semua iPhone + Sinkron Island Restore + Finalisasi Hapus Palette/Zoom2x

### The Change

Melanjutkan working tree sesi terputus dan menuntaskannya:

1. **RDAR fix lengkap semua iPhone**: tabel `knownGoodNativeCanvases` dilengkapi `iPhone18,3` = iPhone 17 (1206x2622), `iPhone18,4` = Air (1260x2736), `iPhone18,5` = 17e (1170x2532); mapping iPhone18,* dikonfirmasi via AppleDB + gist adamawolf (bukan lagi "pending confirmation"). Kini seluruh iPhone XS s/d 17 Pro Max punya entri known-good sehingga Fix RDAR tidak jatuh ke fallback UIScreen.nativeBounds di device manapun.
2. **Self-check tabel canvas**: harness CI `Support/RDARFixCheck.swift` dapat `checkKnownGoodCanvases()` - asersi model kunci (11/13/16 Pro/17 Pro) terisi, >=30 entri, dan setiap dimensi adalah panel portrait yang plausible (guard anti-typo).
3. **Sinkron restore Dynamic Island**: `hideDynamicIslandOff` (Restore) kini juga MENGHAPUS key capability `YlEtTtHlNesRBMal1CqRaA` dari CacheExtra sebelum menonaktifkan flag SpringBoard - karena `hideDynamicIslandOn` kini stage nilai 0, restore lama meninggalkan nilai itu tertanam sehingga island bisa tetap mati di build yang menghormati rute legacy.
4. **Finalisasi removal**: sweep case-insensitive mengkonfirmasi nol sisa referensi Color Palette / Legacy Palette / Graphics Style / Camera Zoom 2x / requiresCacheDataFlag / gestalt.cacheFlag.skipped di Swift + strings. Assertion checker `check-feature.ps1` yang masih menuntut `CacheDataPatcher.applyCapabilityFlag` di preset apply dibalik jadi larangan (dual-cache tweaks sudah tidak ada; patcher tetap dipakai jalur Siri AI).
5. **Disable Dynamic Island kembali**: entri katalog legacy (capability=0, gated iphone14ProOrLater, EXPERIMENTAL) direstore sesuai permintaan user, plus `hideDynamicIslandOn` ikut stage capability=0 belt-and-suspenders di atas flag SpringBoard resmi Nugget.

### The Reasoning

- Dimensi panel 17/17e/Air diambil dari spesifikasi publik panel masing-masing (17 & 17 Pro share panel 6.3", Air 6.5" 2736x1260, 17e = panel 16e) - bukan karangan.
- Restore harus mengembalikan plist ke bentuk stock (key ABSENT), bukan menimpa dengan nilai lain, supaya satu toggle benar-benar membalik pasangannya di semua build.

### The Tech Debt

- Build tetap diverifikasi lewat CI round-trip (Windows tidak bisa kompilasi Swift).
- Efektivitas rute legacy capability=0 untuk Disable/Hide Island per build iOS belum terbukti device; jalur utama tetap flag SpringBoard.
- Panel dim iPhone 18 generasi berikutnya (fall 2026) belum tentu sama - tabel tinggal ditambah saat device rilis.

## 2026-08-24 - Anti-Gimmick Pass II: RDAR Per-Device Ketat + Island Legacy Toggle Dilipat

### The Change

Tindak lanjut instruksi user "fix rdar harus sesuai tipe hp masing-masing dan tidak gimmick":

1. **Hapus `RDARFix.apply()` tanpa argumen** - satu-satunya jalur yang masih percaya `UIScreen.main.nativeBounds`, dan sudah tidak punya pemanggil sejak dashboard memakai tabel known-good. Dua pemakaian UIScreen yang tersisa aman dan jujur: fallback HANYA untuk hw.machine tak dikenal, selalu disertai catatan eksplisit di status.
2. **Toggle "Disable Dynamic Island" legacy-only dihapus lagi** (case enum, entri katalog, mutual exclusion, 2 key strings): menulis capability=0 saja terbukti enable-only di device island bawaan = silent no-op pada persis audience yang ditarget gate-nya (14 Pro+) - melanggar standar anti-gimmick repo. Off-switch tunggal kini pasangan Hide/Restore yang menggabungkan flag SpringBoard resmi Nugget + staging capability=0; judulnya diubah jadi "Disable Dynamic Island Completely" supaya 1:1 dengan istilah user.
3. Checker `check-feature.ps1` dibalik: `.disableDynamicIsland` kini DILARANG ada di katalog (regression guard), asersi staging capability=0 pindah ke hideDynamicIslandOn.

### The Reasoning

Fitur yang mekanismenya terbukti tidak berfungsi pada device target harus dihapus, bukan dipertahankan dengan label experimental (preseden ba72150). Kebutuhan user ("disable dynamic island") tetap terpenuhi penuh oleh toggle Hide yang lebih kuat karena sekarang membawa kedua mekanisme sekaligus.

### The Tech Debt

- Judul strings hideisland berubah - jika ada materi eksternal yang menyebut nama lama perlu sinkron manual.
- Fallback UIScreen untuk mesin tak dikenal tetap menjadi titik lemah teoretis; diterima karena satu-satunya alternatif adalah menolak melayani device baru.

## 2026-08-24 - Fix 3 Bug UI: Freeze Fix RDAR/Custom Canvas + Liquid Glass EPERM

### The Change

1. **Bug 1 & 3 - Freeze (Fix RDAR & Apply Custom Canvas)**: `StatusDashboardView.runFixRDAR()` / `applyCanvasEveryRoute()` dijalankan **sinkron di main thread**. Keduanya memanggil `manager.readGestalt()` + `saveGestaltOrThrow()` + `RDARFix.apply()` (yang melakukan `bad_query_list` hingga 64 container + `InodeWriter` write). Main thread keblokir → UI freeze / force-close. Perbaikan: seluruh kerja berat dipindah ke `DispatchQueue.global(qos: .userInitiated).async`, status & `showRestartAlert` di-dispatch balik ke main. Tambah guard `@State isWorking` agar tap ganda tidak menumpuk (tombol Custom Canvas dinonaktifkan saat `isWorking`).
2. **Bug 2 - Disable Liquid Glass "Operation not permitted"**: `LiquidGlassController.disableGlobal()` → `GlobalPreferences.setSolariumSuppressed` menulis `.GlobalPreferences.plist` via `InodeWriter.writeVerifiedInPlace` **tanpa `BadQueryLeaseScope`**, sehingga `open(O_WRONLY|O_NOFOLLOW)` dapat `EPERM` (errno=1) dan rollback ikut gagal. Perbaikan: bungkus write dengan `BadQueryLeaseScope.withLease(forPath: path)` (sama persis dengan pola `RDARFix.withResolvedTarget`).
3. **Disable Liquid Glass di Dashboard** ikut di-offload ke background queue (sebelumnya ikut menjalankan `disableGlobal()` sinkron di main thread).
4. Tambah key `common.working` = "Working…" di `WorkPlot/Resources/en.lproj/Localizable.strings` (indikator progres saat operasi background berjalan).

### The Reasoning

- LiquidGlassView.applyChanges() sudah benar pakai background queue; StatusDashboardView belum, padahal beban kerjanya sama berat (probe container + write inode-preserving). Offload adalah penyebab langsung freeze.
- `GlobalPreferences` luput membawa lease padahal `RDARFix` dan `saveGestaltOrThrow` (via GestaltAccess) selalu mengakuisisi lease sebelum `open()`. Tanpa lease, `open()` ditolak kernel dengan EPERM — cocok persis dengan pesan error user.

### The Tech Debt

- Build tetap diverifikasi lewat CI round-trip (Windows tidak bisa kompilasi Swift).
- `isWorking` belum dipakai sebagai guard pada tombol Fix RDAR & Disable Liquid Glass (hanya Custom Canvas) — risiko concurrency rendah karena masing-masing write punya lease sendiri, tapi bisa ditambah kalau user laporkan tap ganda.
- Key `common.working` baru hanya di `en.lproj`; bundle resource English-only sudah konsisten dengan keputusan finalisasi bahasa.

## 2026-08-24 - Pindahkan Disable Liquid Glass dari Home ke Menu More

### The Change

- Tombol "Disable Liquid Glass" dihapus dari Home → Actions (`StatusDashboardView.swift`) — section Actions tersisa Fix RDAR + Respring.
- Aksi yang sama ditambahkan ke More → Liquid Glass (`LiquidGlassView.swift`): tombol `status.lg.disable` dengan ProgressView saat berjalan, guard ganda (`isDisabling`/`isApplying` saling menonaktifkan), jalan di background queue, dan setelah sukses picker mode di-reload via `LiquidGlassController.currentMode()` (karena `disableGlobal` menulis CacheExtra SAGvsp=1) plus alert restart.
- `LiquidGlassController.disableGlobal()` + `GlobalPreferences` TETAP ada (tidak lagi dead code) — kini satu-satunya pemanggil adalah LiquidGlassView. Jalur tulis `.GlobalPreferences.plist` sudah membawa `BadQueryLeaseScope` sejak PR #51.

### The Reasoning

- User melapor dua tombol dengan fungsi sama di dua tempat (Home sering error, More tidak); konsolidasi ke satu lokasi menghilangkan duplikasi dan menyatukan jalur error handling. Error EPERM historis berasal dari write tanpa lease yang sudah diperbaiki #51, jadi fitur di lokasi barunya harus tembus.
- Reload picker pasca-disable menjaga UI jujur: nilai CacheExtra yang baru tertulis langsung tercermin sebagai mode aktif.

### The Tech Debt

- Jika bad_query/CMG tidak bisa membaca salah satu copy `.GlobalPreferences.plist`, `setSolariumSuppressed` tetap throw `lg.error.globalNotReachable` — pesan error jujur, tapi penulisan MobileGestalt (langkah pertama) tetap berhasil tanpa tercatat di statusText karena fungsi throwing all-or-nothing. Bisa dipecah jadi partial-report kalau keluhan muncul.
- Verifikasi build lewat CI round-trip; uji tembus-tulis di device iOS 27 beta tetap wajib.

## 2026-08-24 - Fix EPERM Disable Dynamic Island (Bedah WorkPlotDDI.ipa)

### The Change

- Bedah `WorkPlotDDI.ipa` (build lama repo ~22 Agustus, pra-#48): DDI-nya hanya menulis Gestalt capability `YlEtTtHlNesRBMal1CqRaA=0` — subset dari implementasi sekarang. Tidak ada mekanisme baru untuk di-port.
- Akar masalah "DDI build baru gagal": `SpringBoardPlist.setSuppressed` menulis `com.apple.springboard.plist` via `InodeWriter` **tanpa `BadQueryLeaseScope`** → `open(O_WRONLY)` dapat EPERM → throw di tengah apply → Gestalt pun tidak tersimpan. Bug identik dengan Liquid Glass #51.
- Fix: bungkus write dengan `BadQueryLeaseScope.withLease(forPath: path)` (`SpringBoardPlist.swift`). Audit semua 6 call site InodeWriter: kini SEMUA membawa lease (RDARFix ×2, Patch3105, FileBrowserService.saveText, GlobalPreferences, SpringBoardPlist).

### The Reasoning

- Build lama terlihat "bisa" karena tidak pernah menyentuh springboard.plist; build baru gagal total karena write tanpa lease membatalkan seluruh apply sebelum saveGestalt. Setelah lease fix, hideDynamicIslandOn = capability=0 + flag Nugget (superset, dua rute sekaligus).
- Laporan user "pertama kali disable bisa, setelahnya tidak": EPERM membuat apply #2 dst gagal total (throw memotong sebelum saveGestalt), sementara kesan pertama-bisa kemungkinan dari rute legacy di build lama. Karena itu rute SpringBoard kini NON-FATAL: gagal flag hanya jadi baris "SpringBoard: failed (...)" di status, capability=0 tetap tersimpan — dua rute independen tidak boleh saling bunuh.

### The Tech Debt

- Uji device: hide/show island di iPhone native-island iOS 27 beta + verifikasi restore menghapus capability key & flag.

## 2026-08-24 - Riset GoldenNugget & FixRDAR4XR11: Verifikasi Spoof Jujur + Canvas Aman XR/11

### The Change

1. **SPOOF - verifikasi pasca-tulis**: `DeviceSpoofingManager.verify(target:in:)` baru (pure helper) menghitung berapa identity key yang benar-benar membawa nilai target setelah save; `SiriAITweaksView.applyChanges` kini menampilkan "Spoof <nama>: N/M keys verified on disk" (+ baris rdar.verify.fail bila parsial). Alasannya: **GoldenNugget (fork Nugget dgn iOS 27 support) menghentikan MobileGestalt sepenuhnya** untuk iOS 27 - CacheExtra yang ditulis langsung tidak dijamin dihormati mobilegestaltd di build 24A5380h, jadi "spoof ga jalan walau restart" kemungkinan besar sistem mengabaikan CacheExtra, bukan tulisan kita gagal. Status kini membedakan dua kasus itu.
2. **SPOOF - offload main thread**: applyChanges dipindah ke background queue (pola #51/#52); readGestalt+backup+save sinkron di main thread = kelas freeze yang sama.
3. **RDAR - lokasi Managed Preferences**: `RDARFix.candidatePaths` kini probe `/var/Managed Preferences/mobile/com.apple.iokit.IOMobileGraphicsFamily.plist` (+ /private/var) PALING AWAL - FixRDAR4XR11 membuktikan copy di domain Managed Preferences adalah yang menyembuhkan XR/11 (Cowabunga Lite restore ke path persis ini).
4. **RDAR - canvas aman XR/11**: tabel `rdarSafeCanvases` baru: iPhone11,8 = 786x1704 (bukan native 828x1792, dari plist rilis FixRDAR4XR11 "optimized"); `fixCanvas(machine:)` = safe -> native -> nil, dipakai runFixRDAR & applyCanvasSizesGestalt. Menulis native ke XR/11 dengan RDAR aktif justru mempertahankan UI bug.
5. Percobaan membuat dict ArtworkDevice bila tidak ada DIBATALKAN - check-feature.ps1 menegaskan owner rule: spoof harus loud-fail tanpa ArtworkDevice (guard dipertahankan).

### The Reasoning

- Tanpa verifikasi, laporan "spoof ga jalan" tidak bisa dipilah: tulisan gagal vs sistem mengabaikan. Kini status menjawabnya; kalau verify 100% tapi device tetap tidak berubah, itu bukti CacheExtra-only mati di build tsb dan spoof butuh rute lain (tidak ada mesin patch CacheData struktural di repo - ketiganya marker-byte opaque).
- FixRDAR4XR11 (2024, direbuild) masih relevan karena mekanismenya file-level sama dengan jalur bad_query kita: taruh plist graphics di tempat yang dibaca IOKit.

### The Tech Debt

- Spoof di iOS 27 beta tetap TIDAK DIJAMIN tampil - kalau verify penuh tapi device diam, satu-satunya rute lanjutan adalah patch CacheData struktural (belum ada) atau menunggu komunitas menemukan jalur iOS 27.
- `verify()` belum masuk harness CI (Support/RDARFixCheck.swift) - bisa ditambah sebagai pure-function test.
- Uji device: RDAR XR/11 via Managed Preferences path + canvas 786x1704.

## 2026-08-24 - Fix Regresi Spoof: Kembali ke Write-Set Minimal yang Terbukti

### The Change

1. **Akar masalah "spoofing ga jalan walau restart"** ditemukan via bedah IPA lama (`WorkPlot.ipa_4`, era 51c177b) + git history: versi LAMA yang terbukti jalan hanya menulis ProductType x9 + board/HWModel x9 + nama marketing (kalau sudah ter-cache) + CompatibleDeviceFallback di dalam ArtworkDevice. Versi BARU menambah tulisan CPU platform (t8130/t8140/t8150), RegulatoryModelNumber, dan region US/US-A - blast identitas+region ini membuat mobilegestaltd di iOS 27 tidak mempercayai seluruh CacheExtra dan mengabaikan SEMUA key.
2. **`DeviceSpoofingManager.apply()`** dikembalikan ke write-set minimal terbukti; `changedKeyCount` dan `verify` ikut disesuaikan (hanya menghitung key yang benar-benar ditulis).
3. `cpuKeys`/`regulatoryModelKeys` dipertahankan sebagai konstanta karena preset bawaan masih menulisnya secara eksplisit (diberi komentar ponytail); `regionValues` dihapus total.
4. **check-feature.ps1**: dua asersi region US/US-A diganti regression guard baru - spoof picker DILARANG menulis region/CPU/regulatory (pola `regionValues` dilarang muncul).
5. **Repo cleanup** (permintaan user): `.reference/` (decompile IPA 3105), `skill-observations/`, dan `docs/superpowers/` dicabut dari git tracking + masuk .gitignore (+ pola `*.ipa`); file tetap ada lokal.

### The Reasoning

- Prinsip repo sendiri: jangan bertahan pada mekanisme yang tidak terbukti. Bukti lapangan (IPA lama jalan, baru gagal) lebih kuat daripada teori "identitas lengkap lebih konsisten" - konsistensi berlebihan justru memicu penolakan daemon.
- Preset bawaan sengaja TIDAK diubah di batch ini (masih menulis CPU/regulatory) - risiko terpisah, evaluasi menyusul setelah picker spoof dikonfirmasi jalan lagi di device.

### The Tech Debt

- Preset "iPhone 17 Pro Max Spoof" kemungkinan besar kena regresi yang sama (menulis CPU t8150 + A3257 lewat jalur preset) - pantau laporan user; kalau iya, terapkan write-set minimal yang sama di apply engine preset.
- Verifikasi device: spoof picker -> About berubah setelah full restart di iOS 27 beta.
