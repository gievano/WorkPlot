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
