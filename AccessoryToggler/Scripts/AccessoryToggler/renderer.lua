local configMod = require("AccessoryToggler.config")
local toggler = require("AccessoryToggler.toggler")

local M = {}

-- Helper to split accessory ID into Category Type and Buff name
local function GetAccessoryLabelParts(staticId)
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

function M.Draw(hud, SizeX, SizeY)
    if not configMod.CONFIG.Enabled then return end


    -- Only draw the hotbar if player has at least one accessory equipped or tracked
    local hasAny = false
    for i = 1, 4 do
        if toggler.equippedAccessories[i] then
            hasAny = true
            break
        end
    end
    -- Only draw the hotbar if player has at least one accessory equipped or tracked, or edit mode is active
    local hasAny = false
    for i = 1, 4 do
        if toggler.equippedAccessories[i] then
            hasAny = true
            break
        end
    end
    if not hasAny and not configMod.EditModeActive then return end

    -- Unwrap SizeX/SizeY safely
    local sx = SizeX
    if type(sx) == "userdata" or type(sx) == "table" then
        local status, val = pcall(function() return sx:get() end)
        if status then sx = val end
    end
    local sy = SizeY
    if type(sy) == "userdata" or type(sy) == "table" then
        local status, val = pcall(function() return sy:get() end)
        if status then sy = val end
    end

    local screenW = (type(sx) == "number" and sx > 0) and sx or 1920.0
    local screenH = (type(sy) == "number" and sy > 0) and sy or 1080.0

    -- Layout variables
    local scale = configMod.CONFIG.HUDScale or 1.0
    local size = 56.0 * scale
    local gap = 12.0 * scale
    local totalW = (4.0 * size) + (3.0 * gap)

    -- Bottom Center Positioning
    local x = configMod.CONFIG.HUDX or ((screenW / 2.0) - (totalW / 2.0))
    local y = configMod.CONFIG.HUDY or (screenH - size - 130.0)

    -- Materialize coordinate defaults if Edit Mode is active
    if configMod.EditModeActive then
        if not configMod.CONFIG.HUDX then
            configMod.CONFIG.HUDX = x
        end
        if not configMod.CONFIG.HUDY then
            configMod.CONFIG.HUDY = y
        end
    end

    -- Colors
    local cardBg = configMod.CONFIG.CardBg
    local textColorLabel = configMod.CONFIG.TextColorLabel
    local textColorEnabled = configMod.CONFIG.TextColorEnabled
    local textColorDisabled = configMod.CONFIG.TextColorDisabled
    
    local emptyBg = { R = 0.0, G = 0.0, B = 0.0, A = 0.3 }
    local emptyBorder = { R = 0.25, G = 0.25, B = 0.3, A = 0.4 }

    for uiIdx = 1, 4 do
        local slotX = x + (uiIdx - 1) * (size + gap)
        local acc = toggler.equippedAccessories[uiIdx]

        if not acc then
            -- Draw Empty Slot
            hud:DrawRect(emptyBorder, slotX, y, size, size)
            hud:DrawRect(emptyBg, slotX + 1.5, y + 1.5, size - 3.0, size - 3.0)

            -- Key number (5, 6, 7, 8)
            local keyLabel = tostring(uiIdx + 4)
            hud:DrawText(keyLabel, { R = 0.4, G = 0.4, B = 0.4, A = 0.5 }, slotX + 5.0 * scale, y + 4.0 * scale, nil, 0.65 * scale, false)

            -- Dash indicator
            local textW = 0
            pcall(function() textW = hud:GetTextSize("-", nil, 0.8 * scale) end)
            if not textW or textW == 0 then textW = 6.0 * scale end
            hud:DrawText("-", { R = 0.4, G = 0.4, B = 0.4, A = 0.5 }, slotX + (size / 2.0) - (textW / 2.0), y + (size / 2.0) - (9.0 * scale), nil, 0.8 * scale, false)
        else
            -- Choose slot colors based on enabled/disabled state
            local borderColor = acc.disabled and textColorDisabled or textColorEnabled
            local textMainColor = acc.disabled and { R = 0.5, G = 0.5, B = 0.5, A = 0.8 } or { R = 1.0, G = 1.0, B = 1.0, A = 1.0 }

            -- Draw Active/Disabled Slot Box
            hud:DrawRect(borderColor, slotX, y, size, size)
            hud:DrawRect(cardBg, slotX + 1.5, y + 1.5, size - 3.0, size - 3.0)

            -- Draw Key label (5, 6, 7, 8)
            local keyLabel = tostring(uiIdx + 4)
            hud:DrawText(keyLabel, textColorLabel, slotX + 5.0 * scale, y + 4.0 * scale, nil, 0.65 * scale, false)

            -- Split accessory static ID into Category Type and Buff name
            local typeText, buffText = GetAccessoryLabelParts(acc.staticId)
            
            -- Draw Type Text (Top Line)
            local typeScale = 0.45 * scale
            local typeW = 0
            pcall(function() typeW = hud:GetTextSize(typeText, nil, typeScale) end)
            if not typeW or typeW == 0 then typeW = #typeText * 3.8 * scale end
            local typeX = slotX + (size / 2.0) - (typeW / 2.0)
            local typeY = y + (size * 0.25) - (4.0 * scale)
            hud:DrawText(typeText, { R = 0.7, G = 0.7, B = 0.7, A = acc.disabled and 0.4 or 0.8 }, typeX, typeY, nil, typeScale, false)

            -- Draw Buff Text (Bottom Line)
            local buffScale = 0.55 * scale
            local buffW = 0
            pcall(function() buffW = hud:GetTextSize(buffText, nil, buffScale) end)
            if not buffW or buffW == 0 then buffW = #buffText * 4.6 * scale end
            local buffX = slotX + (size / 2.0) - (buffW / 2.0)
            local buffY = y + (size * 0.6) - (4.0 * scale)
            hud:DrawText(buffText, textMainColor, buffX, buffY, nil, buffScale, false)

            -- Draw Status indicator line at the bottom
            hud:DrawRect(borderColor, slotX + 5.0 * scale, y + size - 6.0 * scale, size - 10.0 * scale, 2.0 * scale)
        end
    end

    -- Draw Edit Mode Overlay Banner and Border Box
    if configMod.EditModeActive then
        local borderPadding = 10.0 * scale
        local boxX = x - borderPadding
        local boxY = y - borderPadding
        local boxW = totalW + borderPadding * 2.0
        local boxH = size + borderPadding * 2.0
        
        local editBorderColor = { R = 0.0, G = 0.5, B = 1.0, A = 0.8 }
        local editBgColor = { R = 0.0, G = 0.1, B = 0.2, A = 0.4 }
        hud:DrawRect(editBorderColor, boxX, boxY, boxW, boxH)
        hud:DrawRect(editBgColor, boxX + 1.5, boxY + 1.5, boxW - 3.0, boxH - 3.0)
        
        -- Redraw the slots on top of Edit Mode Background
        for uiIdx = 1, 4 do
            local slotX = x + (uiIdx - 1) * (size + gap)
            local acc = toggler.equippedAccessories[uiIdx]
            if not acc then
                hud:DrawRect(emptyBorder, slotX, y, size, size)
                hud:DrawRect(emptyBg, slotX + 1.5, y + 1.5, size - 3.0, size - 3.0)
                local keyLabel = tostring(uiIdx + 4)
                hud:DrawText(keyLabel, { R = 0.4, G = 0.4, B = 0.4, A = 0.5 }, slotX + 5.0 * scale, y + 4.0 * scale, nil, 0.65 * scale, false)
                hud:DrawText("-", { R = 0.4, G = 0.4, B = 0.4, A = 0.5 }, slotX + (size / 2.0) - (6.0 * scale / 2.0), y + (size / 2.0) - (9.0 * scale), nil, 0.8 * scale, false)
            else
                local borderColor = acc.disabled and textColorDisabled or textColorEnabled
                local textMainColor = acc.disabled and { R = 0.5, G = 0.5, B = 0.5, A = 0.8 } or { R = 1.0, G = 1.0, B = 1.0, A = 1.0 }
                hud:DrawRect(borderColor, slotX, y, size, size)
                hud:DrawRect(cardBg, slotX + 1.5, y + 1.5, size - 3.0, size - 3.0)
                local keyLabel = tostring(uiIdx + 4)
                hud:DrawText(keyLabel, textColorLabel, slotX + 5.0 * scale, y + 4.0 * scale, nil, 0.65 * scale, false)
                local typeText, buffText = GetAccessoryLabelParts(acc.staticId)
                local typeScale = 0.45 * scale
                local typeW = 0
                pcall(function() typeW = hud:GetTextSize(typeText, nil, typeScale) end)
                if not typeW or typeW == 0 then typeW = #typeText * 3.8 * scale end
                hud:DrawText(typeText, { R = 0.7, G = 0.7, B = 0.7, A = acc.disabled and 0.4 or 0.8 }, slotX + (size / 2.0) - (typeW / 2.0), y + (size * 0.25) - (4.0 * scale), nil, typeScale, false)
                local buffScale = 0.55 * scale
                local buffW = 0
                pcall(function() buffW = hud:GetTextSize(buffText, nil, buffScale) end)
                if not buffW or buffW == 0 then buffW = #buffText * 4.6 * scale end
                hud:DrawText(buffText, textMainColor, slotX + (size / 2.0) - (buffW / 2.0), y + (size * 0.6) - (4.0 * scale), nil, buffScale, false)
                hud:DrawRect(borderColor, slotX + 5.0 * scale, y + size - 6.0 * scale, size - 10.0 * scale, 2.0 * scale)
            end
        end

        local textLine1 = "EDIT MODE ACTIVE"
        local textLine2 = "ARROWS: MOVE | +/-: SCALE | ALT+F7: SAVE"
        
        local textScale1 = 0.6 * scale
        local textScale2 = 0.45 * scale
        
        local textW1 = 0
        pcall(function() textW1 = hud:GetTextSize(textLine1, nil, textScale1) end)
        if not textW1 or textW1 == 0 then textW1 = #textLine1 * 5.0 * scale end
        
        local textW2 = 0
        pcall(function() textW2 = hud:GetTextSize(textLine2, nil, textScale2) end)
        if not textW2 or textW2 == 0 then textW2 = #textLine2 * 3.8 * scale end
        
        local maxW = math.max(textW1, textW2) + 20.0 * scale
        local bannerH = 42.0 * scale
        local bannerX = x + (totalW / 2.0) - (maxW / 2.0)
        local bannerY = y - bannerH - 12.0 * scale
        
        hud:DrawRect(editBorderColor, bannerX, bannerY, maxW, bannerH)
        hud:DrawRect({ R = 0.02, G = 0.05, B = 0.12, A = 0.9 }, bannerX + 1.5, bannerY + 1.5, maxW - 3.0, bannerH - 3.0)
        
        hud:DrawText(textLine1, { R = 0.0, G = 1.0, B = 0.8, A = 1.0 }, bannerX + (maxW / 2.0) - (textW1 / 2.0), bannerY + 5.0 * scale, nil, textScale1, false)
        hud:DrawText(textLine2, { R = 0.9, G = 0.9, B = 0.9, A = 0.9 }, bannerX + (maxW / 2.0) - (textW2 / 2.0), bannerY + bannerH - 17.0 * scale, nil, textScale2, false)
    end
end

return M
