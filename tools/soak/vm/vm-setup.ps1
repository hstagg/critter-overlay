# Inside the test VM (over SSH, as the admin test user): Git for Windows,
# Godot 4.7.2 with its export templates, and the repo. Safe to run again.
param([string]$Branch = "v3", [string]$GodotVersion = "4.7.2-stable")
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$tools = "C:\tools"
New-Item -ItemType Directory -Force $tools, "$tools\godot", "C:\soak" | Out-Null
$rel = "https://github.com/godotengine/godot/releases/download/$GodotVersion"

if (-not (Test-Path "C:\Program Files\Git\bin\git.exe")) {
    $git = (Invoke-RestMethod https://api.github.com/repos/git-for-windows/git/releases/latest).assets |
        Where-Object { $_.name -match '^Git-.*-64-bit\.exe$' } | Select-Object -First 1
    curl.exe -sSL -o "$tools\git-setup.exe" $git.browser_download_url
    Start-Process "$tools\git-setup.exe" -ArgumentList "/VERYSILENT", "/NORESTART", "/NOCANCEL", "/SP-", "/SUPPRESSMSGBOXES" -Wait
}

if (-not (Test-Path "$tools\godot\godot.exe")) {
    curl.exe -sSL -o "$tools\godot.zip" "$rel/Godot_v${GodotVersion}_win64.exe.zip"
    Expand-Archive "$tools\godot.zip" "$tools\godot" -Force
    # The console build, so stdout reaches redirections and logs.
    Copy-Item "$tools\godot\Godot_v${GodotVersion}_win64_console.exe" "$tools\godot\godot.exe"
}
$templates = Join-Path $env:APPDATA ("Godot\export_templates\" + ($GodotVersion -replace '-', '.'))
if (-not (Test-Path "$templates\windows_release_x86_64.exe")) {
    # A .tpz is a zip of templates\; Expand-Archive only takes a .zip name.
    curl.exe -sSL -o "$tools\templates.zip" "$rel/Godot_v${GodotVersion}_export_templates.tpz"
    Expand-Archive "$tools\templates.zip" "$tools\templates" -Force
    New-Item -ItemType Directory -Force $templates | Out-Null
    Copy-Item "$tools\templates\templates\*" $templates -Recurse -Force
    Remove-Item "$tools\templates.zip", "$tools\templates" -Recurse -Force
}

$path = [Environment]::GetEnvironmentVariable("Path", "Machine")
foreach ($p in "$tools\godot", "C:\Program Files\Git\bin") {
    if ($path -notlike "*$p*") { $path = "$path;$p" }
}
[Environment]::SetEnvironmentVariable("Path", $path, "Machine")
$env:Path = "$env:Path;$tools\godot;C:\Program Files\Git\bin"

if (-not (Test-Path "C:\critter-overlay\.git")) {
    git clone -q https://github.com/hstagg/critter-overlay.git C:\critter-overlay
}
git -C C:\critter-overlay fetch -q origin
git -C C:\critter-overlay checkout -q $Branch
git -C C:\critter-overlay pull -q --ff-only
"git: " + (git --version)
"godot: " + (& "$tools\godot\godot.exe" --version)
"templates: " + (Test-Path "$templates\windows_release_x86_64.exe")
"repo: " + (git -C C:\critter-overlay log --oneline -1)
