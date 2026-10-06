; installer-v3.iss - Inno Setup 6 script for Critter Overlay v3 (the Godot build)
;
; Build with build-v3.ps1, or:  ISCC.exe /DMyAppVersion=3.0.0 installer-v3.iss
; Input:  ..\build\  (CritterOverlay.exe and critter_native DLL from the Godot export)
; Output: installer\output\CritterOverlaySetup-<version>.exe
;
; AppId is v2.0's, unchanged: installing v3 upgrades a v2.0 install in place
; (same folder, same Start menu entry), and the startup entry keeps v2.0's
; name (CritterOverlay), so a user's start-with-Windows choice carries over.

#define MyAppName "Critter Overlay"
#define MyAppPublisher "hstagg"
#define MyAppExeName "CritterOverlay.exe"
#define MyAppDescription "Small companions for long days."

#ifndef MyAppVersion
  #define MyAppVersion "3.0.0"
#endif

[Setup]
; Fixed GUID, shared with v2.0. Never change it.
AppId={{A7D3B2E4-9C1F-4E8A-B5D6-3F7A2C8E4B9D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://github.com/hstagg/critter-overlay
AppSupportURL=https://github.com/hstagg/critter-overlay/issues
AppUpdatesURL=https://github.com/hstagg/critter-overlay/releases
AppComments={#MyAppDescription}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableDirPage=yes
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
OutputDir=output
OutputBaseFilename=CritterOverlaySetup-{#MyAppVersion}
SetupIconFile=..\godot\icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2/ultra
SolidCompression=yes
WizardStyle=modern
LicenseFile=license.txt
CloseApplications=yes
RestartApplications=no
MinVersion=10.0

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[InstallDelete]
; v2.0 was a PyInstaller build: its runtime folder is not part of v3.
Type: filesandordirs; Name: "{app}\_internal"

[Files]
Source: "..\build\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

[Code]

var
  ShouldDeleteAppData: Boolean;

function InitializeUninstall(): Boolean;
begin
  ShouldDeleteAppData := MsgBox(
    'Do you also want to delete your critters'' Collection, berries, clothes and settings?' + #13#10 +
    'YES - remove everything.' + #13#10 +
    'NO  - keep it, so a reinstall picks up where you left off.' + #13#10 +
    'The default is NO.',
    mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES;
  Result := True;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  Dir: String;
begin
  if CurUninstallStep = usUninstall then
    RegDeleteValue(HKEY_CURRENT_USER, 'Software\Microsoft\Windows\CurrentVersion\Run', 'CritterOverlay');
  if (CurUninstallStep = usPostUninstall) and ShouldDeleteAppData then
  begin
    // v3's data, then v2.0's
    Dir := ExpandConstant('{userappdata}\Critter Overlay');
    if DirExists(Dir) then DelTree(Dir, True, True, True);
    Dir := ExpandConstant('{userappdata}\CritterOverlay');
    if DirExists(Dir) then DelTree(Dir, True, True, True);
  end;
end;
