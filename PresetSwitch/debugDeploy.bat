@echo off
:: Define source and destination paths
set "SOURCE=D:\Mods\Palword\PresetSwitch\Scripts"
set "DEST_PROD=D:\Games\Palworld_Alt\Mods\NativeMods\UE4SS\Mods\PresetSwitch\Scripts"
set "DEST_DEBUG=D:\Games\Palworld_Alt\Mods\NativeMods\UE4SS\Mods\PresetSwitchDEBUG\Scripts"

:: Copy files
:: xcopy "%SOURCE%" "%DEST_PROD%" /E /I /Y
xcopy "%SOURCE%" "%DEST_DEBUG%" /E /I /Y

exit /b 0
