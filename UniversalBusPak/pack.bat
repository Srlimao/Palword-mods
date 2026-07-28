@echo off
echo Packaging UniversalBusPak.pak using UnrealPak...
python "%~dp0pack_pak.py"

set OUTPUT_PAK=%~dp0UniversalBusPak.pak
set DEST_CLIENT=C:\Program Files (x86)\Steam\steamapps\common\Palworld\Pal\Content\Paks\LogicMods
set DEST_SERVER=D:\Games\GameServers\PalworldLocal\Pal\Content\Paks\LogicMods

if exist "%OUTPUT_PAK%" (
    if not exist "%DEST_CLIENT%" mkdir "%DEST_CLIENT%"
    if not exist "%DEST_SERVER%" mkdir "%DEST_SERVER%"
    
    copy /Y "%OUTPUT_PAK%" "%DEST_CLIENT%\UniversalBusPak.pak"
    copy /Y "%OUTPUT_PAK%" "%DEST_SERVER%\UniversalBusPak.pak"
    echo Deployed UniversalBusPak.pak to client and server LogicMods folders!
) else (
    echo Error: UniversalBusPak.pak not found.
)

pause

