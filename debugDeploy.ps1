param (
    [Parameter(Mandatory=$true, Position=0)]
    [string]$ModName
)

$ErrorActionPreference = "Stop"

$WorkspaceDir = "D:\Mods\Palword"
$ModDir = Join-Path $WorkspaceDir $ModName

if (-not (Test-Path $ModDir)) {
    Write-Error "Mod directory '$ModName' does not exist at: $ModDir"
}

# Primary local debug game directory
$BaseDebugDir = "C:\Program Files (x86)\Steam\steamapps\common\Palworld\Mods\NativeMods\UE4SS\Mods"
$ServerDebugDir = "D:\Games\GameServers\PalworldLocal\Mods\NativeMods\UE4SS\Mods"

# Determine target directories
$Targets = @()

if (Test-Path $BaseDebugDir) {
    $Targets += (Join-Path $BaseDebugDir "$($ModName)DEBUG")
    $Targets += (Join-Path $BaseDebugDir $ModName)
}

# MapsPlusServer special handling for local test server
if ($ModName -eq "MapsPlusServer" -and (Test-Path $ServerDebugDir)) {
    $Targets += (Join-Path $ServerDebugDir "$($ModName)DEBUG")
    $Targets += (Join-Path $ServerDebugDir $ModName)
}

Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host " Debug Deploying: $ModName" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan

$SourceScripts = Join-Path $ModDir "Scripts"
$InfoFile = Join-Path $ModDir "Info.json"
$EnabledFile = Join-Path $ModDir "enabled.txt"

foreach ($target in $Targets) {
    # Synchronize Scripts folder
    if (Test-Path $SourceScripts) {
        $destScripts = Join-Path $target "Scripts"
        if (-not (Test-Path $destScripts)) {
            New-Item -ItemType Directory -Path $destScripts -Force | Out-Null
        }
        Copy-Item -Path "$SourceScripts\*" -Destination $destScripts -Recurse -Force
        Write-Host "Copied Scripts -> $destScripts" -ForegroundColor Green
    } else {
        # If mod root contains files directly (or custom structure)
        if (-not (Test-Path $target)) {
            New-Item -ItemType Directory -Path $target -Force | Out-Null
        }
        Copy-Item -Path "$ModDir\*" -Destination $target -Recurse -Force -Exclude "docs", "*.zip", "*.tmp"
        Write-Host "Copied root -> $target" -ForegroundColor Green
    }

    # Copy Info.json if present
    if (Test-Path $InfoFile) {
        Copy-Item -Path $InfoFile -Destination (Join-Path $target "Info.json") -Force
        Write-Host "Copied Info.json -> $target" -ForegroundColor Gray
    }

    # Copy enabled.txt if present
    if (Test-Path $EnabledFile) {
        Copy-Item -Path $EnabledFile -Destination (Join-Path $target "enabled.txt") -Force
        Write-Host "Copied enabled.txt -> $target" -ForegroundColor Gray
    }
}

Write-Host "`nDebug deployment for $ModName completed successfully!" -ForegroundColor Green
