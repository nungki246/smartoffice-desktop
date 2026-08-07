@echo off
rem SmartOffice Desktop - build script (all modules + launcher)
rem
rem Builds the launcher and every SIMRS-* module project. The launcher
rem project lives in src\modules\launcher\ and its executable is built into
rem the app root (next to apps\ and the runtime DLLs). Module projects live
rem under src\modules\<name>\ and each module's executable is built into its
rem own folder so programmers can test/develop it in place. When a module is
rem confirmed working, copy the exe manually into <launcher-dir>\apps\, which
rem the launcher reads from.

setlocal
set LAZBUILD=C:\lazarus\lazbuild.exe
set "ROOT=%~dp0"

echo.
echo === SmartOfficeDesktop (launcher) ===
"%LAZBUILD%" "%ROOT%src\modules\launcher\SmartOfficeDesktop.lpi"
if errorlevel 1 goto :failed
if exist "%ROOT%SmartOfficeDesktop.exe" (
  copy /y "%ROOT%SmartOfficeDesktop.exe" "%ROOT%src\modules\launcher\SmartOfficeDesktop.exe" >nul
  echo   copied to "%ROOT%src\modules\launcher\SmartOfficeDesktop.exe"
)

for /d %%D in ("%ROOT%src\modules\*") do (
  if /i not "%%~nxD"=="launcher" (
    for %%L in ("%%D\*.lpi") do (
      echo.
      echo === %%~nL ===
      "%LAZBUILD%" "%%L"
      if errorlevel 1 goto :failed
      if exist "%%D\%%~nL.exe" (
        copy /y "%%D\%%~nL.exe" "%ROOT%apps\%%~nL.exe" >nul
        echo   copied to "%ROOT%apps\%%~nL.exe"
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
