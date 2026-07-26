@echo off
if "%~1"=="" (
    echo Usage: debugDeploy.bat ^<ModName^>
    echo Example: debugDeploy.bat HUDLocator
    exit /b 1
)

powershell.exe -ExecutionPolicy Bypass -File "%~dp0debugDeploy.ps1" -ModName "%~1"
exit /b %ERRORLEVEL%
