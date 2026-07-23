local configMod = require("AccessoryToggler.config")
local toggler = require("AccessoryToggler.toggler")
local utils = require("AccessoryToggler.utils")

local M = {}

-- Pre-allocated static structures for color tables to avoid per-frame GC allocations
local emptyBg = { R = 0.0, G = 0.0, B = 0.0, A = 0.3 }
local emptyBorder = { R = 0.25, G = 0.25, B = 0.3, A = 0.4 }

local editBorderColor = { R = 0.0, G = 0.5, B = 1.0, A = 0.8 }
local editBgColor = { R = 0.0, G = 0.1, B = 0.2, A = 0.4 }
local bannerBgColor = { R = 0.02, G = 0.05, B = 0.12, A = 0.9 }

local editBannerTextCol1 = { R = 0.0, G = 1.0, B = 0.8, A = 1.0 }
local editBannerTextCol2 = { R = 0.9, G = 0.9, B = 0.9, A = 0.9 }

local slotTextDisabled = { R = 0.5, G = 0.5, B = 0.5, A = 0.8 }
local slotTextEnabled = { R = 1.0, G = 1.0, B = 1.0, A = 1.0 }

local slotTypeDisabled = { R = 0.7, G = 0.7, B = 0.7, A = 0.4 }
local slotTypeEnabled = { R = 0.7, G = 0.7, B = 0.7, A = 0.8 }

local emptyTextCol = { R = 0.4, G = 0.4, B = 0.4, A = 0.5 }

local function GetShortKeyLabel(keyStr, defaultLabel)
    if not keyStr or keyStr == "" then return defaultLabel end
    local k = string.upper(tostring(keyStr))
    local numMap = {ONE="1", TWO="2", THREE="3", FOUR="4", FIVE="5", SIX="6", SEVEN="7", EIGHT="8", NINE="9", ZERO="0"}
    if numMap[k] then return numMap[k] end
    if k:sub(1,4) == "NUM_" then return "N" .. k:sub(5) end
    if k == "LEFT MOUSE BUTTON" then return "LMB" end
    if k == "RIGHT MOUSE BUTTON" then return "RMB" end
    if k == "MIDDLE MOUSE BUTTON" then return "MMB" end
    if k == "THUMB MOUSE BUTTON" then return "MB4" end
    if k == "THUMB MOUSE BUTTON 2" then return "MB5" end
    if #k > 4 then return k:sub(1,3) end
    return k
end

local function DrawSlot(hud, slotX, y, size, scale, acc, uiIdx, textColorDisabled, textColorEnabled, textColorLabel, cardBg, emptyBorder, emptyBg)
    local rawKey = configMod.CONFIG.KeyBinds and configMod.CONFIG.KeyBinds["ToggleSlot" .. uiIdx]
    local defaultKeyLabel = tostring(uiIdx + 4)
    local keyLabel = GetShortKeyLabel(rawKey, defaultKeyLabel)

    if not acc then
        -- Draw Empty Slot
        hud:DrawRect(emptyBorder, slotX, y, size, size)
        hud:DrawRect(emptyBg, slotX + 1.5, y + 1.5, size - 3.0, size - 3.0)

        -- Key number
        utils.DrawText(hud, keyLabel, emptyTextCol, slotX + 5.0 * scale, y + 4.0 * scale, 0.65 * scale, false)

        -- Dash indicator
        local textW = utils.GetTextSize(hud, "-", 0.8 * scale)
        if not textW or textW == 0 then
            local font, scaleMult = utils.GetFontAndScale()
            textW = 6.0 * scale * scaleMult
        end
        utils.DrawText(hud, "-", emptyTextCol, slotX + (size / 2.0) - (textW / 2.0), y + (size / 2.0) - (9.0 * scale), 0.8 * scale, false)
    else
        -- Choose slot colors based on enabled/disabled state
        local borderColor = acc.disabled and textColorDisabled or textColorEnabled
        local textMainColor = acc.disabled and slotTextDisabled or slotTextEnabled

        -- Draw Active/Disabled Slot Box
        hud:DrawRect(borderColor, slotX, y, size, size)
        hud:DrawRect(cardBg, slotX + 1.5, y + 1.5, size - 3.0, size - 3.0)

        -- Draw Key label
        utils.DrawText(hud, keyLabel, textColorLabel, slotX + 5.0 * scale, y + 4.0 * scale, 0.65 * scale, false)

        local transType = acc.transType or "GEAR"
        local transBuff = acc.transBuff or "-"
        
        -- Draw Type Text (Top Line)
        local typeScale = 0.45 * scale
        local typeW = utils.GetTextSize(hud, transType, typeScale)
        if not typeW or typeW == 0 then
            local font, scaleMult = utils.GetFontAndScale()
            typeW = utils.GetStringLength(transType) * 8.4 * typeScale * scaleMult
        end
        local typeX = slotX + (size / 2.0) - (typeW / 2.0)
        local typeY = y + (size * 0.25) - (4.0 * scale)
        utils.DrawText(hud, transType, acc.disabled and slotTypeDisabled or slotTypeEnabled, typeX, typeY, typeScale, false)

        -- Draw Buff Text (Bottom Line)
        local buffScale = 0.55 * scale
        local buffW = utils.GetTextSize(hud, transBuff, buffScale)
        if not buffW or buffW == 0 then
            local font, scaleMult = utils.GetFontAndScale()
            buffW = utils.GetStringLength(transBuff) * 8.4 * buffScale * scaleMult
        end
        local buffX = slotX + (size / 2.0) - (buffW / 2.0)
        local buffY = y + (size * 0.6) - (4.0 * scale)
        utils.DrawText(hud, transBuff, textMainColor, buffX, buffY, buffScale, false)

        -- Draw Status indicator line at the bottom
        hud:DrawRect(borderColor, slotX + 5.0 * scale, y + size - 6.0 * scale, size - 10.0 * scale, 2.0 * scale)
    end
end

function M.Draw(hud, SizeX, SizeY)
    if not configMod.CONFIG.Enabled and not configMod.EditModeActive then return end

    local sx = utils.SafeUnwrap(SizeX)
    local sy = utils.SafeUnwrap(SizeY)

    local screenW = (type(sx) == "number" and sx > 0) and sx or 1920.0
    local screenH = (type(sy) == "number" and sy > 0) and sy or 1080.0

    -- Layout variables
    local scale = configMod.CONFIG.HUDScale or 1.0
    local size = 56.0 * scale
    local gap = 12.0 * scale
    local slotsToShow = configMod.CONFIG.SlotsToShow or 4
    slotsToShow = math.max(1, math.min(4, math.floor(tonumber(slotsToShow) or 4)))
    local totalW = (slotsToShow * size) + ((slotsToShow - 1) * gap)

    local maxScrollX = screenW - totalW
    if maxScrollX <= 0 then maxScrollX = 1 end
    local maxScrollY = screenH - size
    if maxScrollY <= 0 then maxScrollY = 1 end

    local x
    local migrated = false
    local oldX = configMod.CONFIG.HUDX
    local oldY = configMod.CONFIG.HUDY

    if configMod.CONFIG.HUDX then
        if configMod.CONFIG.HUDX > 100.0 then
            local newX = tonumber(string.format("%.1f", (configMod.CONFIG.HUDX / maxScrollX) * 100.0))
            print(string.format("[AccessoryToggler] Migrating HUDX from pixel %.1f to percentage %.1f%% (ScreenW: %.1f, HUDW: %.1f)", configMod.CONFIG.HUDX, newX, screenW, totalW))
            configMod.CONFIG.HUDX = newX
            migrated = true
        end
        configMod.CONFIG.HUDX = math.max(0.0, math.min(100.0, configMod.CONFIG.HUDX))
        x = (configMod.CONFIG.HUDX / 100.0) * maxScrollX
    else
        x = (screenW / 2.0) - (totalW / 2.0)
    end

    local y
    if configMod.CONFIG.HUDY then
        if configMod.CONFIG.HUDY > 100.0 then
            local newY = tonumber(string.format("%.1f", (configMod.CONFIG.HUDY / maxScrollY) * 100.0))
            print(string.format("[AccessoryToggler] Migrating HUDY from pixel %.1f to percentage %.1f%% (ScreenH: %.1f, HUDH: %.1f)", configMod.CONFIG.HUDY, newY, screenH, size))
            configMod.CONFIG.HUDY = newY
            migrated = true
        end
        configMod.CONFIG.HUDY = math.max(0.0, math.min(100.0, configMod.CONFIG.HUDY))
        y = (configMod.CONFIG.HUDY / 100.0) * maxScrollY
    else
        y = screenH - size - 130.0
    end

    if migrated then
        pcall(function()
            configMod.SaveConfig()
            print(string.format("[AccessoryToggler] Legacy coordinate config successfully migrated: HUDX (%s -> %s%%), HUDY (%s -> %s%%)", tostring(oldX), tostring(configMod.CONFIG.HUDX), tostring(oldY), tostring(configMod.CONFIG.HUDY)))
        end)
    end

    -- Materialize coordinate defaults if Edit Mode is active
    if configMod.EditModeActive then
        if not configMod.CONFIG.HUDX then
            configMod.CONFIG.HUDX = tonumber(string.format("%.1f", (x / maxScrollX) * 100.0))
        end
        if not configMod.CONFIG.HUDY then
            configMod.CONFIG.HUDY = tonumber(string.format("%.1f", (y / maxScrollY) * 100.0))
        end
    end

    -- Colors
    local cardBg = configMod.CONFIG.CardBg
    local textColorLabel = configMod.CONFIG.TextColorLabel
    local textColorEnabled = configMod.CONFIG.TextColorEnabled
    local textColorDisabled = configMod.CONFIG.TextColorDisabled

    if configMod.EditModeActive then
        local borderPadding = 10.0 * scale
        local boxX = x - borderPadding
        local boxY = y - borderPadding
        local boxW = totalW + borderPadding * 2.0
        local boxH = size + borderPadding * 2.0
        
        hud:DrawRect(editBorderColor, boxX, boxY, boxW, boxH)
        hud:DrawRect(editBgColor, boxX + 1.5, boxY + 1.5, boxW - 3.0, boxH - 3.0)
        
        -- Text Banner
        local textLine1 = configMod.GetTranslation("EditModeActive", "EDIT MODE ACTIVE")
        local rawEditKey = configMod.CONFIG.KeyBinds and configMod.CONFIG.KeyBinds.ToggleEditMode
        local rawResetKey = configMod.CONFIG.KeyBinds and configMod.CONFIG.KeyBinds.ResetCoords
        local editKeyStr = GetShortKeyLabel(rawEditKey, "F7")
        local resetKeyStr = GetShortKeyLabel(rawResetKey, "R")
        
        local textLine2 = configMod.GetTranslation("EditModeInstructions", "ARROWS: MOVE | +/-: SCALE | ALT+R: RESET | ALT+F7: SAVE")
        textLine2 = textLine2:gsub("ALT%+F7", "ALT+" .. editKeyStr)
        textLine2 = textLine2:gsub("ALT%+R", "ALT+" .. resetKeyStr)
        
        local textScale1 = 0.6 * scale
        local textScale2 = 0.45 * scale
        
        local textW1 = utils.GetTextSize(hud, textLine1, textScale1)
        if not textW1 or textW1 == 0 then
            local font, scaleMult = utils.GetFontAndScale()
            textW1 = utils.GetStringLength(textLine1) * 8.4 * textScale1 * scaleMult
        end
        
        local textW2 = utils.GetTextSize(hud, textLine2, textScale2)
        if not textW2 or textW2 == 0 then
            local font, scaleMult = utils.GetFontAndScale()
            textW2 = utils.GetStringLength(textLine2) * 8.4 * textScale2 * scaleMult
        end
        
        local maxW = math.max(textW1, textW2) + 20.0 * scale
        local bannerH = 42.0 * scale
        local bannerX = x + (totalW / 2.0) - (maxW / 2.0)
        local bannerY = y - bannerH - 12.0 * scale
        
        hud:DrawRect(editBorderColor, bannerX, bannerY, maxW, bannerH)
        hud:DrawRect(bannerBgColor, bannerX + 1.5, bannerY + 1.5, maxW - 3.0, bannerH - 3.0)
        
        utils.DrawText(hud, textLine1, editBannerTextCol1, bannerX + (maxW / 2.0) - (textW1 / 2.0), bannerY + 5.0 * scale, textScale1, false)
        utils.DrawText(hud, textLine2, editBannerTextCol2, bannerX + (maxW / 2.0) - (textW2 / 2.0), bannerY + bannerH - 17.0 * scale, textScale2, false)
    end

    for uiIdx = 1, slotsToShow do
        local slotX = x + (uiIdx - 1) * (size + gap)
        local acc = toggler.equippedAccessories[uiIdx]
        DrawSlot(hud, slotX, y, size, scale, acc, uiIdx, textColorDisabled, textColorEnabled, textColorLabel, cardBg, emptyBorder, emptyBg)
    end
end

return M
