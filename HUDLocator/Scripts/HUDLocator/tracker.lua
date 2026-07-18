local UEHelpers = require("UEHelpers")
local configMod = require("HUDLocator.config")
local scanners = require("HUDLocator.scanners")

local M = {}

M.activePlayers = {}
M.activeRelics = {}
M.activeChests = {}
M.activeEggs = {}
M.activeCaves = {}
M.cachedLocalPlayer = nil

-- Scan players, relics, chests, eggs, caves
function M.scan()
    if not configMod.CONFIG.Global.Enabled then
        M.activePlayers = {}
        M.activeRelics = {}
        M.activeChests = {}
        M.activeEggs = {}
        M.activeCaves = {}
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
        return
    end

    local localPlayer = UEHelpers.GetPlayer()
    if not localPlayer or not localPlayer:IsValid() then
        M.activePlayers = {}
        M.activeRelics = {}
        M.activeChests = {}
        M.activeEggs = {}
        M.activeCaves = {}
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
end

return M
