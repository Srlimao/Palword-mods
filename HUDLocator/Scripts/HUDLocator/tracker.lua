local UEHelpers = require("UEHelpers")
local configMod = require("HUDLocator.config")
local logger = require("HUDLocator.logger")
local CONFIG = configMod.CONFIG

local M = {}

M.activePlayers = {}
M.activeRelics = {}
M.activeChests = {}
M.activeEggs = {}
M.activeCaves = {}
M.cachedLocalPlayer = nil

local hasLoggedDungeons = false

local dungeonClasses = {
    "BP_DungeonFixedEntrance_C",
    "BP_DungeonFixedEntrance_forest_1_C",
    "BP_DungeonFixedEntrance_forest_2_C",
    "BP_DungeonFixedEntrance_forest_3_C",
    "BP_DungeonFixedEntrance_forest_4_C",
    "BP_DungeonFixedEntrance_forest_5_C",
    "BP_DungeonFixedEntrance_grass_1_C",
    "BP_DungeonFixedEntrance_grass_2_C",
    "BP_DungeonFixedEntrance_grass_3_C",
    "BP_DungeonFixedEntrance_grass_4_C",
    "BP_DungeonFixedEntrance_grass_5_C",
    "BP_DungeonFixedEntrance_grass_6_C",
    "BP_DungeonFixedEntrance_grass_7_C",
    "PalDungeonEntrance"
}
local currentClassIndex = 1
local tempCaves = {}

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
        
        -- If the actor is hidden, it has been picked up/disabled
        if egg.bHidden then return true end
        
        -- If the map object model is gone or invalid, it has been picked up
        local model = egg.MapObjectModel
        if not model or not model:IsValid() then return true end
        
        if type(egg.bPickedInClient) == "boolean" and egg.bPickedInClient then return true end
        
        local concrete = model.ConcreteModel
        if concrete and concrete:IsValid() then
            if type(concrete.bPicked) == "boolean" and concrete.bPicked then return true end
            if type(concrete.bIsPicked) == "boolean" and concrete.bIsPicked then return true end
        end
        
        return false
    end)
    
    if status then return picked else return false end
end

-- Helper to safely retrieve dungeon level and active/cooldown state
local function GetDungeonDetails(cave)
    local level = nil
    local state = "Closed"
    
    pcall(function()
        if cave:IsValid() then
            local stageModel = cave.StageModel
            if stageModel and stageModel:IsValid() then
                local instanceModel = stageModel.InstanceModel
                if instanceModel and instanceModel:IsValid() then
                    level = instanceModel.Level
                    
                    local bossState = instanceModel.BossState
                    if bossState == 1 then
                        state = "Cleared"
                    else
                        state = "Open"
                    end
                end
            end
        end
    end)
    
    return level, state
end

-- Scan players, relics, and chests
function M.scan()
    if not CONFIG.Enabled then
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

    -- 5. Scan Caves
    if CONFIG.ShowCaves then
        local cls = dungeonClasses[currentClassIndex]
        tempCaves[cls] = {}

        local caves = FindAllOf(cls) or {}
        local successCount = 0
        local closestDistSq = math.huge

        for _, cave in ipairs(caves) do
            if cave:IsValid() then
                local status, err = pcall(function()
                    local cavePos = cave:K2_GetActorLocation()
                    if cavePos then
                        successCount = successCount + 1
                        local dx = cavePos.X - playerPos.X
                        local dy = cavePos.Y - playerPos.Y
                        local dz = cavePos.Z - playerPos.Z
                        local distSq = dx*dx + dy*dy + dz*dz
                        if distSq < closestDistSq then
                            closestDistSq = distSq
                        end
                        if distSq <= maxDistSq then
                            local level, state = GetDungeonDetails(cave)
                            table.insert(tempCaves[cls], { 
                                X = cavePos.X, 
                                Y = cavePos.Y, 
                                Z = cavePos.Z,
                                Level = level,
                                State = state
                            })
                        end
                    end
                end)
            end
        end

        currentClassIndex = currentClassIndex + 1
        if currentClassIndex > #dungeonClasses then
            currentClassIndex = 1
        end

        local merged = {}
        for _, classCaves in pairs(tempCaves) do
            for _, c in ipairs(classCaves) do
                table.insert(merged, c)
            end
        end
        M.activeCaves = merged

        if not hasLoggedDungeons and successCount > 0 then
            hasLoggedDungeons = true
            logger.log("Cave Scan (Initial detection): Found " .. tostring(successCount) .. " active caves for class " .. cls)
            if closestDistSq ~= math.huge then
                logger.log("Cave Scan (Initial detection): Closest is " .. tostring(math.sqrt(closestDistSq) / 100.0) .. " meters away.")
            end
        end
    else
        M.activeCaves = {}
        tempCaves = {}
    end
end

return M
