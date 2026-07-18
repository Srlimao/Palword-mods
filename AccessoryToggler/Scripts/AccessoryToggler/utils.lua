local UEHelpers = require("UEHelpers")
local configMod = require("AccessoryToggler.config")

local M = {}

M.CachedFont = nil
M.FontScaleMultiplier = 0.7
local lastFontScanTime = 0
local fontScanInterval = 10.0

function M.GetStringLength(str)
    if not str then return 0 end
    local status, len = pcall(function() return utf8.len(str) end)
    if status and len then
        return len
    end
    -- Fallback for standard ASCII or when utf8 library is not available
    return string.len(str)
end

function M.FindAndCacheFont()
    if M.CachedFont and M.CachedFont:IsValid() then
        return M.CachedFont
    end

    local currentTime = os.clock()
    if currentTime - lastFontScanTime < fontScanInterval then
        return nil
    end
    lastFontScanTime = currentTime
    
    pcall(function()
        local fonts = FindAllOf("Font")
        if fonts then
            for _, f in ipairs(fonts) do
                if f:IsValid() then
                    local name = f:GetFullName()
                    if string.find(name:lower(), "/game/") then
                        M.CachedFont = f
                        print("[AccessoryToggler] Successfully matched and cached game UI font: " .. name)
                        return f
                    end
                end
            end
        end
    end)
    return nil
end

function M.GetFontAndScale()
    local font = M.CachedFont
    local scaleMult = font and M.FontScaleMultiplier or 1.0
    return font, scaleMult
end

local LoggedKeys = {}
local function LogOnce(key, msg)
    if not LoggedKeys[key] then
        LoggedKeys[key] = true
        print("[AccessoryToggler] " .. msg)
    end
end

function M.DrawText(hud, text, color, x, y, baseScale, scalePosition)
    local font, scaleMult = M.GetFontAndScale()
    local finalScale = (baseScale or 1.0) * scaleMult
    hud:DrawText(text, color, x, y, font, finalScale, scalePosition or false)
end

-- Safely measure text width using UCanvas:K2_TextSize
function M.GetTextSize(hud, text, baseScale)
    local font, scaleMult = M.GetFontAndScale()
    local finalScale = (baseScale or 1.0) * scaleMult
    local width = 0
    
    if font then
        local success, err = pcall(function()
            local canvas = hud.Canvas
            if canvas and canvas:IsValid() then
                local size = canvas:K2_TextSize(font, text, { X = finalScale, Y = finalScale })
                if size then
                    width = size.X or size.x or 0
                end
            end
        end)
        
        if success and width and width > 0 then
            LogOnce("text_size_success", string.format("GetTextSize successfully measuring font sizes via UCanvas. Example: text='%s', scale=%.2f -> width=%.2f", tostring(text), finalScale, width))
        else
            local errMsg = err or (not hud.Canvas and "hud.Canvas is nil" or "K2_TextSize returned nil size")
            LogOnce("text_size_fail_" .. tostring(text), string.format("GetTextSize failed or returned 0 for text '%s' (scale=%.2f). Error: %s. Using fallback character spacing.", tostring(text), finalScale, tostring(errMsg)))
        end
    end
    
    return width
end

return M
