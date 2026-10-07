; installer-v3.iss - Inno Setup 6 script for Critter Overlay v3 (the Godot build)
;
; Build with build-v3.ps1, or:  ISCC.exe /DMyAppVersion=3.0.0 installer-v3.iss
; Input:  ..\build\  (CritterOverlay.exe and critter_native DLL from the Godot export),
;         or the folder given by /DBuildDir= (build-v3.ps1 -Admin passes ..\build-admin)
; Output: installer\output\CritterOverlaySetup-<version>.exe
;
; AppId is v2.0's, unchanged: installing v3 upgrades a v2.0 install in place
; (same folder, same Start menu entry), and the startup entry keeps v2.0's
; name (CritterOverlay), so a user's start-with-Windows choice carries over.
;
; One-click updates (godot/updater.gd) run this installer with:
;   /SILENT or /VERYSILENT /SP- /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS
;   /LOG=<file>  /UPDATE=1  [/RELAUNCH=<path to CritterOverlay.exe>]
; /UPDATE=1 waits for the app, which has just been told to quit, to let go of
; its mutex. /RELAUNCH starts the app again afterwards, whether the install
; went through or not, so nobody is left without their critters. An update
; also moves the old files aside first and puts them back if it fails part
; way (see PrepareToInstall). A manual install behaves as before.

#define MyAppName "Critter Overlay"
#define MyAppPublisher "hstagg"
#define MyAppExeName "CritterOverlay.exe"
#define MyAppDescription "Small companions for long days."

#ifndef MyAppVersion
  #define MyAppVersion "3.0.0"
#endif
#ifndef BuildDir
  #define BuildDir "..\build"
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
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

[Code]

var
  ShouldDeleteAppData: Boolean;
  Updating: Boolean;       // started by the app (/UPDATE=1)
  Finished: Boolean;       // the install went through
  Moved: TArrayOfString;   // the old files, moved aside

function InitializeSetup(): Boolean;
var
  Waited: Integer;
begin
  // The app's single-instance mutex (main.gd). Restart Manager
  // (CloseApplications) remains the backstop if it is still held.
  Updating := ExpandConstant('{param:UPDATE|0}') = '1';
  if Updating then
  begin
    Waited := 0;
    while CheckForMutexes('CritterOverlay.v3') and (Waited < 15000) do
    begin
      Sleep(250);
      Waited := Waited + 250;
    end;
  end;
  Result := True;
end;

// Inno does not put back files it replaced when an install fails part way,
// which could leave a new exe beside an old DLL. So an update first moves
// the old files into update-backup (a rename, on the same disk), and puts
// them back if the install does not finish. If they cannot be moved, the
// update stops before anything is touched.

function BackupDir(): String;
begin
  Result := ExpandConstant('{app}\update-backup');
end;

procedure PutBack();
var
  I: Integer;
  Name: String;
begin
  for I := 0 to GetArrayLength(Moved) - 1 do
  begin
    Name := ExpandConstant('{app}\') + Moved[I];
    if FileExists(Name) then
      DeleteFile(Name);
    RenameFile(BackupDir() + '\' + Moved[I], Name);
  end;
  SetArrayLength(Moved, 0);
  DelTree(BackupDir(), True, True, True);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  FindRec: TFindRec;
  Names: TArrayOfString;
  I, N: Integer;
begin
  Result := '';
  if not Updating then
    Exit;
  N := 0;
  if FindFirst(ExpandConstant('{app}\*'), FindRec) then
  try
    repeat
      if (FindRec.Attributes and FILE_ATTRIBUTE_DIRECTORY = 0) and (Pos('unins', Lowercase(FindRec.Name)) <> 1) then
      begin
        SetArrayLength(Names, N + 1);
        Names[N] := FindRec.Name;
        N := N + 1;
      end;
    until not FindNext(FindRec);
  finally
    FindClose(FindRec);
  end;
  DelTree(BackupDir(), True, True, True);
  ForceDirectories(BackupDir());
  for I := 0 to N - 1 do
  begin
    if not RenameFile(ExpandConstant('{app}\') + Names[I], BackupDir() + '\' + Names[I]) then
    begin
      Result := 'Could not move ' + Names[I] + ' aside to update it.';
      Log(Result);
      PutBack();
      Exit;
    end;
    SetArrayLength(Moved, GetArrayLength(Moved) + 1);
    Moved[GetArrayLength(Moved) - 1] := Names[I];
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssDone then
  begin
    Finished := True;
    if Updating then
      DelTree(BackupDir(), True, True, True);
  end;
end;

procedure DeinitializeSetup();
var
  Path: String;
  Code: Integer;
begin
  if Updating and not Finished and (GetArrayLength(Moved) > 0) then
  begin
    Log('The update did not finish: putting the old files back.');
    PutBack();
  end;
  // Start the app again, updated or not, so nobody is left without critters.
  Path := ExpandConstant('{param:RELAUNCH|}');
  if (Path <> '') and FileExists(Path) then
    ExecAsOriginalUser(Path, '', '', SW_SHOWNORMAL, ewNoWait, Code);
end;

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
