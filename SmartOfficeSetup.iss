[Setup]
AppId={{8F2E6B1C-4A9D-4C5E-9B2A-7F1D3E8A5C10}
AppName=SmartOffice Desktop
AppVersion=1.0.15
AppVerName=SmartOffice Desktop 1.0.15
AppPublisher=Rumah Sakit
AppPublisherURL=https://example.com
; Per-user install so the auto-update can replace files without admin rights.
DefaultDirName={localappdata}\Programs\SmartOffice Desktop
DefaultGroupName=SmartOffice Desktop
OutputDir=installer
OutputBaseFilename=SmartOfficeDesktopSetup
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
SetupLogging=yes
WizardStyle=modern
DisableProgramGroupPage=auto
PrivilegesRequired=lowest
SetupIconFile=smartoffice.ico
UninstallDisplayIcon={app}\SmartOfficeDesktop.exe

[Languages]
Name: "id"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "SmartOfficeDesktop.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "apps\*.exe"; DestDir: "{app}\apps"; Flags: ignoreversion recursesubdirs
Source: "libpq.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "sqlite3.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "libssl-3-x64.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "libcrypto-3-x64.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "libiconv-2.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "libintl-9.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "libwinpthread-1.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "zlib1.dll"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\SmartOffice Desktop"; Filename: "{app}\SmartOfficeDesktop.exe"
Name: "{autodesktop}\SmartOffice Desktop"; Filename: "{app}\SmartOfficeDesktop.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Buat shortcut di desktop"; GroupDescription: "Ikon tambahan:"; Flags: unchecked
Name: "delappdata"; Description: "Hapus data aplikasi (pengaturan, log, database)"; GroupDescription: "Data pengguna:"; Flags: unchecked

[UninstallDelete]
Type: filesandordirs; Name: "{userappdata}\SmartOfficeDesktop"; Tasks: delappdata

[Run]
Filename: "{app}\SmartOfficeDesktop.exe"; Description: "Jalankan SmartOffice Desktop"; Flags: nowait postinstall skipifsilent
