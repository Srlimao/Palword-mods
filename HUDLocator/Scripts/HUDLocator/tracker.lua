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
    if not configMod.CONFIG.Enabled then
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
    if not localPlayer or not localPlayer:IsValid() then return end

    M.cachedLocalPlayer = localPlayer

    local playerPos = localPlayer:K2_GetActorLocation()
    if not playerPos then return end

    local maxDistSq = configMod.CONFIG.MaxDistance * configMod.CONFIG.MaxDistance

    -- 1. Scan Players
    if configMod.CONFIG.ShowPlayers then
        local localPlayerState = localPlayer.PlayerState
        M.activePlayers = scanners.ScanPlayers(localPlayerState)
    else
        M.activePlayers = {}
    end

    -- 2. Scan Relics
    if configMod.CONFIG.ShowRelics then
        M.activeRelics = scanners.ScanRelics(playerPos, maxDistSq)
    else
        M.activeRelics = {}
    end

    -- 3. Scan Chests
    if configMod.CONFIG.ShowChests then
        M.activeChests = scanners.ScanChests(playerPos, maxDistSq)
    else
        M.activeChests = {}
    end

    -- 4. Scan Eggs
    if configMod.CONFIG.EggFilter ~= "None" then
        M.activeEggs = scanners.ScanEggs(playerPos, maxDistSq, configMod.CONFIG.EggFilter, configMod.CONFIG.Debug)
    else
        M.activeEggs = {}
    end

    -- 5. Scan Caves
    if configMod.CONFIG.ShowCaves then
        M.activeCaves = scanners.ScanCaves(playerPos, maxDistSq)
    else
        M.activeCaves = {}
        scanners.tempCaves = {}
    end
end

return M
