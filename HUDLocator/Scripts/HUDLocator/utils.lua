local UEHelpers = require("UEHelpers")
local configMod = require("HUDLocator.config")

local M = {}

M.MapObjectNameCache = {}
M.ItemNameCache = {}
M.LoggedTranslations = {}
M.MasterDataUtility = nil

function M.LogOnce(key, msg)
    if not M.LoggedTranslations[key] then
        M.LoggedTranslations[key] = true
        print("[HUDLocator] " .. msg)
    end
end

function M.GetTranslatedMapObjectName(masterDataId)
    local idStr = nil
    if type(masterDataId) == "string" then
        idStr = masterDataId
    elseif type(masterDataId) == "userdata" then
        pcall(function() idStr = masterDataId:ToString() end)
    end
    if not idStr then idStr = tostring(masterDataId) end

    if configMod.CONFIG.Language ~= "system" and configMod.CONFIG.Language ~= "" then
        if string.find(idStr, "TreasureBox") then return configMod.GetTranslation("Chest") end
        if string.find(idStr, "Relic") then return configMod.GetTranslation("Relic") end
        if string.find(idStr, "PalEgg") then return configMod.GetTranslation("Egg") end
        return nil
    end

    if M.MapObjectNameCache[idStr] then
        return M.MapObjectNameCache[idStr]
    end
    
    if not M.MasterDataUtility then
        local status, util = pcall(function() return StaticFindObject("/Script/Pal.Default__PalMasterDataTablesUtility") end)
        if status and util then M.MasterDataUtility = util end
    end
    
    local statusWorld, world = pcall(function() return UEHelpers.GetWorld() end)
    if statusWorld and world then
        if M.MasterDataUtility then
            local mapObjectKey = "MAPOBJECT_NAME_" .. idStr
            local status, outText = pcall(function()
                return M.MasterDataUtility:GetLocalizedText(world, 13, FName(mapObjectKey))
            end)
            M.LogOnce(mapObjectKey, string.format("MapObjectName lookup key=%s, status=%s, outText=%s", mapObjectKey, tostring(status), tostring(outText)))
            if status and outText then
                local strStatus, str = pcall(function() return outText:ToString() end)
                M.LogOnce(mapObjectKey .. "_str", string.format("MapObjectName stringify key=%s, strStatus=%s, str=%s", mapObjectKey, tostring(strStatus), tostring(str)))
                if strStatus and str and str ~= "" and str ~= mapObjectKey then
                    M.MapObjectNameCache[idStr] = str
                    return str
                end
            end
        end
    end
    
    return nil
end

function M.GetTranslatedDungeonName(overrideId)
    if not overrideId or overrideId:ToString() == "None" then
        return nil
    end
    local idStr = overrideId:ToString()
    local dungeonKey = idStr
    if not string.match(idStr, "^NAME_") then
        dungeonKey = "NAME_" .. idStr
    end
    
    if configMod.CONFIG.Language ~= "system" and configMod.CONFIG.Language ~= "" then
        return configMod.GetTranslation("Cave")
    end
    
    if not M.MasterDataUtility then
        local status, util = pcall(function() return StaticFindObject("/Script/Pal.Default__PalMasterDataTablesUtility") end)
        if status and util then M.MasterDataUtility = util end
    end
    
    local statusWorld, world = pcall(function() return UEHelpers.GetWorld() end)
    if statusWorld and world then
        if M.MasterDataUtility then
            local status, outText = pcall(function()
                return M.MasterDataUtility:GetLocalizedText(world, 21, FName(dungeonKey))
            end)
            M.LogOnce(dungeonKey, string.format("DungeonName lookup key=%s, status=%s, outText=%s", dungeonKey, tostring(status), tostring(outText)))
            if status and outText then
                local strStatus, str = pcall(function() return outText:ToString() end)
                M.LogOnce(dungeonKey .. "_str", string.format("DungeonName stringify key=%s, strStatus=%s, str=%s", dungeonKey, tostring(strStatus), tostring(str)))
                if strStatus and str and str ~= "" and str ~= dungeonKey then
                    return str
                end
            end
        end
    end
    return nil
end

function M.GetTranslatedItemName(itemId)
    local idStr = nil
    if type(itemId) == "string" then
        idStr = itemId
    elseif type(itemId) == "userdata" then
        pcall(function() idStr = itemId:ToString() end)
    end
    if not idStr then idStr = tostring(itemId) end

    if configMod.CONFIG.Language ~= "system" and configMod.CONFIG.Language ~= "" then
        if string.find(idStr, "Relic") then return configMod.GetTranslation("Relic") end
        return nil
    end

    if M.ItemNameCache[idStr] then
        return M.ItemNameCache[idStr]
    end
    
    if not M.MasterDataUtility then
        local status, util = pcall(function() return StaticFindObject("/Script/Pal.Default__PalMasterDataTablesUtility") end)
        if status and util then M.MasterDataUtility = util end
    end
    
    local statusWorld, world = pcall(function() return UEHelpers.GetWorld() end)
    if statusWorld and world then
        if M.MasterDataUtility then
            local itemKey = "ITEM_NAME_" .. idStr
            local status, outText = pcall(function()
                return M.MasterDataUtility:GetLocalizedText(world, 11, FName(itemKey))
            end)
            M.LogOnce(itemKey, string.format("ItemName lookup key=%s, status=%s, outText=%s", itemKey, tostring(status), tostring(outText)))
            if status and outText then
                local strStatus, str = pcall(function() return outText:ToString() end)
                M.LogOnce(itemKey .. "_str", string.format("ItemName stringify key=%s, strStatus=%s, str=%s", itemKey, tostring(strStatus), tostring(str)))
                if strStatus and str and str ~= "" and str ~= itemKey then
                    M.ItemNameCache[idStr] = str
                    return str
                end
            end
        end
    end
    
    return nil
end

function M.GetTranslatedRelicName(relicType)
    local itemId = "Relic"
    local num = nil
    if type(relicType) == "number" then
        num = relicType
    elseif type(relicType) == "userdata" then
        local statusVal, val = pcall(function() return relicType.value end)
        if statusVal and type(val) == "number" then
            num = val
        else
            local statusVal2, val2 = pcall(function() return relicType:value() end)
            if statusVal2 and type(val2) == "number" then
                num = val2
            else
                num = tonumber(tostring(relicType))
            end
        end
    end
    
    if num == 0 then
        itemId = "Relic"
    elseif num and num >= 1 and num <= 12 then
        itemId = string.format("Relic_%02d", num)
    end

    return M.GetTranslatedItemName(itemId)
end

function M.IsRelicPicked(relic)
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

function M.IsChestOpened(chest)
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

function M.IsEggPicked(egg)
    local status, picked = pcall(function()
        if not egg:IsValid() then return true end
        if egg.bHidden then return true end
        
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

function M.GetDungeonDetails(cave)
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

function M.GetDistanceSq(posA, posB)
    local dx = posA.X - posB.X
    local dy = posA.Y - posB.Y
    local dz = posA.Z - posB.Z
    return dx*dx + dy*dy + dz*dz
end

return M
