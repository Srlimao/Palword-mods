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
M.hasLoggedPlayers = false
M.hasLoggedRelics = false
M.hasLoggedChests = false
M.hasLoggedEggs = false
M.hasLoggedLoot = false
M.hasLoggedNotes = false

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
    if not M.hasLoggedPlayers and #newPlayers > 0 then
        M.hasLoggedPlayers = true
        logger.log("Player Scan (Initial detection): Found " .. tostring(#newPlayers) .. " other players.")
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
    if not M.hasLoggedRelics and #newRelics > 0 then
        M.hasLoggedRelics = true
        logger.log("Relic Scan (Initial detection): Found " .. tostring(#newRelics) .. " relics.")
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
                        local isJunk = false
                        local gradeVal = nil
                        local statusModel, model = pcall(function() return chest.MapObjectModel end)
                        if statusModel and model and model:IsValid() then
                            local dataIdStatus, dataId = pcall(function() return model.MapObjectMasterDataId end)
                            if dataIdStatus and dataId then
                                local idStr = dataId:ToString()
                                if idStr == "TreasureBox" then
                                    local concrete = model.ConcreteModel
                                    if concrete and concrete:IsValid() then
                                        local statusGrade, grade = pcall(function() return concrete:GetTreasureGradeType() end)
                                        if not statusGrade or not grade then
                                            statusGrade, grade = pcall(function() return concrete.TreasureGradeType end)
                                        end
                                        if statusGrade and type(grade) == "number" then
                                            gradeVal = grade + 1
                                            idStr = "TreasureBox_Grade" .. tostring(gradeVal)
                                        end
                                    end
                                end

                                if string.find(idStr, "RequiredLongHold") or string.find(idStr, "Search") then
                                    isJunk = true
                                end
                                local trans = utils.GetTranslatedMapObjectName(idStr)
                                if trans then
                                    if isJunk then
                                        trans = string.gsub(trans, "%s*%b()", "")
                                    end
                                    name = trans
                                end

                                -- Append Grade name/suffix if standard chest and gradeVal is parsed
                                if not isJunk and gradeVal then
                                    local gradeKey = "Grade_" .. tostring(gradeVal)
                                    local gradeLabel = configMod.GetTranslation(gradeKey, "G" .. tostring(gradeVal))
                                    name = name .. " (" .. gradeLabel .. ")"
                                end
                            end
                        end

                        local filter = configMod.CONFIG.Chests.Filter or "Both"
                        local shouldAdd = true
                        if filter == "Chests" and isJunk then
                            shouldAdd = false
                        elseif filter == "Junk" and not isJunk then
                            shouldAdd = false
                        end

                        if shouldAdd then
                            table.insert(newChests, { X = chestPos.X, Y = chestPos.Y, Z = chestPos.Z, Name = name })
                        end
                    end
                end
            end)
        end
    end
    if not M.hasLoggedChests and #newChests > 0 then
        M.hasLoggedChests = true
        logger.log("Chest Scan (Initial detection): Found " .. tostring(#newChests) .. " chests.")
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
    
    if not M.hasLoggedEggs and #newEggs > 0 then
        M.hasLoggedEggs = true
        logger.log("Egg Scan (Initial detection): Found " .. tostring(#newEggs) .. " eggs.")
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
    
    if configMod.CONFIG.Global.Debug then
        print(string.format("[HUDLocator] ScanCaves: Class %s, found %d total actors, inserted %d within max distance. Total merged caves: %d", cls, successCount, #M.tempCaves[cls], #merged))
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

local function GetItemDetails(actor)
    local name = nil
    local itemIdStr = nil
    
    local statusModel, model = pcall(function() return actor.MapObjectModel end)
    if statusModel and model then
        local isValid = false
        pcall(function() isValid = model:IsValid() end)
        if isValid then
            local concrete = nil
            pcall(function() concrete = model.ConcreteModel end)
            if concrete then
                local isConcreteValid = false
                pcall(function() isConcreteValid = concrete:IsValid() end)
                if isConcreteValid then
                    -- 1. Check if it's a drop item model (has ItemId)
                    local itemId = nil
                    pcall(function() itemId = concrete.ItemId end)
                    if itemId then
                        local staticId = nil
                        pcall(function() staticId = itemId.StaticId end)
                        if staticId then
                            pcall(function() itemIdStr = staticId:ToString() end)
                        end
                    end
                    
                    -- 2. Check if it's a level pickup model (has VisualStaticItemId)
                    if not itemIdStr then
                        local visualId = nil
                        local visualIdStatus = pcall(function() visualId = concrete:GetVisualStaticItemId() end)
                        if not visualIdStatus or not visualId then
                            pcall(function() visualId = concrete.VisualStaticItemId end)
                        end
                        if visualId then
                            pcall(function() itemIdStr = visualId:ToString() end)
                        end
                    end
                end
            end
        end
    end
    
    if itemIdStr and itemIdStr ~= "None" then
        name = utils.GetTranslatedItemName(itemIdStr)
        if not name or name == "" then
            name = itemIdStr -- fallback to internal name
        end
    end
    
    return name, itemIdStr
end

function M.ScanLoot(playerPos, maxDistSq, filters)
    local newLoot = {}
    local actors = {}
    local statusVisible, visibleActors = pcall(function() return FindAllOf("BP_MapObject_TreasureBox_VisibleContent_C") end)
    if statusVisible and visibleActors then
        for _, actor in ipairs(visibleActors) do
            table.insert(actors, actor)
        end
    end
    
    local statusLevel, levelActors = pcall(function() return FindAllOf("PalMapLevelObject") end)
    if statusLevel and levelActors then
        for _, actor in ipairs(levelActors) do
            table.insert(actors, actor)
        end
    end
    
    -- De-duplicate actors safely using table lookup
    local seen = {}
    local uniqueActors = {}
    for _, actor in ipairs(actors) do
        if not seen[actor] then
            seen[actor] = true
            table.insert(uniqueActors, actor)
        end
    end
    
    for _, actor in ipairs(uniqueActors) do
        if actor:IsValid() then
            pcall(function()
                local lootPos = actor:K2_GetActorLocation()
                if lootPos then
                    if utils.GetDistanceSq(lootPos, playerPos) <= maxDistSq then
                        local name, itemIdStr = GetItemDetails(actor)
                        if name and name ~= "" then
                            local shouldAdd = true
                            if filters and #filters > 0 then
                                shouldAdd = false
                                local lowerName = name:lower()
                                local lowerId = itemIdStr:lower()
                                for _, filter in ipairs(filters) do
                                    local lowerFilter = filter:lower()
                                    if string.find(lowerName, lowerFilter, 1, true) or string.find(lowerId, lowerFilter, 1, true) then
                                        shouldAdd = true
                                        break
                                    end
                                end
                            end
                            
                            if shouldAdd then
                                table.insert(newLoot, { X = lootPos.X, Y = lootPos.Y, Z = lootPos.Z, Name = name })
                            end
                        end
                    end
                end
            end)
        end
    end
    
    if not M.hasLoggedLoot and #newLoot > 0 then
        M.hasLoggedLoot = true
        logger.log("Loot Scan (Initial detection): Found " .. tostring(#newLoot) .. " loot items on ground.")
    end
    
    return newLoot
end

function M.ScanNotes(playerPos, maxDistSq)
    local newNotes = {}
    local notes = FindAllOf("PalLevelObjectNote") or {}
    for _, note in ipairs(notes) do
        if note:IsValid() and not utils.IsNotePicked(note) then
            pcall(function()
                local notePos = note:K2_GetActorLocation()
                if notePos then
                    if utils.GetDistanceSq(notePos, playerPos) <= maxDistSq then
                        local name = nil
                        local statusName, noteKey = pcall(function() return note.NoteRowName.Key end)
                        if statusName and noteKey then
                            local trans = utils.GetTranslatedNoteName(noteKey)
                            if trans then
                                name = trans
                            else
                                name = configMod.GetTranslation("Note", "Journal")
                            end
                        else
                            name = configMod.GetTranslation("Note", "Journal")
                        end
                        table.insert(newNotes, { X = notePos.X, Y = notePos.Y, Z = notePos.Z, Name = name })
                    end
                end
            end)
        end
    end
    
    if not M.hasLoggedNotes and #newNotes > 0 then
        M.hasLoggedNotes = true
        logger.log("Note Scan (Initial detection): Found " .. tostring(#newNotes) .. " journals.")
    end
    return newNotes
end

return M
