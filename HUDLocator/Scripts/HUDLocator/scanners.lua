local UEHelpers = require("UEHelpers")
local configMod = require("HUDLocator.config")
local utils = require("HUDLocator.utils")
local logger = require("HUDLocator.logger")

local M = {}

M.dungeonClasses = {
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
M.currentClassIndex = 1
M.tempCaves = {}
M.hasLoggedDungeons = false

function M.ScanPlayers(localPlayerState)
    local newPlayers = {}
    local seen = {}
    
    if localPlayerState and localPlayerState:IsValid() then
        local playerStates = FindAllOf("PalPlayerState") or {}
        
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
    end
    return newPlayers
end

function M.ScanRelics(playerPos, maxDistSq)
    local newRelics = {}
    local relics = FindAllOf("PalLevelObjectRelic") or {}
    for _, relic in ipairs(relics) do
        if relic:IsValid() and not utils.IsRelicPicked(relic) then
            pcall(function()
                local relicPos = relic:K2_GetActorLocation()
                if relicPos then
                    if utils.GetDistanceSq(relicPos, playerPos) <= maxDistSq then
                        local name = nil
                        local statusType, relicType = pcall(function() return relic:GetRelicType() end)
                        if not statusType or not relicType then
                            statusType, relicType = pcall(function() return relic.RelicType end)
                        end
                        local resolvedType = (statusType and relicType) and relicType or 0
                        local trans = utils.GetTranslatedRelicName(resolvedType)
                        if trans then
                            name = trans
                        else
                            name = configMod.GetTranslation("Relic", "Relic")
                        end
                        table.insert(newRelics, { X = relicPos.X, Y = relicPos.Y, Z = relicPos.Z, Name = name })
                    end
                end
            end)
        end
    end
    return newRelics
end

function M.ScanChests(playerPos, maxDistSq)
    local newChests = {}
    local chests = FindAllOf("PalMapObjectTreasureBox") or {}
    for _, chest in ipairs(chests) do
        if chest:IsValid() and not utils.IsChestOpened(chest) then
            pcall(function()
                local chestPos = chest:K2_GetActorLocation()
                if chestPos then
                    if utils.GetDistanceSq(chestPos, playerPos) <= maxDistSq then
                        local name = configMod.GetTranslation("Chest", "Chest")
                        local statusModel, model = pcall(function() return chest.MapObjectModel end)
                        if statusModel and model and model:IsValid() then
                            local dataIdStatus, dataId = pcall(function() return model.MapObjectMasterDataId end)
                            if dataIdStatus and dataId then
                                local trans = utils.GetTranslatedMapObjectName(dataId)
                                if trans then name = trans end
                            end
                        end
                        table.insert(newChests, { X = chestPos.X, Y = chestPos.Y, Z = chestPos.Z, Name = name })
                    end
                end
            end)
        end
    end
    return newChests
end

function M.ScanEggs(playerPos, maxDistSq, eggFilter, debug)
    local newEggs = {}
    local eggs = FindAllOf("PalMapObjectPalEgg") or {}
    for _, egg in ipairs(eggs) do
        local isPicked = utils.IsEggPicked(egg)
        if egg:IsValid() and not isPicked then
            pcall(function()
                local eggPos = egg:K2_GetActorLocation()
                if eggPos then
                    if utils.GetDistanceSq(eggPos, playerPos) <= maxDistSq then
                        local sizeStr = ""
                        local statusScale, scale = pcall(function() return egg.Scale end)
                        
                        if statusScale and type(scale) == "number" then
                            if scale >= 1.9 then sizeStr = "Huge"
                            elseif scale >= 1.05 then sizeStr = "Large"
                            end
                        else
                            if debug then
                                logger.log("Failed to get egg scale. Fallback to normal. Error: " .. tostring(scale))
                            end
                        end

                        local shouldAdd = true
                        if eggFilter == "HugeOnly" and sizeStr ~= "Huge" then
                            shouldAdd = false
                        elseif eggFilter == "Large+" and sizeStr == "" then
                            shouldAdd = false
                        end

                        if shouldAdd then
                            local name = nil
                            local useSizePrefix = true
                            local statusModel, model = pcall(function() return egg.MapObjectModel end)
                            if statusModel and model and model:IsValid() then
                                local concrete = model.ConcreteModel
                                if concrete and concrete:IsValid() then
                                    local visualIdStatus, visualId = pcall(function() return concrete:GetVisualStaticItemId() end)
                                    if not visualIdStatus or not visualId then
                                        visualIdStatus, visualId = pcall(function() return concrete.VisualStaticItemId end)
                                    end
                                    if visualIdStatus and visualId and visualId:ToString() ~= "None" then
                                        local itemIdStr = visualId:ToString()
                                        local trans = utils.GetTranslatedItemName(itemIdStr)
                                        if trans then
                                            name = trans
                                            useSizePrefix = false
                                        end
                                    end
                                end
                                
                                if not name then
                                    local dataIdStatus, dataId = pcall(function() return model.MapObjectMasterDataId end)
                                    if dataIdStatus and dataId then
                                        local trans = utils.GetTranslatedMapObjectName(dataId)
                                        if trans then name = trans end
                                    end
                                end
                            end
                            
                            if not name then
                                name = configMod.GetTranslation("Egg", "Egg")
                            end
                            
                            local transSize = ""
                            if useSizePrefix and sizeStr ~= "" then
                                transSize = configMod.GetTranslation(sizeStr, sizeStr) .. " "
                            end
                            
                            table.insert(newEggs, { X = eggPos.X, Y = eggPos.Y, Z = eggPos.Z, SizePrefix = transSize, Name = name })
                        end
                    end
                end
            end)
        end
    end
    return newEggs
end

function M.ScanCaves(playerPos, maxDistSq)
    local cls = M.dungeonClasses[M.currentClassIndex]
    M.tempCaves[cls] = {}

    local caves = FindAllOf(cls) or {}
    local successCount = 0
    local closestDistSq = math.huge

    for _, cave in ipairs(caves) do
        if cave:IsValid() then
            local status, err = pcall(function()
                local cavePos = cave:K2_GetActorLocation()
                if cavePos then
                    successCount = successCount + 1
                    local distSq = utils.GetDistanceSq(cavePos, playerPos)
                    if distSq < closestDistSq then
                        closestDistSq = distSq
                    end
                    if distSq <= maxDistSq then
                        local level, state = utils.GetDungeonDetails(cave)
                        local dungeonName = nil
                        pcall(function()
                            local stageModel = cave.StageModel
                            if stageModel and stageModel:IsValid() then
                                local instanceModel = stageModel.InstanceModel
                                if instanceModel and instanceModel:IsValid() then
                                    local overrideId = instanceModel.OverrideDungeonNameTextId
                                    if overrideId then
                                        local trans = utils.GetTranslatedDungeonName(overrideId)
                                        if trans then dungeonName = trans end
                                    end
                                end
                            end
                        end)
                        if not dungeonName then
                            dungeonName = configMod.GetTranslation("Cave", "Cave")
                        end
                        table.insert(M.tempCaves[cls], { 
                            X = cavePos.X, 
                            Y = cavePos.Y, 
                            Z = cavePos.Z,
                            Level = level,
                            State = state,
                            Name = dungeonName
                        })
                    end
                end
            end)
        end
    end

    M.currentClassIndex = M.currentClassIndex + 1
    if M.currentClassIndex > #M.dungeonClasses then
        M.currentClassIndex = 1
    end

    local merged = {}
    for _, classCaves in pairs(M.tempCaves) do
        for _, c in ipairs(classCaves) do
            table.insert(merged, c)
        end
    end

    if not M.hasLoggedDungeons and successCount > 0 then
        M.hasLoggedDungeons = true
        logger.log("Cave Scan (Initial detection): Found " .. tostring(successCount) .. " active caves for class " .. cls)
        if closestDistSq ~= math.huge then
            logger.log("Cave Scan (Initial detection): Closest is " .. tostring(math.sqrt(closestDistSq) / 100.0) .. " meters away.")
        end
    end
    
    return merged
end

return M
