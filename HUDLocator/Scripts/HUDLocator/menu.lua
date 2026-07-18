local configMod = require("HUDLocator.config")
local popup = require("HUDLocator.popup")
local utils = require("HUDLocator.utils")
local CONFIG = configMod.CONFIG

local M = {}

M.isOpen = false
local selectedIndex = 1

local menuItems = {
    {
        name = "Master Enabled",
        get = function() return CONFIG.Global.Enabled end,
        set = function(v) CONFIG.Global.Enabled = v end,
        type = "boolean",
        transKey = "Settings_Enable"
    },
    {
        name = "Show Players",
        get = function() return CONFIG.Players.Enabled end,
        set = function(v) CONFIG.Players.Enabled = v end,
        type = "boolean",
        transKey = "Settings_ShowPlayers"
    },
    {
        name = "Show Relics",
        get = function() return CONFIG.Relics.Enabled end,
        set = function(v) CONFIG.Relics.Enabled = v end,
        type = "boolean",
        transKey = "Settings_ShowRelics"
    },
    {
        name = "Show Chests",
        get = function() return CONFIG.Chests.Enabled end,
        set = function(v) CONFIG.Chests.Enabled = v end,
        type = "boolean",
        transKey = "Settings_ShowChests"
    },
    {
        name = "Show Caves",
        get = function() return CONFIG.Caves.Enabled end,
        set = function(v) CONFIG.Caves.Enabled = v end,
        type = "boolean",
        transKey = "Settings_ShowCaves"
    },
    {
        name = "Egg Filter",
        get = function() return CONFIG.Eggs.Filter end,
        set = function(v) CONFIG.Eggs.Filter = v end,
        type = "enum",
        values = { "All", "Large+", "HugeOnly", "None" },
        transKey = "Settings_EggFilter"
    },
    {
        name = "Advanced Styles",
        get = function() return "Action_OpenURL" end,
        type = "action",
        action = function()
            local url = configMod.ConfiguratorURL or "https://pal-mod-configurator.dunhas.com/"
            local json = require("HUDLocator.json")
            local success, jsonStr = pcall(function() return json.stringify(CONFIG) end)
            if success and jsonStr then
                local encoded = utils.UrlEncode(jsonStr)
                url = url .. "?config=" .. encoded
            end
            utils.OpenURL(url)
            popup.Show(configMod.GetTranslation("Menu_OpeningURL", "Opening Configurator..."), 120)
            
            -- Automatically close the menu so they don't overwrite it when returning from the browser
            M.isOpen = false
            pcall(configMod.SaveConfig)
        end,
        transKey = "Settings_AdvancedStyles",
        valKey = "Action_OpenURL"
    },
    {
        name = "Max Distance (All)",
        get = function() return CONFIG.Players.MaxDistance end,
        set = function(v)
            CONFIG.Players.MaxDistance = v
            CONFIG.Relics.MaxDistance = v
            CONFIG.Chests.MaxDistance = v
            CONFIG.Eggs.MaxDistance = v
            CONFIG.Caves.MaxDistance = v
        end,
        type = "number",
        min = 5000,
        max = 100000,
        step = 5000,
        format = function(v) return math.floor((v or 15000) / 100) .. "m" end,
        transKey = "Settings_MaxDistance"
    },
    {
        name = "Scan Interval",
        get = function() return CONFIG.Global.ScanIntervalMs end,
        set = function(v) CONFIG.Global.ScanIntervalMs = v end,
        type = "number",
        min = 500,
        max = 5000,
        step = 250,
        format = function(v) return (v or 1500) .. "ms" end,
        transKey = "Settings_ScanInterval"
    },
    {
        name = "Language",
        get = function() return CONFIG.Global.Language or "system" end,
        set = function(v) CONFIG.Global.Language = v end,
        type = "enum",
        values = { "system", "en", "es", "ja", "zh-Hans", "zh-Hant", "fr", "it", "de", "ko", "pt-BR", "ru", "th", "vi", "id", "tr", "pl", "es-MX" },
        transKey = "Settings_Language"
    }
}

function M.Toggle()
    M.isOpen = not M.isOpen
    if M.isOpen then
        -- Load the latest configuration from disk before opening the menu
        pcall(configMod.LoadConfig)
        popup.Show(configMod.GetTranslation("Menu_Opened", "Configuration Menu Opened\nUse ALT + Up/Down/Left/Right"),
            180)
    else
        popup.Show(configMod.GetTranslation("Menu_Closed", "Configuration Menu Closed & Saved"), 120)
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
        if item.type == "action" then
            if item.action then
                pcall(item.action)
            end
        elseif item.type == "boolean" then
            item.set(not item.get())
        elseif item.type == "enum" then
            local current = item.get()
            local idx = 1
            for i, val in ipairs(item.values) do
                if val == current then
                    idx = i; break
                end
            end
            if dir == "right" then
                idx = idx + 1
                if idx > #item.values then idx = 1 end
            else
                idx = idx - 1
                if idx < 1 then idx = #item.values end
            end
            item.set(item.values[idx])
        elseif item.type == "number" then
            local val = item.get() or item.min
            if dir == "right" then
                val = val + item.step
                if val > item.max then val = item.max end
            else
                val = val - item.step
                if val < item.min then val = item.min end
            end
            item.set(val)
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

    -- Retrieve cached font and scale multiplier
    local font, scaleMult = utils.GetFontAndScale()

    -- Define menu size & positioning (Left side HUD, modern layout)
    local menuW = font and 480.0 or 400.0
    local menuH = font and (450.0 + 60.0 * scaleMult) or 480.0
    local menuX = 50.0
    local menuY = (screenH / 2.0) - (menuH / 2.0)

    local padL = font and 30.0 or 20.0
    local padHighlight = font and 20.0 or 10.0
    local padText = font and 28.0 or 15.0
    local padVal = font and 35.0 or 25.0

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
    local headerText = configMod.GetTranslation("Settings_Title", "HUD LOCATOR SETTINGS")
    utils.DrawText(hud, headerText, { R = 0.0, G = 0.95, B = 1.0, A = 1.0 }, menuX + padL, menuY + 15.0, 1.2, false)

    -- Subheader keybind tips
    local tipText = configMod.GetTranslation("Menu_Tips", "ALT+Up/Down: Navigate | ALT+Left/Right: Change")
    local tipY = font and (menuY + 38.0 + 8.0 * scaleMult) or (menuY + 38.0)
    utils.DrawText(hud, tipText, { R = 0.6, G = 0.6, B = 0.7, A = 1.0 }, menuX + padL, tipY, 0.75, false)

    -- Separator line
    local sepY = font and (menuY + 52.0 + 12.0 * scaleMult) or (menuY + 52.0)
    hud:DrawRect({ R = 0.2, G = 0.2, B = 0.3, A = 0.4 }, menuX + padL, sepY, menuW - padL * 2, 1.0)

    -- Draw menu items
    local startY = font and (menuY + 60.0 + 12.0 * scaleMult) or (menuY + 65.0)
    local rowH = font and (28.0 + 8.0 * scaleMult) or 34.0

    for i, item in ipairs(menuItems) do
        local isSelected = (i == selectedIndex)
        local itemY = startY + (i - 1) * rowH

        -- Selection highlight background row bar
        if isSelected then
            local highlightBg = { R = 0.0, G = 0.95, B = 1.0, A = 0.15 }
            hud:DrawRect(highlightBg, menuX + padHighlight, itemY - 4.0, menuW - padHighlight * 2, rowH - 4.0)
        end

        -- Get display value
        local rawVal = item.get()
        local valStr = ""
        if item.type == "boolean" then
            valStr = rawVal and configMod.GetTranslation("Menu_ON", "ON") or configMod.GetTranslation("Menu_OFF", "OFF")
        elseif item.type == "enum" then
            local filterKey = "Filter_" .. tostring(rawVal):gsub("%+", "Plus")
            valStr = configMod.GetTranslation(filterKey, tostring(rawVal))
        elseif item.type == "number" then
            if item.format then
                valStr = item.format(rawVal)
            else
                valStr = tostring(rawVal)
            end
        elseif item.type == "label" then
            valStr = tostring(rawVal)
        elseif item.type == "action" then
            valStr = configMod.GetTranslation(item.valKey or "Action_OpenURL", "Alt+Right to Open")
        end

        -- Color definitions
        local nameColor = isSelected and { R = 0.0, G = 0.95, B = 1.0, A = 1.0 } or
            { R = 0.9, G = 0.9, B = 0.95, A = 1.0 }
        local valColor = { R = 1.0, G = 1.0, B = 1.0, A = 1.0 }
        if item.type == "boolean" then
            valColor = rawVal and { R = 0.0, G = 0.96, B = 0.83, A = 1.0 } or { R = 1.0, G = 0.35, B = 0.37, A = 1.0 }
        elseif item.type == "label" or item.type == "action" then
            valColor = { R = 0.5, G = 0.9, B = 0.5, A = 1.0 }
        end

        -- Name string
        local prefix = isSelected and "> " or "  "
        local displayName = configMod.GetTranslation(item.transKey, item.name)
        local displayStr = prefix .. displayName
        utils.DrawText(hud, displayStr, nameColor, menuX + padText, itemY, 1.0, false)

        -- Value string (aligned right)
        local valueText = isSelected and "[ " .. valStr .. " ]" or valStr
        local charW = font and (7.0 + 2.0 * scaleMult) or 7.5
        local valueW = utils.GetStringLength(valueText) * charW * scaleMult
        local valueX = menuX + menuW - valueW - padVal
        utils.DrawText(hud, valueText, valColor, valueX, itemY, 1.0, false)
    end

    -- Separator line
    hud:DrawRect({ R = 0.2, G = 0.2, B = 0.3, A = 0.4 }, menuX + padL, menuY + menuH - 50.0, menuW - padL * 2, 1.0)

    -- Footer status / version
    local footerText = configMod.GetTranslation("Menu_Footer", "ALT+F6 to Close & Save Settings")
    utils.DrawText(hud, footerText, { R = 0.5, G = 0.5, B = 0.6, A = 1.0 }, menuX + padL, menuY + menuH - 32.0, 0.75,
        false)
end

return M
