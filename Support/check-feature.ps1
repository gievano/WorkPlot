$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
function Read-ProjectFile([string]$path) {
    [IO.File]::ReadAllText((Join-Path $repoRoot $path))
}
function Require([bool]$condition, [string]$message) {
    if (-not $condition) { throw $message }
}
function Array-Values([string]$source, [string]$name) {
    $match = [regex]::Match($source, "(?s)static let $name = \[(.*?)\]")
    Require $match.Success "Missing array $name"
    @([regex]::Matches($match.Groups[1].Value, '"([^"\r\n]+)"') | ForEach-Object { $_.Groups[1].Value })
}

$spoofing = Read-ProjectFile "WorkPlot\Managers\DeviceSpoofingManager.swift"
$productKeys = @(Array-Values $spoofing "productTypeKeys")
$boardKeys = @(Array-Values $spoofing "hwModelKeys")
Require ($productKeys.Count -eq 9) "Expected 9 ProductType keys, got $($productKeys.Count)"
Require ($boardKeys.Count -eq 9) "Expected 9 board keys, got $($boardKeys.Count)"
Require ($spoofing -match '"h63QSdBCiT/z0WU6rdQv6Q":\s*"US"') "Missing US region value"
Require ($spoofing -match '"yK\+xavymRGZ3xWc1tb8XDg":\s*"US/A"') "Missing US/A region value"
Require ($spoofing -notmatch 'D74AP|D97AP') "Rejected board value found"
Require ($spoofing -match 'guard var artwork = cacheExtra\[GestaltArtwork\.artworkKey\] as\? \[String: Any\] else') "Spoof apply must require ArtworkDevice before staging mutations"
Require ($spoofing -notmatch 'if var artwork = cacheExtra\[GestaltArtwork\.artworkKey\]') "Spoof apply must not silently skip ArtworkDevice"

$tweaks = Read-ProjectFile "WorkPlot\Managers\GestaltTweaks.swift"
$requiredDefinitions = @(
    '(?s)id:\s*\.colorPaletteGraphics.*?deviceGate:\s*\.iphone13OrLater,\s*requiresCacheDataFlag:\s*true',
    '(?s)id:\s*\.graphicsStyle.*?deviceGate:\s*\.iphone11Or12Only,\s*requiresCacheDataFlag:\s*true',
    '(?s)id:\s*\.colorPaletteLegacy.*?deviceGate:\s*\.iphone13OrBelow,\s*requiresCacheDataFlag:\s*true',
    '(?s)id:\s*\.cameraZoom2x.*?deviceGate:\s*\.belowIPhone15,\s*requiresCacheDataFlag:\s*true'
)
foreach ($pattern in $requiredDefinitions) {
    Require ($tweaks -match $pattern) "A dual-cache tweak is missing its required gate or CacheData flag"
}
Require ($tweaks -match '(?s)id:\s*\.colorPaletteLegacy.*?values:\s*\["03hWmMtMs\+4nzama4/PzHQ":\s*1\].*?requiresCacheDataFlag:\s*true') "Legacy Color Palette must stage its CacheExtra candidate with CacheData"

$patcher = Read-ProjectFile "WorkPlot\Managers\CacheDataPatcher.swift"
Require ($patcher -match 'plist\["CacheData"\]\s+as\?\s+Data') "CacheData patcher must scope its input to the CacheData value"
Require ($patcher -match 'base64EncodedString\(\)') "CacheData patcher must encode CacheData directly"
Require ($patcher -match 'Data\(base64Encoded:') "CacheData patcher must decode the patched CacheData directly"
Require ($patcher -notmatch 'PropertyListSerialization') "CacheData patcher must not reserialize the whole plist"
$original = [regex]::Match($patcher, '(?s)originalMarker\s*=\s*"([A-Za-z0-9+/=]+)"').Groups[1].Value
$replacement = [regex]::Match($patcher, '(?s)replacementMarker\s*=\s*"([A-Za-z0-9+/=]+)"').Groups[1].Value
Require ($original.Length -gt 0 -and $original.Length -eq $replacement.Length) "CacheData markers must be present and equal length"
$differences = 0
for ($index = 0; $index -lt $original.Length; $index++) {
    if ($original[$index] -ne $replacement[$index]) { $differences++ }
}
Require ($differences -eq 1) "CacheData markers must differ by exactly one character"
Require ($patcher -match 'totalHits\s*=\s*offHits\.count\s*\+\s*onHits\.count' -and $patcher -match 'guard totalHits > 0' -and $patcher -match 'guard totalHits == 1') "CacheData patcher must reject missing, duplicate, and mixed markers"

$presetView = Read-ProjectFile "WorkPlot\UI\GestaltPresetManagerView.swift"
Require (([regex]::Matches($presetView, 'manager\.saveGestaltOrThrow\(plist\)')).Count -eq 1) "Preset apply must use one throwing save"
Require ($presetView -notmatch 'manager\.saveGestalt\(plist\)') "Preset apply must not swallow save errors"
Require ($presetView -match 'CacheDataPatcher\.applyCapabilityFlag') "Preset apply must stage CacheData with CacheExtra"
$siriView = Read-ProjectFile "WorkPlot\UI\SiriAITweaksView.swift"
Require (([regex]::Matches($siriView, 'manager\.saveGestaltOrThrow\(plist\)')).Count -eq 1) "Siri AI apply must use one throwing save"
Require ($siriView -notmatch 'manager\.saveGestalt\(plist\)') "Siri AI apply must not swallow save errors"
$restart = Read-ProjectFile "WorkPlot\Managers\RestartOptions.swift"
Require ($restart -match '\.alert\(') "Heavy restart flow must use a modal alert"
Require ($restart -match 'Button\(L10n\.shared\.tr\("siriai\.restart\.respring"\)\)') "Restart flow must offer the working respring action"
Require ($restart -match 'Button\(L10n\.shared\.tr\("restart\.action\.guide"\)\)') "Restart flow must surface the honest manual restart guide"
Require ($restart -notmatch 'launchctl') "Restart flow must not pretend to spawn processes"

$access = Read-ProjectFile "WorkPlot\Exploit\GestaltAccess.m"
Require ($access -match 'static BOOL GestaltRestoreOriginal') "Gestalt write failures must share a verified rollback helper"
Require ($access -match '(?s)if \(!\[verification isEqualToData:data\]\).*?GestaltRestoreOriginal\(fd, targetPath, original\)') "Post-write verification failure must restore the original plist"
Require ($access -notmatch '(?s)close\(fd\);\s*NSData \*verification') "The write descriptor must remain open until verification finishes"

# iOS 27-only scope: the OS gate must route through the verified-beta check
# and must not resurrect the dropped 17/18/26 ranges.
Require ($access -match 'VersionIsVerifiedIOS27Beta\(') "The supported-OS gate must use the verified iOS 27 beta check"
Require ($access -notmatch 'majorVersion == 17|majorVersion == 18|majorVersion == 26') "The OS gate must stay iOS/iPadOS 27-only"
Require ($access -match '24A5355q' -and $access -match '24A5390f') "Verified iOS 27 developer/public beta builds must remain allowlisted"
Require ($access -match 'activeMethod') "GestaltAccess must expose which method provided access"
Require ($access -match 'CmgLease \*cmgLease = \[CmgLease leaseWithError:&cmgDetail\]') "connectWithError must fall back to the CMG method"
Require ($access -match 'self\.activeMethod = @"bad_query"' -and $access -match 'self\.activeMethod = @"cmg"') "Both connect paths must report their method name"
Require (([regex]::Matches($access, 'stage=identity|CMG')).Count -ge 2) "Failure details must name stages and the CMG fallback"

$cmg = Read-ProjectFile "WorkPlot\Exploit\CmgBridge.m"
Require ($cmg -match 'container_query_create' -and $cmg -match 'container_query_set_class') "CMG bridge must drive the ContainerManager query API"
Require ($cmg -match 'container_query_set_transient') "CMG bridge must set transient like mond does"
Require ($cmg -match 'container_query_operation_set_platform' -and $cmg -match 'container_query_operation_set_flags') "CMG bridge must configure platform and flags on the operation"
Require ($cmg -match 'container_object_sandbox_extension_activate' -and $cmg -match 'container_object_get_path') "CMG bridge must activate the extension and read its path"
Require ($cmg -match '0x0000008100000000ULL') "CMG flags must match mond/MobileHouseArrest-PoC (1<<32 | 1<<39)"
Require ($cmg -match 'systemgroup\.com\.apple\.mobilegestaltcache') "CMG must target the MobileGestaltCache system group"
Require ($cmg -notmatch 'com\.apple\.mobile\.MobileHouseArrest') "CMG has no bundle identifier requirement and must never reference one"

$project = Read-ProjectFile "WorkPlot\WorkPlot.xcodeproj\project.pbxproj"
Require (([regex]::Matches($project, 'PRODUCT_BUNDLE_IDENTIFIER = com\.apple\.mobile\.MobileHouseArrest;')).Count -eq 2) "Both build configurations must preserve the MobileHouseArrest bundle identifier"
Require ($project -notmatch 'PRODUCT_BUNDLE_IDENTIFIER = com\.workplot\.app;') "The incompatible WorkPlot bundle identifier is still configured"
Require (([regex]::Matches($project, 'IPHONEOS_DEPLOYMENT_TARGET = 16\.0;')).Count -eq 2) "Both build configurations must support the 3105-compatible iOS 16 floor"

$bridge = Read-ProjectFile "WorkPlot\Exploit\BadQueryBridge.m"
Require ($bridge -match 'kBadQueryExpectedBundleIdentifier') "bad_query must still record the expected sideload identity"
Require ($bridge -match 'stage=identity') "Identity mismatches must carry a stage=identity diagnostic note"
Require ($bridge -match 'BadQueryAnnotate') "Query failures must attach the identity diagnostic note instead of blocking early"
Require ($bridge -match 'stage=query') "ContainerManager rejection must name the query stage"

$bridgingHeader = Read-ProjectFile "WorkPlot\Exploit\WorkPlot-Bridging-Header.h"
Require ($bridgingHeader -match '#import "CmgBridge\.h"') "The bridging header must expose CmgBridge to Swift"

$exploitManager = Read-ProjectFile "WorkPlot\Managers\ExploitManager.swift"
Require ($exploitManager -match 'try access\.connect\(\)') "System access check must let GestaltAccess pick the method (no fatal preflight)"
Require ($exploitManager -match 'exploitMethod = access\.activeMethod') "The manager must publish which method provided access"
Require ($exploitManager -match 'showsSigningHint') "A rewritten bundle identifier must surface the signing hint"
Require ($exploitManager -match 'captureStockSnapshotIfNeeded') "First successful connect must capture the stock snapshot"

# Sprint-1 key corrections (verified against PoomSmart/MGKeys)
$tweaksText = Read-ProjectFile "WorkPlot\Managers\GestaltTweaks.swift"
$siriApplier = Read-ProjectFile "WorkPlot\Managers\SiriModeApplier.swift"
Require ($siriApplier -match 'a3n5T9sFtlyQ74NEp9ESxg') "SiriMode must use the correct MGKeys value a3n5T9sFtlyQ74NEp9ESxg"
Require ($siriApplier -notmatch 'a3n5T9sFtyQ74NEp9ESxg') "The old SiriMode typo must be gone"
# Post-split architecture (PR #40): the Siri mode flag belongs ONLY to the
# Siri AI path; Apple Intelligence stages the eligibility key alone.
$aiController = Read-ProjectFile "WorkPlot\Managers\AppleIntelligenceController.swift"
Require ($aiController -match '"A62OafQ85EJAiiqKn4agtg"') "Apple Intelligence must stage the eligibility key A62OafQ85EJAiiqKn4agtg"
Require ($aiController -notmatch 'a3n5T9sFtlyQ74NEp9ESxg') "Apple Intelligence must not write the Siri mode flag anymore"
Require ($tweaksText -notmatch 'a3n5T9sFtlyQ74NEp9ESxg') "The Gestalt catalog must not duplicate the Siri mode flag toggle"
Require ($tweaksText -match 'mmu76v66k1dAtghToInT8g') "disableParallax must write the real CacheExtra key"
Require ($tweaksText -notmatch '"UIParallaxCapability"') "Plaintext capability names must not be written as Gestalt keys"

# Session log + revert-to-stock surface
$sessionLogger = Read-ProjectFile "WorkPlot\Managers\SessionLogger.swift"
Require ($sessionLogger -match 'limit = 300') "SessionLogger keeps a bounded ring buffer of 300 lines"
Require ($sessionLogger -match 'func clear\(\)') "Session log must be clearable"
$backupStore = Read-ProjectFile "WorkPlot\Managers\GestaltBackupStore.swift"
Require ($backupStore -match 'static func createNamed') "Named snapshots (Stock Snapshot) require createNamed"
$sessionLogView = Read-ProjectFile "WorkPlot\UI\SessionLogView.swift"
Require ($sessionLogView -match 'SessionLogger\.shared') "Session log viewer must read the shared logger"
$moreMenu = Read-ProjectFile "WorkPlot\UI\MoreMenuView.swift"
Require ($moreMenu -match 'SessionLogView\(\)') "More menu must link the session log viewer"
$backupView = Read-ProjectFile "WorkPlot\UI\BackupRestoreManagerView.swift"
Require ($backupView -match 'Stock Snapshot') "Backup manager must offer Revert to Stock Snapshot"
Require ($backupView -match 'RDARFix\.restoreOriginalCanvas') "Backup manager must expose the persistent RDAR canvas restore"

$statusDashboard = Read-ProjectFile "WorkPlot\UI\StatusDashboardView.swift"
Require ($statusDashboard -match 'status\.methodLabel') "Dashboard must show which exploit method is active"

$strings = Read-ProjectFile "WorkPlot\Resources\en.lproj\Localizable.strings"
foreach ($key in @('status\.exploitActive', 'status\.methodLabel', 'status\.signingHint', 'sessionlog\.title', 'backup\.revertStock', 'rdar\.restoreCanvas', 'siri\.rebootHint')) {
    Require ($strings -match ('"' + $key + '"')) "Missing localization key $key"
}

Write-Host "Feature OK: iOS 27 dual-method access (bad_query + CMG fallback), verified rollback, non-fatal identity diagnostics, corrected MGKeys values, stock snapshot/session log, and staged diagnostics."
