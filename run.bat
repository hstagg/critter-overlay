@echo off
pythonw "%~dp0src\main.py" 2>nul || python "%~dp0src\main.py"
