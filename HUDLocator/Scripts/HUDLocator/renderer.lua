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

    -- Unwrap screen dimensions safely
    local sx = SizeX
    if type(sx) == "userdata" or type(sx) == "table" then pcall(function() sx = sx:get() end) end
    local sy = SizeY
    if type(sy) == "userdata" or type(sy) == "table" then pcall(function() sy = sy:get() end) end

    local screenW = (type(sx) == "number" and sx > 0) and sx or 1920.0
    local screenH = (type(sy) == "number" and sy > 0) and sy or 1080.0

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

            if pal.Actor and pal.Actor:IsValid() then
                local isDestroyed = false
                pcall(function() isDestroyed = pal.Actor:IsActorBeingDestroyed() end)
                local isHidden = false
                pcall(function() isHidden = pal.Actor.bHidden or (pal.Actor.IsHidden and pal.Actor:IsHidden()) end)

                if not isDestroyed and not isHidden then
                    local liveLoc = nil
                    pcall(function() liveLoc = pal.Actor:K2_GetActorLocation() end)
                    if liveLoc then
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

    -- 9. Draw Active Region Progress Tracker HUD Overlay (if enabled)
    if CONFIG.Completionist and CONFIG.Completionist.Enabled and CONFIG.Completionist.ShowHUDTracker then
        pcall(function()
            local activeRegName = completion.currentRegionName or "Grasslands & Central Isles"
            local activeRegId = completion.currentRegionId or "grasslands"
            local statsMap = completion.cachedRegionStats or {}
            local regStats = statsMap[activeRegId]

            local cardW = 340.0
            local cardH = 125.0
            local cardX = screenW - cardW - 30.0
            local cardY = 40.0

            local bgCol = { R = 0.05, G = 0.07, B = 0.15, A = 0.85 }
            local borderCol = { R = 0.0, G = 0.95, B = 1.0, A = 0.6 }
            local shadowCol = { R = 0.0, G = 0.0, B = 0.0, A = 0.9 }
            local titleCol = { R = 0.0, G = 0.95, B = 1.0, A = 1.0 }
            local textCol = { R = 0.9, G = 0.9, B = 0.95, A = 1.0 }

            -- Draw Card Background & Shadow
            hud:DrawRect(shadowCol, cardX - 2.0, cardY - 2.0, cardW + 4.0, cardH + 4.0)
            hud:DrawRect(bgCol, cardX, cardY, cardW, cardH)
            hud:DrawRect(borderCol, cardX, cardY, cardW, 3.0)

            -- Header: Region Name & Progress
            local pct = regStats and regStats.percent or 0
            utils.DrawText(hud, "📍 " .. activeRegName, titleCol, cardX + 15.0, cardY + 12.0, 1.0, false)
            utils.DrawText(hud, pct .. "% Completed", { R = 0.0, G = 0.96, B = 0.83, A = 1.0 }, cardX + cardW - 120.0, cardY + 12.0, 0.9, false)

            -- Progress Bar
            local barX = cardX + 15.0
            local barY = cardY + 38.0
            local barW = cardW - 30.0
            local barH = 6.0
            hud:DrawRect({ R = 0.15, G = 0.15, B = 0.25, A = 0.8 }, barX, barY, barW, barH)
            local fillW = math.max(0.0, math.min(barW, barW * (pct / 100.0)))
            if fillW > 0 then
                hud:DrawRect({ R = 0.0, G = 0.96, B = 0.83, A = 0.9 }, barX, barY, fillW, barH)
            end

            -- Stat Lines
            if regStats then
                local line1 = string.format("🗿 Effigies: %d/%d   👹 Alphas: %d/%d", 
                    regStats.effigies.collected, regStats.effigies.total,
                    regStats.alphas.defeated, regStats.alphas.total)
                local line2 = string.format("🦅 Fast Travel: %d/%d  🏰 Towers: %d/%d  🎯 Bounties: %d/%d",
                    regStats.fastTravels.unlocked, regStats.fastTravels.total,
                    regStats.towers.defeated, regStats.towers.total,
                    regStats.bounties.cleared, regStats.bounties.total)

                utils.DrawText(hud, line1, textCol, cardX + 15.0, cardY + 54.0, 0.8, false)
                utils.DrawText(hud, line2, textCol, cardX + 15.0, cardY + 84.0, 0.75, false)
            end
        end)
    end

    -- 10. Draw Full Completionist List Modal (if toggled open in menu)
    if menu.isCompletionistViewOpen then
        pcall(function()
            local modalW = 540.0
            local modalH = 600.0
            local modalX = screenW - modalW - 40.0
            local modalY = (screenH / 2.0) - (modalH / 2.0)

            local bgCol = { R = 0.04, G = 0.06, B = 0.12, A = 0.92 }
            local borderCol = { R = 0.0, G = 0.95, B = 1.0, A = 0.8 }
            local shadowCol = { R = 0.0, G = 0.0, B = 0.0, A = 0.95 }
            local headerCol = { R = 0.0, G = 0.95, B = 1.0, A = 1.0 }

            -- Draw Panel Shadow & Base
            hud:DrawRect(shadowCol, modalX - 2.0, modalY - 2.0, modalW + 4.0, modalH + 4.0)
            hud:DrawRect(bgCol, modalX, modalY, modalW, modalH)
            hud:DrawRect(borderCol, modalX, modalY, modalW, 4.0)

            -- Header Title & Subtitle
            utils.DrawText(hud, "🏆 REGIONAL COMPLETIONIST LIST", headerCol, modalX + 20.0, modalY + 16.0, 1.25, false)
            local globPct = completion.globalSaveProgress and completion.globalSaveProgress.overallPercent or 0
            utils.DrawText(hud, "Global Save Progress: " .. globPct .. "%", { R = 0.0, G = 0.96, B = 0.83, A = 1.0 }, modalX + modalW - 200.0, modalY + 18.0, 0.9, false)

            -- Separator Line
            hud:DrawRect({ R = 0.2, G = 0.25, B = 0.35, A = 0.5 }, modalX + 20.0, modalY + 48.0, modalW - 40.0, 1.0)

            -- Render List of Regions
            local startY = modalY + 60.0
            local cardH = 70.0
            local gapY = 6.0

            for idx, reg in ipairs(completion.Regions) do
                local rY = startY + (idx - 1) * (cardH + gapY)
                local stats = completion.cachedRegionStats and completion.cachedRegionStats[reg.id]
                local isCurr = (reg.id == completion.currentRegionId)

                local rBg = isCurr and { R = 0.0, G = 0.3, B = 0.4, A = 0.35 } or { R = 0.08, G = 0.1, B = 0.18, A = 0.6 }
                local rBorder = isCurr and { R = 0.0, G = 0.96, B = 0.83, A = 0.9 } or { R = 0.2, G = 0.2, B = 0.3, A = 0.4 }

                hud:DrawRect(rBg, modalX + 20.0, rY, modalW - 40.0, cardH)
                hud:DrawRect(rBorder, modalX + 20.0, rY, 3.0, cardH)

                -- Region Title & Current Location Badge
                local titleStr = (reg.icon or "") .. " " .. reg.name
                if isCurr then titleStr = titleStr .. "  [CURRENT LOCATION]" end
                local tCol = isCurr and { R = 0.0, G = 0.96, B = 0.83, A = 1.0 } or { R = 0.95, G = 0.95, B = 1.0, A = 1.0 }
                utils.DrawText(hud, titleStr, tCol, modalX + 30.0, rY + 8.0, 0.95, false)

                local regPct = stats and stats.percent or 0
                utils.DrawText(hud, regPct .. "%", { R = 0.0, G = 0.96, B = 0.83, A = 1.0 }, modalX + modalW - 75.0, rY + 8.0, 0.9, false)

                -- Details Line: Effigies, Alphas, Fast Travels, Watch Towers, Bounties
                if stats then
                    local detStr = string.format("🗿 Effigies: %d/%d   👹 Alphas: %d/%d   🦅 Fast Travel: %d/%d",
                        stats.effigies.collected, stats.effigies.total,
                        stats.alphas.defeated, stats.alphas.total,
                        stats.fastTravels.unlocked, stats.fastTravels.total)
                    local detStr2 = string.format("🏰 Watch Towers: %d/%d   🎯 Bounties: %d/%d",
                        stats.towers.defeated, stats.towers.total,
                        stats.bounties.cleared, stats.bounties.total)

                    utils.DrawText(hud, detStr, { R = 0.8, G = 0.85, B = 0.9, A = 1.0 }, modalX + 30.0, rY + 30.0, 0.72, false)
                    utils.DrawText(hud, detStr2, { R = 0.8, G = 0.85, B = 0.9, A = 1.0 }, modalX + 30.0, rY + 48.0, 0.72, false)
                end
            end
        end)
    end
end

return M
