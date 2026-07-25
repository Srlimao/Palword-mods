@echo off
:: Define source and destination paths
set "SOURCE=D:\Mods\Palword\StatMonitor\Scripts"
set "DEST=D:\Games\Palworld_Alt\Mods\NativeMods\UE4SS\Mods\StatMonitor\Scripts"

xcopy "%SOURCE%" "%DEST%" /E /I /Y
copy /Y "D:\Mods\Palword\StatMonitor\enabled.txt" "D:\Games\Palworld_Alt\Mods\NativeMods\UE4SS\Mods\StatMonitor\enabled.txt"

exit /b 0
