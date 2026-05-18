@echo off
title Critter Overlay - Python Installer
color 0B

echo.
echo  =============================================
echo    CRITTER OVERLAY  ^|  Python Installer
echo  =============================================
echo.
echo  This will download and install Python 3.12 automatically.
echo  Python is free and open source (python.org).
echo.
echo  Press any key to start, or close this window to cancel.
pause >nul

echo.
echo  Downloading Python 3.12 ...
echo  (About 25 MB - may take a moment)
echo.

set "PY_URL=https://www.python.org/ftp/python/3.12.9/python-3.12.9-amd64.exe"
set "PY_INSTALLER=%TEMP%\python_critter_setup.exe"

powershell -NoProfile -Command "Invoke-WebRequest -Uri '%PY_URL%' -OutFile '%PY_INSTALLER%' -UseBasicParsing"

if not exist "%PY_INSTALLER%" (
    echo.
    echo  [ERROR] Download failed. Please check your internet connection
    echo  and try again, or install Python manually from:
    echo.
    echo      https://www.python.org/downloads/
    echo.
    echo  When installing manually, tick "Add Python to PATH".
    echo.
    pause
    exit /b 1
)

echo.
echo  Installing Python silently...
echo  (This takes about 30 seconds)
echo.

"%PY_INSTALLER%" /quiet InstallAllUsers=0 PrependPath=1 Include_test=0 Include_pip=1
del "%PY_INSTALLER%" >nul 2>&1

echo.
echo  =============================================
echo    Python installed!
echo  =============================================
echo.
echo  IMPORTANT: Close this window completely, then
echo  double-click setup.bat to finish setting up
echo  Critter Overlay.
echo.
echo  (A fresh window is needed so Python is detected.)
echo.
pause
exit
