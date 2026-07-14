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
        local scale = 1.8
        local R, G, B = 0.2, 0.8, 1.0
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
        
        local x = screenW / 2.0
        local y = screenH / 4.0

        -- Try to center text exactly
        local width = 0
        pcall(function() width = hud:GetTextSize(PopupText, nil, scale) end)
        if width and width > 0 then
            x = x - (width / 2.0)
        else
            -- Rough fallback
            x = x - (#PopupText * 10 * scale / 2.0)
        end

        -- Draw drop shadow
        hud:DrawText(
            PopupText,
            {R=0, G=0, B=0, A=A},
            x+2, y+2,
            nil,
            scale,
            false
        )
        -- Draw main text
        hud:DrawText(
            PopupText,
            {R=R, G=G, B=B, A=A},
            x, y,
            nil,
            scale,
            false
        )

        PopupTimer = PopupTimer - 1
    end
end

return M
