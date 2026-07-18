local utils = require("HUDLocator.utils")

local M = {}

local PopupText = ""
local PopupTimer = 0
local MaxTimer = 180 -- ~3 seconds at 60fps

function M.Show(text, duration)
    PopupText = text
    PopupTimer = duration or MaxTimer
end

function M.Draw(hud, SizeX, SizeY)
    if PopupTimer > 0 then
        -- Color theme matching settings menu
        local R, G, B = 0.0, 0.95, 1.0
        local A = 1.0
        
        -- Fade out effect in the last 60 frames
        if PopupTimer < 60 then
            A = PopupTimer / 60.0
        end

        -- Unwrap UE4SS RemoteUnrealParams safely
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

        -- Use a default 1080p fallback if size is not provided or invalid
        local screenW = (type(sx) == "number" and sx > 0) and sx or 1920.0
        local screenH = (type(sy) == "number" and sy > 0) and sy or 1080.0
        
        local y = screenH / 4.0

        -- Parse lines (handling newlines)
        local lines = {}
        for line in string.gmatch(PopupText, "[^\r\n]+") do
            table.insert(lines, line)
        end
        if #lines == 0 then lines = { PopupText } end

        local font, scaleMult = utils.GetFontAndScale()
        local baseScale = 1.25
        local finalScale = baseScale * scaleMult
        
        local lineH = font and (26.0 * finalScale) or (20.0 * finalScale)
        local lineGap = 6.0 * scaleMult
        local padX = 25.0
        local padY = 15.0
        local bw = 2.0

        -- Calculate max line width
        local maxW = 0
        local widths = {}
        for i, line in ipairs(lines) do
            local w = utils.GetTextSize(hud, line, baseScale)
            if not w or w == 0 then
                w = utils.GetStringLength(line) * 9.5 * finalScale
            end
            widths[i] = w
            if w > maxW then
                maxW = w
            end
        end

        -- Box dimensions
        local contentH = #lines * lineH + (#lines - 1) * lineGap
        local boxW = maxW + padX * 2
        local boxH = contentH + padY * 2
        
        local boxX = screenW / 2.0 - boxW / 2.0
        local boxY = y - boxH / 2.0

        -- Panel colors (Glassmorphism look matching menu.lua)
        local cardBg = { R = 0.05, G = 0.07, B = 0.15, A = 0.85 * A }
        local borderCol = { R = 0.0, G = 0.95, B = 1.0, A = 0.6 * A }
        local borderShadow = { R = 0.0, G = 0.0, B = 0.0, A = 0.9 * A }

        -- Draw shadow
        hud:DrawRect(borderShadow, boxX - bw, boxY - bw, boxW + bw * 2, boxH + bw * 2)
        -- Draw main card background
        hud:DrawRect(cardBg, boxX, boxY, boxW, boxH)
        -- Draw neon accent line at the top
        hud:DrawRect(borderCol, boxX, boxY, boxW, 2.5)

        -- Draw lines of text
        local currentY = boxY + padY
        for i, line in ipairs(lines) do
            local w = widths[i]
            local textX = boxX + (boxW / 2.0) - (w / 2.0)
            
            -- Title is neon cyan, secondary lines are off-white
            local textColor = { R = R, G = G, B = B, A = A }
            if i > 1 then
                textColor = { R = 0.9, G = 0.9, B = 0.95, A = A * 0.9 }
            end
            
            -- Drop shadow
            utils.DrawText(hud, line, { R = 0.0, G = 0.0, B = 0.0, A = A * 0.8 }, textX + 1.5, currentY + 1.5, baseScale, false)
            -- Main text
            utils.DrawText(hud, line, textColor, textX, currentY, baseScale, false)
            
            currentY = currentY + lineH + lineGap
        end

        PopupTimer = PopupTimer - 1
    end
end

return M
