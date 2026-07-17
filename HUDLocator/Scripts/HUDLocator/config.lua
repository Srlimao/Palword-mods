local json = require("HUDLocator.json")

local M = {}

-- Config settings
M.CONFIG = {
    Global = {
        Enabled = true,
        Language = "system",
        ScanIntervalMs = 1500,
        Debug = false,
        KeyBinds = {
            ToggleMenu = "F6",
            MenuUp = "UP_ARROW",
            MenuDown = "DOWN_ARROW",
            MenuLeft = "LEFT_ARROW",
            MenuRight = "RIGHT_ARROW"
        }
    },
    Players = {
        Enabled = true,
        MaxDistance = 15000.0,
        GraceRadiusM = 30,
        Style = {
            DrawBox = false,
            FontScale = 1.2,
            SmallFontScale = 0.9,
            TextOffsetZ = 120.0,
            NameColor = { R = 0.0, G = 0.0, B = 0.0, A = 1.0 },
            DistColor = { R = 0.0, G = 0.0, B = 0.0, A = 1.0 },
            BoxColor = { R = 0.8, G = 0.8, B = 1.0, A = 1.0 },
            BorderColor = { R = 0.0, G = 0.0, B = 0.0, A = 1.0 },
            BorderWidth = 1.5,
            BoxPadX = 10.0,
            BoxPadY = 6.0,
            FontCharW = 8.0,
            FontLineH = 12.0
        }
    },
    Relics = {
        Enabled = true,
        MaxDistance = 15000.0,
        Style = {
            DrawBox = false,
            FontScale = 1.2,
            SmallFontScale = 0.9,
            TextOffsetZ = 80.0,
            NameColor = { R = 0.1, G = 0.9, B = 0.9, A = 1.0 },
            DistColor = { R = 0.1, G = 0.9, B = 0.9, A = 1.0 },
            BoxColor = { R = 0.8, G = 0.8, B = 1.0, A = 1.0 },
            BorderColor = { R = 0.0, G = 0.0, B = 0.0, A = 1.0 },
            BorderWidth = 1.5,
            BoxPadX = 10.0,
            BoxPadY = 6.0,
            FontCharW = 8.0,
            FontLineH = 12.0
        }
    },
    Chests = {
        Enabled = true,
        MaxDistance = 15000.0,
        Style = {
            DrawBox = false,
            FontScale = 1.2,
            SmallFontScale = 0.9,
            TextOffsetZ = 80.0,
            NameColor = { R = 0.9, G = 0.7, B = 0.1, A = 1.0 },
            DistColor = { R = 0.9, G = 0.7, B = 0.1, A = 1.0 },
            BoxColor = { R = 0.8, G = 0.8, B = 1.0, A = 1.0 },
            BorderColor = { R = 0.0, G = 0.0, B = 0.0, A = 1.0 },
            BorderWidth = 1.5,
            BoxPadX = 10.0,
            BoxPadY = 6.0,
            FontCharW = 8.0,
            FontLineH = 12.0
        }
    },
    Eggs = {
        Filter = "All",
        MaxDistance = 15000.0,
        Style = {
            DrawBox = false,
            FontScale = 1.2,
            SmallFontScale = 0.9,
            TextOffsetZ = 80.0,
            NameColor = { R = 0.8, G = 0.5, B = 0.8, A = 1.0 },
            DistColor = { R = 0.8, G = 0.5, B = 0.8, A = 1.0 },
            BoxColor = { R = 0.8, G = 0.8, B = 1.0, A = 1.0 },
            BorderColor = { R = 0.0, G = 0.0, B = 0.0, A = 1.0 },
            BorderWidth = 1.5,
            BoxPadX = 10.0,
            BoxPadY = 6.0,
            FontCharW = 8.0,
            FontLineH = 12.0
        }
    },
    Caves = {
        Enabled = true,
        MaxDistance = 15000.0,
        Style = {
            DrawBox = false,
            FontScale = 1.2,
            SmallFontScale = 0.9,
            TextOffsetZ = 80.0,
            NameColor = { R = 0.6, G = 0.2, B = 0.9, A = 1.0 },
            DistColor = { R = 0.6, G = 0.2, B = 0.9, A = 1.0 },
            BoxColor = { R = 0.8, G = 0.8, B = 1.0, A = 1.0 },
            BorderColor = { R = 0.0, G = 0.0, B = 0.0, A = 1.0 },
            BorderWidth = 1.5,
            BoxPadX = 10.0,
            BoxPadY = 6.0,
            FontCharW = 8.0,
            FontLineH = 12.0
        }
    }
}

function M.DebugPrint(msg)
    if M.CONFIG.Debug then
        print("[HUDLocator] " .. tostring(msg))
    end
end

local function GetConfigFilePath()
    local info = debug.getinfo(1, "S")
    if info and info.source and info.source:sub(1, 1) == "@" then
        local src = info.source:sub(2)
        -- Match the parent directory of "Scripts/HUDLocator/config.lua"
        local modDir = src:match("(.*)[/\\]Scripts[/\\]HUDLocator[/\\]config%.lua")
        if modDir then
            return modDir .. "/config.json"
        end
    end
    return "Mods/HUDLocator/config.json"
end

local defaultJSON = [[{
  "Global": {
    "Enabled": true,
    "Language": "system",
    "ScanIntervalMs": 1500,
    "Debug": false,
    "KeyBinds": {
      "ToggleMenu": "F6",
      "MenuUp": "UP_ARROW",
      "MenuDown": "DOWN_ARROW",
      "MenuLeft": "LEFT_ARROW",
      "MenuRight": "RIGHT_ARROW"
    }
  },
  "Players": {
    "Enabled": true,
    "MaxDistance": 15000.0,
    "GraceRadiusM": 30,
    "Style": {
      "DrawBox": false,
      "FontScale": 1.2,
      "SmallFontScale": 0.9,
      "TextOffsetZ": 120.0,
      "NameColor": { "R": 0.0, "G": 0.0, "B": 0.0, "A": 1.0 },
      "DistColor": { "R": 0.0, "G": 0.0, "B": 0.0, "A": 1.0 },
      "BoxColor": { "R": 0.8, "G": 0.8, "B": 1.0, "A": 1.0 },
      "BorderColor": { "R": 0.0, "G": 0.0, "B": 0.0, "A": 1.0 },
      "BorderWidth": 1.5,
      "BoxPadX": 10.0,
      "BoxPadY": 6.0,
      "FontCharW": 8.0,
      "FontLineH": 12.0
    }
  },
  "Relics": {
    "Enabled": true,
    "MaxDistance": 15000.0,
    "Style": {
      "DrawBox": false,
      "FontScale": 1.2,
      "SmallFontScale": 0.9,
      "TextOffsetZ": 80.0,
      "NameColor": { "R": 0.1, "G": 0.9, "B": 0.9, "A": 1.0 },
      "DistColor": { "R": 0.1, "G": 0.9, "B": 0.9, "A": 1.0 },
      "BoxColor": { "R": 0.8, "G": 0.8, "B": 1.0, "A": 1.0 },
      "BorderColor": { "R": 0.0, "G": 0.0, "B": 0.0, "A": 1.0 },
      "BorderWidth": 1.5,
      "BoxPadX": 10.0,
      "BoxPadY": 6.0,
      "FontCharW": 8.0,
      "FontLineH": 12.0
    }
  },
  "Chests": {
    "Enabled": true,
    "MaxDistance": 15000.0,
    "Style": {
      "DrawBox": false,
      "FontScale": 1.2,
      "SmallFontScale": 0.9,
      "TextOffsetZ": 80.0,
      "NameColor": { "R": 0.9, "G": 0.7, "B": 0.1, "A": 1.0 },
      "DistColor": { "R": 0.9, "G": 0.7, "B": 0.1, "A": 1.0 },
      "BoxColor": { "R": 0.8, "G": 0.8, "B": 1.0, "A": 1.0 },
      "BorderColor": { "R": 0.0, "G": 0.0, "B": 0.0, "A": 1.0 },
      "BorderWidth": 1.5,
      "BoxPadX": 10.0,
      "BoxPadY": 6.0,
      "FontCharW": 8.0,
      "FontLineH": 12.0
    }
  },
  "Eggs": {
    "Filter": "All",
    "MaxDistance": 15000.0,
    "Style": {
      "DrawBox": false,
      "FontScale": 1.2,
      "SmallFontScale": 0.9,
      "TextOffsetZ": 80.0,
      "NameColor": { "R": 0.8, "G": 0.5, "B": 0.8, "A": 1.0 },
      "DistColor": { "R": 0.8, "G": 0.5, "B": 0.8, "A": 1.0 },
      "BoxColor": { "R": 0.8, "G": 0.8, "B": 1.0, "A": 1.0 },
      "BorderColor": { "R": 0.0, "G": 0.0, "B": 0.0, "A": 1.0 },
      "BorderWidth": 1.5,
      "BoxPadX": 10.0,
      "BoxPadY": 6.0,
      "FontCharW": 8.0,
      "FontLineH": 12.0
    }
  },
  "Caves": {
    "Enabled": true,
    "MaxDistance": 15000.0,
    "Style": {
      "DrawBox": false,
      "FontScale": 1.2,
      "SmallFontScale": 0.9,
      "TextOffsetZ": 80.0,
      "NameColor": { "R": 0.6, "G": 0.2, "B": 0.9, "A": 1.0 },
      "DistColor": { "R": 0.6, "G": 0.2, "B": 0.9, "A": 1.0 },
      "BoxColor": { "R": 0.8, "G": 0.8, "B": 1.0, "A": 1.0 },
      "BorderColor": { "R": 0.0, "G": 0.0, "B": 0.0, "A": 1.0 },
      "BorderWidth": 1.5,
      "BoxPadX": 10.0,
      "BoxPadY": 6.0,
      "FontCharW": 8.0,
      "FontLineH": 12.0
    }
  }
}
]]

function M.LoadConfig()
    local configPath = GetConfigFilePath()
    local paths = {
        configPath,
        "Mods/HUDLocator/config.json",
        "Mods/ManagedMods/HUDLocator/config.json",
        "Mods/NativeMods/UE4SS/Mods/HUDLocator/config.json",
        "hudlocator.config.json",
        "config.json"
    }
    
    local file = nil
    local actualPath = nil
    for _, path in ipairs(paths) do
        file = io.open(path, "r")
        if file then 
            actualPath = path
            break 
        end
    end
    
    if not file then
        print("[HUDLocator] Config file not found. Generating default at: " .. configPath)
        local outFile = io.open(configPath, "w")
        if not outFile then
            configPath = "hudlocator.config.json"
            outFile = io.open(configPath, "w")
        end
        if outFile then
            outFile:write(defaultJSON)
            outFile:close()
            print("[HUDLocator] Default config generated at " .. configPath)
        else
            print("[HUDLocator] Failed to generate default config.")
        end
        return
    end
    
    local content = file:read("*all")
    file:close()
    
    local parsed = json.parse(content)
    if parsed then
        -- Handle migrations from old flat config to new nested config
        if parsed.ShowPlayers ~= nil then
            print("[HUDLocator] Migrating old flat config to nested tracker config...")
            M.CONFIG.Players.Enabled = parsed.ShowPlayers
            M.CONFIG.Relics.Enabled = parsed.ShowRelics
            M.CONFIG.Chests.Enabled = parsed.ShowChests
            M.CONFIG.Caves.Enabled = parsed.ShowCaves
            if parsed.EggFilter then M.CONFIG.Eggs.Filter = parsed.EggFilter end
            if parsed.MaxDistance then
                M.CONFIG.Players.MaxDistance = parsed.MaxDistance
                M.CONFIG.Relics.MaxDistance = parsed.MaxDistance
                M.CONFIG.Chests.MaxDistance = parsed.MaxDistance
                M.CONFIG.Caves.MaxDistance = parsed.MaxDistance
                M.CONFIG.Eggs.MaxDistance = parsed.MaxDistance
            end
            if parsed.ScanIntervalMs then M.CONFIG.Global.ScanIntervalMs = parsed.ScanIntervalMs end
            if parsed.GraceRadiusM then M.CONFIG.Players.GraceRadiusM = parsed.GraceRadiusM end
            if parsed.Enabled ~= nil then M.CONFIG.Global.Enabled = parsed.Enabled end
        else
            for k, section in pairs(parsed) do
                if type(section) == "table" and M.CONFIG[k] then
                    for subK, subV in pairs(section) do
                        if k == "Players" and subK ~= "Style" and M.CONFIG[k].Style and M.CONFIG[k].Style[subK] ~= nil then
                            -- Migrate old Players flat styling properties to Style
                            if type(subV) == "table" and type(M.CONFIG[k].Style[subK]) == "table" then
                                for cK, cV in pairs(subV) do
                                    M.CONFIG[k].Style[subK][cK] = cV
                                end
                            else
                                M.CONFIG[k].Style[subK] = subV
                            end
                        elseif k ~= "Players" and k ~= "Global" and subK == "Color" then
                            -- Migrate old Color to Style.NameColor and Style.DistColor
                            if M.CONFIG[k].Style then
                                for cK, cV in pairs(subV) do
                                    M.CONFIG[k].Style.NameColor[cK] = cV
                                    M.CONFIG[k].Style.DistColor[cK] = cV
                                end
                            end
                        elseif k ~= "Players" and k ~= "Global" and subK ~= "Style" and M.CONFIG[k].Style and M.CONFIG[k].Style[subK] ~= nil then
                            -- Migrate old Relics/Chests/Eggs/Caves flat styling properties to Style
                            if type(subV) == "table" and type(M.CONFIG[k].Style[subK]) == "table" then
                                for cK, cV in pairs(subV) do
                                    M.CONFIG[k].Style[subK][cK] = cV
                                end
                            else
                                M.CONFIG[k].Style[subK] = subV
                            end
                        elseif type(subV) == "table" and type(M.CONFIG[k][subK]) == "table" then
                            for cK, cV in pairs(subV) do
                                if type(cV) == "table" and type(M.CONFIG[k][subK][cK]) == "table" then
                                    for dK, dV in pairs(cV) do
                                        M.CONFIG[k][subK][cK][dK] = dV
                                    end
                                else
                                    M.CONFIG[k][subK][cK] = cV
                                end
                            end
                        else
                            M.CONFIG[k][subK] = subV
                        end
                    end
                end
            end
        end
        print("[HUDLocator] Config loaded successfully!")
    else
        print("[HUDLocator] Failed to parse config, using defaults.")
    end
    
    -- Auto-save new attributes so the user's config file updates instantly
    M.SaveConfig()
end

function M.SaveConfig()
    local configPath = GetConfigFilePath()
    local outFile = io.open(configPath, "w")
    if outFile then
        local status, str = pcall(function() return json.stringify(M.CONFIG) end)
        if status and str then
            outFile:write(str)
            print("[HUDLocator] Configuration saved successfully to " .. configPath)
        else
            print("[HUDLocator] Failed to stringify config: " .. tostring(str))
        end
        outFile:close()
    else
        print("[HUDLocator] Failed to open config file for writing: " .. configPath)
    end
end

M.Translations = {}

local function GetTranslationsFilePath()
    local info = debug.getinfo(1, "S")
    if info and info.source and info.source:sub(1, 1) == "@" then
        local src = info.source:sub(2)
        local modDir = src:match("(.*)[/\\]Scripts[/\\]HUDLocator[/\\]config%.lua")
        if modDir then
            return modDir .. "/Scripts/HUDLocator/translations.json"
        end
    end
    return "Mods/HUDLocator/Scripts/HUDLocator/translations.json"
end

M.AllTranslations = nil

function M.LoadTranslations()
    local transPath = GetTranslationsFilePath()
    local file = io.open(transPath, "r")
    
    if not file then
        print("[HUDLocator] Translations file not found at: " .. transPath)
        return
    end
    
    local content = file:read("*all")
    file:close()
    
    local parsed = json.parse(content)
    if parsed then
        M.AllTranslations = parsed
        print("[HUDLocator] Translations file loaded successfully.")
    else
        print("[HUDLocator] Failed to parse translations.")
    end
end

local LastLangCheck = 0
local CachedLang = nil

local function ResolveActiveLanguage()
    if M.CONFIG and M.CONFIG.Global and M.CONFIG.Global.Language and M.CONFIG.Global.Language ~= "system" and M.CONFIG.Global.Language ~= "" then
        return M.CONFIG.Global.Language
    end

    if CachedLang then
        return CachedLang
    end
    
    local now = os.time()
    if now - LastLangCheck < 5 then
        return "en"
    end
    LastLangCheck = now
    
    local activeLang = "en"
    local statusIntl, IntlLibrary = pcall(function() return StaticFindObject("/Script/Engine.Default__KismetInternationalizationLibrary") end)
    local langResolved = false
    
    if statusIntl and IntlLibrary then
        local langStatus, lang = pcall(function() return IntlLibrary:GetCurrentLanguage() end)
        if langStatus and type(lang) == "string" and lang ~= "" then
            print("[HUDLocator] KismetInternationalizationLibrary string language: " .. tostring(lang))
            activeLang = lang
            langResolved = true
        elseif langStatus and type(lang) == "userdata" then
            local sStatus, s = pcall(function() return lang:ToString() end)
            if sStatus and s and s ~= "" then
                print("[HUDLocator] KismetInternationalizationLibrary userdata language: " .. tostring(s))
                activeLang = s
                langResolved = true
            end
        else
            print("[HUDLocator] KismetInternationalizationLibrary returned invalid language type or empty string: " .. tostring(lang))
        end
    else
        print("[HUDLocator] Could not find KismetInternationalizationLibrary")
    end
    
    if not langResolved then
        local status, SystemLibrary = pcall(function() return StaticFindObject("/Script/Engine.Default__KismetSystemLibrary") end)
        if status and SystemLibrary then
            local langStatus, lang = pcall(function() return SystemLibrary:GetDefaultLanguage() end)
            if langStatus and type(lang) == "string" and lang ~= "" then
                print("[HUDLocator] KismetSystemLibrary string language: " .. tostring(lang))
                activeLang = lang
                langResolved = true
            elseif langStatus and type(lang) == "userdata" then
                local sStatus, s = pcall(function() return lang:ToString() end)
                if sStatus and s and s ~= "" then
                    print("[HUDLocator] KismetSystemLibrary userdata language: " .. tostring(s))
                    activeLang = s
                    langResolved = true
                end
            else
                print("[HUDLocator] KismetSystemLibrary returned invalid language type or empty string: " .. tostring(lang))
            end
        else
            print("[HUDLocator] Could not find KismetSystemLibrary")
        end
    end
    
    if langResolved then
        CachedLang = activeLang
        print("[HUDLocator] Game language locked to: " .. activeLang)
    else
        print("[HUDLocator] Failed to resolve any language, defaulting to: " .. activeLang)
    end
    
    return activeLang
end

function M.GetTranslation(key, default)
    if M.AllTranslations then
        local activeLang = ResolveActiveLanguage()
        
        -- Try direct lookup
        local langDict = M.AllTranslations[activeLang]
        
        -- Try case-insensitive / normalized lookup if direct lookup fails
        if not langDict then
            local lowerLang = activeLang:lower()
            local mappedLang = nil
            if lowerLang == "zh-cn" or lowerLang == "zh-sg" or lowerLang:find("hans") then
                mappedLang = "zh-Hans"
            elseif lowerLang == "zh-tw" or lowerLang == "zh-hk" or lowerLang:find("hant") then
                mappedLang = "zh-Hant"
            elseif lowerLang == "pt-br" or lowerLang == "pt" then
                mappedLang = "pt-BR"
            elseif lowerLang == "es-mx" then
                mappedLang = "es-MX"
            end
            
            if mappedLang then
                langDict = M.AllTranslations[mappedLang]
            end
        end
        
        -- Try short language code fallback (e.g. "en-us" -> "en")
        if not langDict then
            local shortLang = string.sub(activeLang, 1, 2):lower()
            for k, v in pairs(M.AllTranslations) do
                if k:lower() == shortLang then
                    langDict = v
                    break
                end
            end
        end
        
        -- Ultimate fallback to English
        if not langDict then
            langDict = M.AllTranslations["en"]
        end
        
        if langDict and langDict[key] and langDict[key] ~= "" then
            return langDict[key]
        end
    end
    return default or key
end

-- Initialize configuration on load
pcall(M.LoadConfig)
pcall(M.LoadTranslations)

return M
