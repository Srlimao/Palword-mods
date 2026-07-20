@echo off
:: Define source and destination paths
set "SOURCE=D:\Mods\Palword\AccessoryToggler\Scripts"
set "DEST_PROD=D:\Games\Palworld_Alt\Mods\NativeMods\UE4SS\Mods\AccessoryToggler\Scripts"
set "DEST_DEBUG=D:\Games\Palworld_Alt\Mods\NativeMods\UE4SS\Mods\AccessoryTogglerDEBUG\Scripts"

:: Copy files
:: xcopy "%SOURCE%" "%DEST_PROD%" /E /I /Y
xcopy "%SOURCE%" "%DEST_DEBUG%" /E /I /Y

exit /b 0
