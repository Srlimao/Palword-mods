@echo off
:: Define source and destination paths
set "SOURCE=D:\Mods\Palword\MapsPlusServer\Scripts"
set "DEST=D:\Games\Palworld_Alt\Mods\NativeMods\UE4SS\Mods\MapsPlusServerDEBUG\Scripts"
set "DEST_SERVER=D:\Games\GameServers\PalworldLocal\Mods\NativeMods\UE4SS\Mods\MapsPlusServerDEBUG\Scripts"
set "SOURCE_INFO=D:\Mods\Palword\MapsPlusServer\Info.json"
set "DEST_INFO=D:\Games\Palworld_Alt\Mods\NativeMods\UE4SS\Mods\MapsPlusServerDEBUG\Info.json"
set "DEST_INFO_SERVER=D:\Games\GameServers\PalworldLocal\Mods\NativeMods\UE4SS\Mods\MapsPlusServerDEBUG\Info.json"

:: Copy the Scripts folder and its contents
xcopy "%SOURCE%" "%DEST%" /E /I /Y
xcopy "%SOURCE%" "%DEST_SERVER%" /E /I /Y

:: Copy the Info.json manifest file
copy /Y "%SOURCE_INFO%" "%DEST_INFO%"
copy /Y "%SOURCE_INFO%" "%DEST_INFO_SERVER%"

exit /b 0
