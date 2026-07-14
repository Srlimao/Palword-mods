local configMod = require("HUDLocator.config")
local popup = require("HUDLocator.popup")
local CONFIG = configMod.CONFIG

local M = {}

M.isOpen = false
local selectedIndex = 1

local menuItems = {
    {
        name = "Enabled",
        key = "Enabled",
        type = "boolean"
    },
    {
        name = "Show Players",
        key = "ShowPlayers",
        type = "boolean"
    },
    {
        name = "Show Relics",
        key = "ShowRelics",
        type = "boolean"
    },
    {
        name = "Show Chests",
        key = "ShowChests",
        type = "boolean"
    },
    {
        name = "Show Caves",
        key = "ShowCaves",
        type = "boolean"
    },
    {
        name = "Egg Filter",
        key = "EggFilter",
        type = "enum",
        values = {"All", "Large+", "HugeOnly", "None"}
    },
    {
        name = "Box Style",
        key = "DrawBox",
        type = "boolean"
    },
    {
        name = "Max Distance",
        key = "MaxDistance",
        type = "number",
        min = 5000,
        max = 100000,
        step = 5000,
        format = function(v) return math.floor(v / 100) .. "m" end
    },
    {
        name = "Scan Interval",
        key = "ScanIntervalMs",
        type = "number",
        min = 500,
        max = 5000,
        step = 250,
        format = function(v) return v .. "ms" end
    }
}

function M.Toggle()
    M.isOpen = not M.isOpen
    if M.isOpen then
        popup.Show("Configuration Menu Opened\nUse ALT + Up/Down/Left/Right", 180)
    else
        popup.Show("Configuration Menu Closed & Saved", 120)
        pcall(configMod.SaveConfig)
    end
end

function M.Navigate(dir)
    if not M.isOpen then return end
    
    if dir == "up" then
        selectedIndex = selectedIndex - 1
        if selectedIndex < 1 then selectedIndex = #menuItems end
    elseif dir == "down" then
        selectedIndex = selectedIndex + 1
        if selectedIndex > #menuItems then selectedIndex = 1 end
    elseif dir == "left" or dir == "right" then
        local item = menuItems[selectedIndex]
        if item.type == "boolean" then
            CONFIG[item.key] = not CONFIG[item.key]
        elseif item.type == "enum" then
            local current = CONFIG[item.key]
            local idx = 1
            for i, val in ipairs(item.values) do
                if val == current then idx = i; break end
            end
            if dir == "right" then
                idx = idx + 1
                if idx > #item.values then idx = 1 end
            else
                idx = idx - 1
                if idx < 1 then idx = #item.values end
            end
            CONFIG[item.key] = item.values[idx]
        elseif item.type == "number" then
            local val = CONFIG[item.key] or item.min
            if dir == "right" then
                val = val + item.step
                if val > item.max then val = item.max end
            else
                val = val - item.step
                if val < item.min then val = item.min end
            end
            CONFIG[item.key] = val
        end
        
        -- Automatically trigger SaveConfig on changes
        pcall(configMod.SaveConfig)
    end
end

function M.Draw(hud, SizeX, SizeY)
    if not M.isOpen then return end
    
    -- Unwrap screenspace dimensions safely
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
    
    -- Define menu size & positioning (Left side HUD, modern layout)
    local menuW = 380.0
    local menuH = 420.0
    local menuX = 50.0
    local menuY = (screenH / 2.0) - (menuH / 2.0)
    
    -- Draw modern semi-transparent glass panel
    local cardBg = { R = 0.05, G = 0.07, B = 0.15, A = 0.85 }
    local borderCol = { R = 0.0, G = 0.95, B = 1.0, A = 0.6 }
    local borderShadow = { R = 0.0, G = 0.0, B = 0.0, A = 0.9 }
    
    -- Main panel drop shadow
    hud:DrawRect(borderShadow, menuX - 2.0, menuY - 2.0, menuW + 4.0, menuH + 4.0)
    -- Main background panel
    hud:DrawRect(cardBg, menuX, menuY, menuW, menuH)
    -- Sleek top accent line (Neon Blue)
    hud:DrawRect(borderCol, menuX, menuY, menuW, 3.0)
    
    -- Header text
    local headerText = "HUD LOCATOR SETTINGS"
    local scaleHeader = 1.2
    hud:DrawText(headerText, { R = 0.0, G = 0.95, B = 1.0, A = 1.0 }, menuX + 20.0, menuY + 15.0, nil, scaleHeader, false)
    
    -- Subheader keybind tips
    local tipText = "ALT+Up/Down: Navigate | ALT+Left/Right: Change"
    local scaleTips = 0.75
    hud:DrawText(tipText, { R = 0.6, G = 0.6, B = 0.7, A = 1.0 }, menuX + 20.0, menuY + 38.0, nil, scaleTips, false)
    
    -- Separator line
    hud:DrawRect({ R = 0.2, G = 0.2, B = 0.3, A = 0.4 }, menuX + 20.0, menuY + 52.0, menuW - 40.0, 1.0)
    
    -- Draw menu items
    local startY = menuY + 65.0
    local rowH = 34.0
    local scaleRow = 1.0
    
    for i, item in ipairs(menuItems) do
        local isSelected = (i == selectedIndex)
        local itemY = startY + (i - 1) * rowH
        
        -- Selection highlight background row bar
        if isSelected then
            local highlightBg = { R = 0.0, G = 0.95, B = 1.0, A = 0.15 }
            hud:DrawRect(highlightBg, menuX + 10.0, itemY - 4.0, menuW - 20.0, rowH - 4.0)
        end
        
        -- Get display value
        local rawVal = CONFIG[item.key]
        local valStr = ""
        if item.type == "boolean" then
            valStr = rawVal and "ON" or "OFF"
        elseif item.type == "enum" then
            valStr = tostring(rawVal)
        elseif item.type == "number" then
            if item.format then
                valStr = item.format(rawVal)
            else
                valStr = tostring(rawVal)
            end
        end
        
        -- Color definitions
        local nameColor = isSelected and { R = 0.0, G = 0.95, B = 1.0, A = 1.0 } or { R = 0.9, G = 0.9, B = 0.95, A = 1.0 }
        local valColor = { R = 1.0, G = 1.0, B = 1.0, A = 1.0 }
        if item.type == "boolean" then
            valColor = rawVal and { R = 0.0, G = 0.96, B = 0.83, A = 1.0 } or { R = 1.0, G = 0.35, B = 0.37, A = 1.0 }
        end
        
        -- Name string
        local prefix = isSelected and "> " or "  "
        local displayStr = prefix .. item.name
        hud:DrawText(displayStr, nameColor, menuX + 15.0, itemY, nil, scaleRow, false)
        
        -- Value string (aligned right)
        local valueText = isSelected and "[ " .. valStr .. " ]" or valStr
        local valueW = #valueText * 7.5 * scaleRow
        local valueX = menuX + menuW - valueW - 25.0
        hud:DrawText(valueText, valColor, valueX, itemY, nil, scaleRow, false)
    end
    
    -- Separator line
    hud:DrawRect({ R = 0.2, G = 0.2, B = 0.3, A = 0.4 }, menuX + 20.0, menuY + menuH - 45.0, menuW - 40.0, 1.0)
    
    -- Footer status / version
    local footerText = "ALT+F6 to Close & Save Settings"
    hud:DrawText(footerText, { R = 0.5, G = 0.5, B = 0.6, A = 1.0 }, menuX + 20.0, menuY + menuH - 30.0, nil, 0.75, false)
end

return M
