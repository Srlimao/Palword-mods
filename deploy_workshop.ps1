param (
    [Parameter(Mandatory=$true)]
    [string]$ModName,
    [Parameter(Mandatory=$false)]
    [string]$ChangeNote
)

$ErrorActionPreference = "Stop"

# 1. Load configuration
$ConfigFile = Join-Path $PSScriptRoot "deploy_config.json"
$TemplateFile = Join-Path $PSScriptRoot "deploy_config.template.json"

if (-not (Test-Path $ConfigFile)) {
    if (Test-Path $TemplateFile) {
        Copy-Item $TemplateFile $ConfigFile
        Write-Error "Created local 'deploy_config.json' from template. Please open it and configure your 'SteamUsername' before proceeding."
    } else {
        Write-Error "Local configuration file 'deploy_config.json' not found, and template is missing."
    }
}

$ConfigObj = Get-Content $ConfigFile -Raw | ConvertFrom-Json
$SteamCmdPath = $ConfigObj.SteamCmdPath
$SteamUsername = $ConfigObj.SteamUsername

if (-not $SteamCmdPath -or $SteamUsername -eq "YOUR_STEAM_USERNAME") {
    Write-Error "Please configure a valid SteamCmdPath and SteamUsername in 'deploy_config.json'."
}

if (-not (Test-Path $SteamCmdPath)) {
    Write-Error "SteamCMD executable not found at: $SteamCmdPath"
}

# 2. Verify Mod directory and configs
$ModDir = Join-Path $PSScriptRoot $ModName
if (-not (Test-Path $ModDir)) {
    Write-Error "Mod directory '$ModName' does not exist at: $ModDir"
}

$InfoFile = Join-Path $ModDir "Info.json"
if (-not (Test-Path $InfoFile)) {
    Write-Error "Info.json manifest not found in $ModName directory."
}

$WorkshopFile = Join-Path $ModDir ".workshop.json"
if (-not (Test-Path $WorkshopFile)) {
    Write-Error ".workshop.json metadata not found in $ModName directory."
}

# Parse JSONs
$Info = Get-Content $InfoFile -Raw | ConvertFrom-Json
$Workshop = Get-Content $WorkshopFile -Raw | ConvertFrom-Json

$Version = $Info.Version
$PublishedFileId = $Workshop.publishedfileid

# Use passed ChangeNote, otherwise fallback to .workshop.json value
if (-not $ChangeNote -or $ChangeNote -eq "") {
    $ChangeNote = $Workshop.changenote
}
$ThumbnailName = $Info.Thumbnail

if (-not $PublishedFileId -or $PublishedFileId -eq "") {
    Write-Error "publishedfileid is missing or empty in .workshop.json."
}

if (-not $ChangeNote -or $ChangeNote -eq "") {
    $ChangeNote = "Version $Version release"
}

# 3. Setup Staging Directory
$StagingDir = Join-Path $PSScriptRoot "staging"
$ModStagingDir = Join-Path $StagingDir $ModName

if (Test-Path $ModStagingDir) {
    Remove-Item $ModStagingDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $ModStagingDir | Out-Null

# Copy clean files for release
Write-Host "Staging files for '$ModName' (v$Version)..." -ForegroundColor Cyan

# 1. Info.json
Copy-Item $InfoFile (Join-Path $ModStagingDir "Info.json")

# 2. Thumbnail
$ThumbnailPath = Join-Path $ModDir $ThumbnailName
if (Test-Path $ThumbnailPath) {
    Copy-Item $ThumbnailPath (Join-Path $ModStagingDir $ThumbnailName)
} else {
    Write-Warning "Thumbnail '$ThumbnailName' declared in Info.json was not found."
}

# 3. Scripts
$ScriptsSrc = Join-Path $ModDir "Scripts"
if (Test-Path $ScriptsSrc) {
    Copy-Item $ScriptsSrc (Join-Path $ModStagingDir "Scripts") -Recurse
} else {
    Write-Error "Scripts directory not found in mod."
}

# 4. Optional assets (e.g. item_list.json)
$ItemListPath = Join-Path $ModDir "item_list.json"
if (Test-Path $ItemListPath) {
    Copy-Item $ItemListPath (Join-Path $ModStagingDir "item_list.json")
    Write-Host "Staged optional file: item_list.json"
}

# 4. Generate VDF File
$VdfPath = Join-Path $ModStagingDir "upload.vdf"
$ContentFolderAbs = (Resolve-Path $ModStagingDir).Path
$PreviewFileAbs = (Resolve-Path (Join-Path $ModStagingDir $ThumbnailName)).Path

# Escape backslashes for VDF format
$ContentFolderEsc = $ContentFolderAbs.Replace('\', '\\')
$PreviewFileEsc = $PreviewFileAbs.Replace('\', '\\')

# Load description if available
$DescriptionFile = Join-Path $ModDir "description_steam.txt"
$DescriptionEsc = ""
if (Test-Path $DescriptionFile) {
    $DescriptionContent = Get-Content $DescriptionFile -Raw
    $DescriptionEsc = $DescriptionContent.Replace('\', '\\').Replace('"', '\"')
    Write-Host "Found description_steam.txt. Including description in upload VDF." -ForegroundColor Cyan
}

$VdfContent = @"
"workshopitem"
{
  "appid" "1623730"
  "publishedfileid" "$PublishedFileId"
  "contentfolder" "$ContentFolderEsc"
  "previewfile" "$PreviewFileEsc"
  "changenote" "$ChangeNote"
"@

if ($DescriptionEsc -ne "") {
    $VdfContent += "`n  `"description`" `"$DescriptionEsc`""
}

$VdfContent += "`n}"

[System.IO.File]::WriteAllText($VdfPath, $VdfContent)
Write-Host "Generated VDF at: $VdfPath" -ForegroundColor Gray

# 5. Run SteamCMD
Write-Host "Launching SteamCMD to upload mod (ID: $PublishedFileId) to Steam Workshop..." -ForegroundColor Yellow
Write-Host "SteamCMD Command: & '$SteamCmdPath' +login $SteamUsername +workshop_build_item '$VdfPath' +quit" -ForegroundColor DarkGray

$OutFile = Join-Path $StagingDir "steamcmd_output_$ModName.log"
$Process = Start-Process -FilePath $SteamCmdPath -ArgumentList "+login", $SteamUsername, "+workshop_build_item", "`"$VdfPath`"", "+quit" -Wait -NoNewWindow -PassThru -RedirectStandardOutput $OutFile

# Print log to console
$LogContent = Get-Content $OutFile
$LogContent | Write-Host

# 6. Analyze Output and Update Metadata
$Success = $false
foreach ($line in $LogContent) {
    if ($line -like "*Success. Workshop item ID*" -or $line -like "*Success. Update workshop item*" -or $line -like "*Committing update...Success*") {
        $Success = $true
        break
    }
}

if ($Success) {
    Write-Host "`n[SUCCESS] Mod '$ModName' v$Version successfully published to Steam Workshop (ID: $PublishedFileId)!" -ForegroundColor Green
    
    # Update .workshop.json
    $Workshop.last_published_version = $Version
    $Workshop.changenote = $ChangeNote
    $UpdatedJson = $Workshop | ConvertTo-Json
    [System.IO.File]::WriteAllText($WorkshopFile, $UpdatedJson)
    Write-Host "Updated last_published_version and changenote in .workshop.json." -ForegroundColor Gray
} else {
    Write-Error "SteamCMD failed to publish the mod. Please check the logs above or steamcmd_output.log."
}
