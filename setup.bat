@echo off
setlocal enabledelayedexpansion
title Critter Overlay - Setup
color 0A

echo.
echo  =============================================
echo    CRITTER OVERLAY  ^|  First Time Setup
echo  =============================================
echo.

REM -------------------------------------------------------
REM Refresh PATH from registry so newly-installed Python
REM is visible even without restarting Explorer
REM -------------------------------------------------------
powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('PATH','User')" > "%TEMP%\critter_upath.tmp" 2>nul
for /f "usebackq delims=" %%P in ("%TEMP%\critter_upath.tmp") do set "PATH=!PATH!;%%P"
del "%TEMP%\critter_upath.tmp" >nul 2>&1

powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('PATH','Machine')" > "%TEMP%\critter_mpath.tmp" 2>nul
for /f "usebackq delims=" %%P in ("%TEMP%\critter_mpath.tmp") do set "PATH=!PATH!;%%P"
del "%TEMP%\critter_mpath.tmp" >nul 2>&1

REM -------------------------------------------------------
REM Find Python
REM -------------------------------------------------------
call :find_python

if not defined PYTHON_EXE (
    echo  [!] Python was not detected on this computer.
    echo.
    echo  To install it automatically, run:
    echo.
    echo      pythoninstall.bat
    echo.
    echo  That file is included in this folder.
    echo  Once Python is installed, run setup.bat again.
    echo.
    pause
    exit /b 1
)

echo  [OK] Python found: %PYTHON_EXE%
echo.

REM -------------------------------------------------------
REM Check version is 3.9 - 3.13
REM (pygame does not yet publish wheels for 3.14+, and building
REM  from source on Windows almost always fails for end users.)
REM -------------------------------------------------------
for /f "tokens=*" %%V in ('"%PYTHON_EXE%" -c "import sys;print(\"{}.{}\".format(sys.version_info[0],sys.version_info[1]))"') do set "PY_VER=%%V"

"%PYTHON_EXE%" -c "import sys; exit(0 if (3,9) <= sys.version_info[:2] < (3,14) else 1)" >nul 2>&1
if errorlevel 1 (
    echo  [ERROR] Detected Python %PY_VER%, which is not supported.
    echo.
    echo  Critter Overlay needs Python 3.9 - 3.13.
    echo  Pygame does not yet have prebuilt wheels for 3.14 or newer.
    echo.
    echo  To fix this:
    echo    1. Run  pythoninstall.bat  in this folder - it installs Python 3.12.
    echo    2. Or uninstall your current Python from "Add or remove programs"
    echo       and then run pythoninstall.bat.
    echo.
    pause
    exit /b 1
)

echo  [OK] Python version OK (%PY_VER%).
echo.
echo  Installing required packages (this may take a minute)...
echo.

REM -------------------------------------------------------
REM Install packages, with an SSL-retry fallback for users
REM behind firewalls / with outdated root certificates.
REM -------------------------------------------------------
set "PIP_PACKAGES=pygame numpy keyboard pystray Pillow"
set "TRUSTED_HOSTS=--trusted-host pypi.org --trusted-host files.pythonhosted.org --trusted-host pypi.python.org"

"%PYTHON_EXE%" -m pip install --upgrade pip --quiet --no-warn-script-location
"%PYTHON_EXE%" -m pip install %PIP_PACKAGES% --quiet --no-warn-script-location
if not errorlevel 1 goto :install_ok

echo.
echo  [!] First install attempt failed.
echo      Retrying with SSL workaround (trusted hosts + certifi refresh)...
echo.

"%PYTHON_EXE%" -m pip install --upgrade certifi --quiet --no-warn-script-location %TRUSTED_HOSTS%
"%PYTHON_EXE%" -m pip install %PIP_PACKAGES% --no-warn-script-location %TRUSTED_HOSTS%
if not errorlevel 1 goto :install_ok

echo.
echo  [ERROR] Package installation failed.
echo.
echo  Most common causes:
echo    1. Pygame has no wheel for your Python version - reinstall using
echo       pythoninstall.bat to get Python 3.12.
echo    2. A firewall, VPN, or antivirus is intercepting pip's SSL
echo       connection to pypi.org.
echo    3. Your Python install is missing trusted root certificates
echo       (try: "%PYTHON_EXE%" -m pip install --upgrade certifi).
echo.
echo  See TROUBLESHOOTING.txt for step-by-step fixes.
echo.
pause
exit /b 1

:install_ok
echo  [OK] All packages installed.
echo.

echo.
echo  =============================================
echo    All done!  Starting Critter Overlay now...
echo  =============================================
echo.
echo  Animals will appear on your screen periodically.
echo  Open settings with:  Ctrl + Shift + A
echo  Pause the app with:  Ctrl + Shift + P
echo.
echo  You can close this window.
echo.
timeout /t 3 /nobreak >nul

start "" "%PYTHONW_EXE%" "%~dp0src\main.py"
exit


REM ===================================================================
REM :find_python
REM Prefers a SUPPORTED Python (3.9 - 3.13) over whatever's on PATH.
REM This means a user with both 3.14 (unsupported) and 3.12 installed
REM will automatically get 3.12 picked, even if 3.14 is first on PATH.
REM Sets PYTHON_EXE and PYTHONW_EXE.
REM ===================================================================
:find_python
set "PYTHON_EXE="
set "PYTHONW_EXE="

REM 1. Ask the py launcher for each supported version, newest first.
REM    The py launcher is the standard Windows entry point and knows
REM    about every Python install registered with the system.
for %%V in (3.13 3.12 3.11 3.10 3.9) do (
    if "!PYTHON_EXE!"=="" (
        py -%%V --version >nul 2>&1
        if not errorlevel 1 (
            for /f "tokens=* delims=" %%P in ('py -%%V -c "import sys; print(sys.executable)" 2^>nul') do (
                if "!PYTHON_EXE!"=="" set "PYTHON_EXE=%%P"
            )
        )
    )
)
if defined PYTHON_EXE goto :derive_pythonw

REM 2. Scan user-install locations for supported versions explicitly.
REM    pythoninstall.bat drops Python 3.12 here, so this is the
REM    fallback path when py launcher is missing/broken.
for %%V in (Python313 Python312 Python311 Python310 Python39) do (
    if "!PYTHON_EXE!"=="" (
        if exist "%LOCALAPPDATA%\Programs\Python\%%V\python.exe" (
            set "PYTHON_EXE=%LOCALAPPDATA%\Programs\Python\%%V\python.exe"
        )
    )
)
if defined PYTHON_EXE goto :derive_pythonw

REM 3. System-wide installs of supported versions.
for %%V in (Python313 Python312 Python311 Python310 Python39) do (
    if "!PYTHON_EXE!"=="" (
        if exist "C:\Program Files\%%V\python.exe" (
            set "PYTHON_EXE=C:\Program Files\%%V\python.exe"
        )
    )
)
if defined PYTHON_EXE goto :derive_pythonw

REM ----- Nothing supported was found. Fall back to ANY Python so we
REM       can give a useful version-mismatch error downstream. -----

REM 4. Check PATH via `where` — skip Windows Store stubs (WindowsApps).
for /f "tokens=* delims=" %%P in ('where python 2^>nul') do (
    if "!PYTHON_EXE!"=="" (
        set "_PYPATH=%%P"
        if /i "!_PYPATH:WindowsApps=!" == "!_PYPATH!" (
            "%%P" --version >nul 2>&1
            if not errorlevel 1 set "PYTHON_EXE=%%P"
        )
    )
)
if defined PYTHON_EXE goto :derive_pythonw

REM 5. Generic py -3 launcher (could be 3.14+).
py -3 --version >nul 2>&1
if not errorlevel 1 (
    for /f "tokens=* delims=" %%P in ('py -3 -c "import sys; print(sys.executable)"') do (
        if "!PYTHON_EXE!"=="" set "PYTHON_EXE=%%P"
    )
)
if defined PYTHON_EXE goto :derive_pythonw

REM 6. Any remaining install dir.
for /d %%D in ("%LOCALAPPDATA%\Programs\Python\Python3*") do (
    if "!PYTHON_EXE!"=="" (
        if exist "%%D\python.exe" set "PYTHON_EXE=%%D\python.exe"
    )
)
if defined PYTHON_EXE goto :derive_pythonw

for /d %%D in ("C:\Program Files\Python3*") do (
    if "!PYTHON_EXE!"=="" (
        if exist "%%D\python.exe" set "PYTHON_EXE=%%D\python.exe"
    )
)
if defined PYTHON_EXE goto :derive_pythonw

for /d %%D in ("C:\Python3*") do (
    if "!PYTHON_EXE!"=="" (
        if exist "%%D\python.exe" set "PYTHON_EXE=%%D\python.exe"
    )
)
if defined PYTHON_EXE goto :derive_pythonw

goto :eof

:derive_pythonw
for %%F in ("!PYTHON_EXE!") do set "PYTHONW_EXE=%%~dpFpythonw.exe"
if not exist "!PYTHONW_EXE!" set "PYTHONW_EXE=!PYTHON_EXE!"
goto :eof
