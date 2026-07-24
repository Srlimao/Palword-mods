@echo off
set "SOURCE=D:\Mods\Palword\MapsPlusServer\Scripts"
set "SOURCE_INFO=D:\Mods\Palword\MapsPlusServer\Info.json"

:: Deploy to Client (both MapsPlusServer and MapsPlusServerDEBUG)
xcopy "%SOURCE%" "D:\Games\Palworld_Alt\Mods\NativeMods\UE4SS\Mods\MapsPlusServer\Scripts" /E /I /Y
copy /Y "%SOURCE_INFO%" "D:\Games\Palworld_Alt\Mods\NativeMods\UE4SS\Mods\MapsPlusServer\Info.json"
xcopy "%SOURCE%" "D:\Games\Palworld_Alt\Mods\NativeMods\UE4SS\Mods\MapsPlusServerDEBUG\Scripts" /E /I /Y
copy /Y "%SOURCE_INFO%" "D:\Games\Palworld_Alt\Mods\NativeMods\UE4SS\Mods\MapsPlusServerDEBUG\Info.json"

:: Deploy to Server (both MapsPlusServer and MapsPlusServerDEBUG)
xcopy "%SOURCE%" "D:\Games\GameServers\PalworldLocal\Mods\NativeMods\UE4SS\Mods\MapsPlusServer\Scripts" /E /I /Y
copy /Y "%SOURCE_INFO%" "D:\Games\GameServers\PalworldLocal\Mods\NativeMods\UE4SS\Mods\MapsPlusServer\Info.json"
xcopy "%SOURCE%" "D:\Games\GameServers\PalworldLocal\Mods\NativeMods\UE4SS\Mods\MapsPlusServerDEBUG\Scripts" /E /I /Y
copy /Y "%SOURCE_INFO%" "D:\Games\GameServers\PalworldLocal\Mods\NativeMods\UE4SS\Mods\MapsPlusServerDEBUG\Info.json"

exit /b 0
