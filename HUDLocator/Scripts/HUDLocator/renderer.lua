local configMod = require("HUDLocator.config")
local popup = require("HUDLocator.popup")
local menu = require("HUDLocator.menu")
local utils = require("HUDLocator.utils")
local completion = require("HUDLocator.completion")
local CONFIG = configMod.CONFIG

local M = {}

-- Pre-allocated static table buffers to prevent GC allocations during ReceiveDrawHUD frame ticks
local playerPosBuffer = { X = 0.0, Y = 0.0, Z = 0.0 }
local textWorldPosBuffer = { X = 0.0, Y = 0.0, Z = 0.0 }
local beaconBaseWorldBuffer = { X = 0.0, Y = 0.0, Z = 0.0 }
local beaconTopWorldBuffer = { X = 0.0, Y = 0.0, Z = 0.0 }
local beaconColorBuffer = { R = 0.0, G = 0.0, B = 0.0, A = 1.0 }

-- Pre-allocated color tables for Progress Tracker Card and Edit Mode
local cardBgCol = { R = 0.05, G = 0.07, B = 0.15, A = 0.85 }
local cardBorderCol = { R = 0.0, G = 0.95, B = 1.0, A = 0.6 }
local cardShadowCol = { R = 0.0, G = 0.0, B = 0.0, A = 0.9 }
local cardTitleCol = { R = 0.0, G = 0.95, B = 1.0, A = 1.0 }
local cardTextCol = { R = 0.9, G = 0.9, B = 0.95, A = 1.0 }
local cardPctCol = { R = 0.0, G = 0.96, B = 0.83, A = 1.0 }
local cardBarBgCol = { R = 0.15, G = 0.15, B = 0.25, A = 0.8 }
local cardBarFillCol = { R = 0.0, G = 0.96, B = 0.83, A = 0.9 }

local editBorderCol = { R = 0.0, G = 0.95, B = 1.0, A = 0.8 }
local editBgCol = { R = 0.0, G = 0.1, B = 0.2, A = 0.35 }
local bannerBgCol = { R = 0.02, G = 0.05, B = 0.12, A = 0.92 }
local editBannerTextCol1 = { R = 0.0, G = 1.0, B = 0.8, A = 1.0 }
local editBannerTextCol2 = { R = 0.9, G = 0.9, B = 0.95, A = 0.9 }

local modalBgCol = { R = 0.04, G = 0.06, B = 0.12, A = 0.92 }
local modalBorderCol = { R = 0.0, G = 0.95, B = 1.0, A = 0.8 }
local modalShadowCol = { R = 0.0, G = 0.0, B = 0.0, A = 0.95 }
local modalHeaderCol = { R = 0.0, G = 0.95, B = 1.0, A = 1.0 }
local modalSepCol = { R = 0.2, G = 0.25, B = 0.35, A = 0.5 }
local modalCurrBgCol = { R = 0.0, G = 0.3, B = 0.4, A = 0.35 }
local modalNormalBgCol = { R = 0.08, G = 0.1, B = 0.18, A = 0.6 }
local modalCurrBorderCol = { R = 0.0, G = 0.96, B = 0.83, A = 0.9 }
local modalNormalBorderCol = { R = 0.2, G = 0.2, B = 0.3, A = 0.4 }
local modalCurrTextCol = { R = 0.0, G = 0.96, B = 0.83, A = 1.0 }
local modalNormalTextCol = { R = 0.95, G = 0.95, B = 1.0, A = 1.0 }
local modalDetTextCol = { R = 0.8, G = 0.85, B = 0.9, A = 1.0 }

local cachedEditBanner1 = nil
local cachedEditBanner2 = nil

local drawnBoxCount = 0
local drawnBoxes = {}
for i = 1, 150 do
    drawnBoxes[i] = { x = 0.0, y = 0.0, w = 0.0, h = 0.0 }
end

-- Render a 3D glowing beam and ground flare at the location
local function DrawCaveBeacon(hud, pos, color)
    beaconBaseWorldBuffer.X = pos.X; beaconBaseWorldBuffer.Y = pos.Y; beaconBaseWorldBuffer.Z = pos.Z
    beaconTopWorldBuffer.X = pos.X; beaconTopWorldBuffer.Y = pos.Y; beaconTopWorldBuffer.Z = pos.Z + 1500.0 -- 15 meters tall
    
    local ueScreenBase = hud:Project(beaconBaseWorldBuffer, false)
    local ueScreenTop = hud:Project(beaconTopWorldBuffer, false)

    -- Optimize: Read .Z first, and conditionally evaluate .X and .Y to avoid reflection overhead for off-screen items
    local screenBaseZ = ueScreenBase.Z
    local screenTopZ = ueScreenTop.Z
    
    if screenBaseZ > 0.0 or screenTopZ > 0.0 then
        local screenBaseX, screenBaseY = ueScreenBase.X, ueScreenBase.Y
        local screenTopX, screenTopY = ueScreenTop.X, ueScreenTop.Y

        beaconColorBuffer.R = color.R; beaconColorBuffer.G = color.G; beaconColorBuffer.B = color.B
        
        beaconColorBuffer.A = 0.05
        hud:DrawLine(screenBaseX, screenBaseY, screenTopX, screenTopY, beaconColorBuffer, 16.0)
        beaconColorBuffer.A = 0.12
        hud:DrawLine(screenBaseX, screenBaseY, screenTopX, screenTopY, beaconColorBuffer, 8.0)
        
        beaconColorBuffer.R = 1.0; beaconColorBuffer.G = 1.0; beaconColorBuffer.B = 1.0; beaconColorBuffer.A = 0.35
        hud:DrawLine(screenBaseX, screenBaseY, screenTopX, screenTopY, beaconColorBuffer, 2.0)
        
        beaconColorBuffer.R = color.R; beaconColorBuffer.G = color.G; beaconColorBuffer.B = color.B
        local steps = 5
        local baseSize = 24.0
        for i = 1, steps do
            local size = baseSize * (1.0 + (i - 1) * 0.6)
            beaconColorBuffer.A = 0.15 * (1.0 - (i - 1) / steps)
            hud:DrawRect(beaconColorBuffer, screenBaseX - size/2, screenBaseY - size/2, size, size)
        end
    end
end

-- Render tracker label (either box style or simple text style)
local function DrawTrackerLabel(hud, worldPos, nameStr, distStr, style, screenW, screenH, subStr, nameColorOverride, bracketDistStr, subItems)
    textWorldPosBuffer.X = worldPos.X
    textWorldPosBuffer.Y = worldPos.Y
    textWorldPosBuffer.Z = worldPos.Z + style.TextOffsetZ
    local ueTextScreen = hud:Project(textWorldPosBuffer, false)
    
    -- Optimize: Read .Z first, and conditionally evaluate .X and .Y to avoid reflection overhead for off-screen items
    local textScreenZ = ueTextScreen.Z
    if textScreenZ <= 0.0 then return end

    local textScreenX = ueTextScreen.X
    local textScreenY = ueTextScreen.Y
    
    -- Screen Viewport Bounds Culling: Only render text for items visible on the screen
    local margin = 100.0
    local isVisibleOnScreen = (textScreenX >= -margin) and (textScreenX <= screenW + margin)
                          and (textScreenY >= -margin) and (textScreenY <= screenH + margin)
    
    if isVisibleOnScreen then
        local font, scaleMult = utils.GetFontAndScale()
        local fontScale = style.FontScale * scaleMult
        local smallFontScale = style.SmallFontScale * scaleMult
        local nameColor = nameColorOverride or style.NameColor
        
        local charW = style.FontCharW
        local lineH = style.FontLineH
        if font then
            charW = charW * 1.6
            lineH = lineH * 2.8
        end

        local useMultiColor = (style.UseRarityColors ~= false) and subItems and (#subItems > 0)
        local hasSub = (subStr and subStr ~= "") or useMultiColor
        local subH = hasSub and (lineH * smallFontScale) or 0
        local lineGap = font and 6.0 or 4.0

        local subW = 0
        local sepW = 0
        if useMultiColor then
            sepW = utils.GetTextSize(hud, ", ", style.SmallFontScale)
            if not sepW or sepW == 0 then sepW = 2 * charW * smallFontScale end
            for i = 1, #subItems do
                local item = subItems[i]
                local itemW = utils.GetTextSize(hud, item.name, style.SmallFontScale)
                if not itemW or itemW == 0 then itemW = utils.GetStringLength(item.name) * charW * smallFontScale end
                subW = subW + itemW
                if i < #subItems then
                    subW = subW + sepW
                end
            end
        elseif subStr and subStr ~= "" then
            subW = utils.GetTextSize(hud, subStr, style.SmallFontScale)
            if not subW or subW == 0 then
                subW = utils.GetStringLength(subStr) * charW * smallFontScale
            end
        end

        local nameW = utils.GetTextSize(hud, nameStr, style.FontScale)
        if not nameW or nameW == 0 then
            nameW = utils.GetStringLength(nameStr) * charW * fontScale
        end

        local distPartStr = bracketDistStr or (distStr and ("[" .. distStr .. "]") or "")
        local distW = 0
        if style.DrawBox then
            if distStr then
                distW = utils.GetTextSize(hud, distStr, style.SmallFontScale)
                if not distW or distW == 0 then distW = utils.GetStringLength(distStr) * charW * smallFontScale end
            end
        else
            if distPartStr ~= "" then
                distW = utils.GetTextSize(hud, distPartStr, style.SmallFontScale)
                if not distW or distW == 0 then distW = utils.GetStringLength(distPartStr) * charW * smallFontScale end
            end
        end

        local nameH  = lineH * fontScale
        local distH  = distStr and (lineH * smallFontScale) or 0
        local contentW = math.max(nameW, distW, subW)
        local contentH = nameH + (distStr and (lineGap + distH) or 0) + (subH > 0 and (lineGap + subH) or 0)

        local finalScreenY = textScreenY
        for i = 1, drawnBoxCount do
            local b = drawnBoxes[i]
            local dx = math.abs(textScreenX - b.x)
            local dy = math.abs(finalScreenY - b.y)
            if dx < (contentW + b.w) * 0.48 and dy < (contentH + b.h) * 0.55 then
                finalScreenY = b.y - (contentH + b.h) * 0.5 - 4.0
            end
        end

        if drawnBoxCount < 150 then
            drawnBoxCount = drawnBoxCount + 1
            local b = drawnBoxes[drawnBoxCount]
            b.x = textScreenX
            b.y = finalScreenY
            b.w = contentW
            b.h = contentH
        end

        if style.DrawBox then
            local bw     = style.BorderWidth
            local padX = style.BoxPadX
            local padY = style.BoxPadY
            if font then
                padX = padX + 4.0
                padY = padY + 2.0
            end
            
            local boxW = contentW + padX * 2
            local boxH = contentH + padY * 2
            
            local boxX = textScreenX - boxW * 0.5
            local boxY = finalScreenY - boxH * 0.5
 
            -- Draw border
            hud:DrawRect(style.BorderColor, boxX - bw, boxY - bw, boxW + bw * 2, boxH + bw * 2)
 
            -- Draw background fill box
            hud:DrawRect(style.BoxColor, boxX, boxY, boxW, boxH)
            
            local nameX = textScreenX - nameW * 0.5
            local nameY = boxY + padY
            
            utils.DrawText(hud, nameStr, nameColor, nameX, nameY, style.FontScale, false)
            
            local nextY = nameY + nameH + lineGap
            if useMultiColor then
                local curX = textScreenX - subW * 0.5
                for i = 1, #subItems do
                    local item = subItems[i]
                    local itemW = utils.GetTextSize(hud, item.name, style.SmallFontScale)
                    if not itemW or itemW == 0 then itemW = utils.GetStringLength(item.name) * charW * smallFontScale end
                    utils.DrawText(hud, item.name, item.color or nameColor, curX, nextY, style.SmallFontScale, false)
                    curX = curX + itemW
                    if i < #subItems then
                        utils.DrawText(hud, ", ", style.DistColor or style.BorderColor, curX, nextY, style.SmallFontScale, false)
                        curX = curX + sepW
                    end
                end
                nextY = nextY + subH + lineGap
            elseif subStr and subStr ~= "" then
                local subX = textScreenX - subW * 0.5
                utils.DrawText(hud, subStr, nameColor, subX, nextY, style.SmallFontScale, false)
                nextY = nextY + subH + lineGap
            end

            if distStr then
                local distX = textScreenX - distW * 0.5
                utils.DrawText(hud, distStr, style.DistColor, distX, nextY, style.SmallFontScale, false)
            end
        else
            -- Simple text format: Name \n SubText \n [Distance]
            local startX = textScreenX - nameW * 0.5
            local simpleY = finalScreenY - contentH * 0.5
            
            utils.DrawText(hud, nameStr, style.BorderColor, startX + 1.0, simpleY + 1.0, style.FontScale, false)
            utils.DrawText(hud, nameStr, nameColor, startX, simpleY, style.FontScale, false)
            
            local nextY = simpleY + nameH + lineGap
            if useMultiColor then
                local curX = textScreenX - subW * 0.5
                for i = 1, #subItems do
                    local item = subItems[i]
                    local itemW = utils.GetTextSize(hud, item.name, style.SmallFontScale)
                    if not itemW or itemW == 0 then itemW = utils.GetStringLength(item.name) * charW * smallFontScale end
                    utils.DrawText(hud, item.name, style.BorderColor, curX + 1.0, nextY + 1.0, style.SmallFontScale, false)
                    utils.DrawText(hud, item.name, item.color or nameColor, curX, nextY, style.SmallFontScale, false)
                    curX = curX + itemW
                    if i < #subItems then
                        utils.DrawText(hud, ", ", style.BorderColor, curX + 1.0, nextY + 1.0, style.SmallFontScale, false)
                        utils.DrawText(hud, ", ", style.DistColor or style.BorderColor, curX, nextY, style.SmallFontScale, false)
                        curX = curX + sepW
                    end
                end
                nextY = nextY + subH + lineGap
            elseif subStr and subStr ~= "" then
                local subX = textScreenX - subW * 0.5
                utils.DrawText(hud, subStr, style.BorderColor, subX + 1.0, nextY + 1.0, style.SmallFontScale, false)
                utils.DrawText(hud, subStr, nameColor, subX, nextY, style.SmallFontScale, false)
                nextY = nextY + subH + lineGap
            end

            if distStr then
                local distX = textScreenX - distW * 0.5
                utils.DrawText(hud, distPartStr, style.BorderColor, distX + 1.0, nextY + 1.0, style.SmallFontScale, false)
                utils.DrawText(hud, distPartStr, style.DistColor, distX, nextY, style.SmallFontScale, false)
            end
        end
    end
end

-- Main entry point for drawing
function M.draw(hud, activePlayers, activeRelics, activeChests, activeEggs, activeCaves, activeLoot, activeNotes, activePals, cachedLocalPlayer, SizeX, SizeY)
    -- 1. Draw Settings Menu (always allowed, even if mod is disabled)
    menu.Draw(hud, SizeX, SizeY)
    
    -- 2. Draw Popups (always allowed)
    popup.Draw(hud, SizeX, SizeY)

    -- Unwrap screen dimensions safely
    local sx = SizeX
    if type(sx) == "userdata" or type(sx) == "table" then pcall(function() sx = sx:get() end) end
    local sy = SizeY
    if type(sy) == "userdata" or type(sy) == "table" then pcall(function() sy = sy:get() end) end

    local screenW = (type(sx) == "number" and sx > 0) and sx or 1920.0
    local screenH = (type(sy) == "number" and sy > 0) and sy or 1080.0

    -- 3. Draw Active Region Progress Tracker HUD Overlay (if enabled or edit mode active)
    if (CONFIG.Completionist and CONFIG.Completionist.Enabled and CONFIG.Completionist.ShowHUDTracker) or configMod.EditModeActive then
        pcall(function()
            local activeRegName = completion.currentRegionName or "Grasslands & Central Isles"
            local activeRegId = completion.currentRegionId or "grasslands"
            local statsMap = completion.cachedRegionStats or {}
            local regStats = statsMap[activeRegId]

            local scale = (CONFIG.Completionist and CONFIG.Completionist.HUDScale) or 1.0
            scale = math.max(0.5, math.min(2.0, scale))

            local cardW = 340.0 * scale
            local cardH = 125.0 * scale

            local maxScrollX = math.max(1.0, screenW - cardW)
            local maxScrollY = math.max(1.0, screenH - cardH)

            local cardX, cardY
            if CONFIG.Completionist and CONFIG.Completionist.HUDX then
                cardX = (CONFIG.Completionist.HUDX / 100.0) * maxScrollX
            else
                cardX = screenW - cardW - (30.0 * scale)
            end

            if CONFIG.Completionist and CONFIG.Completionist.HUDY then
                cardY = (CONFIG.Completionist.HUDY / 100.0) * maxScrollY
            else
                cardY = 40.0 * scale
            end

            -- Clamp inside screen bounds
            cardX = math.max(0.0, math.min(screenW - cardW, cardX))
            cardY = math.max(0.0, math.min(screenH - cardH, cardY))

            -- Materialize percentage coordinates if Edit Mode is active
            if configMod.EditModeActive then
                if not CONFIG.Completionist.HUDX then
                    CONFIG.Completionist.HUDX = tonumber(string.format("%.1f", (cardX / maxScrollX) * 100.0))
                end
                if not CONFIG.Completionist.HUDY then
                    CONFIG.Completionist.HUDY = tonumber(string.format("%.1f", (cardY / maxScrollY) * 100.0))
                end
            end

            -- Draw Card Background & Shadow
            hud:DrawRect(cardShadowCol, cardX - 2.0 * scale, cardY - 2.0 * scale, cardW + 4.0 * scale, cardH + 4.0 * scale)
            hud:DrawRect(cardBgCol, cardX, cardY, cardW, cardH)
            hud:DrawRect(cardBorderCol, cardX, cardY, cardW, 3.0 * scale)

            -- Header: Region Name & Progress
            local pct = regStats and regStats.percent or 0
            utils.DrawText(hud, "[>] " .. activeRegName, cardTitleCol, cardX + 15.0 * scale, cardY + 12.0 * scale, 1.0 * scale, false)
            utils.DrawText(hud, pct .. "% Completed", cardPctCol, cardX + cardW - (120.0 * scale), cardY + 12.0 * scale, 0.9 * scale, false)

            -- Progress Bar
            local barX = cardX + 15.0 * scale
            local barY = cardY + 38.0 * scale
            local barW = cardW - 30.0 * scale
            local barH = 6.0 * scale
            hud:DrawRect(cardBarBgCol, barX, barY, barW, barH)
            local fillW = math.max(0.0, math.min(barW, barW * (pct / 100.0)))
            if fillW > 0 then
                hud:DrawRect(cardBarFillCol, barX, barY, fillW, barH)
            end

            -- Stat Lines
            if regStats then
                local line1 = string.format("Effigies: %d/%d   Alphas: %d/%d", 
                    regStats.effigies.collected, regStats.effigies.total,
                    regStats.alphas.defeated, regStats.alphas.total)
                local line2 = string.format("Fast Travel: %d/%d  Towers: %d/%d  Bounties: %d/%d",
                    regStats.fastTravels.unlocked, regStats.fastTravels.total,
                    regStats.towers.defeated, regStats.towers.total,
                    regStats.bounties.cleared, regStats.bounties.total)

                utils.DrawText(hud, line1, cardTextCol, cardX + 15.0 * scale, cardY + 54.0 * scale, 0.8 * scale, false)
                utils.DrawText(hud, line2, cardTextCol, cardX + 15.0 * scale, cardY + 84.0 * scale, 0.75 * scale, false)
            end

            -- Draw Edit Mode Overlay if active
            if configMod.EditModeActive then
                local pad = 8.0 * scale
                local boxX = cardX - pad
                local boxY = cardY - pad
                local boxW = cardW + pad * 2.0
                local boxH = cardH + pad * 2.0

                hud:DrawRect(editBorderCol, boxX, boxY, boxW, boxH)
                hud:DrawRect(editBgCol, boxX + 1.5, boxY + 1.5, boxW - 3.0, boxH - 3.0)

                -- Instruction Banner
                if not cachedEditBanner1 then
                    local textLine1 = configMod.GetTranslation("EditModeActive", "EDIT MODE ACTIVE")
                    local rawEditKey = (CONFIG.Global.KeyBinds and CONFIG.Global.KeyBinds.ToggleEditMode) or "F7"
                    local rawResetKey = (CONFIG.Global.KeyBinds and CONFIG.Global.KeyBinds.ResetCoords) or "R"

                    local textLine2 = configMod.GetTranslation("EditModeInstructions", "ARROWS: MOVE | +/-: SCALE | ALT+R: RESET | ALT+F7: SAVE")
                    textLine2 = textLine2:gsub("ALT%+F7", "ALT+" .. rawEditKey)
                    textLine2 = textLine2:gsub("ALT%+R", "ALT+" .. rawResetKey)

                    cachedEditBanner1 = textLine1
                    cachedEditBanner2 = textLine2
                end

                local textLine1 = cachedEditBanner1
                local textLine2 = cachedEditBanner2

                local textScale1 = 0.65 * scale
                local textScale2 = 0.5 * scale

                local font, scaleMult = utils.GetFontAndScale()
                local textW1 = utils.GetTextSize(hud, textLine1, textScale1)
                if not textW1 or textW1 == 0 then
                    textW1 = utils.GetStringLength(textLine1) * 8.4 * textScale1 * scaleMult
                end

                local textW2 = utils.GetTextSize(hud, textLine2, textScale2)
                if not textW2 or textW2 == 0 then
                    textW2 = utils.GetStringLength(textLine2) * 8.4 * textScale2 * scaleMult
                end

                local bannerW = math.max(textW1, textW2) + 24.0 * scale
                local bannerH = 44.0 * scale
                local bannerX = cardX + (cardW / 2.0) - (bannerW / 2.0)
                
                local bannerY = (cardY > bannerH + 12.0 * scale) and (cardY - bannerH - 10.0 * scale) or (cardY + cardH + 10.0 * scale)

                hud:DrawRect(editBorderCol, bannerX, bannerY, bannerW, bannerH)
                hud:DrawRect(bannerBgCol, bannerX + 1.5, bannerY + 1.5, bannerW - 3.0, bannerH - 3.0)

                utils.DrawText(hud, textLine1, editBannerTextCol1, bannerX + (bannerW / 2.0) - (textW1 / 2.0), bannerY + 6.0 * scale, textScale1, false)
                utils.DrawText(hud, textLine2, editBannerTextCol2, bannerX + (bannerW / 2.0) - (textW2 / 2.0), bannerY + bannerH - 18.0 * scale, textScale2, false)
            else
                cachedEditBanner1 = nil
                cachedEditBanner2 = nil
            end
        end)
    end

    -- 4. Draw Full Completionist List Modal (if toggled open in menu)
    if menu.isCompletionistViewOpen then
        pcall(function()
            local modalW = 540.0
            local modalH = 600.0
            local modalX = screenW - modalW - 40.0
            local modalY = (screenH / 2.0) - (modalH / 2.0)

            -- Draw Panel Shadow & Base
            hud:DrawRect(modalShadowCol, modalX - 2.0, modalY - 2.0, modalW + 4.0, modalH + 4.0)
            hud:DrawRect(modalBgCol, modalX, modalY, modalW, modalH)
            hud:DrawRect(modalBorderCol, modalX, modalY, modalW, 4.0)

            -- Header Title & Subtitle
            utils.DrawText(hud, "REGIONAL COMPLETIONIST LIST", modalHeaderCol, modalX + 20.0, modalY + 16.0, 1.25, false)
            local globPct = completion.globalSaveProgress and completion.globalSaveProgress.overallPercent or 0
            utils.DrawText(hud, "Global Save Progress: " .. globPct .. "%", { R = 0.0, G = 0.96, B = 0.83, A = 1.0 }, modalX + modalW - 200.0, modalY + 18.0, 0.9, false)

            -- Separator Line
            hud:DrawRect(modalSepCol, modalX + 20.0, modalY + 48.0, modalW - 40.0, 1.0)

            -- Render List of Regions
            local startY = modalY + 60.0
            local cardH = 70.0
            local gapY = 6.0

            for idx, reg in ipairs(completion.Regions) do
                local rY = startY + (idx - 1) * (cardH + gapY)
                local stats = completion.cachedRegionStats and completion.cachedRegionStats[reg.id]
                local isCurr = (reg.id == completion.currentRegionId)

                local rBg = isCurr and modalCurrBgCol or modalNormalBgCol
                local rBorder = isCurr and modalCurrBorderCol or modalNormalBorderCol

                hud:DrawRect(rBg, modalX + 20.0, rY, modalW - 40.0, cardH)
                hud:DrawRect(rBorder, modalX + 20.0, rY, 3.0, cardH)

                -- Region Title & Current Location Badge
                local titleStr = (reg.icon or "") .. " " .. reg.name
                if isCurr then titleStr = titleStr .. "  [CURRENT LOCATION]" end
                local tCol = isCurr and modalCurrTextCol or modalNormalTextCol
                utils.DrawText(hud, titleStr, tCol, modalX + 30.0, rY + 8.0, 0.95, false)

                local regPct = stats and stats.percent or 0
                utils.DrawText(hud, regPct .. "%", { R = 0.0, G = 0.96, B = 0.83, A = 1.0 }, modalX + modalW - 75.0, rY + 8.0, 0.9, false)

                -- Details Line: Effigies, Alphas, Fast Travels, Watch Towers, Bounties
                if stats then
                    local detStr = string.format("Effigies: %d/%d   Alphas: %d/%d   Fast Travel: %d/%d",
                        stats.effigies.collected, stats.effigies.total,
                        stats.alphas.defeated, stats.alphas.total,
                        stats.fastTravels.unlocked, stats.fastTravels.total)
                    local detStr2 = string.format("Watch Towers: %d/%d   Bounties: %d/%d",
                        stats.towers.defeated, stats.towers.total,
                        stats.bounties.cleared, stats.bounties.total)

                    utils.DrawText(hud, detStr, modalDetTextCol, modalX + 30.0, rY + 30.0, 0.72, false)
                    utils.DrawText(hud, detStr2, modalDetTextCol, modalX + 30.0, rY + 48.0, 0.72, false)
                end
            end
        end)
    end

    -- 5. Draw 3D World Markers
    if not CONFIG.Global.Enabled then return end

    drawnBoxCount = 0

    -- Early return if no active items exist to draw across all categories
    local totalActiveCount = #activePlayers + #activeRelics + #activeChests + #activeEggs + #activeCaves + #activeLoot + #activeNotes + (activePals and #activePals or 0)
    if totalActiveCount == 0 then return end
    
    if not cachedLocalPlayer or not cachedLocalPlayer:IsValid() then return end
    local uePlayerPos = cachedLocalPlayer:K2_GetActorLocation()
    if not uePlayerPos then return end
    playerPosBuffer.X = uePlayerPos.X
    playerPosBuffer.Y = uePlayerPos.Y
    playerPosBuffer.Z = uePlayerPos.Z

    -- 1. Draw Players
    if CONFIG.Players.Enabled then
        local graceRadiusUEUnits = CONFIG.Players.GraceRadiusM * 100.0
        local graceRadiusSq = graceRadiusUEUnits * graceRadiusUEUnits
        for _, otherPlayer in ipairs(activePlayers) do
            local dx = otherPlayer.Pos.X - playerPosBuffer.X
            local dy = otherPlayer.Pos.Y - playerPosBuffer.Y
            local dz = otherPlayer.Pos.Z - playerPosBuffer.Z
            local distSq = dx*dx + dy*dy + dz*dz
            
            if distSq > graceRadiusSq then
                local labelStr = otherPlayer.LabelStr
                if not labelStr then
                    labelStr = "@ " .. otherPlayer.Name
                    otherPlayer.LabelStr = labelStr
                end

                if not otherPlayer.distSqUpper or distSq < otherPlayer.distSqLower or distSq >= otherPlayer.distSqUpper then
                    local dist = math.sqrt(distSq)
                    local distMeters = math.floor(dist / 100.0)

                    otherPlayer.distSqLower = (distMeters * 100.0) * (distMeters * 100.0)
                    otherPlayer.distSqUpper = ((distMeters + 1) * 100.0) * ((distMeters + 1) * 100.0)

                    if otherPlayer.lastDistMeters ~= distMeters then
                        otherPlayer.lastDistMeters = distMeters
                        local mStr = distMeters .. "m"
                        otherPlayer.cachedDistStr = mStr
                        otherPlayer.cachedBracketStr = "[" .. mStr .. "]"
                    end
                end

                DrawTrackerLabel(hud, otherPlayer.Pos, labelStr, otherPlayer.cachedDistStr, CONFIG.Players.Style, screenW, screenH, nil, nil, otherPlayer.cachedBracketStr)
            end
        end
    end

    -- 2. Draw Relics
    if CONFIG.Relics.Enabled then
        for _, pos in ipairs(activeRelics) do
            local name = pos.Name or "Relic"
            DrawTrackerLabel(hud, pos, name, pos.DistStr, CONFIG.Relics.Style, screenW, screenH, nil, nil, pos.BracketDistStr)
        end
    end

    -- 3. Draw Chests
    if CONFIG.Chests.Enabled then
        for _, pos in ipairs(activeChests) do
            local name = pos.Name or "Chest"
            DrawTrackerLabel(hud, pos, name, pos.DistStr, CONFIG.Chests.Style, screenW, screenH, nil, nil, pos.BracketDistStr)
        end
    end

    -- 4. Draw Eggs
    if CONFIG.Eggs.Filter ~= "None" then
        for _, pos in ipairs(activeEggs) do
            local name = pos.FullName or pos.Name or "Egg"
            DrawTrackerLabel(hud, pos, name, pos.DistStr, CONFIG.Eggs.Style, screenW, screenH, nil, nil, pos.BracketDistStr)
        end
    end

    -- 5. Draw Caves
    if CONFIG.Caves.Enabled then
        for _, pos in ipairs(activeCaves) do
            if pos.ShowBeacon then
                DrawCaveBeacon(hud, pos, CONFIG.Caves.Style.NameColor or { R = 0.5, G = 0.0, B = 1.0, A = 1.0 })
            end
            local name = pos.Name or "Cave"
            DrawTrackerLabel(hud, pos, name, pos.DistStr, CONFIG.Caves.Style, screenW, screenH, nil, nil, pos.BracketDistStr)
        end
    end

    -- 6. Draw Loot
    if CONFIG.Loot.Enabled then
        for _, pos in ipairs(activeLoot) do
            local name = pos.Name or "Loot"
            DrawTrackerLabel(hud, pos, name, pos.DistStr, CONFIG.Loot.Style, screenW, screenH, nil, nil, pos.BracketDistStr)
        end
    end

    -- 7. Draw Notes
    if CONFIG.Notes.Enabled then
        for _, pos in ipairs(activeNotes) do
            local name = pos.Name or "Note"
            DrawTrackerLabel(hud, pos, name, pos.DistStr, CONFIG.Notes.Style, screenW, screenH, nil, nil, pos.BracketDistStr)
        end
    end

    -- 8. Draw Pals
    if CONFIG.Pals and CONFIG.Pals.Enabled and activePals then
        for _, pal in ipairs(activePals) do
            local drawPos = pal
            local distStr = pal.DistStr
            local bracketDistStr = pal.BracketDistStr

            local actor = pal.Actor
            if actor and actor:IsValid() then
                local isDestroyed = false
                local okD, resD = pcall(actor.IsActorBeingDestroyed, actor)
                if okD then isDestroyed = resD end

                local isHidden = false
                if not isDestroyed then
                    local okH, resH = pcall(function() return actor.bHidden or (actor.IsHidden and actor:IsHidden()) end)
                    if okH and resH then isHidden = true end
                end

                if not isDestroyed and not isHidden then
                    local okLoc, liveLoc = pcall(actor.K2_GetActorLocation, actor)
                    if okLoc and liveLoc then
                        drawPos = liveLoc
                        local dx = liveLoc.X - playerPosBuffer.X
                        local dy = liveLoc.Y - playerPosBuffer.Y
                        local dz = liveLoc.Z - playerPosBuffer.Z
                        local distSq = dx*dx + dy*dy + dz*dz
                        if not pal.liveDistSqUpper or distSq < pal.liveDistSqLower or distSq >= pal.liveDistSqUpper then
                            local mInt = math.floor(math.sqrt(distSq) / 100.0)

                            pal.liveDistSqLower = (mInt * 100.0) * (mInt * 100.0)
                            pal.liveDistSqUpper = ((mInt + 1) * 100.0) * ((mInt + 1) * 100.0)

                            if pal.lastLiveMeters ~= mInt then
                                pal.lastLiveMeters = mInt
                                local mStr = mInt .. "m"
                                pal.cachedLiveDistStr = mStr
                                pal.cachedLiveBracketStr = "[" .. mStr .. "]"
                            end
                        end

                        distStr = pal.cachedLiveDistStr
                        bracketDistStr = pal.cachedLiveBracketStr
                    end
                else
                    drawPos = nil
                end
            end

            if drawPos then
                local colorOverride = nil
                if pal.IsShiny and CONFIG.Pals.Style and CONFIG.Pals.Style.ShinyColor then
                    colorOverride = CONFIG.Pals.Style.ShinyColor
                elseif pal.IsBoss and CONFIG.Pals.Style and CONFIG.Pals.Style.BossColor then
                    colorOverride = CONFIG.Pals.Style.BossColor
                end

                local subStr = pal.PassivesStr
                DrawTrackerLabel(hud, drawPos, pal.Name, distStr, CONFIG.Pals.Style, screenW, screenH, subStr, colorOverride, bracketDistStr, pal.Passives)
            end
        end
    end
end

return M
