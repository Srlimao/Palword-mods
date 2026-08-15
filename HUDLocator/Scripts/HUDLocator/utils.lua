local UEHelpers = require("UEHelpers")
local configMod = require("HUDLocator.config")
local logger = require("HUDLocator.logger")

local M = {}

M.MapObjectNameCache = {}
M.ItemNameCache = {}
M.DungeonNameCache = {}
M.NoteNameCache = {}
M.PalNameCache = {}
M.PassiveNameCache = {}
M.LoggedTranslations = {}
M.MasterDataUtility = nil
M.CachedFont = nil
M.FontScaleMultiplier = 0.7
local lastFontScanTime = 0
local fontScanInterval = 10.0

function M.GetFontAndScale()
    local font = M.CachedFont
    local systemMult = font and M.FontScaleMultiplier or 1.0
    local userScale = 1.0
    if configMod.CONFIG and configMod.CONFIG.Global and configMod.CONFIG.Global.FontScale then
        userScale = configMod.CONFIG.Global.FontScale
    end
    return font, systemMult * userScale
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

local TextSizeCache = {}

-- Safely measure text width using Unreal Engine's GetTextSize.
-- Falls back to 0 on failure. Logs outcomes once via M.LogOnce to avoid frame-rate lag.
function M.GetTextSize(hud, text, baseScale)
    if not text or text == "" then return 0 end
    local font, scaleMult = M.GetFontAndScale()
    local finalScale = (baseScale or 1.0) * scaleMult
    
    local cacheKey = text .. "_" .. string.format("%.3f", finalScale)
    if TextSizeCache[cacheKey] then
        return TextSizeCache[cacheKey]
    end
    
    local width = 0
    if font then
        local success, err = pcall(function()
            local canvas = hud.Canvas
            if canvas and canvas:IsValid() then
                -- UCanvas:K2_TextSize(class UFont* RenderFont, FString RenderText, FVector2D Scale)
                local size = canvas:K2_TextSize(font, text, { X = finalScale, Y = finalScale })
                if size then
                    width = size.X or size.x or 0
                end
            end
        end)
        
        if success and width and width > 0 then
            TextSizeCache[cacheKey] = width
            M.LogOnce("text_size_success", string.format("GetTextSize successfully measuring font sizes via UCanvas. Example: text='%s', scale=%.2f -> width=%.2f (using custom font: %s)", tostring(text), finalScale, width, tostring(font ~= nil)))
        else
            local errMsg = err or (not hud.Canvas and "hud.Canvas is nil" or "K2_TextSize returned nil size")
            M.LogOnce("text_size_fail_" .. tostring(text), string.format("GetTextSize failed or returned 0 for text '%s' (scale=%.2f, custom font: %s). Error: %s. Using fallback character spacing.", tostring(text), finalScale, tostring(font ~= nil), tostring(errMsg)))
        end
    end
    
    return width
end

function M.DebugPrint(msg)
    configMod.DebugPrint(msg)
end

function M.LogOnce(key, msg)
    if not M.LoggedTranslations[key] then
        M.LoggedTranslations[key] = true
        M.DebugPrint(msg)
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
        if string.find(idStr, "RequiredLongHold") or string.find(idStr, "Search") then return configMod.GetTranslation("Junk", "Junk") end
        if string.find(idStr, "TreasureBox") then return configMod.GetTranslation("Chest", "Chest") end
        if string.find(idStr, "Relic") then return configMod.GetTranslation("Relic", "Relic") end
        if string.find(idStr, "PalEgg") then return configMod.GetTranslation("Egg", "Egg") end
        return idStr
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
                if strStatus and str and str ~= "" then
                    if str == mapObjectKey then
                        -- Translation failed (e.g. custom constructed ID string like TreasureBox_GradeX), cache a fallback
                        if string.find(idStr, "TreasureBox") then
                            str = configMod.GetTranslation("Chest", "Chest")
                        elseif string.find(idStr, "Relic") then
                            str = configMod.GetTranslation("Relic", "Relic")
                        elseif string.find(idStr, "PalEgg") then
                            str = configMod.GetTranslation("Egg", "Egg")
                        else
                            str = idStr
                        end
                    end
                    M.MapObjectNameCache[idStr] = str
                    return str
                end
            end
        end
    end
    
    -- Cache failure fallback to avoid calling GetLocalizedText on every scan loop tick
    local fallback = idStr
    if string.find(idStr, "TreasureBox") then
        fallback = configMod.GetTranslation("Chest", "Chest")
    elseif string.find(idStr, "Relic") then
        fallback = configMod.GetTranslation("Relic", "Relic")
    elseif string.find(idStr, "PalEgg") then
        fallback = configMod.GetTranslation("Egg", "Egg")
    end
    M.MapObjectNameCache[idStr] = fallback
    return fallback
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
        return configMod.GetTranslation("Cave", "Cave")
    end

    if M.DungeonNameCache[idStr] then
        return M.DungeonNameCache[idStr]
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
                if strStatus and str and str ~= "" then
                    if str == dungeonKey then
                        str = configMod.GetTranslation("Cave", "Cave")
                    end
                    M.DungeonNameCache[idStr] = str
                    return str
                end
            end
        end
    end
    
    -- Cache translation failure fallback
    M.DungeonNameCache[idStr] = configMod.GetTranslation("Cave", "Cave")
    return M.DungeonNameCache[idStr]
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
        if string.find(idStr, "Relic") then return configMod.GetTranslation("Relic", "Relic") end
        return idStr
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
                if strStatus and str and str ~= "" then
                    if str == itemKey then
                        str = idStr
                    end
                    M.ItemNameCache[idStr] = str
                    return str
                end
            end
        end
    end
    
    -- Cache failure fallback
    M.ItemNameCache[idStr] = idStr
    return idStr
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

function M.IsNotePicked(note)
    local status, picked = pcall(function()
        if note:IsValid() then
            return note.bPickedInClient
        end
        return true
    end)
    if status then
        return picked
    else
        return true
    end
end

function M.GetTranslatedNoteName(noteKey)
    local idStr = nil
    if type(noteKey) == "string" then
        idStr = noteKey
    elseif type(noteKey) == "userdata" then
        pcall(function() idStr = noteKey:ToString() end)
    end
    if not idStr or idStr == "" or idStr == "None" then return nil end
    
    if M.NoteNameCache[idStr] then
        return M.NoteNameCache[idStr]
    end
    
    local friendly = idStr
    local num = string.match(idStr, "CastawayJournal_(%d+)")
    if num then
        friendly = configMod.GetTranslation("Note", "Journal") .. " (" .. configMod.GetTranslation("Castaway", "Castaway") .. " " .. tonumber(num) .. ")"
    else
        local suffix = string.match(idStr, "_(%d+)")
        if suffix then
            local prefix = string.match(idStr, "^([%w_]+)_%d+$") or "Journal"
            friendly = configMod.GetTranslation("Note", "Journal") .. " (" .. prefix .. " " .. tonumber(suffix) .. ")"
        else
            friendly = configMod.GetTranslation("Note", "Journal") .. " (" .. idStr .. ")"
        end
    end
    
    M.NoteNameCache[idStr] = friendly
    return friendly
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

local function GetModDir()
    local info = debug.getinfo(1, "S")
    if info and info.source and info.source:sub(1, 1) == "@" then
        local src = info.source:sub(2)
        local modDir = src:match("(.*)[/\\ ]Scripts[/\\]HUDLocator[/\\]utils%.lua")
        if modDir then
            return modDir
        end
    end
    return "Mods/HUDLocator"
end

local hasDumpedTextures = false
function M.DumpAllLoadedTextures()
    if hasDumpedTextures then return end
    hasDumpedTextures = true
    
    logger.log("Starting background texture scan...")
    local status, textures = pcall(function() return FindAllOf("Texture2D") end)
    if status and textures then
        logger.log(string.format("Texture scan completed. Found %d loaded Texture2D objects.", #textures))
        local modDir = GetModDir()
        local filepath = modDir .. "/loaded_textures.txt"
        logger.log("Writing textures to " .. filepath)
        
        local file = io.open(filepath, "w")
        if file then
            file:write("Loaded Texture2D objects:\n\n")
            for _, t in ipairs(textures) do
                if t:IsValid() then
                    local name = t:GetFullName()
                    file:write(name .. "\n")
                end
            end
            file:close()
            logger.log("Successfully wrote all loaded textures to file!")
        else
            logger.log("Failed to open loaded_textures.txt for writing")
        end
    else
        logger.log("Failed to scan Texture2D: " .. tostring(textures))
    end
end

function M.TArrayToTable(arrayVal)
    local t = {}
    if not arrayVal then return t end
    if type(arrayVal) == "table" then return arrayVal end
    if type(arrayVal) == "userdata" then
        if arrayVal.ForEach then
            pcall(function()
                arrayVal:ForEach(function(arg1, arg2)
                    local val = nil
                    if type(arg1) ~= "number" then
                        val = arg1
                    else
                        val = arg2
                    end
                    if val then
                        table.insert(t, val)
                    end
                end)
            end)
        else
            for i = 0, 100 do
                local elem = nil
                local success = pcall(function() elem = arrayVal[i] end)
                if not success or not elem then break end
                table.insert(t, elem)
            end
        end
    end
    return t
end

function M.FNameToString(fn)
    if not fn then return "" end
    if type(fn) == "string" then return fn end
    if type(fn) == "userdata" then
        if fn.get then
            local success, inner = pcall(function() return fn:get() end)
            if success and inner then
                fn = inner
            end
        end
        if type(fn) == "string" then return fn end
        if type(fn) == "userdata" and fn.ToString then
            local success, str = pcall(function() return fn:ToString() end)
            if success and str and type(str) == "string" and not string.find(str, "RemoteUnrealParam") then
                return str
            end
        end
    end
    local s = tostring(fn)
    if string.find(s, "RemoteUnrealParam") then
        return ""
    end
    return s
end

function M.GetCleanPalId(idStr)
    if not idStr or idStr == "" then return "" end
    local clean = idStr
    -- Strip Blueprint prefixes and suffixes if present
    clean = string.gsub(clean, "^BP_", "")
    clean = string.gsub(clean, "_C$", "")
    
    -- Strip Boss / Predator / Raid / Gym prefixes (case-insensitive)
    clean = string.gsub(clean, "^[Bb][Oo][Ss][Ss]_", "")
    clean = string.gsub(clean, "^[Ff][Bb][Oo][Ss][Ss]_", "")
    clean = string.gsub(clean, "^[Pp][Rr][Ee][Dd][Aa][Tt][Oo][Rr]_", "")
    clean = string.gsub(clean, "^[Rr][Aa][Ii][Dd]_", "")
    clean = string.gsub(clean, "^[Gg][Yy][Mm]_", "")
    
    -- Strip Boss suffixes
    clean = string.gsub(clean, "_[Bb][Oo][Ss][Ss]$", "")
    
    return clean
end

function M.GetTranslatedPalName(masterDataId)
    local idStr = nil
    if type(masterDataId) == "string" then
        idStr = masterDataId
    elseif type(masterDataId) == "userdata" then
        pcall(function() idStr = masterDataId:ToString() end)
    end
    if not idStr then idStr = tostring(masterDataId) end

    local cleanId = M.GetCleanPalId(idStr)
    if cleanId == "" then cleanId = idStr end

    if M.PalNameCache[cleanId] then
        return M.PalNameCache[cleanId]
    end

    if not M.MasterDataUtility then
        local status, util = pcall(function() return StaticFindObject("/Script/Pal.Default__PalMasterDataTablesUtility") end)
        if status and util then M.MasterDataUtility = util end
    end

    local statusWorld, world = pcall(function() return UEHelpers.GetWorld() end)
    if statusWorld and world and M.MasterDataUtility then
        local palKey = "PAL_NAME_" .. cleanId
        local status, outText = pcall(function()
            return M.MasterDataUtility:GetLocalizedText(world, 4, FName(palKey))
        end)
        if status and outText then
            local strStatus, str = pcall(function() return outText:ToString() end)
            if strStatus and str and str ~= "" and str ~= palKey then
                M.PalNameCache[cleanId] = str
                return str
            end
        end
    end

    M.PalNameCache[cleanId] = cleanId
    return cleanId
end

function M.GetTranslatedPassiveName(passiveId)
    local idStr = M.FNameToString(passiveId)
    if not idStr or idStr == "" or idStr == "None" then return "" end

    if M.PassiveNameCache[idStr] then
        return M.PassiveNameCache[idStr]
    end

    if not M.MasterDataUtility then
        local status, util = pcall(function() return StaticFindObject("/Script/Pal.Default__PalMasterDataTablesUtility") end)
        if status and util then M.MasterDataUtility = util end
    end

    local statusWorld, world = pcall(function() return UEHelpers.GetWorld() end)
    if statusWorld and world and M.MasterDataUtility then
        local status, outText = pcall(function()
            return M.MasterDataUtility:GetLocalizedText(world, 16, FName(idStr))
        end)
        if not status or not outText or outText:ToString() == idStr then
            status, outText = pcall(function()
                return M.MasterDataUtility:GetLocalizedText(world, 16, FName("PASSIVE_" .. idStr))
            end)
        end
        if status and outText then
            local strStatus, str = pcall(function() return outText:ToString() end)
            if strStatus and str and str ~= "" and str ~= idStr and str ~= ("PASSIVE_" .. idStr) then
                M.PassiveNameCache[idStr] = str
                return str
            end
        end
    end

    M.PassiveNameCache[idStr] = idStr
    return idStr
end

-- Fast sequential axis spatial distance evaluation
function M.IsWithinDistanceSq(uePos, playerPos, maxDistSq)
    if not uePos or not playerPos then return false, math.huge end
    local px = uePos.X
    local dx = px - playerPos.X
    local dxSq = dx * dx
    if dxSq > maxDistSq then return false, math.huge end

    local py = uePos.Y
    local dy = py - playerPos.Y
    local dySq = dy * dy
    if (dxSq + dySq) > maxDistSq then return false, math.huge end

    local pz = uePos.Z
    local dz = pz - playerPos.Z
    local distSq = dxSq + dySq + dz * dz
    if distSq > maxDistSq then return false, math.huge end

    return true, distSq
end

return M

