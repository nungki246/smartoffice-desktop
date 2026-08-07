[Setup]
AppId={{8F2E6B1C-4A9D-4C5E-9B2A-7F1D3E8A5C10}
AppName=SmartOffice Desktop
AppVersion=1.0.0
AppVerName=SmartOffice Desktop 1.0.0
AppPublisher=Rumah Sakit
AppPublisherURL=https://example.com
DefaultDirName={autopf}\SmartOffice Desktop
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
PrivilegesRequired=admin

[Languages]
Name: "id"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "SmartOfficeDesktop.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "apps\*.exe"; DestDir: "{app}\apps"; Flags: ignoreversion recursesubdirs

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
