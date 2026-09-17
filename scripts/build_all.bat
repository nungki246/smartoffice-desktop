@echo off
rem SmartOffice Desktop - build script (all modules + launcher)
rem
rem Struktur folder:
rem   src\modules\launcher\SmartOfficeDesktop.lpi  -> bin\SmartOfficeDesktop.exe
rem   src\modules\<name>\SIMRS-<name>.lpi          -> bin\apps\SIMRS-<name>.exe
rem
rem Jalankan dari folder mana saja; ROOT dihitung dari lokasi script ini.

setlocal
set LAZBUILD=C:\lazarus\lazbuild.exe
set "ROOT=%~dp0.."
set "BIN=%ROOT%\bin"
set "APPS=%ROOT%\bin\apps"

rem Buat folder target jika belum ada
if not exist "%BIN%"  mkdir "%BIN%"
if not exist "%APPS%" mkdir "%APPS%"

echo.
echo === SmartOfficeDesktop (launcher) ===
"%LAZBUILD%" "%ROOT%\src\modules\launcher\SmartOfficeDesktop.lpi"
if errorlevel 1 goto :failed
echo   OK ^> %BIN%\SmartOfficeDesktop.exe

rem Compile semua modul di bawah src\modules\ kecuali launcher
for /d %%D in ("%ROOT%\src\modules\*") do (
  if /i not "%%~nxD"=="launcher" (
    if /i not "%%~nxD"=="backup" (
      for %%L in ("%%D\*.lpi") do (
        echo.
        echo === %%~nL ===
        "%LAZBUILD%" "%%L"
        if errorlevel 1 goto :failed
        echo   OK ^> %APPS%\%%~nL.exe
      )
    )
  )
)

echo.
echo ALL BUILDS OK.
exit /b 0

:failed
echo.
echo Build FAILED.
exit /b 1