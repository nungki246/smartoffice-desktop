@echo off
rem ============================================================
rem SmartOffice Desktop - rilis otomatis satu perintah.
rem
rem Menjalankan satu tahap: bump versi -> build all -> commit/push
rem -> buat tag+release GitHub -> upload aset -> installer.
rem
rem Pemakaian:
rem   release.bat                       (versi auto-bump patch)
rem   release.bat -Version 1.1.0        (versi eksplisit)
rem   release.bat -Notes "isi catatan rilis"
rem   release.bat -SkipGitCommit        (tanpa commit/push)
rem   release.bat -SkipInstaller        (tanpa kompilasi installer)
rem ============================================================
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0release.ps1" %*
if errorlevel 1 (
  echo.
  echo ===== RELEASE GAGAL =====
  exit /b 1
)
echo.
echo ===== RELEASE SELESAI =====
exit /b 0