# Panduan Menambah Modul Baru

Panduan ini menjelaskan cara menambahkan modul baru ke SmartOffice Desktop, dari
membuat proyek modul, mendaftarkannya, hingga build semua dan merilis ke GitHub.

---

## 1. Gambaran Arsitektur

- Setiap modul adalah **executable terpisah** bernama `SIMRS-<Nama>.exe`
  (folder `src\modules\<nama>\`). Modul TIDAK dikompilasi ke dalam launcher.
- Launcher membaca daftar aplikasi dari tabel database `apps` dan menampilkannya
  di panel navigasi (daftar di-refresh setiap **8 detik**).
- Saat modul diklik, launcher menjalankan `apps\SIMRS-<Nama>.exe` dan
  mengirimkan kredensial lewat **environment variable**:
  - `SMARTOFFICE_USER`
  - `SMARTOFFICE_TOKEN`
  (fallback: parameter baris perintah `--user=... --token=...`).
- Modul memvalidasi token via `RBAC.LoginWithToken`, lalu membuka jendela
  host `TModuleHostForm` dan men-dock view-nya ke dalam jendela tersebut.

Struktur yang relevan:

```
src\
  uApp.pas            -> InitApp, DoneApp, LogMsg, exception handler
  uLaunch.pas         -> auth hand-over, single-instance, peluncur EXE
  uModuleHost.pas     -> jendela host bersama untuk semua modul
  uModule.pas         -> TBaseModule (identity modul in-process)
  uModuleView.pas     -> base view
  security\uRBAC.pas  -> login, token, skema tabel (termasuk tabel apps)
  db\uDB.pas          -> koneksi PostgreSQL / SQLite
  modules\
    <nama>\
      SIMRS-<Nama>.lpr
      SIMRS-<Nama>.lpi
      u<Nama>View.pas
      u<Nama>View.lfm
apps\SIMRS-<Nama>.exe   -> hasil build yang dibaca launcher
build_all.bat           -> build launcher + semua modul, salin ke apps\
release.ps1             -> bump versi, build, commit, push, release, installer
```

---

## 2. Membuat Folder dan File Modul

Buat folder `src\modules\<nama>\`. Nama modul dan nama EXE harus konsisten:

| Aspek           | Nilai contoh (modul baru "Rawat Jalan")                |
| --------------- | ------------------------------------------------------ |
| Folder          | `src\modules\rawatjalan\`                              |
| Project (LPI)   | `SIMRS-RawatJalan.lpi`                                 |
| Program (LPR)   | `SIMRS-RawatJalan.lpr`                                 |
| EXE hasil build | `SIMRS-RawatJalan.exe` -> disalin ke `apps\`           |
| Mutex kunci     | `RawatJalan` (bisa beda dari judul, harus unik)        |
| `app_id` di DB  | `rawatjalan`                                           |

> **Penting**: nama file `.lpi`/`.lpr` menentukan nama EXE (`SIMRS-<Nama>.exe`).
> `build_all.bat` menyalin `SIMRS-<Nama>.exe` dari folder modul ke `apps\`
> berdasarkan nama proyek, dan `release.ps1` meng-upload semua `apps\SIMRS-*.exe`
> sebagai aset rilis. Updater juga meng-cocokkan aset berdasarkan nama file.

---

## 3. Menyalin Proyek dari Modul yang Sudah Ada (Paling Cepat)

Cara tercepat adalah menyalin modul kecil yang sudah ada lalu menyesuaikan.

1. Salin folder modul `pendaftaran`:

   ```powershell
   Copy-Item -Recurse "src\modules\pendaftaran" "src\modules\rawatjalan"
   ```

2. Hapus folder hasil build lama agar tidak ikut ter-commit:

   ```powershell
   Remove-Item -Recurse -Force "src\modules\rawatjalan\lib"
   Remove-Item -Force "src\modules\rawatjalan\SIMRS-Pendaftaran.exe"
   Remove-Item -Recurse -Force "src\modules\rawatjalan\backup"
   ```

3. Ganti nama file menjadi `SIMRS-RawatJalan.*`:

   ```powershell
   Rename-Item "src\modules\rawatjalan\SIMRS-Pendaftaran.lpr" "SIMRS-RawatJalan.lpr"
   Rename-Item "src\modules\rawatjalan\SIMRS-Pendaftaran.lpi" "SIMRS-RawatJalan.lpi"
   Rename-Item "src\modules\rawatjalan\SIMRS-Pendaftaran.lps" "SIMRS-RawatJalan.lps" -ErrorAction SilentlyContinue
   Rename-Item "src\modules\rawatjalan\uPendaftaranView.pas" "uRawatJalanView.pas"
   Rename-Item "src\modules\rawatjalan\uPendaftaranView.lfm" "uRawatJalanView.lfm"
   ```

   Lalu lakukan find & replace di seluruh file:
   - `Pendaftaran` -> `RawatJalan` (dan varian `pendaftaran` -> `rawatjalan`)
   - `TPendaftaranView` -> `TRawatJalanView`
   - `uPendaftaranView` -> `uRawatJalanView`
   - `Pendaftaran` (judul, mutex, `app_id`) -> `Rawat Jalan` / `RawatJalan`

4. Sesuaikan baris-baris berikut di `.lpr`:

   - `EnsureSingleInstance('Pendaftaran')` -> `EnsureSingleInstance('RawatJalan')`
   - `ModuleHostForm.Setup('Pendaftaran', TRawatJalanView.Create(nil))` -> judul baru
   - `LogMsg('Modul Pendaftaran dibuka...')` -> nama baru

5. Di `.lpi`, ganti referensi unit `uPendaftaranView.pas` menjadi
   `uRawatJalanView.pas` (path relatif `../../...` untuk unit bersama tetap sama).

6. Sesuaikan `ModuleVersion` di `uRawatJalanView.pas`:

   ```pascal
   const
     ModuleVersion = '1.0.0';
   ```

> Alternatif: buat proyek baru langsung dari Lazarus IDE (File -> New -> Program),
> simpan sebagai `SIMRS-RawatJalan.lpi` di `src\modules\rawatjalan\`, lalu tambahkan
> unit bersama ke proyek dengan path relatif `../../` dan set:
>
> - Search Paths -> OtherUnitFiles: `../..;../../db;../../security;.`
> - Target filename: `SIMRS-RawatJalan`
> - DebugInfoType: `dsDwarf3`, GenerateDebugInfo: `False`

---

## 4. Kerangka Minimal LPR

Jika membuat dari nol, minimal file `SIMRS-RawatJalan.lpr`:

```pascal
program SIMRSRawatJalan;

{$mode objfpc}{$H+}

uses
  Interfaces,
  Forms,
  SysUtils,
  Dialogs,
  Graphics,
  uApp,
  uRBAC,
  uLaunch,
  uModuleHost,
  uRawatJalanView,
  uIcons,
  uTheme;

var
  UserName, Token: string;

procedure SetAppIcon;
var
  Bmp: TBitmap;
  Ico: TIcon;
begin
  Bmp := TBitmap.Create;
  try
    Bmp.SetSize(32, 32);
    Bmp.PixelFormat := pf32bit;
    DrawAppIcon(Bmp, RGBToColor(31, 78, 121), gDocument);
    Ico := TIcon.Create;
    try
      Ico.Assign(Bmp);
      Application.Icon := Ico;
    finally
      Ico.Free;
    end;
  finally
    Bmp.Free;
  end;
end;

begin
  Application.Scaled := True;
  Application.Initialize;
  InstallExceptionHandler;
  SetAppIcon;
  if not EnsureSingleInstance('RawatJalan') then
    Exit;
  InitApp;
  try
    AppDB.ConnectFromConfig;
    if not AppDB.Connected then
      raise Exception.Create('Database tidak terhubung: ' + AppDB.LastError);
    RBAC.EnsureSchema;
    GetModuleAuth(UserName, Token);
    if IsDevMode then
      RBAC.LoginDev
    else
      RBAC.LoginWithToken(UserName, Token);
    if not RBAC.IsLoggedIn then
      raise Exception.Create('Sesi tidak valid atau telah kedaluwarsa.' + sLineBreak +
        'Buka modul melalui SmartOffice Desktop.');
    Application.CreateForm(TModuleHostForm, ModuleHostForm);
    ModuleHostForm.Setup('Rawat Jalan', TRawatJalanView.Create(nil));
    LogMsg('Modul Rawat Jalan dibuka oleh ' + RBAC.Username);
    Application.Run;
  except
    on E: Exception do
    begin
      LogMsg('RawatJalan: ' + E.ClassName + ' at ' +
        IntToHex(PtrUInt(ExceptAddr), 8) + ': ' + E.Message);
      MessageDlg('Kesalahan', E.Message, mtError, [mbOK], 0);
    end;
  end;
  DoneApp;
end.
```

> `EnsureSingleInstance('<Kunci>')` membuat mutex `Local\SmartOfficeDesktop-<Kunci>`.
> Kunci harus unik di antara semua modul. Jika kunci sudah dipakai proses lain,
> modul keluar diam-diam — itu sebabnya launcher (v1.0.11+) akan mematikan proses
> stale yang tidak punya jendela lalu meluncurkan ulang.

---

## 5. View Minimal

`uRawatJalanView.pas` minimal (isi layout di `.lfm` seperti modul lain):

```pascal
unit uRawatJalanView;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls;

const
  ModuleVersion = '1.0.0';

type
  TRawatJalanView = class(TFrame)
  public
    constructor Create(AOwner: TComponent); override;
  end;

implementation

uses
  uApp, uDB, uTheme;

{$R *.lfm}

constructor TRawatJalanView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner); // stream .lfm
  if csDesigning in ComponentState then
    Exit;
  Color := AppTheme.ColorBackgroundAlt;
  Font.Name := AppTheme.FontFamily;
  Font.Size := AppTheme.FontSizeMD;
  LogMsg('Rawat Jalan view dibuat');
end;

end.
```

Tambahkan `uRawatJalanView.lfm` (minimal satu frame kosong):

```
object RawatJalanView: TRawatJalanView
  Left = 0
  Top = 0
  Width = 640
  Height = 480
  Caption = 'Rawat Jalan'
  Color = clWhite
  ParentBackground = False
  TabOrder = 0
end
```

---

## 6. Build Semua (`build_all.bat`)

`build_all.bat` otomatis:
1. Build launcher (`src\modules\launcher\SmartOfficeDesktop.lpi`) ke root.
2. Loop semua folder di `src\modules\` (kecuali `launcher`), build setiap `*.lpi`,
   lalu salin `SIMRS-<Nama>.exe` ke `apps\`.

Jalankan:

```powershell
.\build_all.bat
```

Harus berakhir dengan `ALL BUILDS OK.` Verifikasi:

```powershell
Get-Item apps\SIMRS-RawatJalan.exe
```

Untuk build cepat satu modul saja:

```powershell
& "C:\lazarus\lazbuild.exe" "src\modules\rawatjalan\SIMRS-RawatJalan.lpi"
```

---

## 7. Mendaftarkan Modul di Database `apps`

Launcher hanya menampilkan aplikasi yang ada di tabel `apps`. Ada dua cara.

### 7a. Melalui Modul "Manajemen Aplikasi"

Login -> buka modul **Manajemen Aplikasi** -> Tambah:
- App ID: `rawatjalan`
- Judul: `Rawat Jalan`
- Deskripsi: ...
- Kategori: `Aplikasi`
- File EXE: `SIMRS-RawatJalan.exe`
- Versi: `1.0.0`
- Urutan & Aktif: sesuai kebutuhan

Daftar launcher otomatis ter-refresh dalam ~8 detik.

### 7b. SQL Langsung

PostgreSQL:

```sql
insert into apps (app_id, title, description, category, exe_file, version, sort_order, is_active)
values ('rawatjalan', 'Rawat Jalan', 'Pelayanan rawat jalan', 'Aplikasi',
        'SIMRS-RawatJalan.exe', '1.0.0', 10, true);
```

SQLite:

```sql
insert into apps (app_id, title, description, category, exe_file, version, sort_order, is_active)
values ('rawatjalan', 'Rawat Jalan', 'Pelayanan rawat jalan', 'Aplikasi',
        'SIMRS-RawatJalan.exe', '1.0.0', 10, 1);
```

Skema tabel `apps` dibuat otomatis oleh `RBAC.EnsureSchema` (PostgreSQL maupun
SQLite), jadi tabel pasti sudah ada.

---

## 8. Uji Lokal

1. Pastikan `apps\SIMRS-RawatJalan.exe` ada.
2. Pastikan baris di tabel `apps` aktif (`is_active = true`).
3. Jalankan launcher (`SmartOfficeDesktop.exe`), login.
4. Modul `Rawat Jalan` muncul di navigasi dalam ~8 detik.
5. Klik modul -> jendela host terbuka dengan view modul.
6. Cek log `%APPDATA%\SmartOfficeDesktop\smartoffice.log` untuk:
   - `Meluncurkan modul: rawatjalan (...)` dari launcher
   - `Modul Rawat Jalan dibuka oleh <user>` dari modul

Catatan: kredensial diambil dari env `SMARTOFFICE_USER`/`SMARTOFFICE_TOKEN`
(lihat `GetModuleAuth` di `uLaunch.pas`). Untuk pengujian dari IDE, jalankan
modul dengan define `SMARTOFFICE_DEVBUILD` agar `IsDevMode = True`.

---

## 9. Commit dan Release (`release.ps1`)

> **PENTING**: sebelum rilis, perbarui hitungan aset di `release.ps1` baris ~96:
> `if ($assets.Count -ne 16)` -> ganti `16` menjadi jumlah aset baru
> (launcher + jumlah `SIMRS-*.exe` + 8 DLL). Menambah satu modul berarti
> `16 -> 17`. Jika tidak diubah, skrip akan throw `Jumlah aset tidak 16`.

1. Commit perubahan sumber terlebih dahulu (folder `src\modules\rawatjalan\` dan
   `apps\SIMRS-RawatJalan.exe`):

   ```powershell
   git add src\modules\rawatjalan apps\SIMRS-RawatJalan.exe
   git commit -m "Tambah modul Rawat Jalan"
   git push origin main
   ```

2. Jalankan rilis. `release.ps1` akan: menaikkan versi (auto-bump dari
   `src\uVersion.pas`), kill proses berjalan, build semua via `build_all.bat`,
   verifikasi aset, commit+push bump versi, cek tag, buat GitHub Release,
   upload semua aset, dan kompilasi installer:

   ```powershell
   .\release.ps1 -Notes "Menambahkan modul Rawat Jalan."
   ```

   Untuk menentukan versi eksplisit:

   ```powershell
   .\release.ps1 -Version 1.0.12 -Notes "Rawat Jalan: perbaikan X."
   ```

3. Skrip selesai dengan URL rilis:
   `https://github.com/nungki246/smartoffice-desktop/releases/tag/v<versi>`

4. Pengguna memperbarui via menu **Alat -> Periksa Pembaruan** (semua aset
   rilis diunduh ke `%APPDATA%\SmartOfficeDesktop\updates\`, lalu:
   - `SIMRS-*.exe` disalin ke `apps\`
   - `SmartOfficeDesktop.exe` di-update via self-update batch
   - file lain disalin ke root instalasi)

> Modul yang berjalan akan dihentikan dulu saat update diterapkan, jadi tutup
> modul atau biarkan updater menanganinya otomatis.

---

## 10. Ringkasan Checklist

- [ ] Folder `src\modules\<nama>\` dibuat dengan `SIMRS-<Nama>.lpi`, `.lpr`, view.
- [ ] `EnsureSingleInstance` memakai kunci unik.
- [ ] `ModuleVersion` di-set di view.
- [ ] `build_all.bat` selesai dengan `ALL BUILDS OK.` dan `apps\SIMRS-<Nama>.exe` ada.
- [ ] Baris di tabel `apps` terdaftar (via Manajemen Aplikasi atau SQL).
- [ ] Login -> modul muncul -> klik -> jendela host terbuka.
- [ ] Jumlah aset di `release.ps1` disesuaikan (default `16`).
- [ ] Perubahan di-commit & di-push.
- [ ] `.\release.ps1 -Notes "..."` sukses sampai installer jadi.
- [ ] Verifikasi update otomatis dari launcher.

---

## Referensi File

| File                         | Peran                                                  |
| ---------------------------- | ------------------------------------------------------ |
| `src\uLaunch.pas`            | auth hand-over, single-instance, peluncur EXE          |
| `src\uModuleHost.pas`        | jendela host bersama untuk semua modul                 |
| `src\uApp.pas`               | `InitApp`, `DoneApp`, `LogMsg`, exception handler      |
| `src\security\uRBAC.pas`     | login/token, skema tabel `apps`                        |
| `src\db\uDB.pas`             | koneksi PostgreSQL / SQLite                            |
| `src\uModuleManager.pas`     | muat aplikasi eksternal dari tabel `apps`              |
| `src\uApps.pas`              | CRUD tabel `apps` (`TAppsService`)                     |
| `build_all.bat`              | build launcher + semua modul, salin ke `apps\`         |
| `release.ps1`                | bump versi, build, commit/push, release, installer     |
| `SmartOfficeSetup.iss`       | installer Inno Setup (memasukkan `apps\*.exe` otomatis)|
