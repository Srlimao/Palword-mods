local utils = require("AccessoryToggler.utils")

local M = {}

local PopupText = ""
local PopupLines = {}
local PopupTimer = 0
local MaxTimer = 180 -- ~3 seconds at 60fps
local PopupColor = { R = 0.2, G = 0.8, B = 1.0, A = 1.0 }

-- Pre-allocated static tables for drawing to avoid per-frame GC allocations
local staticCardBg = { R = 0.05, G = 0.07, B = 0.15, A = 0.85 }
local staticBorderCol = { R = 0.2, G = 0.8, B = 1.0, A = 0.6 }
local staticBorderShadow = { R = 0.0, G = 0.0, B = 0.0, A = 0.9 }

local staticTextColor = { R = 1.0, G = 1.0, B = 1.0, A = 1.0 }
local staticSecondaryColor = { R = 0.9, G = 0.9, B = 0.95, A = 0.9 }
local staticShadowColor = { R = 0.0, G = 0.0, B = 0.0, A = 0.8 }

local staticWidths = {}

function M.Show(text, duration, color)
    PopupText = text
    PopupTimer = duration or MaxTimer
    if color then
        PopupColor = color
    else
        PopupColor = { R = 0.2, G = 0.8, B = 1.0, A = 1.0 }
    end

    -- Pre-parse lines once at show time instead of every frame
    PopupLines = {}
    for line in string.gmatch(PopupText, "[^\r\n]+") do
        table.insert(PopupLines, line)
    end
    if #PopupLines == 0 then PopupLines = { PopupText } end
end

function M.Draw(hud, SizeX, SizeY)
    if PopupTimer > 0 then
        local A = 1.0
        
        -- Fade out effect in the last 60 frames
        if PopupTimer < 60 then
            A = PopupTimer / 60.0
        end

        local sx = utils.SafeUnwrap(SizeX)
        local sy = utils.SafeUnwrap(SizeY)

        local screenW = (type(sx) == "number" and sx > 0) and sx or 1920.0
        local screenH = (type(sy) == "number" and sy > 0) and sy or 1080.0
        
        local y = screenH / 4.0

        local font, scaleMult = utils.GetFontAndScale()
        local baseScale = 1.4
        local finalScale = baseScale * scaleMult
        
        local lineH = font and (26.0 * finalScale) or (20.0 * finalScale)
        local lineGap = 6.0 * scaleMult
        local padX = 25.0
        local padY = 15.0
        local bw = 2.0

        -- Calculate max line width using reusable table
        local maxW = 0
        for k in pairs(staticWidths) do staticWidths[k] = nil end
        for i, line in ipairs(PopupLines) do
            local w = utils.GetTextSize(hud, line, baseScale)
            if not w or w == 0 then
                w = utils.GetStringLength(line) * 9.5 * finalScale
            end
            staticWidths[i] = w
            if w > maxW then
                maxW = w
            end
        end

        -- Box dimensions
        local contentH = #PopupLines * lineH + (#PopupLines - 1) * lineGap
        local boxW = maxW + padX * 2
        local boxH = contentH + padY * 2
        
        local boxX = screenW / 2.0 - boxW / 2.0
        local boxY = y - boxH / 2.0

        -- Update pre-allocated color tables to avoid GC spikes
        staticCardBg.A = 0.85 * A
        staticBorderCol.R = PopupColor.R
        staticBorderCol.G = PopupColor.G
        staticBorderCol.B = PopupColor.B
        staticBorderCol.A = 0.6 * A
        staticBorderShadow.A = 0.9 * A

        -- Draw shadow
        hud:DrawRect(staticBorderShadow, boxX - bw, boxY - bw, boxW + bw * 2, boxH + bw * 2)
        -- Draw main card background
        hud:DrawRect(staticCardBg, boxX, boxY, boxW, boxH)
        -- Draw neon accent line at the top
        hud:DrawRect(staticBorderCol, boxX, boxY, boxW, 2.5)

        -- Draw lines of text
        local currentY = boxY + padY
        for i, line in ipairs(PopupLines) do
            local w = staticWidths[i]
            local textX = boxX + (boxW / 2.0) - (w / 2.0)
            
            local textColor
            if i == 1 then
                staticTextColor.R = PopupColor.R
                staticTextColor.G = PopupColor.G
                staticTextColor.B = PopupColor.B
                staticTextColor.A = A
                textColor = staticTextColor
            else
                staticSecondaryColor.A = A * 0.9
                textColor = staticSecondaryColor
            end
            
            -- Drop shadow
            staticShadowColor.A = A * 0.8
            utils.DrawText(hud, line, staticShadowColor, textX + 1.5, currentY + 1.5, baseScale, false)
            -- Main text
            utils.DrawText(hud, line, textColor, textX, currentY, baseScale, false)
            
            currentY = currentY + lineH + lineGap
        end

        PopupTimer = PopupTimer - 1
    end
end

return M
