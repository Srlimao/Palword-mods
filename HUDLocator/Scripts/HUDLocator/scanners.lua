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
M.hasLoggedPals = false

-- Optimize: Evaluate .X, .Y, .Z sequentially and short-circuit to avoid reflection overhead for distant items
local function IsWithinDistanceSq(uePos, pX, pY, pZ, maxDistSq)
    local x = uePos.X
    local dx = x - pX
    local distSq = dx * dx
    if distSq > maxDistSq then return false, 0, 0, 0, 0 end

    local y = uePos.Y
    local dy = y - pY
    distSq = distSq + dy * dy
    if distSq > maxDistSq then return false, 0, 0, 0, 0 end

    local z = uePos.Z
    local dz = z - pZ
    distSq = distSq + dz * dz
    if distSq > maxDistSq then return false, 0, 0, 0, 0 end

    return true, x, y, z, distSq
end

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
                            if loc then
                                -- Optimize: Convert UE FVector to native Lua table to avoid thousands of C++ property reflection lookups during distance checks
                                local locX, locY, locZ = loc.X, loc.Y, loc.Z
                                if locX ~= 0.0 or locY ~= 0.0 or locZ ~= 0.0 then
                                    seen[nameStr] = true
                                    table.insert(newPlayers, {
                                        Name = nameStr,
                                        Pos = { X = locX, Y = locY, Z = locZ }
                                    })
                                end
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
                local ueRelicPos = relic:K2_GetActorLocation()
                if ueRelicPos then
                    local isWithin, rx, ry, rz, distSq = IsWithinDistanceSq(ueRelicPos, playerPos.X, playerPos.Y, playerPos.Z, maxDistSq)
                    if isWithin then
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
                        local distStr = math.floor(math.sqrt(distSq) / 100.0) .. "m"
                        table.insert(newRelics, { X = rx, Y = ry, Z = rz, Name = name, DistStr = distStr })
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

local function ParseGradeNumFromString(str)
    if not str then return nil end
    local text = tostring(str)
    local g = text:match("Grade0*(%d+)") or text:match("Grade(%d+)") or text:match("Tier(%d+)")
    if g then
        return tonumber(g)
    end
    return nil
end

local function GetChestGradeNumber(chest, concrete)
    if concrete and concrete:IsValid() then
        local status, grade = pcall(function() return concrete:GetTreasureGradeType() end)
        if not status or grade == nil then
            status, grade = pcall(function() return concrete.TreasureGradeType end)
        end
        if status and grade ~= nil then
            if type(grade) == "number" then
                return grade + 1
            elseif type(grade) == "string" or type(grade) == "userdata" then
                local num = ParseGradeNumFromString(tostring(grade))
                if num then return num end
            end
        end
        local concreteName = nil
        pcall(function() concreteName = concrete:GetName() end)
        if concreteName then
            local num = ParseGradeNumFromString(concreteName)
            if num then return num end
        end
    end

    local visualChildName = nil
    pcall(function()
        if chest.VisualActor and chest.VisualActor.ChildActor then
            visualChildName = chest.VisualActor.ChildActor:GetName()
        end
    end)
    if visualChildName then
        local num = ParseGradeNumFromString(visualChildName)
        if num then return num end
    end

    local modelClassName = nil
    pcall(function()
        if chest.ConcreteModelClass then
            modelClassName = chest.ConcreteModelClass:GetName()
        end
    end)
    if modelClassName then
        local num = ParseGradeNumFromString(modelClassName)
        if num then return num end
    end

    return nil
end

local function IsChestGradeAllowed(gradeNum, gradeFilter)
    if not gradeFilter or gradeFilter == "All" then
        return true
    elseif gradeFilter == "None" then
        return false
    end

    if not gradeNum then
        return false
    end

    if gradeFilter == "Grade2+" then
        return gradeNum >= 2
    elseif gradeFilter == "Grade3+" then
        return gradeNum >= 3
    elseif gradeFilter == "Grade4+" then
        return gradeNum >= 4
    elseif gradeFilter == "Grade5+" then
        return gradeNum >= 5
    elseif gradeFilter == "Grade6Only" then
        return gradeNum >= 6
    end

    return true
end

function M.ScanChests(playerPos, maxDistSq)
    local newChests = {}
    local chests = FindAllOf("PalMapObjectTreasureBox") or {}
    for _, chest in ipairs(chests) do
        if chest:IsValid() and not utils.IsChestOpened(chest) then
            pcall(function()
                local ueChestPos = chest:K2_GetActorLocation()
                if ueChestPos then
                    local isWithin, cx, cy, cz, distSq = IsWithinDistanceSq(ueChestPos, playerPos.X, playerPos.Y, playerPos.Z, maxDistSq)
                    if isWithin then
                        local name = configMod.GetTranslation("Chest", "Chest")
                        local isJunk = false
                        local gradeVal = nil
                        local statusModel, model = pcall(function() return chest.MapObjectModel end)
                        if statusModel and model and model:IsValid() then
                            local concrete = model.ConcreteModel
                            gradeVal = GetChestGradeNumber(chest, concrete)

                            local dataIdStatus, dataId = pcall(function() return model.MapObjectMasterDataId end)
                            if dataIdStatus and dataId then
                                local idStr = dataId:ToString()
                                if idStr == "TreasureBox" and gradeVal then
                                    idStr = "TreasureBox_Grade" .. tostring(gradeVal)
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
                        local gradeFilter = configMod.CONFIG.Chests.GradeFilter or "All"
                        local shouldAdd = true
                        if filter == "Chests" and isJunk then
                            shouldAdd = false
                        elseif filter == "Junk" and not isJunk then
                            shouldAdd = false
                        end

                        if shouldAdd and not isJunk then
                            if not IsChestGradeAllowed(gradeVal, gradeFilter) then
                                shouldAdd = false
                            end
                        end

                        if shouldAdd then
                            local distStr = math.floor(math.sqrt(distSq) / 100.0) .. "m"
                            table.insert(newChests, { X = cx, Y = cy, Z = cz, Name = name, DistStr = distStr })
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
                local ueEggPos = egg:K2_GetActorLocation()
                if ueEggPos then
                    local isWithin, ex, ey, ez, distSq = IsWithinDistanceSq(ueEggPos, playerPos.X, playerPos.Y, playerPos.Z, maxDistSq)
                    if isWithin then
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
                            
                            local distStr = math.floor(math.sqrt(distSq) / 100.0) .. "m"
                            table.insert(newEggs, { X = ex, Y = ey, Z = ez, SizePrefix = transSize, Name = name, FullName = transSize .. name, DistStr = distStr })
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
                local ueCavePos = cave:K2_GetActorLocation()
                if ueCavePos then
                    -- Optimize: Inline C++ properties to locals and defer table allocation to reduce GC pressure in loops
                    local cx, cy, cz = ueCavePos.X, ueCavePos.Y, ueCavePos.Z
                    successCount = successCount + 1
                    local dx, dy, dz = cx - playerPos.X, cy - playerPos.Y, cz - playerPos.Z
                    local distSq = dx*dx + dy*dy + dz*dz
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
                        local nameStr = dungeonName
                        if level then
                            local lv = configMod.GetTranslation("Cave_Lv", "Lv.")
                            local stateStr = state
                            if stateStr == "Open" then stateStr = configMod.GetTranslation("Cave_Open", "Open")
                            elseif stateStr == "Cleared" then stateStr = configMod.GetTranslation("Cave_Cleared", "Cleared")
                            end
                            nameStr = dungeonName .. " " .. lv .. level .. " (" .. stateStr .. ")"
                        else
                            local closed = configMod.GetTranslation("Cave_Closed", "(Closed)")
                            nameStr = dungeonName .. " " .. closed
                        end
                        local distStr = math.floor(math.sqrt(distSq) / 100.0) .. "m"
                        table.insert(M.tempCaves[cls], { 
                            X = cx,
                            Y = cy,
                            Z = cz,
                            Level = level,
                            State = state,
                            Name = nameStr,
                            DistStr = distStr
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
    
    configMod.DebugPrint(string.format("ScanCaves: Class %s, found %d total actors, inserted %d within max distance. Total merged caves: %d", cls, successCount, #M.tempCaves[cls], #merged))

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
    
    -- De-duplicate actors safely using string keys instead of raw C++ reflected objects
    local seen = {}
    local uniqueActors = {}
    for _, actor in ipairs(actors) do
        local key = nil
        pcall(function() key = actor:GetFullName() end)
        key = key or tostring(actor)
        if not seen[key] then
            seen[key] = true
            table.insert(uniqueActors, actor)
        end
    end
    
    for _, actor in ipairs(uniqueActors) do
        if actor:IsValid() then
            pcall(function()
                local ueLootPos = actor:K2_GetActorLocation()
                if ueLootPos then
                    local isWithin, lx, ly, lz, distSq = IsWithinDistanceSq(ueLootPos, playerPos.X, playerPos.Y, playerPos.Z, maxDistSq)
                    if isWithin then
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
                                local distStr = math.floor(math.sqrt(distSq) / 100.0) .. "m"
                                table.insert(newLoot, { X = lx, Y = ly, Z = lz, Name = name, DistStr = distStr })
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
                local ueNotePos = note:K2_GetActorLocation()
                if ueNotePos then
                    local isWithin, nx, ny, nz, distSq = IsWithinDistanceSq(ueNotePos, playerPos.X, playerPos.Y, playerPos.Z, maxDistSq)
                    if isWithin then
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
                        local distStr = math.floor(math.sqrt(distSq) / 100.0) .. "m"
                        table.insert(newNotes, { X = nx, Y = ny, Z = nz, Name = name, DistStr = distStr })
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

local function EvaluatePalRule(rule, palName, charIdStr, isShiny, isBoss, palPassives)
    if not rule then return false, 0 end

    if rule.palname and rule.palname ~= "" and rule.palname ~= "*" then
        local targetName = string.lower(rule.palname)
        local lowerPalName = string.lower(palName or "")
        local lowerCharId = string.lower(charIdStr or "")
        if not string.find(lowerPalName, targetName, 1, true) and not string.find(lowerCharId, targetName, 1, true) then
            return false, 0
        end
    end

    if rule.shiny == true and not isShiny then
        return false, 0
    end

    if rule.boss == true and not isBoss then
        return false, 0
    end

    local matchedPassivesCount = 0
    local matchedPassiveNames = {}
    if rule.passive and type(rule.passive) == "table" then
        local requiredList = rule.passive.passives
        local minThreshold = rule.passive.min_passive_threshold or 1

        if requiredList and type(requiredList) == "table" and #requiredList > 0 then
            local palPassiveMap = {}
            for _, pName in ipairs(palPassives) do
                palPassiveMap[string.lower(tostring(pName))] = true
            end

            for _, reqP in ipairs(requiredList) do
                local lowerReq = string.lower(tostring(reqP))
                if palPassiveMap[lowerReq] then
                    matchedPassivesCount = matchedPassivesCount + 1
                    table.insert(matchedPassiveNames, reqP)
                end
            end

            if matchedPassivesCount < minThreshold then
                return false, 0
            end
        end
    end

    return true, matchedPassivesCount, matchedPassiveNames
end

function M.ScanPals(playerPos, maxDistSq, palConfig)
    local newPals = {}
    local actors = FindAllOf("BP_MonsterBase_C") or FindAllOf("PalMonsterCharacter") or {}
    
    local filterMode = palConfig.FilterMode or "TrackerListOnly"
    local rulesList = palConfig.TrackerPals or {}
    local showPassives = palConfig.ShowPassives ~= false
    local showLevel = palConfig.ShowLevel ~= false

    for _, actor in ipairs(actors) do
        if actor:IsValid() then
            pcall(function()
                local uePos = actor:K2_GetActorLocation()
                if uePos then
                    local isWithin, px, py, pz, distSq = IsWithinDistanceSq(uePos, playerPos.X, playerPos.Y, playerPos.Z, maxDistSq)
                    if isWithin then
                        local charParam = nil
                        pcall(function() charParam = actor:GetCharacterParameterComponent() end)

                        local staticParam = nil
                        pcall(function() staticParam = actor.StaticCharacterParameterComponent end)

                        local indivParam = nil
                        if charParam and charParam:IsValid() then
                            pcall(function() indivParam = charParam:GetIndividualParameter() end)
                        end

                        local isDead = false
                        if indivParam and indivParam:IsValid() then
                            pcall(function() isDead = indivParam:IsDead() end)
                        end

                        if not isDead then
                            local isShiny = false
                            if indivParam and indivParam:IsValid() then
                                pcall(function() isShiny = indivParam:IsRarePal() end)
                            elseif staticParam and staticParam:IsValid() then
                                pcall(function() isShiny = staticParam:IsRarePal() end)
                            end

                            local isBoss = false
                            if staticParam and staticParam:IsValid() then
                                pcall(function() isBoss = staticParam.IsBoss_Database or staticParam:IsBossPal_Database() end)
                            end

                            local charIdStr = ""
                            if indivParam and indivParam:IsValid() then
                                pcall(function()
                                    local cId = indivParam:GetCharacterID()
                                    if cId then charIdStr = cId:ToString() end
                                end)
                            end

                            if string.find(charIdStr, "Boss_") then
                                isBoss = true
                            end

                            local palName = utils.GetTranslatedPalName(charIdStr)

                            local level = nil
                            if indivParam and indivParam:IsValid() then
                                pcall(function() level = indivParam:GetLevel() end)
                            elseif charParam and charParam:IsValid() then
                                pcall(function() level = charParam:GetLevel() end)
                            end

                            local rank = 0
                            if indivParam and indivParam:IsValid() then
                                pcall(function() rank = indivParam:GetRank() end)
                            end

                            local rawPassives = {}
                            if indivParam and indivParam:IsValid() then
                                pcall(function()
                                    local pList = indivParam:GetPassiveSkillList()
                                    rawPassives = utils.TArrayToTable(pList)
                                end)
                                if #rawPassives == 0 then
                                    pcall(function()
                                        local pList = indivParam.PassiveSkillList
                                        rawPassives = utils.TArrayToTable(pList)
                                    end)
                                end
                            end

                            local palPassivesStr = {}
                            local translatedPassives = {}
                            for _, pName in ipairs(rawPassives) do
                                local strP = utils.FNameToString(pName)
                                if strP and strP ~= "" and strP ~= "None" then
                                    table.insert(palPassivesStr, strP)
                                    local transP = utils.GetTranslatedPassiveName(strP)
                                    if transP and transP ~= "" then
                                        table.insert(translatedPassives, transP)
                                    end
                                end
                            end

                            local shouldTrack = false
                            local matchedPassiveCount = 0

                            if filterMode == "All" then
                                shouldTrack = true
                            elseif filterMode == "ShinyOnly" then
                                shouldTrack = isShiny
                            elseif filterMode == "BossOnly" then
                                shouldTrack = isBoss
                            elseif filterMode == "ShinyOrBoss" then
                                shouldTrack = isShiny or isBoss
                            elseif filterMode == "TrackerListOnly" then
                                for _, rule in ipairs(rulesList) do
                                    local pass, count = EvaluatePalRule(rule, palName, charIdStr, isShiny, isBoss, palPassivesStr)
                                    if pass then
                                        shouldTrack = true
                                        if count > matchedPassiveCount then
                                            matchedPassiveCount = count
                                        end
                                        break
                                    end
                                end
                            end

                            if shouldTrack then
                                local labelParts = { palName }

                                if showLevel and level then
                                    table.insert(labelParts, "lv." .. tostring(level))
                                end

                                if rank and rank > 0 then
                                    local stars = string.rep("*", rank)
                                    table.insert(labelParts, stars)
                                end

                                if isShiny then
                                    table.insert(labelParts, "Shiny")
                                end

                                if isBoss then
                                    table.insert(labelParts, "Boss")
                                end

                                if matchedPassiveCount > 0 then
                                    table.insert(labelParts, "(" .. tostring(matchedPassiveCount) .. ")")
                                end

                                local formattedLabel = table.concat(labelParts, " ")
                                local distStr = math.floor(math.sqrt(distSq) / 100.0) .. "m"

                                table.insert(newPals, {
                                    X = px, Y = py, Z = pz,
                                    Name = formattedLabel,
                                    PalName = palName,
                                    Level = level,
                                    IsShiny = isShiny,
                                    IsBoss = isBoss,
                                    Passives = showPassives and translatedPassives or {},
                                    DistStr = distStr
                                })
                            end
                        end
                    end
                end
            end)
        end
    end

    if not M.hasLoggedPals and #newPals > 0 then
        M.hasLoggedPals = true
        logger.log("Pal Scan (Initial detection): Found " .. tostring(#newPals) .. " tracked Pals.")
    end

    return newPals
end

return M
