-- Mod Options Framework Integration for HUDLocator
local configMod = require("HUDLocator.config")

local M = {}
M.pmoClient = nil
M.currentGeneration = -1

local function FormatPalTrackerList(trackerPals)
    if type(trackerPals) ~= "table" then return "" end
    local list = {}
    for _, item in ipairs(trackerPals) do
        if type(item) == "string" and item ~= "" then
            table.insert(list, item)
        elseif type(item) == "table" and type(item.palname) == "string" and item.palname ~= "" then
            table.insert(list, item.palname)
        end
    end
    return table.concat(list, ", ")
end

local function ParsePalTrackerList(str, existingTrackerPals)
    local newNamesList = {}
    if type(str) == "string" then
        for name in string.gmatch(str, "([^,]+)") do
            local trimmed = name:match("^%s*(.-)%s*$")
            if trimmed and trimmed ~= "" then
                table.insert(newNamesList, trimmed)
            end
        end
    end

    local existingMap = {}
    if type(existingTrackerPals) == "table" then
        for _, rule in ipairs(existingTrackerPals) do
            if type(rule) == "table" and type(rule.palname) == "string" and rule.palname ~= "" then
                existingMap[rule.palname:lower()] = rule
            elseif type(rule) == "string" and rule ~= "" then
                existingMap[rule:lower()] = { palname = rule }
            end
        end
    end

    local result = {}
    for _, name in ipairs(newNamesList) do
        local lower = name:lower()
        if existingMap[lower] then
            local ruleCopy = existingMap[lower]
            if type(ruleCopy) == "table" then
                ruleCopy.palname = name
                table.insert(result, ruleCopy)
            else
                table.insert(result, { palname = name })
            end
        else
            table.insert(result, { palname = name })
        end
    end
    return result
end

local function FormatLootFilters(filters)
    if type(filters) ~= "table" then return "" end
    local list = {}
    for _, item in ipairs(filters) do
        if type(item) == "string" and item ~= "" then
            table.insert(list, item)
        end
    end
    return table.concat(list, ", ")
end

local function ParseLootFilters(str)
    local result = {}
    if type(str) ~= "string" then return result end
    for item in string.gmatch(str, "([^,]+)") do
        local trimmed = item:match("^%s*(.-)%s*$")
        if trimmed and trimmed ~= "" then
            table.insert(result, trimmed)
        end
    end
    return result
end

local function ApplySettings(settings, gen)
    if not settings then return end
    if gen and type(gen) == "number" and gen >= 0 then
        M.currentGeneration = gen
    end

    local CONFIG = configMod.CONFIG

    if settings["Global_Enabled"] ~= nil then CONFIG.Global.Enabled = settings["Global_Enabled"] end
    if settings["Global_ScanIntervalMs"] ~= nil then CONFIG.Global.ScanIntervalMs = settings["Global_ScanIntervalMs"] end
    if settings["Global_MaxDistance"] ~= nil then
        local d = settings["Global_MaxDistance"]
        if CONFIG.Global then CONFIG.Global.MaxDistance = d end
        if CONFIG.Players then CONFIG.Players.MaxDistance = d end
        if CONFIG.Relics then CONFIG.Relics.MaxDistance = d end
        if CONFIG.Chests then CONFIG.Chests.MaxDistance = d end
        if CONFIG.Eggs then CONFIG.Eggs.MaxDistance = d end
        if CONFIG.Caves then CONFIG.Caves.MaxDistance = d end
        if CONFIG.Loot then CONFIG.Loot.MaxDistance = d end
        if CONFIG.Notes then CONFIG.Notes.MaxDistance = d end
        if CONFIG.Pals then CONFIG.Pals.MaxDistance = d end
    end
    if settings["Global_FontScale"] ~= nil then CONFIG.Global.FontScale = settings["Global_FontScale"] end
    if settings["Global_Language"] ~= nil then CONFIG.Global.Language = settings["Global_Language"] end

    if settings["Players_Enabled"] ~= nil and CONFIG.Players then CONFIG.Players.Enabled = settings["Players_Enabled"] end
    if settings["Relics_Enabled"] ~= nil and CONFIG.Relics then CONFIG.Relics.Enabled = settings["Relics_Enabled"] end
    if settings["Chests_Enabled"] ~= nil and CONFIG.Chests then CONFIG.Chests.Enabled = settings["Chests_Enabled"] end
    if settings["Chests_Filter"] ~= nil and CONFIG.Chests then CONFIG.Chests.Filter = settings["Chests_Filter"] end
    if settings["Chests_GradeFilter"] ~= nil and CONFIG.Chests then CONFIG.Chests.GradeFilter = settings["Chests_GradeFilter"] end
    if settings["Caves_Enabled"] ~= nil and CONFIG.Caves then CONFIG.Caves.Enabled = settings["Caves_Enabled"] end
    if settings["Eggs_Filter"] ~= nil and CONFIG.Eggs then CONFIG.Eggs.Filter = settings["Eggs_Filter"] end
    if settings["Notes_Enabled"] ~= nil and CONFIG.Notes then CONFIG.Notes.Enabled = settings["Notes_Enabled"] end
    
    if settings["Loot_Enabled"] ~= nil and CONFIG.Loot then CONFIG.Loot.Enabled = settings["Loot_Enabled"] end
    if settings["Loot_Filters"] ~= nil and CONFIG.Loot then CONFIG.Loot.Filters = ParseLootFilters(settings["Loot_Filters"]) end

    if settings["Pals_Enabled"] ~= nil and CONFIG.Pals then CONFIG.Pals.Enabled = settings["Pals_Enabled"] end
    if settings["Pals_FilterMode"] ~= nil and CONFIG.Pals then CONFIG.Pals.FilterMode = settings["Pals_FilterMode"] end
    if settings["Pals_ShowPassives"] ~= nil and CONFIG.Pals then CONFIG.Pals.ShowPassives = settings["Pals_ShowPassives"] end
    if settings["Pals_ShowLevel"] ~= nil and CONFIG.Pals then CONFIG.Pals.ShowLevel = settings["Pals_ShowLevel"] end
    if settings["Pals_TrackerList"] ~= nil and CONFIG.Pals then CONFIG.Pals.TrackerPals = ParsePalTrackerList(settings["Pals_TrackerList"], CONFIG.Pals.TrackerPals) end

    if settings["Completionist_ShowHUDTracker"] ~= nil and CONFIG.Completionist then CONFIG.Completionist.ShowHUDTracker = settings["Completionist_ShowHUDTracker"] end
    if settings["Completionist_ShowInMenu"] ~= nil and CONFIG.Completionist then CONFIG.Completionist.ShowInMenu = settings["Completionist_ShowInMenu"] end

    pcall(configMod.SaveConfig)
end

function M.Sync()
    if not M.pmoClient then return end
    pcall(function()
        local curGen = M.pmoClient.generation()
        if curGen > M.currentGeneration then
            local gen, updated, settings = M.pmoClient.sync(M.currentGeneration, function(newValues, g)
                ApplySettings(newValues, g)
            end)
            if updated and gen then
                M.currentGeneration = gen
            end
        end
    end)
end

function M.Init()
    local ok, pmo = pcall(require, "PalModOptionsClient")
    if not ok or not pmo then
        return
    end

    M.pmoClient = pmo
    local CONFIG = configMod.CONFIG

    local schema = {
        api = 1,
        id = "HUDLocator",
        mod_folder = "HUDLocator",
        title = "HUD Locator",
        description = "In-game HUD locator for Pals, Relics, Chests, Eggs, Caves, Loot, Notes, and Players.",
        version = 1,
        apply_mode = "event",
        initial_values = {
            Global_Enabled = CONFIG.Global and CONFIG.Global.Enabled or true,
            Global_ScanIntervalMs = CONFIG.Global and CONFIG.Global.ScanIntervalMs or 1500,
            Global_MaxDistance = (CONFIG.Global and CONFIG.Global.MaxDistance) or (CONFIG.Players and CONFIG.Players.MaxDistance) or 15000.0,
            Global_FontScale = CONFIG.Global and CONFIG.Global.FontScale or 1.0,
            Global_Language = CONFIG.Global and CONFIG.Global.Language or "system",
            Players_Enabled = CONFIG.Players and CONFIG.Players.Enabled or true,
            Relics_Enabled = CONFIG.Relics and CONFIG.Relics.Enabled or true,
            Chests_Enabled = CONFIG.Chests and CONFIG.Chests.Enabled or true,
            Chests_Filter = CONFIG.Chests and CONFIG.Chests.Filter or "Both",
            Chests_GradeFilter = CONFIG.Chests and CONFIG.Chests.GradeFilter or "All",
            Caves_Enabled = CONFIG.Caves and CONFIG.Caves.Enabled or true,
            Eggs_Filter = CONFIG.Eggs and CONFIG.Eggs.Filter or "All",
            Notes_Enabled = CONFIG.Notes and CONFIG.Notes.Enabled or true,
            Loot_Enabled = CONFIG.Loot and CONFIG.Loot.Enabled or false,
            Loot_Filters = FormatLootFilters(CONFIG.Loot and CONFIG.Loot.Filters),
            Pals_Enabled = CONFIG.Pals and CONFIG.Pals.Enabled or true,
            Pals_FilterMode = CONFIG.Pals and CONFIG.Pals.FilterMode or "TrackerListOnly",
            Pals_ShowPassives = CONFIG.Pals and CONFIG.Pals.ShowPassives or true,
            Pals_ShowLevel = CONFIG.Pals and CONFIG.Pals.ShowLevel or true,
            Pals_TrackerList = FormatPalTrackerList(CONFIG.Pals and CONFIG.Pals.TrackerPals),
            Completionist_ShowHUDTracker = CONFIG.Completionist and CONFIG.Completionist.ShowHUDTracker or true,
            Completionist_ShowInMenu = CONFIG.Completionist and CONFIG.Completionist.ShowInMenu or true,
        },
        options = {
            { type = "section", label = "Global Settings" },
            {
                key = "Global_Enabled",
                type = "boolean",
                label = "Master Enable",
                hint = "Enable or disable HUD Locator completely.",
                default = true
            },
            {
                key = "Global_ScanIntervalMs",
                type = "integer",
                label = "Scan Interval (ms)",
                hint = "Background actor scan frequency in milliseconds.",
                default = 1500,
                minimum = 500,
                maximum = 5000,
                step = 250
            },
            {
                key = "Global_MaxDistance",
                type = "number",
                label = "Max Distance",
                hint = "Maximum detection distance for all trackers (in centimeters).",
                default = 15000.0,
                minimum = 5000.0,
                maximum = 100000.0,
                step = 5000.0
            },
            {
                key = "Global_FontScale",
                type = "number",
                label = "Font Scale",
                hint = "Global multiplier for text label sizing.",
                default = 1.0,
                minimum = 0.5,
                maximum = 2.0,
                step = 0.1
            },
            {
                key = "Global_Language",
                type = "enum",
                label = "Language",
                hint = "Override system language setting.",
                default = "system",
                choices = { "system", "en", "es", "ja", "zh-Hans", "zh-Hant", "fr", "it", "de", "ko", "pt-BR", "ru", "th", "vi", "id", "tr", "pl", "es-MX" }
            },

            { type = "section", label = "Trackers & Filters" },
            {
                key = "Players_Enabled",
                type = "boolean",
                label = "Show Players",
                hint = "Display markers for nearby players.",
                default = true
            },
            {
                key = "Relics_Enabled",
                type = "boolean",
                label = "Show Lifmunk Relics",
                hint = "Display markers for Lifmunk Effigies.",
                default = true
            },
            {
                key = "Chests_Enabled",
                type = "boolean",
                label = "Show Chests & Junk",
                hint = "Display markers for treasure chests and scrap loot.",
                default = true
            },
            {
                key = "Chests_Filter",
                type = "enum",
                label = "Chest Filter",
                hint = "Filter between chests, junk items, or both.",
                default = "Both",
                choices = { "Both", "Chests", "Junk" }
            },
            {
                key = "Chests_GradeFilter",
                type = "enum",
                label = "Chest Grade Filter",
                hint = "Filter minimum rarity grade for displayed chests.",
                default = "All",
                choices = { "All", "Grade2+", "Grade3+", "Grade4+", "Grade5+", "Grade6Only", "None" }
            },
            {
                key = "Caves_Enabled",
                type = "boolean",
                label = "Show Dungeon Caves",
                hint = "Display markers for active dungeon entrances.",
                default = true
            },
            {
                key = "Eggs_Filter",
                type = "enum",
                label = "Egg Filter",
                hint = "Filter wild egg size categories.",
                default = "All",
                choices = { "All", "Large+", "HugeOnly", "None" }
            },
            {
                key = "Notes_Enabled",
                type = "boolean",
                label = "Show Journal Notes",
                hint = "Display markers for collectible journals.",
                default = true
            },
            {
                key = "Loot_Enabled",
                type = "boolean",
                label = "Show Ground Loot",
                hint = "Display markers for loose items dropped on the ground.",
                default = false
            },
            {
                key = "Loot_Filters",
                type = "text",
                label = "Tracked Items List",
                hint = "Comma-separated item names to track on ground (e.g. PalSphere, CopperKey).",
                default = "",
                max_length = 256
            },
            {
                key = "Pals_Enabled",
                type = "boolean",
                label = "Show Wild Pals",
                hint = "Display markers for wild Pals.",
                default = true
            },
            {
                key = "Pals_FilterMode",
                type = "enum",
                label = "Pal Filter Mode",
                hint = "Criteria used to filter tracked wild Pals.",
                default = "TrackerListOnly",
                choices = { "TrackerListOnly", "All", "ShinyOnly", "BossOnly", "ShinyOrBoss" }
            },
            {
                key = "Pals_ShowPassives",
                type = "boolean",
                label = "Show Pal Passives",
                hint = "Display passive skills on Pal markers.",
                default = true
            },
            {
                key = "Pals_ShowLevel",
                type = "boolean",
                label = "Show Pal Level",
                hint = "Display level numbers on Pal markers.",
                default = true
            },
            {
                key = "Pals_TrackerList",
                type = "text",
                label = "Tracked Pals List",
                hint = "Comma-separated Pal names to track (e.g. Lamball, Anubis, Jetragon).",
                default = "Lamball, Jetragon, Cattiva",
                max_length = 256
            },
            {
                key = "Completionist_ShowHUDTracker",
                type = "boolean",
                label = "Show Progress Tracker HUD",
                hint = "Display zone completion stats on HUD.",
                default = true
            },
            {
                key = "Completionist_ShowInMenu",
                type = "boolean",
                label = "Show Progress In Menu",
                hint = "Enable completionist summary in quick menu.",
                default = true
            }
        }
    }

    pmo.register_when_ready(schema, function(settings, registration_error)
        if settings ~= nil then
            ApplySettings(settings, pmo.generation())
            M.currentGeneration = pmo.generation()
        end
    end)
end

return M
