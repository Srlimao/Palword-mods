param (
    [Parameter(Mandatory=$true)]
    [string]$ModName,
    [Parameter(Mandatory=$false)]
    [ValidateSet("Workshop", "Nexus", "Both")]
    [string]$Target = "Both",
    [Parameter(Mandatory=$false)]
    [string]$ChangeNote,
    [Parameter(Mandatory=$false)]
    [string]$NexusModId,
    [Parameter(Mandatory=$false)]
    [string]$NexusApiKey
)

$ErrorActionPreference = "Stop"

Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host " Automated Mod Deployer: $ModName (Target: $Target)" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan

# 1. Deploy to Steam Workshop if requested
if ($Target -eq "Workshop" -or $Target -eq "Both") {
    Write-Host "`n[1/2] Deploying to Steam Workshop..." -ForegroundColor Yellow
    $workshopArgs = @{
        ModName = $ModName
    }
    if ($ChangeNote) {
        $workshopArgs["ChangeNote"] = $ChangeNote
    }
    
    & "$PSScriptRoot\deploy_workshop.ps1" @workshopArgs
}

# 2. Deploy to Nexus Mods if requested
if ($Target -eq "Nexus" -or $Target -eq "Both") {
    Write-Host "`n[2/2] Deploying to Nexus Mods via MCP Server..." -ForegroundColor Yellow
    $mcpServerDir = "E:\MCP-SERVERS\mod-deploy-mcp-server"
    if (-not $NexusApiKey) {
        $NexusApiKey = $env:NEXUS_MODS_API_KEY
    }
    if (-not $NexusApiKey) {
        $NexusApiKey = [System.Environment]::GetEnvironmentVariable('NEXUS_MODS_API_KEY', 'User')
    }
    if (-not $NexusApiKey) {
        $NexusApiKey = [System.Environment]::GetEnvironmentVariable('NEXUS_MODS_API_KEY', 'Machine')
    }

    if (Test-Path $mcpServerDir) {
        $nodeScript = @"
import { uploadToNexusMods, createModZip } from './nexusClient.js';
import fs from 'fs';
import path from 'path';

async function run() {
  const workspaceDir = 'D:\\\\Mods\\\\Palword';
  const modName = '$ModName';
  const modDir = path.join(workspaceDir, modName);
  
  let infoData = {};
  let workshopData = {};
  try { infoData = JSON.parse(fs.readFileSync(path.join(modDir, 'Info.json'), 'utf-8')); } catch(e){}
  try { workshopData = JSON.parse(fs.readFileSync(path.join(modDir, '.workshop.json'), 'utf-8')); } catch(e){}
  
  const version = infoData.Version || '1.0.0';
  const nexusModId = '$NexusModId' || workshopData.nexus_mod_id;
  const nexusModFileId = '$NexusModFileId' || workshopData.nexus_mod_file_id || workshopData.nexus_file_id;
  const changeNote = '$ChangeNote' || workshopData.changenote || ('v' + version + ' release');
  const apiKey = '$NexusApiKey' || process.env.NEXUS_MODS_API_KEY || process.env.NEXUS_API_KEY;

  if (!nexusModId) {
    console.log('⚠️ Skipped Nexus Mods deployment: nexus_mod_id not found in args or .workshop.json');
    return;
  }

  const tempZip = path.join(workspaceDir, modName + '_v' + version + '.zip');
  console.log('Packaging mod to ' + tempZip + '...');
  await createModZip(modDir, tempZip);

  console.log('Publishing v' + version + ' to Nexus Mods (ID: ' + nexusModId + ')...');
  const res = await uploadToNexusMods({
    apiKey,
    gameDomain: workshopData.game_domain || 'palworld',
    modId: nexusModId,
    modFileId: nexusModFileId,
    zipFilePath: tempZip,
    version,
    fileName: modName + ' v' + version,
    changelog: changeNote
  });

  try { fs.unlinkSync(tempZip); } catch(e){}
  console.log('✅ Nexus Mods deployment successful!');
}

run().catch(err => {
  console.error('❌ Nexus Mods deploy error:', err.message);
  process.exit(1);
});
"@
        $tempJs = Join-Path $mcpServerDir "temp_runner.js"
        Set-Content -Path $tempJs -Value $nodeScript -Encoding UTF8
        try {
            node $tempJs
        } finally {
            Remove-Item $tempJs -ErrorAction SilentlyContinue
        }
    } else {
        Write-Warning "MCP Server directory not found at $mcpServerDir. Skipped Nexus deployment."
    }
}

Write-Host "`n=========================================================" -ForegroundColor Green
Write-Host " Deployment Workflow Completed Successfully!" -ForegroundColor Green
Write-Host "=========================================================" -ForegroundColor Green
