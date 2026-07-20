@echo off
:: Define source and destination paths
set "SOURCE=D:\Mods\Palword\HoldToFire\Scripts"
set "DEST=D:\Games\Palworld_Alt\Mods\NativeMods\UE4SS\Mods\HoldToFireDEBUG\Scripts"

:: /E = Copies directories and subdirectories (including empty ones)
:: /I = Assumes destination is a directory if it doesn't exist
:: /Y = Suppresses prompting to confirm overwriting files
xcopy "%SOURCE%" "%DEST%" /E /I /Y

exit /b 0
