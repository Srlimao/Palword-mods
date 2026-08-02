local utils = require("HUDLocator.utils")
local logger = require("HUDLocator.logger")

local M = {}
M.hasLoggedLoot = false

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
                    local itemId = nil
                    pcall(function() itemId = concrete.ItemId end)
                    if itemId then
                        local staticId = nil
                        pcall(function() staticId = itemId.StaticId end)
                        if staticId then
                            pcall(function() itemIdStr = staticId:ToString() end)
                        end
                    end
                    
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
            name = itemIdStr
        end
    end
    
    return name, itemIdStr
end

function M.Scan(playerPos, maxDistSq, filters)
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
                    local within, distSq = utils.IsWithinDistanceSq(ueLootPos, playerPos, maxDistSq)
                    if within then
                        local name, itemIdStr = GetItemDetails(actor)
                        if name and name ~= "" then
                            local shouldAdd = true
                            if filters and #filters > 0 then
                                shouldAdd = false
                                local lowerName = name:lower()
                                local lowerId = (itemIdStr or ""):lower()
                                for _, filter in ipairs(filters) do
                                    local lowerFilter = tostring(filter):lower()
                                    if string.find(lowerName, lowerFilter, 1, true) or string.find(lowerId, lowerFilter, 1, true) then
                                        shouldAdd = true
                                        break
                                    end
                                end
                            end
                            
                            if shouldAdd then
                                local distStr = math.floor(math.sqrt(distSq) / 100.0) .. "m"
                                table.insert(newLoot, { X = ueLootPos.X, Y = ueLootPos.Y, Z = ueLootPos.Z, Name = name, DistStr = distStr })
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

return M
