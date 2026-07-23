local json = require("HUDLocator.json")

local M = {}
M.ConfigLoadedOnce = false

M.ConfiguratorURL = "https://pal-mod-configurator.dunhas.com/"

-- Config settings
M.CONFIG = {
    Global = {
        Enabled = true,
        Language = "system",
        ScanIntervalMs = 1500,
        FontScale = 1.0,
        Debug = false,
        KeyBinds = {
            Modifier = "ALT",
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
        Filter = "Both",
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
    },
    Loot = {
        Enabled = false,
        MaxDistance = 15000.0,
        Filters = {},
        Style = {
            DrawBox = false,
            FontScale = 1.2,
            SmallFontScale = 0.9,
            TextOffsetZ = 80.0,
            NameColor = { R = 0.2, G = 0.9, B = 0.4, A = 1.0 },
            DistColor = { R = 0.2, G = 0.9, B = 0.4, A = 1.0 },
            BoxColor = { R = 0.8, G = 1.0, B = 0.8, A = 1.0 },
            BorderColor = { R = 0.0, G = 0.0, B = 0.0, A = 1.0 },
            BorderWidth = 1.5,
            BoxPadX = 10.0,
            BoxPadY = 6.0,
            FontCharW = 8.0,
            FontLineH = 12.0
        }
    },
    Notes = {
        Enabled = true,
        MaxDistance = 15000.0,
        Style = {
            DrawBox = false,
            FontScale = 1.2,
            SmallFontScale = 0.9,
            TextOffsetZ = 80.0,
            NameColor = { R = 1.0, G = 0.4, B = 0.4, A = 1.0 },
            DistColor = { R = 1.0, G = 0.4, B = 0.4, A = 1.0 },
            BoxColor = { R = 1.0, G = 0.8, B = 0.8, A = 1.0 },
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

local function GetOldDocumentsConfigFilePath()
    local userProfile = os.getenv("USERPROFILE")
    if not userProfile or userProfile == "" then
        local drive = os.getenv("HOMEDRIVE") or "C:"
        local path = os.getenv("HOMEPATH") or "/Users/Default"
        userProfile = drive .. path
    end
    
    local docsPath = userProfile .. "/Documents"
    
    local oneDrive = os.getenv("OneDrive") or os.getenv("OneDriveConsumer")
    if oneDrive and oneDrive ~= "" then
        docsPath = oneDrive .. "/Documents"
    end
    
    local path = docsPath .. "/My Games/Palworld/ModConfigs/HUDLocator/config.json"
    return string.gsub(path, "\\", "/")
end

local function GetModConfigsDir()
    local localAppData = os.getenv("LOCALAPPDATA")
    if not localAppData or localAppData == "" then
        local userProfile = os.getenv("USERPROFILE")
        if not userProfile or userProfile == "" then
            local drive = os.getenv("HOMEDRIVE") or "C:"
            local path = os.getenv("HOMEPATH") or "/Users/Default"
            userProfile = drive .. path
        end
        localAppData = userProfile .. "/AppData/Local"
    end
    
    local path = localAppData .. "/Pal/Saved/Mods"
    -- Standardize path separator to forward slash for Lua compatibility
    path = string.gsub(path, "\\", "/")
    return path
end

local function GetNewConfigFilePath()
    return GetModConfigsDir() .. "/HUDLocator/config.json"
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
    "FontScale": 1.0,
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
    "Filter": "Both",
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
  },
  "Loot": {
    "Enabled": false,
    "MaxDistance": 15000.0,
    "Filters": [],
    "Style": {
      "DrawBox": false,
      "FontScale": 1.2,
      "SmallFontScale": 0.9,
      "TextOffsetZ": 80.0,
      "NameColor": { "R": 0.2, "G": 0.9, "B": 0.4, "A": 1.0 },
      "DistColor": { "R": 0.2, "G": 0.9, "B": 0.4, "A": 1.0 },
      "BoxColor": { "R": 0.8, "G": 1.0, "B": 0.8, "A": 1.0 },
      "BorderColor": { "R": 0.0, "G": 0.0, "B": 0.0, "A": 1.0 },
      "BorderWidth": 1.5,
      "BoxPadX": 10.0,
      "BoxPadY": 6.0,
      "FontCharW": 8.0,
      "FontLineH": 12.0
    }
  },
  "Notes": {
    "Enabled": true,
    "MaxDistance": 15000.0,
    "Style": {
      "DrawBox": false,
      "FontScale": 1.2,
      "SmallFontScale": 0.9,
      "TextOffsetZ": 80.0,
      "NameColor": { "R": 1.0, "G": 0.4, "B": 0.4, "A": 1.0 },
      "DistColor": { "R": 1.0, "G": 0.4, "B": 0.4, "A": 1.0 },
      "BoxColor": { "R": 1.0, "G": 0.8, "B": 0.8, "A": 1.0 },
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

local function IsArray(t)
    if type(t) ~= "table" then return false end
    local i = 1
    for _ in pairs(t) do
        if t[i] == nil then return false end
        i = i + 1
    end
    return true
end

local function MergeConfig(target, source)
    if not source or type(source) ~= "table" then return end
    for k, defaultVal in pairs(target) do
        local sourceVal = source[k]
        if sourceVal ~= nil then
            if type(defaultVal) == "table" and type(sourceVal) == "table" and not IsArray(defaultVal) then
                MergeConfig(defaultVal, sourceVal)
            else
                target[k] = sourceVal
            end
        end
    end
end

local function IsValidHUDLocatorConfig(parsed)
    if not parsed or type(parsed) ~= "table" then return false end
    if parsed.Players or parsed.Relics or parsed.Chests or parsed.Eggs or parsed.Caves or parsed.Notes or parsed.Global then
        return true
    end
    if parsed.ShowPlayers ~= nil or parsed.ShowRelics ~= nil or parsed.ShowChests ~= nil or parsed.ShowCaves ~= nil then
        return true
    end
    return false
end

function M.LoadConfig()
    local newConfigPath = GetNewConfigFilePath()
    local oldConfigPath = GetConfigFilePath()
    
    -- Try loading from central path first
    local centralLoaded = false
    local file = io.open(newConfigPath, "r")
    if file then
        local content = file:read("*all")
        file:close()
        local parsed = json.parse(content)
        if parsed then
            MergeConfig(M.CONFIG, parsed)
            print("[HUDLocator] Configuration loaded from central path: " .. newConfigPath)
            centralLoaded = true
            M.ConfigLoadedOnce = true
            -- Save back immediately to prune invalid keys and add missing keys
            M.SaveConfig()
        end
    end
    
    -- Central config doesn't exist, check old config files to migrate
    local paths = {
        GetOldDocumentsConfigFilePath(),
        oldConfigPath,
        "Mods/HUDLocator/config.json",
        "Mods/ManagedMods/HUDLocator/config.json",
        "Mods/NativeMods/UE4SS/Mods/HUDLocator/config.json",
        "hudlocator.config.json",
        "config.json"
    }

    if centralLoaded then
        -- Central config already loaded. Clean up old configuration files if they exist.
        for _, path in ipairs(paths) do
            local f = io.open(path, "r")
            if f then
                local content = f:read("*all")
                f:close()
                local parsed = json.parse(content)
                if IsValidHUDLocatorConfig(parsed) then
                    local success, err = os.remove(path)
                    if success then
                        print("[HUDLocator] Cleaned up old configuration file at: " .. path)
                    else
                        print("[HUDLocator] Failed to remove old configuration file at: " .. path .. " - Error: " .. tostring(err))
                    end
                end
            end
        end
        return
    end

    -- If central config failed to load but was previously loaded/saved successfully this session,
    -- DO NOT overwrite it with defaults (the file might be temporarily locked or corrupted).
    if M.ConfigLoadedOnce then
        print("[HUDLocator] WARNING: Failed to read central configuration (file may be locked or invalid). Retaining current in-memory settings.")
        return
    end

    local oldContent = nil
    local migratedPath = nil
    for _, path in ipairs(paths) do
        local f = io.open(path, "r")
        if f then
            local content = f:read("*all")
            f:close()
            local parsed = json.parse(content)
            if IsValidHUDLocatorConfig(parsed) then
                oldContent = content
                migratedPath = path
                print("[HUDLocator] Found existing configuration at: " .. path .. " - Migrating to central path...")
                break
            end
        end
    end

    -- Create central directory structure if missing
    local modConfigDir = GetModConfigsDir() .. "/HUDLocator"
    local outFile = io.open(newConfigPath, "w")
    if not outFile then
        -- Silent directory creation fallback
        pcall(function() os.execute('mkdir "' .. string.gsub(modConfigDir, "/", "\\") .. '" >nul 2>nul') end)
        outFile = io.open(newConfigPath, "w")
    end

    if oldContent then
        local parsed = json.parse(oldContent)
        if parsed then
            -- Handle migrations from old flat config structure to new nested structure
            if parsed.ShowPlayers ~= nil then
                print("[HUDLocator] Migrating old flat config layout to nested layout...")
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
                -- Nested style merges using MergeConfig
                MergeConfig(M.CONFIG, parsed)
            end
            
            -- Save migrated config to central file
            if outFile then
                local str = json.stringify(M.CONFIG)
                outFile:write(str)
                outFile:close()
                print("[HUDLocator] Migrated configuration saved successfully to central path.")
                M.ConfigLoadedOnce = true
                
                -- Delete the migrated file
                if migratedPath then
                    local success, err = os.remove(migratedPath)
                    if success then
                        print("[HUDLocator] Cleaned up old configuration file at: " .. migratedPath)
                    else
                        print("[HUDLocator] Failed to remove old configuration file at: " .. migratedPath .. " - Error: " .. tostring(err))
                    end
                end

                -- Clean up any other remaining old paths
                for _, path in ipairs(paths) do
                    if path ~= migratedPath then
                        local f = io.open(path, "r")
                        if f then
                            local content = f:read("*all")
                            f:close()
                            local otherParsed = json.parse(content)
                            if IsValidHUDLocatorConfig(otherParsed) then
                                local success, err = os.remove(path)
                                if success then
                                    print("[HUDLocator] Cleaned up old configuration file at: " .. path)
                                  else
                                    print("[HUDLocator] Failed to remove old configuration file at: " .. path .. " - Error: " .. tostring(err))
                                end
                            end
                        end
                    end
                end
            end
            return
        end
    end

    -- If no old config, write default config to central path
    if outFile then
        outFile:write(defaultJSON)
        outFile:close()
        print("[HUDLocator] Generated default configuration at: " .. newConfigPath)
        M.ConfigLoadedOnce = true
    else
        print("[HUDLocator] ERROR: Failed to write default config at: " .. newConfigPath)
    end
end

function M.SaveConfig()
    local configPath = GetNewConfigFilePath()
    local outFile = io.open(configPath, "w")
    if outFile then
        local status, str = pcall(function() return json.stringify(M.CONFIG) end)
        if status and str then
            outFile:write(str)
            print("[HUDLocator] Configuration saved successfully to " .. configPath)
            M.ConfigLoadedOnce = true
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
    local statusIntl, IntlLibrary = pcall(function() return StaticFindObject(
        "/Script/Engine.Default__KismetInternationalizationLibrary") end)
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
            print("[HUDLocator] KismetInternationalizationLibrary returned invalid language type or empty string: " ..
            tostring(lang))
        end
    else
        print("[HUDLocator] Could not find KismetInternationalizationLibrary")
    end

    if not langResolved then
        local status, SystemLibrary = pcall(function() return StaticFindObject(
            "/Script/Engine.Default__KismetSystemLibrary") end)
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
                print("[HUDLocator] KismetSystemLibrary returned invalid language type or empty string: " ..
                tostring(lang))
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

M.ResolveActiveLanguage = ResolveActiveLanguage
return M
