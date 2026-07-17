local configMod = require("HUDLocator.config")
local popup = require("HUDLocator.popup")
local menu = require("HUDLocator.menu")
local CONFIG = configMod.CONFIG

local M = {}

-- Render a 3D glowing beam and ground flare at the location
local function DrawCaveBeacon(hud, pos, color)
    local baseWorld = { X = pos.X, Y = pos.Y, Z = pos.Z }
    local topWorld = { X = pos.X, Y = pos.Y, Z = pos.Z + 1500.0 } -- 15 meters tall
    
    local screenBase = hud:Project(baseWorld, false)
    local screenTop = hud:Project(topWorld, false)
    
    if screenBase.Z > 0.0 or screenTop.Z > 0.0 then
        -- Draw glowing cylinder beam using thick Canvas DrawLine calls
        pcall(hud.DrawLine, hud, screenBase.X, screenBase.Y, screenTop.X, screenTop.Y, { R = color.R, G = color.G, B = color.B, A = 0.05 }, 16.0)
        pcall(hud.DrawLine, hud, screenBase.X, screenBase.Y, screenTop.X, screenTop.Y, { R = color.R, G = color.G, B = color.B, A = 0.12 }, 8.0)
        pcall(hud.DrawLine, hud, screenBase.X, screenBase.Y, screenTop.X, screenTop.Y, { R = 1.0, G = 1.0, B = 1.0, A = 0.35 }, 2.0)
        
        -- Draw concentric squares for glowing ground flare
        local steps = 5
        local baseSize = 24.0
        for i = 1, steps do
            local size = baseSize * (1.0 + (i - 1) * 0.6)
            local alpha = 0.15 * (1.0 - (i - 1) / steps)
            hud:DrawRect({ R = color.R, G = color.G, B = color.B, A = alpha }, screenBase.X - size/2, screenBase.Y - size/2, size, size)
        end
    end
end

-- Render tracker label (either box style or simple text style)
local function DrawTrackerLabel(hud, worldPos, nameStr, distStr, style)
    local textWorldPos = { X = worldPos.X, Y = worldPos.Y, Z = worldPos.Z + style.TextOffsetZ }
    local textScreen = hud:Project(textWorldPos, false)
    
    if textScreen.Z > 0.0 then
        if style.DrawBox then
            local nameW  = #nameStr * style.FontCharW * style.FontScale
            local distW  = distStr and (#distStr * style.FontCharW * style.SmallFontScale) or 0
            local nameH  = style.FontLineH * style.FontScale
            local distH  = distStr and (style.FontLineH * style.SmallFontScale) or 0
            local lineGap = 4.0
            local bw     = style.BorderWidth
            
            local contentW = math.max(nameW, distW)
            local contentH = nameH + (distStr and (lineGap + distH) or 0)
            local boxW = contentW + style.BoxPadX * 2
            local boxH = contentH + style.BoxPadY * 2
            
            local boxX = textScreen.X - boxW * 0.5
            local boxY = textScreen.Y - boxH * 0.5
 
            -- Draw border
            hud:DrawRect(style.BorderColor, boxX - bw, boxY - bw, boxW + bw * 2, boxH + bw * 2)
 
            -- Draw background fill box
            hud:DrawRect(style.BoxColor, boxX, boxY, boxW, boxH)
            
            local nameX = textScreen.X - nameW * 0.5
            local nameY = boxY + style.BoxPadY
            
            hud:DrawText(nameStr, style.NameColor, nameX, nameY, nil, style.FontScale, false)
            
            if distStr then
                local distX = textScreen.X - distW * 0.5
                local distY = nameY + nameH + lineGap
                hud:DrawText(distStr, style.DistColor, distX, distY, nil, style.SmallFontScale, false)
            end
        else
            -- Simple text format: Name [Distance]
            local nameW = #nameStr * style.FontCharW * style.FontScale
            local distPartStr = distStr and (" [" .. distStr .. "]") or ""
            local distPartW = distStr and (#distPartStr * style.FontCharW * style.FontScale) or 0
            
            local totalW = nameW + distPartW
            local simpleH = style.FontLineH * style.FontScale
            
            local startX = textScreen.X - totalW * 0.5
            local simpleY = textScreen.Y - simpleH * 0.5
            local off = 1.0
            
            -- Draw Name Part Outline
            hud:DrawText(nameStr, style.BorderColor, startX - off, simpleY - off, nil, style.FontScale, false)
            hud:DrawText(nameStr, style.BorderColor, startX + off, simpleY - off, nil, style.FontScale, false)
            hud:DrawText(nameStr, style.BorderColor, startX - off, simpleY + off, nil, style.FontScale, false)
            hud:DrawText(nameStr, style.BorderColor, startX + off, simpleY + off, nil, style.FontScale, false)
            -- Draw Name Part Main Text
            hud:DrawText(nameStr, style.NameColor, startX, simpleY, nil, style.FontScale, false)
            
            if distStr then
                local distX = startX + nameW
                -- Draw Dist Part Outline
                hud:DrawText(distPartStr, style.BorderColor, distX - off, simpleY - off, nil, style.FontScale, false)
                hud:DrawText(distPartStr, style.BorderColor, distX + off, simpleY - off, nil, style.FontScale, false)
                hud:DrawText(distPartStr, style.BorderColor, distX - off, simpleY + off, nil, style.FontScale, false)
                hud:DrawText(distPartStr, style.BorderColor, distX + off, simpleY + off, nil, style.FontScale, false)
                -- Draw Dist Part Main Text
                hud:DrawText(distPartStr, style.DistColor, distX, simpleY, nil, style.FontScale, false)
            end
        end
    end
end

-- Main entry point for drawing
function M.draw(hud, activePlayers, activeRelics, activeChests, activeEggs, activeCaves, cachedLocalPlayer, SizeX, SizeY)
    -- 1. Draw Settings Menu (always allowed, even if mod is disabled)
    menu.Draw(hud, SizeX, SizeY)
    
    -- 2. Draw Popups (always allowed)
    popup.Draw(hud, SizeX, SizeY)

    if not CONFIG.Global.Enabled then return end
    
    if not cachedLocalPlayer or not cachedLocalPlayer:IsValid() then return end
    local playerPos = cachedLocalPlayer:K2_GetActorLocation()
    if not playerPos then return end

    -- 1. Draw Players
    if CONFIG.Players.Enabled then
        for _, otherPlayer in ipairs(activePlayers) do
            local dx = otherPlayer.Pos.X - playerPos.X
            local dy = otherPlayer.Pos.Y - playerPos.Y
            local dz = otherPlayer.Pos.Z - playerPos.Z
            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
            local distMeters = math.floor(dist / 100.0)
            
            if distMeters > CONFIG.Players.GraceRadiusM then
                local iconStr = "@ "
                local labelStr = iconStr .. otherPlayer.Name
                local distStr = distMeters .. "m"
                DrawTrackerLabel(hud, otherPlayer.Pos, labelStr, distStr, CONFIG.Players.Style)
            end
        end
    end

    -- 2. Draw Relics
    if CONFIG.Relics.Enabled then
        for _, pos in ipairs(activeRelics) do
            local dx = pos.X - playerPos.X
            local dy = pos.Y - playerPos.Y
            local dz = pos.Z - playerPos.Z
            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
            local distMeters = math.floor(dist / 100.0)
            local name = pos.Name or "Relic"
            local distStr = distMeters .. "m"
            DrawTrackerLabel(hud, pos, name, distStr, CONFIG.Relics.Style)
        end
    end

    -- 3. Draw Chests
    if CONFIG.Chests.Enabled then
        for _, pos in ipairs(activeChests) do
            local dx = pos.X - playerPos.X
            local dy = pos.Y - playerPos.Y
            local dz = pos.Z - playerPos.Z
            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
            local distMeters = math.floor(dist / 100.0)
            local name = pos.Name or "Chest"
            local distStr = distMeters .. "m"
            DrawTrackerLabel(hud, pos, name, distStr, CONFIG.Chests.Style)
        end
    end

    -- 4. Draw Eggs
    if CONFIG.Eggs.Filter ~= "None" then
        for _, pos in ipairs(activeEggs) do
            local dx = pos.X - playerPos.X
            local dy = pos.Y - playerPos.Y
            local dz = pos.Z - playerPos.Z
            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
            local distMeters = math.floor(dist / 100.0)
            local prefix = pos.SizePrefix or ""
            local name = pos.Name or "Egg"
            local distStr = distMeters .. "m"
            DrawTrackerLabel(hud, pos, prefix .. name, distStr, CONFIG.Eggs.Style)
        end
    end

    -- 5. Draw Caves
    if CONFIG.Caves.Enabled then
        for _, pos in ipairs(activeCaves) do
            local dx = pos.X - playerPos.X
            local dy = pos.Y - playerPos.Y
            local dz = pos.Z - playerPos.Z
            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
            local distMeters = math.floor(dist / 100.0)
            local name = pos.Name or "Cave"
            local distStr = distMeters .. "m"
            
            local nameStr
            if pos.Level then
                local lv = configMod.GetTranslation("Cave_Lv", "Lv.")
                local stateStr = pos.State
                if stateStr == "Open" then stateStr = configMod.GetTranslation("Cave_Open", "Open")
                elseif stateStr == "Cleared" then stateStr = configMod.GetTranslation("Cave_Cleared", "Cleared")
                end
                nameStr = name .. " " .. lv .. pos.Level .. " (" .. stateStr .. ")"
            else
                local closed = configMod.GetTranslation("Cave_Closed", "(Closed)")
                nameStr = name .. " " .. closed
            end
            
            -- Draw 3D glowing beacon cylinder
            --DrawCaveBeacon(hud, pos, CONFIG.Caves.Style.NameColor)
            
            DrawTrackerLabel(hud, pos, nameStr, distStr, CONFIG.Caves.Style)
        end
    end
end

return M
