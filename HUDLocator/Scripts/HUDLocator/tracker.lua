local UEHelpers = require("UEHelpers")
local configMod = require("HUDLocator.config")
local scanners = require("HUDLocator.scanners")
local utils = require("HUDLocator.utils")
local completion = require("HUDLocator.completion")

local M = {}

M.activePlayers = {}
M.activeRelics = {}
M.activeChests = {}
M.activeEggs = {}
M.activeCaves = {}
M.activeLoot = {}
M.activeNotes = {}
M.activePals = {}
M.cachedLocalPlayer = nil

local hasRunResolve = false
local function ResolvePaths(hud)
    if hasRunResolve then return end
    hasRunResolve = true
    
    configMod.DebugPrint("Resolving item icon paths using BP_PalUIFunctionLibrary...")
    local lib = StaticFindObject("/Game/Pal/Blueprint/UI/BP_PalUIFunctionLibrary.Default__BP_PalUIFunctionLibrary_C")
    if not lib or not lib:IsValid() then
        local classObj = FindFirstOf("BP_PalUIFunctionLibrary_C")
        if classObj and classObj:IsValid() then
            local statusCDO, res = pcall(function() return classObj:GetDefaultObject() end)
            if statusCDO and res and res:IsValid() then
                lib = res
            end
        end
    end
    if not lib or not lib:IsValid() then
        configMod.DebugPrint("Failed to find valid BP_PalUIFunctionLibrary CDO")
        return
    end
    
    local items = { "Relic", "PalEgg", "TreasureBox", "PalSphere", "CopperKey", "Lifmunk" }
    local localAppData = os.getenv("LOCALAPPDATA") or "C:"
    local filepath = string.gsub(localAppData .. "/Pal/Saved/Mods/HUDLocator/resolved_paths.txt", "\\", "/")
    
    local file = io.open(filepath, "w")
    if file then
        file:write("Resolved Item Paths:\n\n")
        for _, item in ipairs(items) do
            local success, softPtr = pcall(function()
                return lib:GetBlueprintItemIcon(FName(item), hud)
            end)
            if success and softPtr then
                local path = tostring(softPtr.AssetPathName)
                file:write(item .. " -> " .. path .. "\n")
                configMod.DebugPrint(item .. " resolved to: " .. path)
            else
                file:write(item .. " -> failed: " .. tostring(softPtr) .. "\n")
                configMod.DebugPrint(item .. " failed to resolve: " .. tostring(softPtr))
            end
        end
        file:close()
        configMod.DebugPrint("Successfully wrote resolved paths to " .. filepath)
    else
        configMod.DebugPrint("Failed to open resolved_paths.txt for writing")
    end
end

local function GetMaxDistSq(categoryConfig)
    local globalDist = (configMod.CONFIG.Global and configMod.CONFIG.Global.MaxDistance) or 15000.0
    local dist = (categoryConfig and categoryConfig.MaxDistance) or globalDist
    return dist * dist
end

-- Scan players, relics, chests, eggs, caves
function M.scan()
    pcall(function()
        local pmoIntegration = require("HUDLocator.pmo_integration")
        pmoIntegration.Sync()
    end)

    if not configMod.CONFIG.Global.Enabled then
        M.activePlayers = {}
        M.activeRelics = {}
        M.activeChests = {}
        M.activeEggs = {}
        M.activeCaves = {}
        M.activeLoot = {}
        M.activeNotes = {}
        M.activePals = {}
        return
    end

    -- Safety check: Only scan when HUD is active (in-world)
    local hudCheck = FindFirstOf("BP_PalHUD_InGame_C")
    if not hudCheck or not hudCheck:IsValid() then
        M.activePlayers = {}
        M.activeRelics = {}
        M.activeChests = {}
        M.activeEggs = {}
        M.activeCaves = {}
        M.activeLoot = {}
        M.activeNotes = {}
        M.activePals = {}
        return
    end

    -- Run font scanner in the background
    if not utils.CachedFont or not utils.CachedFont:IsValid() then
        utils.FindAndCacheFont()
    end

    -- Run texture scanner/dumper to identify icon paths
    utils.DumpAllLoadedTextures()

    -- Run path resolver
    pcall(ResolvePaths, hudCheck)

    local localPlayer = UEHelpers.GetPlayer()
    if not localPlayer or not localPlayer:IsValid() then
        M.activePlayers = {}
        M.activeRelics = {}
        M.activeChests = {}
        M.activeEggs = {}
        M.activeCaves = {}
        M.activeLoot = {}
        M.activeNotes = {}
        M.activePals = {}
        M.cachedLocalPlayer = nil
        scanners.tempCaves = {}
        return 
    end

    M.cachedLocalPlayer = localPlayer

    local uePlayerPos = localPlayer:K2_GetActorLocation()
    if not uePlayerPos then return end

    -- Optimize: Convert UE FVector to native Lua table to avoid thousands of C++ property reflection lookups during distance checks
    local playerPos = { X = uePlayerPos.X, Y = uePlayerPos.Y, Z = uePlayerPos.Z }

    -- 1. Scan Players
    if configMod.CONFIG.Players.Enabled then
        local localPlayerState = localPlayer.PlayerState
        local graceRadiusUEUnits = configMod.CONFIG.Players.GraceRadiusM * 100.0
        local graceRadiusSq = graceRadiusUEUnits * graceRadiusUEUnits
        M.activePlayers = scanners.ScanPlayers(localPlayerState, playerPos, graceRadiusSq)
    else
        M.activePlayers = {}
    end

    -- 2. Scan Relics
    if configMod.CONFIG.Relics.Enabled then
        M.activeRelics = scanners.ScanRelics(playerPos, GetMaxDistSq(configMod.CONFIG.Relics))
    else
        M.activeRelics = {}
    end

    -- 3. Scan Chests
    if configMod.CONFIG.Chests.Enabled then
        M.activeChests = scanners.ScanChests(playerPos, GetMaxDistSq(configMod.CONFIG.Chests))
    else
        M.activeChests = {}
    end

    -- 4. Scan Eggs
    if configMod.CONFIG.Eggs.Filter ~= "None" then
        M.activeEggs = scanners.ScanEggs(playerPos, GetMaxDistSq(configMod.CONFIG.Eggs), configMod.CONFIG.Eggs.Filter, configMod.CONFIG.Global.Debug)
    else
        M.activeEggs = {}
    end

    -- 5. Scan Caves
    if configMod.CONFIG.Caves.Enabled then
        M.activeCaves = scanners.ScanCaves(playerPos, GetMaxDistSq(configMod.CONFIG.Caves))
    else
        M.activeCaves = {}
        scanners.tempCaves = {}
    end

    -- 6. Scan Loot
    if configMod.CONFIG.Loot.Enabled then
        M.activeLoot = scanners.ScanLoot(playerPos, GetMaxDistSq(configMod.CONFIG.Loot), configMod.CONFIG.Loot.Filters)
    else
        M.activeLoot = {}
    end

    -- 7. Scan Notes
    if configMod.CONFIG.Notes and configMod.CONFIG.Notes.Enabled then
        M.activeNotes = scanners.ScanNotes(playerPos, GetMaxDistSq(configMod.CONFIG.Notes))
    else
        M.activeNotes = {}
    end

    -- 8. Scan Pals
    if configMod.CONFIG.Pals and configMod.CONFIG.Pals.Enabled then
        pcall(function()
            M.activePals = scanners.ScanPals(playerPos, GetMaxDistSq(configMod.CONFIG.Pals), configMod.CONFIG.Pals)
        end)
    else
        M.activePals = {}
    end

    -- 9. Scan Completionist Save Data
    pcall(completion.ScanCompletionData)
end

return M
