local configMod = require("HUDLocator.config")
local CONFIG = configMod.CONFIG

local M = {}

-- Render center-aligned 3D floating text above the item location (relics, chests)
local function DrawTextAbove(hud, pos, textStr, color)
    local textWorldPos = { X = pos.X, Y = pos.Y, Z = pos.Z + CONFIG.ItemTextOffsetZ }
    local textScreen = hud:Project(textWorldPos, false)
    
    if textScreen.Z > 0.0 then
        local width = 0
        local height = 0
        pcall(function()
            width, height = hud:GetTextSize(textStr, nil, CONFIG.FontScale)
        end)
        
        -- Fallback default font character metrics if GetTextSize fails
        if not width or width == 0 then
            width = #textStr * CONFIG.FontCharW * CONFIG.FontScale
            height = CONFIG.FontLineH * CONFIG.FontScale
        end
        
        -- Center-align text relative to the projected screen position
        local drawX = textScreen.X - (width / 2.0)
        local drawY = textScreen.Y - (height / 2.0)
        
        hud:DrawText(textStr, color, drawX, drawY, nil, CONFIG.FontScale, false)
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
            local nameW  = #labelStr * CONFIG.FontCharW * CONFIG.FontScale
            local distW  = #distStr  * CONFIG.FontCharW * CONFIG.SmallFontScale
            local nameH  = CONFIG.FontLineH * CONFIG.FontScale
            local distH  = CONFIG.FontLineH * CONFIG.SmallFontScale
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

            hud:DrawText(labelStr, CONFIG.NameColor, nameX, nameY, nil, CONFIG.FontScale, false)
            hud:DrawText(distStr, CONFIG.DistColor, distX, distY, nil, CONFIG.SmallFontScale, false)
        else
            -- Simple single-line format: Name [Distance]
            local simpleStr = nameStr .. " [" .. distStr .. "]"
            local simpleW = #simpleStr * CONFIG.FontCharW * CONFIG.FontScale
            local simpleH = CONFIG.FontLineH * CONFIG.FontScale
            
            local simpleX = textScreen.X - simpleW * 0.5
            local simpleY = textScreen.Y - simpleH * 0.5
            
            local nameCol = { R = 1.0, G = 1.0, B = 1.0, A = 1.0 }
            local borderCol = { R = 0.0, G = 0.0, B = 0.0, A = 0.8 }
            local off = 1.0
            
            -- Draw soft borders
            hud:DrawText(simpleStr, borderCol, simpleX - off, simpleY - off, nil, CONFIG.FontScale, false)
            hud:DrawText(simpleStr, borderCol, simpleX + off, simpleY - off, nil, CONFIG.FontScale, false)
            hud:DrawText(simpleStr, borderCol, simpleX - off, simpleY + off, nil, CONFIG.FontScale, false)
            hud:DrawText(simpleStr, borderCol, simpleX + off, simpleY + off, nil, CONFIG.FontScale, false)
            
            -- Draw main text
            hud:DrawText(simpleStr, nameCol, simpleX, simpleY, nil, CONFIG.FontScale, false)
        end
    end
end

-- Main entry point for drawing
function M.draw(hud, activePlayers, activeRelics, activeChests, activeEggs, cachedLocalPlayer)
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
            local textStr = "Relic [" .. distMeters .. "m]"
            DrawTextAbove(hud, pos, textStr, CONFIG.RelicColor)
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
            local textStr = "Chest [" .. distMeters .. "m]"
            DrawTextAbove(hud, pos, textStr, CONFIG.ChestColor)
        end
    end

    -- 4. Draw Eggs
    if CONFIG.ShowEggs then
        for _, pos in ipairs(activeEggs) do
            local dx = pos.X - playerPos.X
            local dy = pos.Y - playerPos.Y
            local dz = pos.Z - playerPos.Z
            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
            local distMeters = math.floor(dist / 100.0)
            local prefix = pos.SizePrefix or ""
            local textStr = prefix .. "Egg [" .. distMeters .. "m]"
            DrawTextAbove(hud, pos, textStr, CONFIG.EggColor)
        end
    end
end

return M
