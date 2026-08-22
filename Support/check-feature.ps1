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
Require ($restart -match 'Button\(L10n\.shared\.tr\(action\.labelKey\)\)') "Restart actions must be localized"

$access = Read-ProjectFile "WorkPlot\Exploit\GestaltAccess.m"
Require ($access -match 'static BOOL GestaltRestoreOriginal') "Gestalt write failures must share a verified rollback helper"
Require ($access -match '(?s)if \(!\[verification isEqualToData:data\]\).*?GestaltRestoreOriginal\(fd, targetPath, original\)') "Post-write verification failure must restore the original plist"
Require ($access -notmatch '(?s)close\(fd\);\s*NSData \*verification') "The write descriptor must remain open until verification finishes"

Write-Host "Feature OK: 9 ProductType + 9 board keys, 4 gated dual-cache tweaks, scoped CacheData patch, single save, verified rollback, modal restart alert."
