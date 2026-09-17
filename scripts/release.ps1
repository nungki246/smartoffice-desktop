[CmdletBinding()]
param(
  [string]$Version = '',
  [string]$Repo = 'nungki246/smartoffice-desktop',
  [string]$Notes = '',
  [switch]$SkipGitCommit,
  [switch]$SkipInstaller
)

$ErrorActionPreference = 'Stop'

# ============================ konfigurasi ====================================
$LAZBUILD = 'C:\lazarus\lazbuild.exe'
$GH       = 'C:\Program Files\GitHub CLI\gh.exe'
$ISCC     = 'C:\Program Files\Inno Setup 7\ISCC.exe'

$Root        = (Get-Item (Join-Path $PSScriptRoot "..")).FullName
$BinDir      = Join-Path $Root 'bin'
$AppsDir     = Join-Path $Root 'bin\apps'
$VersionPas  = Join-Path $Root 'src\core\uVersion.pas'
$IssFile     = Join-Path $Root 'installer\SmartOfficeSetup.iss'
$BuildAll    = Join-Path $Root 'scripts\build_all.bat'
$IcoFile     = Join-Path $Root 'smartoffice.ico'
$Dlls        = 'libpq.dll','sqlite3.dll','libssl-3-x64.dll','libcrypto-3-x64.dll',`
              'libiconv-2.dll','libintl-9.dll','libwinpthread-1.dll','zlib1.dll'

function Replace-First([string]$Path, [string]$Pattern, [string]$Replacement) {
  $content = [System.IO.File]::ReadAllText($Path)
  if (-not ($content -match $Pattern)) {
    throw "Pola '$Pattern' tidak ditemukan di $Path"
  }
  $content = [System.Text.RegularExpressions.Regex]::Replace($content, $Pattern, $Replacement, 1)
  [System.IO.File]::WriteAllText($Path, $content)
  Write-Host "  versi di $Path -> $Version"
}

function Invoke-Gh {
  param([string[]]$GhArgs)
  # In PowerShell 5.1, merging stderr (2>&1) while $ErrorActionPreference is
  # 'Stop' resets $LASTEXITCODE to 0, hiding real failures. Temporarily switch
  # to Continue so the native exit code is preserved.
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $o = & $GH @GhArgs 2>&1
  $code = $LASTEXITCODE
  $ErrorActionPreference = $prevEap
  return @{ Ok = ($code -eq 0); Output = $o; Code = $code }
}

# ============================ baca / naikkan versi ===========================
if ($Version -eq '') {
  $m = Select-String -Path $VersionPas -Pattern "AppVersion\s*=\s*'([^']+)'" | Select-Object -First 1
  if (-not $m) { throw 'Tidak dapat membaca versi dari src\uVersion.pas' }
  $parts = $m.Matches[0].Groups[1].Value.Split('.')
  if ($parts.Count -eq 3) {
    $patch = [int]$parts[2] + 1
    $Version = "$($parts[0]).$($parts[1]).$patch"
  } else {
    $Version = "$($m.Matches[0].Groups[1].Value).1"
  }
  Write-Host "Versi baru (auto-bump): v$Version"
} else {
  Write-Host "Versi (dari argumen): v$Version"
}
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "Format versi tidak valid: $Version" }

# ============================ naikkan versi di file ==========================
Write-Host 'Menaikkan versi di file sumber...'
Replace-First $VersionPas "AppVersion\s*=\s*'[^']+'\s*;?" "AppVersion = '$Version';"
Replace-First $IssFile   'AppVersion=[\d.]+'         "AppVersion=$Version"
Replace-First $IssFile   'AppVerName=SmartOffice Desktop [\d.]+' "AppVerName=SmartOffice Desktop $Version"

# ============================ kill proses ====================================
Write-Host 'Menghentikan proses SmartOffice yang berjalan...'
Get-Process -ErrorAction SilentlyContinue |
  Where-Object { $_.ProcessName -eq 'SmartOfficeDesktop' -or $_.ProcessName -like 'SIMRS-*' } |
  Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1

# ============================ build ==========================================
Write-Host ''
Write-Host '===== BUILD ====='
$out = & $BuildAll 2>&1
$out |
  Select-String -Pattern '===|ALL BUILDS OK|Build FAILED|Error:|Fatal' |
  ForEach-Object { $_.Line }
if ($LASTEXITCODE -ne 0 -or -not ($out -match 'ALL BUILDS OK')) {
  throw 'Build gagal (ALL BUILDS OK tidak tercapai).'
}

# ============================ verifikasi aset ================================
Write-Host ''
Write-Host '===== VERIFIKASI ASET ====='
$assets = @()
$assets += Get-Item (Join-Path $BinDir 'SmartOfficeDesktop.exe')
$assets += Get-ChildItem (Join-Path $AppsDir 'SIMRS-*.exe')
foreach ($d in $Dlls) { $assets += Get-Item (Join-Path $BinDir $d) }
# Pastikan minimal launcher + setidaknya 1 modul + 8 DLL ditemukan
$minAssets = 1 + (Get-ChildItem (Join-Path $AppsDir 'SIMRS-*.exe')).Count + $Dlls.Count
if ($assets.Count -lt $minAssets) { throw "Jumlah aset tidak mencukupi (ditemukan $($assets.Count), minimal $minAssets)." }
Write-Host "  Total aset yang akan di-upload: $($assets.Count)"
foreach ($a in $assets) { Write-Host "  OK $($a.Name)" }

# ============================ commit + push ==================================
if (-not $SkipGitCommit) {
  Write-Host ''
  Write-Host '===== GIT COMMIT + PUSH ====='
  # Same stderr/exit-code guard as Invoke-Gh: 'Stop' + 2>&1 resets $LASTEXITCODE.
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  git -C $Root add installer\SmartOfficeSetup.iss
  if (Test-Path -LiteralPath $IcoFile) { git -C $Root add smartoffice.ico }
  # Commit only when something was actually staged (git diff --cached --quiet
  # returns 1 when there are staged changes, 0 otherwise).
  git -C $Root diff --cached --quiet
  $stagedCode = $LASTEXITCODE
  if ($stagedCode -eq 1) {
    $co = git -C $Root commit -m "Bump version to $Version" 2>&1
    $commitCode = $LASTEXITCODE
    if ($commitCode -ne 0) {
      $co | ForEach-Object { $_ }
      throw 'git commit gagal.'
    }
  }
  $pushOut = git -C $Root push origin main 2>&1
  $pushCode = $LASTEXITCODE
  $ErrorActionPreference = $prevEap
  if ($pushCode -ne 0) { throw 'git push gagal.' }
  Write-Host '  commit & push OK.'
}

# ============================ cek rilis lama =================================
Write-Host ''
Write-Host "===== CEK TAG v$Version ====="
$r = Invoke-Gh -GhArgs @('release','view',"v$Version",'--repo',$Repo)
if ($r.Ok) { throw "Rilis/tag v$Version sudah ada. Batalkan untuk mencegah overwrite." }
Write-Host '  tag belum ada, lanjut.'

# ============================ buat release ===================================
if ($Notes -eq '') { $Notes = "Rilis otomatis dari build script. Versi $Version." }
Write-Host ''
Write-Host "===== BUAT RELEASE v$Version ====="
$created = $false
foreach ($i in 1..8) {
  $r = Invoke-Gh -GhArgs @('release','create',"v$Version",'--repo',$Repo,
                         '--title',"SmartOffice Desktop $Version",'--notes',$Notes,'--target','main')
  if ($r.Ok) { $created = $true; $r.Output; break }
  Start-Sleep -Seconds 5
}
if (-not $created) { throw 'Gagal membuat release di GitHub.' }

# ============================ upload aset ====================================
Write-Host ''
Write-Host '===== UPLOAD ASET ====='
foreach ($a in $assets) {
  $name = [System.IO.Path]::GetFileName($a.FullName)
  $done = $false
  foreach ($i in 1..10) {
    $r = Invoke-Gh -GhArgs @('release','upload',"v$Version",'--repo',$Repo,$a.FullName)
    if ($r.Ok) { $done = $true; Write-Host "  OK   $name"; break }
    Start-Sleep -Seconds 6
  }
  if (-not $done) { throw "Gagal upload aset: $name" }
}

# ============================ installer ======================================
if (-not $SkipInstaller) {
  Write-Host ''
  Write-Host '===== INSTALLER ====='
  $o = & $ISCC $IssFile 2>&1
  $o | Select-Object -Last 6 | ForEach-Object { $_ }
  if ($LASTEXITCODE -ne 0) { throw 'Kompilasi installer gagal.' }
}

Write-Host ''
Write-Host "=============================================="
Write-Host " SELESAI. Rilis: https://github.com/$Repo/releases/tag/v$Version"
Write-Host "=============================================="
