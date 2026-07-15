local configMod = require("HUDLocator.config")
local popup = require("HUDLocator.popup")
local menu = require("HUDLocator.menu")
local CONFIG = configMod.CONFIG

local M = {}

-- Render center-aligned 3D floating text above the item location (relics, chests)
local function DrawTextAbove(hud, pos, textStr, color, fontScale)
    local textWorldPos = { X = pos.X, Y = pos.Y, Z = pos.Z + CONFIG.ItemTextOffsetZ }
    local textScreen = hud:Project(textWorldPos, false)
    
    if textScreen.Z > 0.0 then
        local width = 0
        local height = 0
        pcall(function()
            width, height = hud:GetTextSize(textStr, nil, fontScale)
        end)
        
        -- Fallback default font character metrics if GetTextSize fails
        if not width or width == 0 then
            width = #textStr * CONFIG.FontCharW * fontScale
            height = CONFIG.FontLineH * fontScale
        end
        
        -- Center-align text relative to the projected screen position
        local drawX = textScreen.X - (width / 2.0)
        local drawY = textScreen.Y - (height / 2.0)
        
        hud:DrawText(textStr, color, drawX, drawY, nil, fontScale, false)
    end
end

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

-- Draw nameplate and distance indicator above player
local function DrawPlayerPlate(hud, otherPlayer, playerPos)
    local dx = otherPlayer.Pos.X - playerPos.X
    local dy = otherPlayer.Pos.Y - playerPos.Y
    local dz = otherPlayer.Pos.Z - playerPos.Z
    local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
    local distMeters = math.floor(dist / 100.0)
    
    -- Skip anyone within the grace radius
    if distMeters <= CONFIG.GraceRadiusM then return end
    
    local nameStr = otherPlayer.Name
    local distStr = distMeters .. "m"
    
    local textWorldPos = { X = otherPlayer.Pos.X, Y = otherPlayer.Pos.Y, Z = otherPlayer.Pos.Z + CONFIG.TextOffsetZ }
    local textScreen = hud:Project(textWorldPos, false)
    
    if textScreen.Z > 0.0 then
        local iconStr = "@ " -- Plain ASCII person indicator
        local labelStr = iconStr .. nameStr

        if CONFIG.DrawBox then
            -- Estimate dimensions for two-line layout
            local nameW  = #labelStr * CONFIG.FontCharW * CONFIG.PlayerFontScale
            local distW  = #distStr  * CONFIG.FontCharW * CONFIG.PlayerSmallFontScale
            local nameH  = CONFIG.FontLineH * CONFIG.PlayerFontScale
            local distH  = CONFIG.FontLineH * CONFIG.PlayerSmallFontScale
            local lineGap = 4.0
            local bw     = CONFIG.BorderWidth
            
            local contentW = math.max(nameW, distW)
            local contentH = nameH + lineGap + distH
            local boxW = contentW + CONFIG.BoxPadX * 2
            local boxH = contentH + CONFIG.BoxPadY * 2
            
            -- Centre box on the projected world point
            local boxX = textScreen.X - boxW * 0.5
            local boxY = textScreen.Y - boxH * 0.5
 
            -- Draw border
            hud:DrawRect(CONFIG.BorderColor, boxX - bw, boxY - bw, boxW + bw * 2, boxH + bw * 2)
 
            -- Draw background fill box
            hud:DrawRect(CONFIG.BoxColor, boxX, boxY, boxW, boxH)
            
            -- Draw name + icon
            local nameX = textScreen.X - nameW * 0.5
            local nameY = boxY + CONFIG.BoxPadY
            
            -- Draw distance
            local distX = textScreen.X - distW * 0.5
            local distY = nameY + nameH + lineGap
 
            hud:DrawText(labelStr, CONFIG.NameColor, nameX, nameY, nil, CONFIG.PlayerFontScale, false)
            hud:DrawText(distStr, CONFIG.DistColor, distX, distY, nil, CONFIG.PlayerSmallFontScale, false)
        else
            -- Simple single-line format: Name [Distance]
            local simpleStr = nameStr .. " [" .. distStr .. "]"
            local simpleW = #simpleStr * CONFIG.FontCharW * CONFIG.PlayerFontScale
            local simpleH = CONFIG.FontLineH * CONFIG.PlayerFontScale
            
            local simpleX = textScreen.X - simpleW * 0.5
            local simpleY = textScreen.Y - simpleH * 0.5
            
            local nameCol = { R = 1.0, G = 1.0, B = 1.0, A = 1.0 }
            local borderCol = { R = 0.0, G = 0.0, B = 0.0, A = 0.8 }
            local off = 1.0
            
            -- Draw soft borders
            hud:DrawText(simpleStr, borderCol, simpleX - off, simpleY - off, nil, CONFIG.PlayerFontScale, false)
            hud:DrawText(simpleStr, borderCol, simpleX + off, simpleY - off, nil, CONFIG.PlayerFontScale, false)
            hud:DrawText(simpleStr, borderCol, simpleX - off, simpleY + off, nil, CONFIG.PlayerFontScale, false)
            hud:DrawText(simpleStr, borderCol, simpleX + off, simpleY + off, nil, CONFIG.PlayerFontScale, false)
            
            -- Draw main text
            hud:DrawText(simpleStr, nameCol, simpleX, simpleY, nil, CONFIG.PlayerFontScale, false)
        end
    end
end

-- Main entry point for drawing
function M.draw(hud, activePlayers, activeRelics, activeChests, activeEggs, activeCaves, cachedLocalPlayer, SizeX, SizeY)
    -- 1. Draw Settings Menu (always allowed, even if mod is disabled)
    menu.Draw(hud, SizeX, SizeY)
    
    -- 2. Draw Popups (always allowed)
    popup.Draw(hud, SizeX, SizeY)

    if not CONFIG.Enabled then return end
    
    if not cachedLocalPlayer or not cachedLocalPlayer:IsValid() then return end
    local playerPos = cachedLocalPlayer:K2_GetActorLocation()
    if not playerPos then return end

    -- 1. Draw Players
    if CONFIG.ShowPlayers then
        for _, otherPlayer in ipairs(activePlayers) do
            DrawPlayerPlate(hud, otherPlayer, playerPos)
        end
    end

    -- 2. Draw Relics
    if CONFIG.ShowRelics then
        for _, pos in ipairs(activeRelics) do
            local dx = pos.X - playerPos.X
            local dy = pos.Y - playerPos.Y
            local dz = pos.Z - playerPos.Z
            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
            local distMeters = math.floor(dist / 100.0)
            local name = pos.Name or "Relic"
            local textStr = name .. " [" .. distMeters .. "m]"
            DrawTextAbove(hud, pos, textStr, CONFIG.RelicColor, CONFIG.RelicFontScale)
        end
    end

    -- 3. Draw Chests
    if CONFIG.ShowChests then
        for _, pos in ipairs(activeChests) do
            local dx = pos.X - playerPos.X
            local dy = pos.Y - playerPos.Y
            local dz = pos.Z - playerPos.Z
            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
            local distMeters = math.floor(dist / 100.0)
            local name = pos.Name or "Chest"
            local textStr = name .. " [" .. distMeters .. "m]"
            DrawTextAbove(hud, pos, textStr, CONFIG.ChestColor, CONFIG.ChestFontScale)
        end
    end

    -- 4. Draw Eggs
    if CONFIG.EggFilter ~= "None" then
        for _, pos in ipairs(activeEggs) do
            local dx = pos.X - playerPos.X
            local dy = pos.Y - playerPos.Y
            local dz = pos.Z - playerPos.Z
            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
            local distMeters = math.floor(dist / 100.0)
            local prefix = pos.SizePrefix or ""
            local name = pos.Name or "Egg"
            local textStr = prefix .. name .. " [" .. distMeters .. "m]"
            DrawTextAbove(hud, pos, textStr, CONFIG.EggColor, CONFIG.EggFontScale)
        end
    end

    -- 5. Draw Caves
    if CONFIG.ShowCaves then
        for _, pos in ipairs(activeCaves) do
            local dx = pos.X - playerPos.X
            local dy = pos.Y - playerPos.Y
            local dz = pos.Z - playerPos.Z
            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
            local distMeters = math.floor(dist / 100.0)
            local name = pos.Name or "Cave"
            
            local textStr
            if pos.Level then
                local lv = configMod.GetTranslation("Cave_Lv", "Lv.")
                local stateStr = pos.State
                if stateStr == "Open" then stateStr = configMod.GetTranslation("Cave_Open", "Open")
                elseif stateStr == "Cleared" then stateStr = configMod.GetTranslation("Cave_Cleared", "Cleared")
                end
                textStr = name .. " " .. lv .. pos.Level .. " (" .. stateStr .. ") [" .. distMeters .. "m]"
            else
                local closed = configMod.GetTranslation("Cave_Closed", "(Closed)")
                textStr = name .. " " .. closed .. " [" .. distMeters .. "m]"
            end
            
            -- Draw 3D glowing beacon cylinder
            --DrawCaveBeacon(hud, pos, CONFIG.CaveColor)
            
            DrawTextAbove(hud, pos, textStr, CONFIG.CaveColor, CONFIG.CaveFontScale)
        end
    end
end

return M
