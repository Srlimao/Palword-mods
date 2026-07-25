local configMod = require("HUDLocator.config")
local popup = require("HUDLocator.popup")
local menu = require("HUDLocator.menu")
local utils = require("HUDLocator.utils")
local CONFIG = configMod.CONFIG

local M = {}

-- Pre-allocated static table buffers to prevent GC allocations during ReceiveDrawHUD frame ticks
local playerPosBuffer = { X = 0.0, Y = 0.0, Z = 0.0 }
local textWorldPosBuffer = { X = 0.0, Y = 0.0, Z = 0.0 }
local beaconBaseWorldBuffer = { X = 0.0, Y = 0.0, Z = 0.0 }
local beaconTopWorldBuffer = { X = 0.0, Y = 0.0, Z = 0.0 }
local beaconColorBuffer = { R = 0.0, G = 0.0, B = 0.0, A = 1.0 }

-- Render a 3D glowing beam and ground flare at the location
local function DrawCaveBeacon(hud, pos, color)
    beaconBaseWorldBuffer.X = pos.X; beaconBaseWorldBuffer.Y = pos.Y; beaconBaseWorldBuffer.Z = pos.Z
    beaconTopWorldBuffer.X = pos.X; beaconTopWorldBuffer.Y = pos.Y; beaconTopWorldBuffer.Z = pos.Z + 1500.0 -- 15 meters tall
    
    local ueScreenBase = hud:Project(beaconBaseWorldBuffer, false)
    local ueScreenTop = hud:Project(beaconTopWorldBuffer, false)

    -- Optimize: Convert UE FVector to native Lua table to avoid thousands of C++ property reflection lookups during distance checks
    local screenBaseX, screenBaseY, screenBaseZ = ueScreenBase.X, ueScreenBase.Y, ueScreenBase.Z
    local screenTopX, screenTopY, screenTopZ = ueScreenTop.X, ueScreenTop.Y, ueScreenTop.Z
    
    if screenBaseZ > 0.0 or screenTopZ > 0.0 then
        beaconColorBuffer.R = color.R; beaconColorBuffer.G = color.G; beaconColorBuffer.B = color.B
        
        beaconColorBuffer.A = 0.05
        pcall(hud.DrawLine, hud, screenBaseX, screenBaseY, screenTopX, screenTopY, beaconColorBuffer, 16.0)
        beaconColorBuffer.A = 0.12
        pcall(hud.DrawLine, hud, screenBaseX, screenBaseY, screenTopX, screenTopY, beaconColorBuffer, 8.0)
        
        beaconColorBuffer.R = 1.0; beaconColorBuffer.G = 1.0; beaconColorBuffer.B = 1.0; beaconColorBuffer.A = 0.35
        pcall(hud.DrawLine, hud, screenBaseX, screenBaseY, screenTopX, screenTopY, beaconColorBuffer, 2.0)
        
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
local function DrawTrackerLabel(hud, worldPos, nameStr, distStr, style, screenW, screenH)
    textWorldPosBuffer.X = worldPos.X
    textWorldPosBuffer.Y = worldPos.Y
    textWorldPosBuffer.Z = worldPos.Z + style.TextOffsetZ
    local ueTextScreen = hud:Project(textWorldPosBuffer, false)
    
    local textScreenX = ueTextScreen.X
    local textScreenY = ueTextScreen.Y
    local textScreenZ = ueTextScreen.Z
    
    -- Screen Viewport Bounds Culling: Only render text for items visible on the screen
    local margin = 100.0
    local isVisibleOnScreen = (textScreenZ > 0.0) 
                          and (textScreenX >= -margin) and (textScreenX <= screenW + margin) 
                          and (textScreenY >= -margin) and (textScreenY <= screenH + margin)
    
    if isVisibleOnScreen then
        local font, scaleMult = utils.GetFontAndScale()
        local fontScale = style.FontScale * scaleMult
        local smallFontScale = style.SmallFontScale * scaleMult
        
        local charW = style.FontCharW
        local lineH = style.FontLineH
        if font then
            charW = charW * 1.6
            lineH = lineH * 2.8
        end

        if style.DrawBox then
            local nameW = utils.GetTextSize(hud, nameStr, style.FontScale)
            if not nameW or nameW == 0 then
                nameW = utils.GetStringLength(nameStr) * charW * fontScale
            end
            
            local distW = 0
            if distStr then
                distW = utils.GetTextSize(hud, distStr, style.SmallFontScale)
                if not distW or distW == 0 then
                    distW = utils.GetStringLength(distStr) * charW * smallFontScale
                end
            end
            
            local nameH  = lineH * fontScale
            local distH  = distStr and (lineH * smallFontScale) or 0
            local lineGap = font and 6.0 or 4.0
            local bw     = style.BorderWidth
            
            local padX = style.BoxPadX
            local padY = style.BoxPadY
            if font then
                padX = padX + 4.0
                padY = padY + 2.0
            end
            
            local contentW = math.max(nameW, distW)
            local contentH = nameH + (distStr and (lineGap + distH) or 0)
            local boxW = contentW + padX * 2
            local boxH = contentH + padY * 2
            
            local boxX = textScreenX - boxW * 0.5
            local boxY = textScreenY - boxH * 0.5
 
            -- Draw border
            hud:DrawRect(style.BorderColor, boxX - bw, boxY - bw, boxW + bw * 2, boxH + bw * 2)
 
            -- Draw background fill box
            hud:DrawRect(style.BoxColor, boxX, boxY, boxW, boxH)
            
            local nameX = textScreenX - nameW * 0.5
            local nameY = boxY + padY
            
            utils.DrawText(hud, nameStr, style.NameColor, nameX, nameY, style.FontScale, false)
            
            if distStr then
                local distX = textScreenX - distW * 0.5
                local distY = nameY + nameH + lineGap
                utils.DrawText(hud, distStr, style.DistColor, distX, distY, style.SmallFontScale, false)
            end
        else
            -- Simple text format: Name \n [Distance]
            local nameW = utils.GetTextSize(hud, nameStr, style.FontScale)
            if not nameW or nameW == 0 then
                nameW = utils.GetStringLength(nameStr) * charW * fontScale
            end
            
            local distPartStr = distStr and ("[" .. distStr .. "]") or ""
            local distPartW = 0
            if distStr then
                distPartW = utils.GetTextSize(hud, distPartStr, style.SmallFontScale)
                if not distPartW or distPartW == 0 then
                    distPartW = utils.GetStringLength(distPartStr) * charW * smallFontScale
                end
            end
            
            local nameH = lineH * fontScale
            local distH = distStr and (lineH * smallFontScale) or 0
            local lineGap = font and 6.0 or 4.0
            
            local contentH = nameH + (distStr and (lineGap + distH) or 0)
            
            local startX = textScreenX - nameW * 0.5
            local simpleY = textScreenY - contentH * 0.5
            
            -- High-Performance Drop Shadow (1 offset pass instead of 4 outline passes to cut C++ reflection calls in half)
            utils.DrawText(hud, nameStr, style.BorderColor, startX + 1.0, simpleY + 1.0, style.FontScale, false)
            utils.DrawText(hud, nameStr, style.NameColor, startX, simpleY, style.FontScale, false)
            
            if distStr then
                local distX = textScreenX - distPartW * 0.5
                local distY = simpleY + nameH + lineGap
                utils.DrawText(hud, distPartStr, style.BorderColor, distX + 1.0, distY + 1.0, style.SmallFontScale, false)
                utils.DrawText(hud, distPartStr, style.DistColor, distX, distY, style.SmallFontScale, false)
            end
        end
    end
end

-- Main entry point for drawing
function M.draw(hud, activePlayers, activeRelics, activeChests, activeEggs, activeCaves, activeLoot, activeNotes, cachedLocalPlayer, SizeX, SizeY)
    -- 1. Draw Settings Menu (always allowed, even if mod is disabled)
    menu.Draw(hud, SizeX, SizeY)
    
    -- 2. Draw Popups (always allowed)
    popup.Draw(hud, SizeX, SizeY)

    if not CONFIG.Global.Enabled then return end

    -- Early return if no active items exist to draw across all categories
    local totalActiveCount = #activePlayers + #activeRelics + #activeChests + #activeEggs + #activeCaves + #activeLoot + #activeNotes
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
        for _, otherPlayer in ipairs(activePlayers) do
            local dx = otherPlayer.Pos.X - playerPosBuffer.X
            local dy = otherPlayer.Pos.Y - playerPosBuffer.Y
            local dz = otherPlayer.Pos.Z - playerPosBuffer.Z
            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
            local distMeters = math.floor(dist / 100.0)
            
            if distMeters > CONFIG.Players.GraceRadiusM then
                local labelStr = otherPlayer.LabelStr
                if not labelStr then
                    labelStr = "@ " .. otherPlayer.Name
                    otherPlayer.LabelStr = labelStr
                end
                local distStr = distMeters .. "m"
                DrawTrackerLabel(hud, otherPlayer.Pos, labelStr, distStr, CONFIG.Players.Style, screenW, screenH)
            end
        end
    end

    -- 2. Draw Relics
    if CONFIG.Relics.Enabled then
        for _, pos in ipairs(activeRelics) do
            local name = pos.Name or "Relic"
            DrawTrackerLabel(hud, pos, name, pos.DistStr, CONFIG.Relics.Style, screenW, screenH)
        end
    end

    -- 3. Draw Chests
    if CONFIG.Chests.Enabled then
        for _, pos in ipairs(activeChests) do
            local name = pos.Name or "Chest"
            DrawTrackerLabel(hud, pos, name, pos.DistStr, CONFIG.Chests.Style, screenW, screenH)
        end
    end

    -- 4. Draw Eggs
    if CONFIG.Eggs.Filter ~= "None" then
        for _, pos in ipairs(activeEggs) do
            local name = pos.FullName or pos.Name or "Egg"
            DrawTrackerLabel(hud, pos, name, pos.DistStr, CONFIG.Eggs.Style, screenW, screenH)
        end
    end

    -- 5. Draw Caves
    if CONFIG.Caves.Enabled then
        for _, pos in ipairs(activeCaves) do
            if pos.ShowBeacon then
                DrawCaveBeacon(hud, pos, CONFIG.Caves.Style.NameColor or { R = 0.5, G = 0.0, B = 1.0, A = 1.0 })
            end
            local name = pos.Name or "Cave"
            DrawTrackerLabel(hud, pos, name, pos.DistStr, CONFIG.Caves.Style, screenW, screenH)
        end
    end

    -- 6. Draw Loot
    if CONFIG.Loot.Enabled then
        for _, pos in ipairs(activeLoot) do
            local name = pos.Name or "Loot"
            DrawTrackerLabel(hud, pos, name, pos.DistStr, CONFIG.Loot.Style, screenW, screenH)
        end
    end

    -- 7. Draw Notes
    if CONFIG.Notes.Enabled then
        for _, pos in ipairs(activeNotes) do
            local name = pos.Name or "Note"
            DrawTrackerLabel(hud, pos, name, pos.DistStr, CONFIG.Notes.Style, screenW, screenH)
        end
    end
end

return M
