[Setup]
AppName=Fatura Mega Okuyucu
AppVersion=1.0
; Admin yetkisi istemesini engeller (UAC uyarisi cikmaz)
PrivilegesRequired=lowest
; Uygulamayi Users\KullaniciAdi\AppData\Local\Programs\Fatura Mega Okuyucu altina kurar
DefaultDirName={userpf}\Fatura Mega Okuyucu
DefaultGroupName=Fatura Mega Okuyucu
OutputBaseFilename=Fatura_Mega_Okuyucu_Setup
DisableProgramGroupPage=yes

[Tasks]
Name: "desktopicon"; Description: "Masaustu simgesi olustur"; GroupDescription: "Ek simgeler:"

[Files]
Source: "FaturaMegaOkuyucu.html"; DestDir: "{app}"
Source: "jsqr.standalone.js"; DestDir: "{app}"
Source: "zxing_reader_bundle.js"; DestDir: "{app}"
Source: "zxing_reader_wasm_b64.js"; DestDir: "{app}"
Source: "mega_launcher.bat"; DestDir: "{app}"
Source: "build_temp_data.ps1"; DestDir: "{app}"
Source: "mega_config.json"; DestDir: "{app}"; Flags: onlyifdoesntexist
; onlyifdoesntexist: kullanici kurallarini duzenlediyse guncelleme/tekrar kurulumda ezilmesin

[Icons]
Name: "{userprograms}\Fatura Mega Okuyucu"; Filename: "{app}\mega_launcher.bat"; WorkingDir: "{app}"
Name: "{userdesktop}\Fatura Mega Okuyucu"; Filename: "{app}\mega_launcher.bat"; WorkingDir: "{app}"; Tasks: desktopicon
; Bu satir Explorer'da secilen dosyalari sag tik > Gonder menusune ekler:
Name: "{userappdata}\Microsoft\Windows\SendTo\Fatura Mega Okuyucu"; Filename: "{app}\mega_launcher.bat"; WorkingDir: "{app}"

[Run]
Filename: "{app}\mega_launcher.bat"; Description: "Fatura Mega Okuyucu'yu simdi ac"; Flags: postinstall nowait skipifsilent
