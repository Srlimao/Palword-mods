local UEHelpers = require("UEHelpers")
local configMod = require("AccessoryToggler.config")

local M = {}

local function SafeGet(val)
    return val:get()
end

function M.SafeUnwrap(param)
    if type(param) == "userdata" or type(param) == "table" then
        local success, val = pcall(SafeGet, param)
        if success then return val end
    end
    return param
end

M.CachedFont = nil
M.FontScaleMultiplier = 0.7
local lastFontScanTime = 0
local fontScanInterval = 10.0

function M.GetStringLength(str)
    if not str then return 0 end
    local status, len = pcall(function() return utf8.len(str) end)
    if status and len then
        return len
    end
    -- Fallback for standard ASCII or when utf8 library is not available
    return string.len(str)
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
    
    pcall(function()
        local fonts = FindAllOf("Font")
        if fonts then
            configMod.DebugPrint(string.format("[FindAndCacheFont] Background font scan starting. Loaded Font count: %d", #fonts))
            for _, f in ipairs(fonts) do
                if f:IsValid() then
                    local name = f:GetFullName()
                    if string.find(name:lower(), "/game/") then
                        M.CachedFont = f
                        configMod.DebugPrint("[FindAndCacheFont] Successfully matched and cached game UI font: " .. name)
                        return f
                    end
                end
            end
        end
    end)
    return nil
end

function M.GetFontAndScale()
    local font = M.CachedFont
    local scaleMult = font and M.FontScaleMultiplier or 1.0
    return font, scaleMult
end

function M.DebugPrint(msg)
    configMod.DebugPrint(msg)
end

local LoggedKeys = {}
function M.LogOnce(key, msg)
    if not LoggedKeys[key] then
        LoggedKeys[key] = true
        M.DebugPrint(msg)
    end
end

function M.DrawText(hud, text, color, x, y, baseScale, scalePosition)
    local font, scaleMult = M.GetFontAndScale()
    local finalScale = (baseScale or 1.0) * scaleMult
    hud:DrawText(text, color, x, y, font, finalScale, scalePosition or false)
end

local TextSizeCache = {}

-- Safely measure text width using UCanvas:K2_TextSize
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
                local size = canvas:K2_TextSize(font, text, { X = finalScale, Y = finalScale })
                if size then
                    width = size.X or size.x or 0
                end
            end
        end)
        
        if success and width and width > 0 then
            TextSizeCache[cacheKey] = width
            M.LogOnce("text_size_success", string.format("GetTextSize successfully measuring font sizes via UCanvas. Example: text='%s', scale=%.2f -> width=%.2f", tostring(text), finalScale, width))
        else
            local errMsg = err or (not hud.Canvas and "hud.Canvas is nil" or "K2_TextSize returned nil size")
            M.LogOnce("text_size_fail_" .. tostring(text), string.format("GetTextSize failed or returned 0 for text '%s' (scale=%.2f). Error: %s. Using fallback character spacing.", tostring(text), finalScale, tostring(errMsg)))
        end
    end
    
    return width
end

-- Split accessory ID into Category Type and Buff name
function M.GetAccessoryLabelParts(staticId)
    if not staticId or staticId == "" then return "GEAR", "-" end
    local idLower = staticId:lower()
    
    if idLower:find("nonkilling") then
        return "RING", "MERCY"
    elseif idLower:find("talentchecker") then
        return "GLASSES", "ABILITY"
    elseif idLower:find("hp") then
        local lvl = idLower:match("_(%d)$") or ""
        local suffix = lvl ~= "" and ("+" .. lvl) or ""
        return "PENDANT", "LIFE" .. suffix
    elseif idLower:find("attack") then
        local lvl = idLower:match("_(%d)$") or ""
        local suffix = lvl ~= "" and ("+" .. lvl) or ""
        return "PENDANT", "ATTACK" .. suffix
    elseif idLower:find("defense") then
        local lvl = idLower:match("_(%d)$") or ""
        local suffix = lvl ~= "" and ("+" .. lvl) or ""
        return "PENDANT", "DEFENSE" .. suffix
    elseif idLower:find("heatresist") then
        local lvl = idLower:match("_(%d)$") or ""
        local suffix = lvl ~= "" and ("+" .. lvl) or ""
        return "SHIRT", "HEAT" .. suffix
    elseif idLower:find("coldresist") then
        local lvl = idLower:match("_(%d)$") or ""
        local suffix = lvl ~= "" and ("+" .. lvl) or ""
        return "SHIRT", "COLD" .. suffix
    elseif idLower:find("heatandcoldresist") then
        local lvl = idLower:match("_(%d)$") or ""
        local suffix = lvl ~= "" and ("+" .. lvl) or ""
        return "SHIRT", "THERMAL" .. suffix
    end
    
    -- Generic split fallback
    return "GEAR", staticId:sub(1, 6):upper()
end

-- Resolve translated category and buff names for an accessory
function M.ResolveTranslatedNames(staticId, accName)
    local typeText, buffText = M.GetAccessoryLabelParts(staticId)
    local transType = configMod.GetTranslation("Label_" .. typeText, typeText)
    local transBuff = nil
    
    if accName and accName ~= "" then
        local buffName = accName
        
        -- Try to strip prefixes
        local prefix = configMod.GetTranslation("Prefix_" .. typeText, "")
        if prefix ~= "" then
            local escaped = prefix:gsub("[%-%^%$%*%+%?.%(%)%[%]%%]", "%%%1")
            buffName = buffName:gsub("^" .. escaped, "")
        end
        
        -- Try to strip suffixes
        local suffixPattern = configMod.GetTranslation("Suffix_" .. typeText, "")
        if suffixPattern ~= "" then
            for pattern in string.gmatch(suffixPattern, "[^,]+") do
                local trimmed = pattern:match("^%s*(.-)%s*$")
                local escaped = trimmed:gsub("[%-%^%$%*%+%?.%(%)%[%]%%]", "%%%1")
                local plusMinus = buffName:match("([%+%-]%d+)$") or ""
                if plusMinus ~= "" then
                    buffName = buffName:gsub("%s*[%+%-]%d+%s*$", "")
                end
                buffName = buffName:gsub("%s*" .. escaped .. "%s*$", "")
                if plusMinus ~= "" then
                    buffName = buffName .. " " .. plusMinus
                end
            end
        end
        
        if buffName ~= "" and buffName ~= accName then
            transBuff = buffName:match("^%s*(.-)%s*$")
        end
    end
    
    if not transBuff or transBuff == "" then
        local baseBuff = buffText:match("^([%a]+)") or buffText
        local suffix = buffText:match("([%+%-]%d+)$") or ""
        transBuff = configMod.GetTranslation("Label_" .. baseBuff, baseBuff) .. suffix
    end
    
    return transType, transBuff
end

return M
