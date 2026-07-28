@echo off
set "SOURCE=D:\Mods\Palword\UniversalBusPakTest\Scripts"
set "SOURCE_INFO=D:\Mods\Palword\UniversalBusPakTest\Info.json"

set "DEST_CLIENT=C:\Program Files (x86)\Steam\steamapps\common\Palworld\Mods\NativeMods\UE4SS\Mods"
xcopy "%SOURCE%" "%DEST_CLIENT%\UniversalBusPakTest\Scripts" /E /I /Y
copy /Y "%SOURCE_INFO%" "%DEST_CLIENT%\UniversalBusPakTest\Info.json"

:: Deploy to Server
xcopy "%SOURCE%" "D:\Games\GameServers\PalworldLocal\Mods\NativeMods\UE4SS\Mods\UniversalBusPakTest\Scripts" /E /I /Y
copy /Y "%SOURCE_INFO%" "D:\Games\GameServers\PalworldLocal\Mods\NativeMods\UE4SS\Mods\UniversalBusPakTest\Info.json"

echo Deployed UniversalBusPakTest to local test client and server!
pause
