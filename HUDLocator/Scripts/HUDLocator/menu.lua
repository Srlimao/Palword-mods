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
        name = "Chest/Junk Tracker",
        get = function() return CONFIG.Chests.Enabled end,
        set = function(v) CONFIG.Chests.Enabled = v end,
        type = "boolean",
        transKey = "Settings_ShowChests"
    },
    {
        name = "Chest Filter",
        get = function() return CONFIG.Chests.Filter or "Both" end,
        set = function(v) CONFIG.Chests.Filter = v end,
        type = "enum",
        values = { "Both", "Chests", "Junk" },
        transKey = "Settings_ChestFilter"
    },
    {
        name = "Chest Grade Filter",
        get = function() return CONFIG.Chests.GradeFilter or "All" end,
        set = function(v) CONFIG.Chests.GradeFilter = v end,
        type = "enum",
        values = { "All", "Grade2+", "Grade3+", "Grade4+", "Grade5+", "Grade6Only", "None" },
        transKey = "Settings_ChestGradeFilter"
    },
    {
        name = "Show Caves",
        get = function() return CONFIG.Caves.Enabled end,
        set = function(v) CONFIG.Caves.Enabled = v end,
        type = "boolean",
        transKey = "Settings_ShowCaves"
    },
    {
        name = "Show Notes",
        get = function() return CONFIG.Notes.Enabled end,
        set = function(v) CONFIG.Notes.Enabled = v end,
        type = "boolean",
        transKey = "Settings_ShowNotes"
    },
    {
        name = "Show Ground Loot",
        get = function() return CONFIG.Loot.Enabled end,
        set = function(v) CONFIG.Loot.Enabled = v end,
        type = "boolean",
        transKey = "Settings_ShowLoot"
    },
    {
        name = "Show Pals",
        get = function() return CONFIG.Pals and CONFIG.Pals.Enabled end,
        set = function(v) if CONFIG.Pals then CONFIG.Pals.Enabled = v end end,
        type = "boolean",
        transKey = "Settings_ShowPals"
    },
    {
        name = "Pal Filter",
        get = function() return (CONFIG.Pals and CONFIG.Pals.FilterMode) or "TrackerListOnly" end,
        set = function(v) if CONFIG.Pals then CONFIG.Pals.FilterMode = v end end,
        type = "enum",
        values = { "TrackerListOnly", "All", "ShinyOnly", "BossOnly", "ShinyOrBoss" },
        transKey = "Settings_PalFilter"
    },
    {
        name = "Show Passives",
        get = function() return CONFIG.Pals and CONFIG.Pals.ShowPassives end,
        set = function(v) if CONFIG.Pals then CONFIG.Pals.ShowPassives = v end end,
        type = "boolean",
        transKey = "Settings_ShowPassives"
    },
    {
        name = "Show Level",
        get = function() return CONFIG.Pals and CONFIG.Pals.ShowLevel end,
        set = function(v) if CONFIG.Pals then CONFIG.Pals.ShowLevel = v end end,
        type = "boolean",
        transKey = "Settings_ShowLevel"
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
        get = function() return (CONFIG.Global and CONFIG.Global.MaxDistance) or CONFIG.Players.MaxDistance end,
        set = function(v)
            if CONFIG.Global then CONFIG.Global.MaxDistance = v end
            if CONFIG.Players then CONFIG.Players.MaxDistance = v end
            if CONFIG.Relics then CONFIG.Relics.MaxDistance = v end
            if CONFIG.Chests then CONFIG.Chests.MaxDistance = v end
            if CONFIG.Eggs then CONFIG.Eggs.MaxDistance = v end
            if CONFIG.Caves then CONFIG.Caves.MaxDistance = v end
            if CONFIG.Loot then CONFIG.Loot.MaxDistance = v end
            if CONFIG.Notes then CONFIG.Notes.MaxDistance = v end
            if CONFIG.Pals then CONFIG.Pals.MaxDistance = v end
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
        name = "Font Scale",
        get = function() return CONFIG.Global.FontScale or 1.0 end,
        set = function(v) CONFIG.Global.FontScale = v end,
        type = "number",
        min = 0.5,
        max = 2.0,
        step = 0.1,
        format = function(v) return string.format("%.1fx", v or 1.0) end,
        transKey = "Settings_FontScale"
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

local function GetVisibleItems()
    local visible = {}
    for _, item in ipairs(menuItems) do
        local isVisible = true
        if item.name == "Chest Filter" then
            if not CONFIG.Chests.Enabled then
                isVisible = false
            end
        end
        if isVisible then
            table.insert(visible, item)
        end
    end
    return visible
end

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

    local visibleItems = GetVisibleItems()
    if #visibleItems == 0 then return end

    -- Ensure selectedIndex is within range of visible items
    if selectedIndex > #visibleItems then
        selectedIndex = #visibleItems
    elseif selectedIndex < 1 then
        selectedIndex = 1
    end

    if dir == "up" then
        selectedIndex = selectedIndex - 1
        if selectedIndex < 1 then selectedIndex = #visibleItems end
    elseif dir == "down" then
        selectedIndex = selectedIndex + 1
        if selectedIndex > #visibleItems then selectedIndex = 1 end
    elseif dir == "left" or dir == "right" then
        local item = visibleItems[selectedIndex]
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

    -- Measure text widths to dynamically size the menu and position the values
    local maxNameW = 0
    local maxValW = 0
    local charW = font and (7.0 + 2.0 * scaleMult) or 7.5
    
    local itemNames = {}
    local formattedValues = {}
    
    local visibleItems = GetVisibleItems()
    
    -- Ensure selectedIndex is within range of visible items
    if selectedIndex > #visibleItems then
        selectedIndex = math.max(1, #visibleItems)
    elseif selectedIndex < 1 then
        selectedIndex = 1
    end
    
    for i, item in ipairs(visibleItems) do
        local isSelected = (i == selectedIndex)
        
        -- Formatted Name
        local prefix = isSelected and "> " or "  "
        local displayName = configMod.GetTranslation(item.transKey, item.name)
        local displayStr = prefix .. displayName
        itemNames[i] = displayStr
        
        local nameW = utils.GetTextSize(hud, displayStr, 1.0)
        if not nameW or nameW == 0 then
            nameW = utils.GetStringLength(displayStr) * charW * scaleMult
        end
        if nameW > maxNameW then
            maxNameW = nameW
        end
        
        -- Formatted Value
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
        
        local valueText = isSelected and "[ " .. valStr .. " ]" or valStr
        formattedValues[i] = valueText
        
        local valW = utils.GetTextSize(hud, valueText, 1.0)
        if not valW or valW == 0 then
            valW = utils.GetStringLength(valueText) * charW * scaleMult
        end
        if valW > maxValW then
            maxValW = valW
        end
    end

    -- Header and tip translations
    local headerText = configMod.GetTranslation("Settings_Title", "HUD LOCATOR SETTINGS")
    local tipText = configMod.GetTranslation("Menu_Tips", "ALT+Up/Down: Navigate | ALT+Left/Right: Change")
    local footerText = configMod.GetTranslation("Menu_Footer", "ALT+F6 to Close & Save Settings")

    -- Pad definitions
    local padL = font and 30.0 or 20.0
    local padHighlight = font and 20.0 or 10.0
    local padText = font and 28.0 or 15.0
    local padVal = font and 35.0 or 25.0
    local gap = font and 40.0 or 30.0

    -- Dynamic width calculation
    local contentW = maxNameW + maxValW + padText + padVal + gap
    
    local headerW = utils.GetTextSize(hud, headerText, 1.2)
    if not headerW or headerW == 0 then
        headerW = utils.GetStringLength(headerText) * charW * 1.2 * scaleMult
    end
    
    local tipW = utils.GetTextSize(hud, tipText, 0.75)
    if not tipW or tipW == 0 then
        tipW = utils.GetStringLength(tipText) * charW * 0.75 * scaleMult
    end
    
    local footerW = utils.GetTextSize(hud, footerText, 0.75)
    if not footerW or footerW == 0 then
        footerW = utils.GetStringLength(footerText) * charW * 0.75 * scaleMult
    end
    
    local maxHeaderFooterW = math.max(headerW, tipW, footerW) + padL * 2
    local menuW = math.max(font and 480.0 or 400.0, contentW, maxHeaderFooterW)

    -- Define menu sizing & positioning (Left side HUD, modern layout)
    local rowH = font and (28.0 + 8.0 * scaleMult) or 34.0
    local menuX = 50.0

    -- Sizing height and offsets dynamically
    local headerOffset = 15.0
    local tipOffset = font and (38.0 + 8.0 * scaleMult) or 38.0
    local topSepOffset = font and (52.0 + 12.0 * scaleMult) or 52.0
    local startYOffset = font and (60.0 + 12.0 * scaleMult) or 65.0
    
    local itemsBottomOffset = startYOffset + #visibleItems * rowH
    local bottomSepOffset = itemsBottomOffset + 12.0
    local footerOffset = bottomSepOffset + 15.0
    local menuH = footerOffset + (font and 25.0 or 20.0)
    
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
    utils.DrawText(hud, headerText, { R = 0.0, G = 0.95, B = 1.0, A = 1.0 }, menuX + padL, menuY + headerOffset, 1.2, false)

    -- Subheader keybind tips
    utils.DrawText(hud, tipText, { R = 0.6, G = 0.6, B = 0.7, A = 1.0 }, menuX + padL, menuY + tipOffset, 0.75, false)

    -- Separator line
    hud:DrawRect({ R = 0.2, G = 0.2, B = 0.3, A = 0.4 }, menuX + padL, menuY + topSepOffset, menuW - padL * 2, 1.0)

    -- Draw menu items
    for i, item in ipairs(visibleItems) do
        local isSelected = (i == selectedIndex)
        local itemY = menuY + startYOffset + (i - 1) * rowH

        -- Selection highlight background row bar
        if isSelected then
            local highlightBg = { R = 0.0, G = 0.95, B = 1.0, A = 0.15 }
            hud:DrawRect(highlightBg, menuX + padHighlight, itemY - 4.0, menuW - padHighlight * 2, rowH - 4.0)
        end

        -- Color definitions
        local nameColor = isSelected and { R = 0.0, G = 0.95, B = 1.0, A = 1.0 } or
            { R = 0.9, G = 0.9, B = 0.95, A = 1.0 }
        
        local rawVal = item.get()
        local valColor = { R = 1.0, G = 1.0, B = 1.0, A = 1.0 }
        if item.type == "boolean" then
            valColor = rawVal and { R = 0.0, G = 0.96, B = 0.83, A = 1.0 } or { R = 1.0, G = 0.35, B = 0.37, A = 1.0 }
        elseif item.type == "label" or item.type == "action" then
            valColor = { R = 0.5, G = 0.9, B = 0.5, A = 1.0 }
        end

        -- Name string
        local displayStr = itemNames[i]
        utils.DrawText(hud, displayStr, nameColor, menuX + padText, itemY, 1.0, false)

        -- Value string (aligned right)
        local valueText = formattedValues[i]
        local valW = utils.GetTextSize(hud, valueText, 1.0)
        if not valW or valW == 0 then
            valW = utils.GetStringLength(valueText) * charW * scaleMult
        end
        local valueX = menuX + menuW - valW - padVal
        utils.DrawText(hud, valueText, valColor, valueX, itemY, 1.0, false)
    end

    -- Bottom separator line
    hud:DrawRect({ R = 0.2, G = 0.2, B = 0.3, A = 0.4 }, menuX + padL, menuY + bottomSepOffset, menuW - padL * 2, 1.0)

    -- Footer status / version
    utils.DrawText(hud, footerText, { R = 0.5, G = 0.5, B = 0.6, A = 1.0 }, menuX + padL, menuY + footerOffset, 0.75,
        false)
end

return M
