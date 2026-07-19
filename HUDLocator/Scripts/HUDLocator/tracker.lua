local UEHelpers = require("UEHelpers")
local configMod = require("HUDLocator.config")
local scanners = require("HUDLocator.scanners")
local utils = require("HUDLocator.utils")

local M = {}

M.activePlayers = {}
M.activeRelics = {}
M.activeChests = {}
M.activeEggs = {}
M.activeCaves = {}
M.activeLoot = {}
M.activeNotes = {}
M.cachedLocalPlayer = nil

local hasRunResolve = false
local function ResolvePaths(hud)
    if hasRunResolve then return end
    hasRunResolve = true
    
    print("[HUDLocator] Resolving item icon paths using BP_PalUIFunctionLibrary...")
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
        print("[HUDLocator] Failed to find valid BP_PalUIFunctionLibrary CDO")
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
                print("[HUDLocator] " .. item .. " resolved to: " .. path)
            else
                file:write(item .. " -> failed: " .. tostring(softPtr) .. "\n")
                print("[HUDLocator] " .. item .. " failed to resolve: " .. tostring(softPtr))
            end
        end
        file:close()
        print("[HUDLocator] Successfully wrote resolved paths to " .. filepath)
    else
        print("[HUDLocator] Failed to open resolved_paths.txt for writing")
    end
end

-- Scan players, relics, chests, eggs, caves
function M.scan()
    if not configMod.CONFIG.Global.Enabled then
        M.activePlayers = {}
        M.activeRelics = {}
        M.activeChests = {}
        M.activeEggs = {}
        M.activeCaves = {}
        M.activeLoot = {}
        M.activeNotes = {}
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
        M.cachedLocalPlayer = nil
        scanners.tempCaves = {}
        return 
    end

    M.cachedLocalPlayer = localPlayer

    local playerPos = localPlayer:K2_GetActorLocation()
    if not playerPos then return end

    -- 1. Scan Players
    if configMod.CONFIG.Players.Enabled then
        local localPlayerState = localPlayer.PlayerState
        M.activePlayers = scanners.ScanPlayers(localPlayerState)
    else
        M.activePlayers = {}
    end

    -- 2. Scan Relics
    if configMod.CONFIG.Relics.Enabled then
        local maxDistSq = configMod.CONFIG.Relics.MaxDistance * configMod.CONFIG.Relics.MaxDistance
        M.activeRelics = scanners.ScanRelics(playerPos, maxDistSq)
    else
        M.activeRelics = {}
    end

    -- 3. Scan Chests
    if configMod.CONFIG.Chests.Enabled then
        local maxDistSq = configMod.CONFIG.Chests.MaxDistance * configMod.CONFIG.Chests.MaxDistance
        M.activeChests = scanners.ScanChests(playerPos, maxDistSq)
    else
        M.activeChests = {}
    end

    -- 4. Scan Eggs
    if configMod.CONFIG.Eggs.Filter ~= "None" then
        local maxDistSq = configMod.CONFIG.Eggs.MaxDistance * configMod.CONFIG.Eggs.MaxDistance
        M.activeEggs = scanners.ScanEggs(playerPos, maxDistSq, configMod.CONFIG.Eggs.Filter, configMod.CONFIG.Global.Debug)
    else
        M.activeEggs = {}
    end

    -- 5. Scan Caves
    if configMod.CONFIG.Caves.Enabled then
        local maxDistSq = configMod.CONFIG.Caves.MaxDistance * configMod.CONFIG.Caves.MaxDistance
        M.activeCaves = scanners.ScanCaves(playerPos, maxDistSq)
    else
        M.activeCaves = {}
        scanners.tempCaves = {}
    end

    -- 6. Scan Loot
    if configMod.CONFIG.Loot.Enabled then
        local maxDistSq = configMod.CONFIG.Loot.MaxDistance * configMod.CONFIG.Loot.MaxDistance
        M.activeLoot = scanners.ScanLoot(playerPos, maxDistSq, configMod.CONFIG.Loot.Filters)
    else
        M.activeLoot = {}
    end

    -- 7. Scan Notes
    if configMod.CONFIG.Notes.Enabled then
        local maxDistSq = configMod.CONFIG.Notes.MaxDistance * configMod.CONFIG.Notes.MaxDistance
        M.activeNotes = scanners.ScanNotes(playerPos, maxDistSq)
    else
        M.activeNotes = {}
    end
end

return M
