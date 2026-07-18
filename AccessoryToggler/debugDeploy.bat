@echo off
:: Define source and destination paths
set "SOURCE=D:\Mods\Palword\AccessoryToggler\Scripts"
set "DEST_PROD=C:\Program Files (x86)\Steam\steamapps\common\Palworld\Mods\NativeMods\UE4SS\Mods\AccessoryToggler\Scripts"
set "DEST_DEBUG=C:\Program Files (x86)\Steam\steamapps\common\Palworld\Mods\NativeMods\UE4SS\Mods\AccessoryTogglerDEBUG\Scripts"

:: Copy files
xcopy "%SOURCE%" "%DEST_PROD%" /E /I /Y
xcopy "%SOURCE%" "%DEST_DEBUG%" /E /I /Y

exit /b 0
