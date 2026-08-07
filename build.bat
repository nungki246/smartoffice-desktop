@echo off
rem SmartOffice Desktop - build script (Windows)
rem Builds launcher + all module executables and copies them next to the
rem launcher. Requires Lazarus lazbuild.exe; adjust the path if needed.
call "%~dp0build_all.bat"
