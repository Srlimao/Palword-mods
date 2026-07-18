local utils = require("AccessoryToggler.utils")

local M = {}

local PopupText = ""
local PopupTimer = 0
local MaxTimer = 180 -- ~3 seconds at 60fps
local PopupColor = { R = 0.2, G = 0.8, B = 1.0, A = 1.0 }

function M.Show(text, duration, color)
    PopupText = text
    PopupTimer = duration or MaxTimer
    if color then
        PopupColor = color
    else
        PopupColor = { R = 0.2, G = 0.8, B = 1.0, A = 1.0 }
    end
end

function M.Draw(hud, SizeX, SizeY)
    if PopupTimer > 0 then
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

        local screenW = (type(sx) == "number" and sx > 0) and sx or 1920.0
        local screenH = (type(sy) == "number" and sy > 0) and sy or 1080.0
        
        local x = screenW / 2.0
        local y = screenH / 4.0

        -- Try to center text exactly
        local baseScale = 1.8
        local width = utils.GetTextSize(hud, PopupText, baseScale)
        if not width or width == 0 then
            -- Fallback estimation
            local font, scaleMult = utils.GetFontAndScale()
            width = utils.GetStringLength(PopupText) * 10 * (baseScale * scaleMult) / 2.0
        end
        
        local drawX = x - (width / 2.0)

        -- Draw drop shadow
        utils.DrawText(hud, PopupText, { R = 0, G = 0, B = 0, A = A }, drawX + 2, y + 2, baseScale, false)
        
        -- Draw main text
        local colorWithAlpha = { R = PopupColor.R, G = PopupColor.G, B = PopupColor.B, A = A }
        utils.DrawText(hud, PopupText, colorWithAlpha, drawX, y, baseScale, false)

        PopupTimer = PopupTimer - 1
    end
end

return M
