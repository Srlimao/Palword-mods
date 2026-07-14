local UEHelpers = require("UEHelpers")
local configMod = require("HUDLocator.config")
local logger = require("HUDLocator.logger")
local CONFIG = configMod.CONFIG

local M = {}

M.activePlayers = {}
M.activeRelics = {}
M.activeChests = {}
M.activeEggs = {}
M.cachedLocalPlayer = nil

-- Helper to safely check if a relic has been picked up
local function IsRelicPicked(relic)
    local status, picked = pcall(function()
        if relic:IsValid() then
            return relic.bPickedInClient
        end
        return true
    end)
    if status then
        return picked
    else
        return true
    end
end

-- Helper to safely check if a chest is already opened
local function IsChestOpened(chest)
    local status, opened = pcall(function()
        if chest:IsValid() then
            local model = chest.MapObjectModel
            if model and model:IsValid() then
                local concrete = model.ConcreteModel
                if concrete and concrete:IsValid() then
                    return concrete.bOpened
                end
            end
        end
        return true
    end)
    if status then
        return opened
    else
        return true
    end
end

-- Helper to safely check if an egg has been picked up
local function IsEggPicked(egg)
    local status, picked = pcall(function()
        if not egg:IsValid() then return true end
        
        if type(egg.bPickedInClient) == "boolean" and egg.bPickedInClient then return true end
        
        -- Try to check the concrete model if it exists
        local model = egg.MapObjectModel
        if model and model:IsValid() then
            local concrete = model.ConcreteModel
            if concrete and concrete:IsValid() then
                if type(concrete.bPicked) == "boolean" and concrete.bPicked then return true end
                if type(concrete.bIsPicked) == "boolean" and concrete.bIsPicked then return true end
            end
        end
        
        return false
    end)
    
    -- If there's an error, we assume it's NOT picked so it doesn't vanish prematurely, but if it is picked, hopefully IsValid() catches it eventually.
    if status then return picked else return false end
end

-- Scan players, relics, and chests
function M.scan()
    if not CONFIG.Enabled then
        M.activePlayers = {}
        M.activeRelics = {}
        M.activeChests = {}
        M.activeEggs = {}
        return
    end

    -- Safety check: Only scan when HUD is active (in-world)
    local hudCheck = FindFirstOf("BP_PalHUD_InGame_C")
    if not hudCheck or not hudCheck:IsValid() then
        M.activePlayers = {}
        M.activeRelics = {}
        M.activeChests = {}
        M.activeEggs = {}
        return
    end

    local localPlayer = UEHelpers.GetPlayer()
    if not localPlayer or not localPlayer:IsValid() then return end

    M.cachedLocalPlayer = localPlayer

    local playerPos = localPlayer:K2_GetActorLocation()
    if not playerPos then return end

    local maxDistSq = CONFIG.MaxDistance * CONFIG.MaxDistance

    -- 1. Scan Players
    if CONFIG.ShowPlayers then
        local localPlayerState = localPlayer.PlayerState
        if localPlayerState and localPlayerState:IsValid() then
            local playerStates = FindAllOf("PalPlayerState") or {}
            local newPlayers = {}
            local seen = {} -- Deduplicate: ghost states linger after disconnect
            
            for _, state in ipairs(playerStates) do
                if state:IsValid() and state ~= localPlayerState then
                    pcall(function()
                        local namePrivate = state.PlayerNamePrivate
                        if namePrivate then
                            local nameStr = namePrivate:ToString()
                            if not seen[nameStr] then
                                local loc = state.CachedPlayerLocation
                                if loc and (loc.X ~= 0.0 or loc.Y ~= 0.0 or loc.Z ~= 0.0) then
                                    seen[nameStr] = true
                                    table.insert(newPlayers, {
                                        Name = nameStr,
                                        Pos = { X = loc.X, Y = loc.Y, Z = loc.Z }
                                    })
                                end
                            end
                        end
                    end)
                end
            end
            M.activePlayers = newPlayers
        end
    else
        M.activePlayers = {}
    end

    -- 2. Scan Relics
    if CONFIG.ShowRelics then
        local newRelics = {}
        local relics = FindAllOf("PalLevelObjectRelic") or {}
        for _, relic in ipairs(relics) do
            if relic:IsValid() and not IsRelicPicked(relic) then
                pcall(function()
                    local relicPos = relic:K2_GetActorLocation()
                    if relicPos then
                        local dx = relicPos.X - playerPos.X
                        local dy = relicPos.Y - playerPos.Y
                        local dz = relicPos.Z - playerPos.Z
                        local distSq = dx*dx + dy*dy + dz*dz
                        if distSq <= maxDistSq then
                            table.insert(newRelics, { X = relicPos.X, Y = relicPos.Y, Z = relicPos.Z })
                        end
                    end
                end)
            end
        end
        M.activeRelics = newRelics
    else
        M.activeRelics = {}
    end

    -- 3. Scan Chests
    if CONFIG.ShowChests then
        local newChests = {}
        local chests = FindAllOf("PalMapObjectTreasureBox") or {}
        for _, chest in ipairs(chests) do
            if chest:IsValid() and not IsChestOpened(chest) then
                pcall(function()
                    local chestPos = chest:K2_GetActorLocation()
                    if chestPos then
                        local dx = chestPos.X - playerPos.X
                        local dy = chestPos.Y - playerPos.Y
                        local dz = chestPos.Z - playerPos.Z
                        local distSq = dx*dx + dy*dy + dz*dz
                        if distSq <= maxDistSq then
                            table.insert(newChests, { X = chestPos.X, Y = chestPos.Y, Z = chestPos.Z })
                        end
                    end
                end)
            end
        end
        M.activeChests = newChests
    else
        M.activeChests = {}
    end

    -- 4. Scan Eggs
    if CONFIG.EggFilter ~= "None" then
        local newEggs = {}
        local eggs = FindAllOf("PalMapObjectPalEgg") or {}
        local dumpedEggProps = false
        
        for _, egg in ipairs(eggs) do
            if egg:IsValid() and not IsEggPicked(egg) then
                pcall(function()
                    local eggPos = egg:K2_GetActorLocation()
                    if eggPos then
                        local dx = eggPos.X - playerPos.X
                        local dy = eggPos.Y - playerPos.Y
                        local dz = eggPos.Z - playerPos.Z
                        local distSq = dx*dx + dy*dy + dz*dz
                        if distSq <= maxDistSq then
                            local sizeStr = ""
                            local status, scale = pcall(function() return egg.Scale end)
                            
                            if status and type(scale) == "number" then
                                -- if CONFIG.Debug then
                                --     logger.log("Egg Scale: " .. tostring(scale))
                                -- end
                                if scale >= 1.9 then sizeStr = "Huge "
                                elseif scale >= 1.05 then sizeStr = "Large "
                                end
                            else
                                if CONFIG.Debug then
                                    logger.log("Failed to get egg scale. Fallback to normal. Error: " .. tostring(scale))
                                end
                            end

                            local shouldAdd = true
                            if CONFIG.EggFilter == "HugeOnly" and sizeStr ~= "Huge " then
                                shouldAdd = false
                            elseif CONFIG.EggFilter == "Large+" and sizeStr == "" then
                                shouldAdd = false
                            end

                            if shouldAdd then
                                table.insert(newEggs, { X = eggPos.X, Y = eggPos.Y, Z = eggPos.Z, SizePrefix = sizeStr })
                            end
                        end
                    end
                end)
            end
        end
        M.activeEggs = newEggs
    else
        M.activeEggs = {}
    end
end

return M
