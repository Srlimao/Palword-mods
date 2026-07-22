@echo off
:: Define source and destination paths
set "SOURCE=D:\Mods\Palword\FreeCam\Scripts"
set "DEST=D:\Games\Palworld_Alt\Mods\NativeMods\UE4SS\Mods\FreeCamDEBUG\Scripts"
set "MOD_ROOT=D:\Mods\Palword\FreeCam"
set "DEST_ROOT=D:\Games\Palworld_Alt\Mods\NativeMods\UE4SS\Mods\FreeCamDEBUG"

xcopy "%SOURCE%" "%DEST%" /E /I /Y

exit /b 0
