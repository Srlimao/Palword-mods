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
    if M.CachedFont then return M.CachedFont end
    local now = os.time()
    if now - lastFontScanTime < fontScanInterval then return nil end
    lastFontScanTime = now
    
    local fontResolved = false
    pcall(function()
        local fonts = FindAllOf("Font")
        if fonts then
            for _, f in ipairs(fonts) do
                local fname = f:GetName()
                if fname == "Ft_PalDefaultFont" then
                    M.CachedFont = f
                    fontResolved = true
                    print("[AccessoryToggler] Successfully resolved and cached game font asset: Ft_PalDefaultFont")
                    break
                end
            end
        end
    end)
    return M.CachedFont
end

function M.GetFontAndScale()
    local font = M.CachedFont
    local scaleMult = font and M.FontScaleMultiplier or 1.0
    return font, scaleMult
end

function M.DrawText(hud, text, color, x, y, baseScale, scalePosition)
    local font, scaleMult = M.GetFontAndScale()
    local finalScale = (baseScale or 1.0) * scaleMult
    hud:DrawText(text, color, x, y, font, finalScale, scalePosition or false)
end

function M.GetTextSize(hud, text, baseScale)
    local font, scaleMult = M.GetFontAndScale()
    local finalScale = (baseScale or 1.0) * scaleMult
    local width = 0
    pcall(function() width = hud:GetTextSize(text, font, finalScale) end)
    return width
end

return M
