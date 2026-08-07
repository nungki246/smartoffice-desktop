unit uVersion;

{
  SmartOffice Desktop - version and update-source constants.

  AppVersion is compared against the latest GitHub release tag (e.g. "v1.0.1").
  Bump AppVersion in this single file before releasing a new build.

  DefaultUpdateRepo uses the "owner/repo" format, e.g.
  'yourname/smartoffice-desktop'. Leave it empty to keep updates disabled
  until the repository is configured in Pengaturan Sistem.
}

{$mode objfpc}{$H+}

interface

const
  AppVersion = '1.0.0';
  AppTitle = 'SmartOffice Desktop';
  DefaultUpdateRepo = '';

implementation

end.
