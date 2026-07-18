local UEHelpers = require("UEHelpers")
local configMod = require("HUDLocator.config")
local logger = require("HUDLocator.logger")

local M = {}

M.MapObjectNameCache = {}
M.ItemNameCache = {}
M.LoggedTranslations = {}
M.MasterDataUtility = nil
M.CachedFont = nil
M.FontScaleMultiplier = 0.7
local lastFontScanTime = 0
local fontScanInterval = 10.0

function M.GetFontAndScale()
    local font = M.CachedFont
    local scaleMult = font and M.FontScaleMultiplier or 1.0
    return font, scaleMult
end

function M.OpenURL(url)
    pcall(function()
        local status, SystemLibrary = pcall(function() return StaticFindObject("/Script/Engine.Default__KismetSystemLibrary") end)
        if status and SystemLibrary then
            SystemLibrary:LaunchURL(url)
            print("[HUDLocator] Launching URL: " .. tostring(url))
        else
            print("[HUDLocator] ERROR: KismetSystemLibrary not found, cannot launch URL.")
        end
    end)
end

function M.UrlEncode(str)
    if not str then return "" end
    str = string.gsub(str, "([^%w %-%_%.%~])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    str = string.gsub(str, " ", "+")
    return str
end

function M.DrawText(hud, text, color, x, y, baseScale, scalePosition)
    local font, scaleMult = M.GetFontAndScale()
    local finalScale = (baseScale or 1.0) * scaleMult
    hud:DrawText(text, color, x, y, font, finalScale, scalePosition or false)
end

function M.GetTextSize(hud, text, baseScale)
    local font, scaleMult = M.GetFontAndScale()
    local finalScale = (baseScale or 1.0) * scaleMult
    local width = 0
    pcall(function() width = hud:GetTextSize(text, font, finalScale) end)
    return width
end

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

    if configMod.CONFIG.Global.Language ~= "system" and configMod.CONFIG.Global.Language ~= "" then
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
    
    if configMod.CONFIG.Global.Language ~= "system" and configMod.CONFIG.Global.Language ~= "" then
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

    if configMod.CONFIG.Global.Language ~= "system" and configMod.CONFIG.Global.Language ~= "" then
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
        
        if type(egg.bPickedInClient) == "boolean" and egg.bPickedInClient then return true end
        
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

function M.FindAndCacheFont()
    if M.CachedFont and M.CachedFont:IsValid() then
        return M.CachedFont
    end

    local currentTime = os.clock()
    if currentTime - lastFontScanTime < fontScanInterval then
        return nil
    end
    lastFontScanTime = currentTime

    logger.log("Starting background font scan...")
    local status, fonts = pcall(function() return FindAllOf("Font") end)
    if status and fonts then
        logger.log(string.format("Font scan completed. Found %d loaded Font objects.", #fonts))
        for _, f in ipairs(fonts) do
            if f:IsValid() then
                local name = f:GetFullName()
                logger.log("Loaded Font: " .. name)
                
                -- Check if it's a game-specific font asset under /Game/ (case-insensitive)
                if string.find(name:lower(), "/game/") then
                    logger.log("Matched and cached game UI font: " .. name)
                    M.CachedFont = f
                    
                    -- Test character length calculation for Thai
                    local testStr = "ถ้ำ"
                    local bytes = #testStr
                    local chars = M.GetStringLength(testStr)
                    logger.log(string.format("UTF-8 Length Test: string='%s', bytes=%d, chars=%d", testStr, bytes, chars))
                    
                    return f
                end
            end
        end
    else
        logger.log("Failed to scan Font objects: " .. tostring(fonts))
    end
    return nil
end

function M.GetStringLength(str)
    if not str then return 0 end
    local status, len = pcall(function() return utf8.len(str) end)
    if status and len then
        return len
    end
    return #str
end

return M
