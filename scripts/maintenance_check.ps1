# PetaFinds — local maintenance check.
# Runs the same checks as the weekly GitHub Actions workflow and writes
# MAINTENANCE_REPORT.md at the repo root.
#
# Usage (from repo root):
#   pwsh -File scripts/maintenance_check.ps1
# Or via the VS Code task: "PetaFinds: Maintenance Check".

$ErrorActionPreference = 'Continue'
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$report = "MAINTENANCE_REPORT.md"
$timestamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz')
$results = New-Object System.Collections.Generic.List[string]
$failures = New-Object System.Collections.Generic.List[string]

function Add-Section($title, $output, $exit) {
    $status = if ($exit -eq 0) { 'PASS' } else { 'FAIL' }
    if ($exit -ne 0) { $failures.Add($title) | Out-Null }
    $results.Add("## $title — $status") | Out-Null
    $results.Add('') | Out-Null
    $results.Add('```') | Out-Null
    $results.Add(($output | Out-String).TrimEnd()) | Out-Null
    $results.Add('```') | Out-Null
    $results.Add('') | Out-Null
}

function Run-Step($title, [scriptblock]$block) {
    Write-Host ""
    Write-Host "==> $title" -ForegroundColor Cyan
    $out = & $block 2>&1
    $code = $LASTEXITCODE
    if ($null -eq $code) { $code = 0 }
    Write-Host ($out | Out-String).TrimEnd()
    Add-Section $title $out $code
}

# 1. flutter pub get
Run-Step "flutter pub get" { flutter pub get }

# 2. flutter analyze
Run-Step "flutter analyze" { flutter analyze }

# 3. flutter test (only if tests exist)
$testFiles = @()
if (Test-Path "test") {
    $testFiles = Get-ChildItem -Path test -Filter '*.dart' -Recurse |
        Where-Object { $_.Name -notlike '*.g.dart' }
}
if ($testFiles.Count -gt 0) {
    Run-Step "flutter test" { flutter test }
} else {
    Add-Section "flutter test" "No tests — skipped." 0
}

# 4. flutter build web
Run-Step "flutter build web" { flutter build web --release }

# 5. git status (informational)
Run-Step "git status" { git status --short }

# 6. Firebase config presence
$missing = @()
foreach ($f in @('firebase/firestore.rules', 'firebase/storage.rules', 'firebase/firestore.indexes.json')) {
    if (-not (Test-Path $f)) { $missing += $f }
}
if ($missing.Count -gt 0) {
    Add-Section "Firebase config files" ("Missing: " + ($missing -join ', ')) 1
} else {
    Add-Section "Firebase config files" "All present." 0
}

# 7. Secret scan (best-effort; matches the CI scan)
$patterns = @(
    'sk\.eyJ',
    'MAPBOX_SECRET',
    'BEGIN PRIVATE KEY',
    'BEGIN RSA PRIVATE KEY',
    'service_account'
)
$hits = New-Object System.Collections.Generic.List[string]
$skipDirs = @('.git', 'build', '.dart_tool', '.idea')
$skipFiles = @('pubspec.lock', 'weekly-maintenance.yml', 'maintenance_check.ps1')
$files = Get-ChildItem -Recurse -File |
    Where-Object {
        $rel = $_.FullName.Substring($repoRoot.Length + 1)
        -not ($skipDirs | Where-Object { $rel -like "$_*" -or $rel -like "*\$_\*" }) -and
        -not ($skipFiles -contains $_.Name)
    }
foreach ($file in $files) {
    foreach ($p in $patterns) {
        $matchInfo = Select-String -Path $file.FullName -Pattern $p -SimpleMatch:$false -ErrorAction SilentlyContinue
        if ($matchInfo) {
            foreach ($m in $matchInfo) {
                $hits.Add(("{0}:{1}: pattern={2}" -f $file.FullName.Substring($repoRoot.Length + 1), $m.LineNumber, $p)) | Out-Null
            }
        }
    }
}
# Committed env files
$envFiles = Get-ChildItem -Recurse -File -Force -Include '.env', '.env.*' -ErrorAction SilentlyContinue |
    Where-Object {
        $rel = $_.FullName.Substring($repoRoot.Length + 1)
        -not ($skipDirs | Where-Object { $rel -like "$_*" -or $rel -like "*\$_\*" })
    }
foreach ($e in $envFiles) {
    $hits.Add(("Committed env file: {0}" -f $e.FullName.Substring($repoRoot.Length + 1))) | Out-Null
}
if ($hits.Count -gt 0) {
    Add-Section "Secret scan" ($hits -join "`n") 1
} else {
    Add-Section "Secret scan" "No matches." 0
}

# Write report
$summary = if ($failures.Count -eq 0) { "All checks PASSED" } else { "FAILED: " + ($failures -join ', ') }
$header = @(
    "# PetaFinds Maintenance Report",
    "",
    "**Run:** $timestamp",
    "**Result:** $summary",
    "",
    "---",
    ""
)
$header + $results | Out-File -FilePath $report -Encoding utf8

Write-Host ""
if ($failures.Count -eq 0) {
    Write-Host "OK: $summary" -ForegroundColor Green
    Write-Host "Report: $report"
    exit 0
} else {
    Write-Host "FAIL: $summary" -ForegroundColor Red
    Write-Host "Report: $report"
    exit 1
}
