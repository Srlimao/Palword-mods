local M = {}

M.Message = ""
M.FramesRemaining = 0
M.Color = { R = 0.0, G = 0.96, B = 0.83, A = 1.0 }

-- Cache for canvas text size measurements to turn O(N) per-frame C++ calls into fast O(1) Lua lookups
local TextSizeCache = {}

function M.Show(text, durationFrames, color)
    M.Message = text or ""
    M.FramesRemaining = durationFrames or 120
    if color then
        M.Color = color
    else
        M.Color = { R = 0.0, G = 0.96, B = 0.83, A = 1.0 }
    end
end

function M.Draw(hud, canvas)
    if M.FramesRemaining <= 0 or not M.Message or M.Message == "" then
        return
    end

    M.FramesRemaining = M.FramesRemaining - 1

    local sizeX = canvas.SizeX
    local sizeY = canvas.SizeY
    if type(sizeX) == "userdata" then sizeX = sizeX:get() end
    if type(sizeY) == "userdata" then sizeY = sizeY:get() end

    sizeX = tonumber(sizeX) or 1920
    sizeY = tonumber(sizeY) or 1080

    local textScale = 1.5
    local cacheKey = M.Message .. "_" .. tostring(textScale)

    local textWidth = TextSizeCache[cacheKey]
    if not textWidth then
        local status, sizeStruct = pcall(function()
            return canvas:K2_TextSize(nil, M.Message, { X = textScale, Y = textScale })
        end)
        if status and sizeStruct then
            textWidth = tonumber(sizeStruct.X) or ( #M.Message * 12 * textScale )
        else
            textWidth = #M.Message * 12 * textScale
        end
        TextSizeCache[cacheKey] = textWidth
    end

    local paddingX = 24
    local cardW = textWidth + (paddingX * 2)
    local cardH = 44
    local cardX = (sizeX - cardW) / 2
    local cardY = sizeY * 0.15 -- Position at top-center of screen

    -- Screen bounds culling check
    if cardX + cardW < 0 or cardX > sizeX or cardY + cardH < 0 or cardY > sizeY then
        return
    end

    -- Draw background card
    pcall(function()
        canvas:K2_DrawBox(
            { X = cardX, Y = cardY },
            { X = cardW, Y = cardH },
            { R = 0.05, G = 0.07, B = 0.15, A = 0.88 },
            1.0
        )
    end)

    -- Draw top glowing accent border line
    pcall(function()
        canvas:K2_DrawLine(
            { X = cardX, Y = cardY },
            { X = cardX + cardW, Y = cardY },
            2.0,
            M.Color
        )
    end)

    -- Streamlined Single Drop Shadow Pass for Text
    pcall(function()
        canvas:K2_DrawText(
            nil,
            M.Message,
            { X = cardX + paddingX + 1, Y = cardY + 10 + 1 },
            { X = textScale, Y = textScale },
            { R = 0.0, G = 0.0, B = 0.0, A = 0.9 },
            0.0,
            { R = 0.0, G = 0.0, B = 0.0, A = 0.0 },
            { X = 0.0, Y = 0.0 },
            false, false, false,
            { R = 0.0, G = 0.0, B = 0.0, A = 0.0 }
        )
    end)

    -- Main Text
    pcall(function()
        canvas:K2_DrawText(
            nil,
            M.Message,
            { X = cardX + paddingX, Y = cardY + 10 },
            { X = textScale, Y = textScale },
            M.Color,
            0.0,
            { R = 0.0, G = 0.0, B = 0.0, A = 0.0 },
            { X = 0.0, Y = 0.0 },
            false, false, false,
            { R = 0.0, G = 0.0, B = 0.0, A = 0.0 }
        )
    end)
end

return M
