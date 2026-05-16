; installer.iss — Inno Setup 6 script for Critter Overlay
;
; Build: ISCC.exe /DMyAppVersion=1.7.0 installer.iss
; Output: installer\output\CritterOverlaySetup-1.7.0.exe
;
; IMPORTANT: AppId is a fixed GUID. Never change it between versions —
; it is how Inno Setup detects an existing install and performs in-place upgrades.

#define MyAppName "Critter Overlay"
#define MyAppPublisher "Harrison Stagg"
#define MyAppExeName "CritterOverlay.exe"
#define MyAppDescription "Adorable desktop companions that wander across your screen."

; MyAppVersion is passed in from build.ps1: /DMyAppVersion=1.7.0
; Fallback if run directly without the define:
#ifndef MyAppVersion
  #define MyAppVersion "1.7.0"
#endif

[Setup]
; Fixed GUID — do NOT change between versions
AppId={{A7D3B2E4-9C1F-4E8A-B5D6-3F7A2C8E4B9D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://github.com/hstagg/critter-overlay
AppSupportURL=https://github.com/hstagg/critter-overlay/issues
AppUpdatesURL=https://github.com/hstagg/critter-overlay/releases
AppComments={#MyAppDescription}

; Install location: Program Files when admin, %LOCALAPPDATA%\Programs\ when not
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}

; Don't ask the user where to install or which start-menu group to create
DisableDirPage=yes
DisableProgramGroupPage=yes

; Allow non-admin installs; offer elevation dialog if the user wants it
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

; Output
OutputDir=output
OutputBaseFilename=CritterOverlaySetup-{#MyAppVersion}
SetupIconFile=icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

; Compression
Compression=lzma2/ultra
SolidCompression=yes

; Wizard
WizardStyle=modern
LicenseFile=license.txt

; Upgrade behaviour: detect and close the running app, relaunch after install
CloseApplications=yes
RestartApplications=yes

; Windows 10 minimum
MinVersion=10.0

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Dirs]
; Create the custom critters folder so v1.8 has somewhere to land without a schema migration
Name: "{userappdata}\CritterOverlay\custom"; Permissions: users-modify

[Files]
; The entire PyInstaller onedir output — recurse into subdirectories
Source: "..\dist\CritterOverlay\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Launch the app after install completes (user can uncheck)
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; Stop the app before uninstall (best-effort; Inno's CloseApplications handles the main case)
Filename: "{app}\{#MyAppExeName}"; Parameters: ""; Flags: skipifdoesntexist runhidden

[UninstallDelete]
; Nothing here intentionally — user data at %APPDATA%\CritterOverlay\ is preserved by default.
; The [Code] section below adds an opt-in deletion checkbox.

[Code]

var
  ShouldDeleteAppData: Boolean;

// Ask the user whether to delete settings and custom critters during uninstall.
// Default is NO — losing data by default is unacceptable.
function InitializeUninstall(): Boolean;
var
  MsgResult: Integer;
begin
  ShouldDeleteAppData := False;

  MsgResult := MsgBox(
    'Do you also want to delete your settings and custom critters?' + #13#10 +
    #13#10 +
    'YES  — remove everything (settings, custom critters).' + #13#10 +
    'NO   — keep your data so you can reinstall and pick up where you left off.' + #13#10 +
    #13#10 +
    'The default is NO.',
    mbConfirmation,
    MB_YESNO or MB_DEFBUTTON2
  );

  if MsgResult = IDYES then
    ShouldDeleteAppData := True;

  Result := True;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  AppDataDir: String;
begin
  // Remove the autostart registry entry the app may have written
  if CurUninstallStep = usUninstall then
    RegDeleteValue(HKEY_CURRENT_USER,
      'Software\Microsoft\Windows\CurrentVersion\Run',
      'CritterOverlay');

  // Optionally delete user data (settings.json, custom critters)
  if CurUninstallStep = usPostUninstall then
  begin
    if ShouldDeleteAppData then
    begin
      AppDataDir := ExpandConstant('{userappdata}\CritterOverlay');
      if DirExists(AppDataDir) then
        if not DelTree(AppDataDir, True, True, True) then
          MsgBox('Could not fully remove ' + AppDataDir + '. You may delete it manually.',
                 mbInformation, MB_OK);
    end;
  end;
end;
