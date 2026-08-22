$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$resourceRoot = Join-Path $repoRoot "WorkPlot\Resources"
$englishPath = Join-Path $resourceRoot "en.lproj\Localizable.strings"
$localizationPath = Join-Path $repoRoot "WorkPlot\Managers\Localization.swift"

$resourceFiles = @(Get-ChildItem $resourceRoot -Recurse -Filter 'Localizable.strings')
if ($resourceFiles.Count -ne 1 -or $resourceFiles[0].FullName -ne $englishPath) {
    throw "English-only mode requires exactly WorkPlot/Resources/en.lproj/Localizable.strings"
}

$bytes = [IO.File]::ReadAllBytes($englishPath)
if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    throw "$englishPath contains a UTF-8 BOM"
}
$text = [IO.File]::ReadAllText($englishPath)
if ($text -match '[\u201C\u201D]') { throw "$englishPath contains smart quotes" }
$entryPattern = '^\s*"([^"\\]+)"\s*=\s*"(?:\\.|[^"\\])*";\s*$'
$invalidLines = @($text -split "`r?`n" | Where-Object { $_.Trim() -and $_ -notmatch '^\s*(?://|/\*.*\*/)' -and $_ -notmatch $entryPattern })
if ($invalidLines.Count) { throw "$englishPath has malformed lines: $($invalidLines -join ' | ')" }
$keys = @($text -split "`r?`n" | ForEach-Object { if ($_ -match $entryPattern) { $Matches[1] } })
$duplicates = @($keys | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name)
if ($duplicates.Count) { throw "$englishPath has duplicate keys: $($duplicates -join ', ')" }

$swiftFiles = @(Get-ChildItem (Join-Path $repoRoot "WorkPlot") -Recurse -Filter '*.swift')
$swiftText = ($swiftFiles | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }) -join "`n"
$usedKeys = @([regex]::Matches($swiftText, '\btr\("([^"\\]+)"\)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
$missingUsedKeys = @($usedKeys | Where-Object { $_ -notin $keys })
if ($missingUsedKeys.Count) { throw "Keys used by tr(...) but missing from English localization: $($missingUsedKeys -join ', ')" }
if ($swiftText -match '\bAppLanguage\b|settings\.language|@Published\s+var\s+language') {
    throw "English-only mode must not expose AppLanguage state or a language selector"
}
if ($swiftText -match '(?i)"[^"\r\n]*\b(?:gagal|tidak|punya|ditemukan|butuh|diperoleh|bukan|berhasil|dihapus|diperbarui|ditambahkan|menulis|membaca|menyimpan|menghapus|mengubah|untuk|paket|arsip|rusak|kosong|pilih|isi|perangkat|mengaktifkan|lagi|lihat)\b[^"\r\n]*"') {
    throw "Swift user-facing string literals must be English-only"
}

$localizationText = [IO.File]::ReadAllText($localizationPath)
if ($localizationText -notmatch 'forResource:\s*"en"') {
    throw "L10n must load the English resource bundle explicitly"
}
$tweaksText = [IO.File]::ReadAllText((Join-Path $repoRoot "WorkPlot\Managers\GestaltTweaks.swift"))
if ($tweaksText -match '(?m)\.init\([^\r\n]+(?:title|detail):\s*"') {
    throw "Gestalt tweak titles/details must use L10n.tr instead of hardcoded copy"
}
if ($tweaksText -match 'case \.(?:region|display|hardware|ipad|internalFeatures):\s*"') {
    throw "Gestalt category labels must use L10n.tr instead of hardcoded copy"
}
if ([IO.File]::ReadAllText((Join-Path $repoRoot "WorkPlot\Managers\RestartOptions.swift")) -match 'Button\(action\.labelKey\)') {
    throw "Restart action labels must resolve labelKey through L10n.tr"
}

Write-Host "L10n OK: English-only bundle with $($keys.Count) unique keys; $($usedKeys.Count) referenced keys resolved."
