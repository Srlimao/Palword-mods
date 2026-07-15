local M = {}

-- Default settings
M.CONFIG = {
    Enabled = true,
    Language = "system",
    HUDX = nil,
    HUDY = nil,
    HUDScale = 1.5,
    ScanIntervalMs = 1000,
    Debug = false,
    -- Colors for HUD drawing
    CardBg = { R = 0.05, G = 0.07, B = 0.15, A = 0.85 },
    BorderColor = { R = 0.0, G = 0.95, B = 1.0, A = 0.6 },
    ShadowColor = { R = 0.0, G = 0.0, B = 0.0, A = 0.9 },
    TextColorEnabled = { R = 0.0, G = 0.96, B = 0.83, A = 1.0 },   -- Neon Green/Cyan
    TextColorDisabled = { R = 1.0, G = 0.35, B = 0.37, A = 1.0 },  -- Neon Red/Orange
    TextColorLabel = { R = 0.9, G = 0.9, B = 0.95, A = 1.0 },       -- Sleek White/Gray
    -- Mappings for friendly names
    AccessoryNames = {
        Accessory_NonKilling = "Ring of Mercy",
        Accessory_Attack_1 = "Attack Pendant",
        Accessory_Attack_2 = "Attack Pendant +1",
        Accessory_Attack_3 = "Attack Pendant +2",
        Accessory_Defense_1 = "Defense Pendant",
        Accessory_Defense_2 = "Defense Pendant +1",
        Accessory_Defense_3 = "Defense Pendant +2",
        Accessory_HP_1 = "Life Pendant",
        Accessory_HP_2 = "Life Pendant +1",
        Accessory_HP_3 = "Life Pendant +2",
        Accessory_HeatResist_1 = "Heat Resistant Underwear",
        Accessory_HeatResist_2 = "Heat Resistant Underwear +1",
        Accessory_HeatResist_3 = "Heat Resistant Underwear +2",
        Accessory_ColdResist_1 = "Thermal Underwear",
        Accessory_ColdResist_2 = "Thermal Underwear +1",
        Accessory_ColdResist_3 = "Thermal Underwear +2",
        Accessory_WorkSpeed_1 = "Work Pendant",
        Accessory_WorkSpeed_2 = "Work Pendant +1",
        Accessory_WorkSpeed_3 = "Work Pendant +2",
    }
}

function M.DebugPrint(msg)
    if M.CONFIG.Debug then
        print("[AccessoryToggler] " .. tostring(msg))
    end
end

-- Lightweight JSON parser/stringifier in pure Lua (since UE4SS may not expose json globally)
local json = {}
function json.parse(str)
    str = str:gsub("//[^\n]*", ""):gsub("/%*.-%*/", "")
    local pos = 1
    local function skip_whitespace()
        while pos <= #str do
            local c = str:sub(pos, pos)
            if c == ' ' or c == '\t' or c == '\n' or c == '\r' then pos = pos + 1 else break end
        end
    end
    local parse_value
    local function parse_object()
        local obj = {}
        pos = pos + 1
        while pos <= #str do
            skip_whitespace()
            local c = str:sub(pos, pos)
            if c == '}' then pos = pos + 1 return obj end
            if c == ',' then pos = pos + 1 skip_whitespace() c = str:sub(pos, pos) end
            if c == '"' then
                pos = pos + 1
                local start = pos
                while pos <= #str and str:sub(pos, pos) ~= '"' do pos = pos + 1 end
                local key = str:sub(start, pos - 1)
                pos = pos + 1
                skip_whitespace()
                if str:sub(pos, pos) ~= ':' then error("Expected ':'") end
                pos = pos + 1
                local val = parse_value()
                obj[key] = val
            else pos = pos + 1 end
        end
        return obj
    end
    local function parse_array()
        local arr = {}
        pos = pos + 1
        while pos <= #str do
            skip_whitespace()
            local c = str:sub(pos, pos)
            if c == ']' then pos = pos + 1 return arr end
            if c == ',' then pos = pos + 1 skip_whitespace() end
            table.insert(arr, parse_value())
        end
        return arr
    end
    local function parse_string()
        pos = pos + 1
        local start = pos
        while pos <= #str do
            local c = str:sub(pos, pos)
            if c == '"' and str:sub(pos - 1, pos - 1) ~= '\\' then break end
            pos = pos + 1
        end
        local val = str:sub(start, pos - 1)
        pos = pos + 1
        return val
    end
    local function parse_number()
        local start = pos
        while pos <= #str do
            local c = str:sub(pos, pos)
            if c:match("[%d%.%-eE%+]") then pos = pos + 1 else break end
        end
        return tonumber(str:sub(start, pos - 1))
    end
    parse_value = function()
        skip_whitespace()
        local c = str:sub(pos, pos)
        if c == '{' then return parse_object()
        elseif c == '[' then return parse_array()
        elseif c == '"' then return parse_string()
        elseif c == 't' and str:sub(pos, pos + 3) == 'true' then pos = pos + 4 return true
        elseif c == 'f' and str:sub(pos, pos + 4) == 'false' then pos = pos + 5 return false
        elseif c == 'n' and str:sub(pos, pos + 3) == 'null' then pos = pos + 4 return nil
        elseif c:match("[%d%.%-]") then return parse_number()
        else error("Unexpected character '" .. c .. "' at position " .. pos) end
    end
    local status, val = pcall(parse_value)
    if status then return val else return nil end
end

function json.stringify(val)
    local t = type(val)
    if t == "table" then
        local isArray = true
        local maxIndex = 0
        for k, v in pairs(val) do
            if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
                isArray = false
                break
            end
            if k > maxIndex then maxIndex = k end
        end
        if isArray then
            local parts = {}
            for i = 1, maxIndex do
                table.insert(parts, json.stringify(val[i]))
            end
            return "[" .. table.concat(parts, ", ") .. "]"
        else
            local parts = {}
            for k, v in pairs(val) do
                table.insert(parts, '"' .. k .. '": ' .. json.stringify(v))
            end
            return "{" .. table.concat(parts, ", ") .. "}"
        end
    elseif t == "string" then
        return '"' .. val .. '"'
    elseif t == "number" or t == "boolean" then
        return tostring(val)
    else
        return "null"
    end
end

local function GetConfigFilePath()
    local info = debug.getinfo(1, "S")
    if info and info.source and info.source:sub(1, 1) == "@" then
        local src = info.source:sub(2)
        local modDir = src:match("(.*)[/\\]Scripts[/\\]AccessoryToggler[/\\]config%.lua")
        if modDir then
            return modDir .. "/config.json"
        end
    end
    return "Mods/AccessoryToggler/config.json"
end

function M.LoadConfig()
    local configPath = GetConfigFilePath()
    local paths = {
        configPath,
        "Mods/AccessoryToggler/config.json",
        "Mods/ManagedMods/AccessoryToggler/config.json",
        "config.json"
    }
    
    local file = nil
    for _, path in ipairs(paths) do
        file = io.open(path, "r")
        if file then break end
    end
    
    if not file then
        -- Generate default config
        local outFile = io.open(configPath, "w")
        if outFile then
            outFile:write(json.stringify(M.CONFIG))
            outFile:close()
        end
        return
    end
    
    local content = file:read("*all")
    file:close()
    
    local parsed = json.parse(content)
    if parsed then
        for k, v in pairs(parsed) do
            if type(v) == "table" and M.CONFIG[k] and type(M.CONFIG[k]) == "table" then
                for subK, subV in pairs(v) do
                    M.CONFIG[k][subK] = subV
                end
            else
                M.CONFIG[k] = v
            end
        end
    end
    -- Self-healing default coordinate migration
    if M.CONFIG.HUDX == 50.0 then M.CONFIG.HUDX = nil end
    if M.CONFIG.HUDY == 400.0 then M.CONFIG.HUDY = nil end
end

M.EditModeActive = false

function M.ToggleEditMode()
    M.EditModeActive = not M.EditModeActive
    if M.EditModeActive then
        print("[AccessoryToggler] HUD Edit Mode Activated!")
    else
        print("[AccessoryToggler] HUD Edit Mode Deactivated! Saving layout changes...")
        M.SaveConfig()
    end
end

function M.SaveConfig()
    local configPath = GetConfigFilePath()
    local outFile = io.open(configPath, "w")
    if outFile then
        local str = json.stringify(M.CONFIG)
        outFile:write(str)
        outFile:close()
    end
end

M.Translations = {}

local function GetTranslationsFilePath()
    local info = debug.getinfo(1, "S")
    if info and info.source and info.source:sub(1, 1) == "@" then
        local src = info.source:sub(2)
        local modDir = src:match("(.*)[/\\]Scripts[/\\]AccessoryToggler[/\\]config%.lua")
        if modDir then
            return modDir .. "/Scripts/AccessoryToggler/translations.json"
        end
    end
    return "Mods/AccessoryToggler/Scripts/AccessoryToggler/translations.json"
end

M.AllTranslations = nil

function M.LoadTranslations()
    local transPath = GetTranslationsFilePath()
    local file = io.open(transPath, "r")
    
    if not file then
        print("[AccessoryToggler] Translations file not found at: " .. transPath)
        return
    end
    
    local content = file:read("*all")
    file:close()
    
    local parsed = json.parse(content)
    if parsed then
        M.AllTranslations = parsed
        print("[AccessoryToggler] Translations file loaded successfully.")
    else
        print("[AccessoryToggler] Failed to parse translations.")
    end
end

local LastLangCheck = 0
local CachedLang = nil

local function ResolveActiveLanguage()
    if M.CONFIG and M.CONFIG.Language and M.CONFIG.Language ~= "system" and M.CONFIG.Language ~= "" then
        return M.CONFIG.Language
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
            print("[AccessoryToggler] KismetInternationalizationLibrary string language: " .. tostring(lang))
            activeLang = lang
            langResolved = true
        elseif langStatus and type(lang) == "userdata" then
            local sStatus, s = pcall(function() return lang:ToString() end)
            if sStatus and s and s ~= "" then
                print("[AccessoryToggler] KismetInternationalizationLibrary userdata language: " .. tostring(s))
                activeLang = s
                langResolved = true
            end
        else
            print("[AccessoryToggler] KismetInternationalizationLibrary returned invalid language type or empty string: " .. tostring(lang))
        end
    else
        print("[AccessoryToggler] Could not find KismetInternationalizationLibrary")
    end
    
    if not langResolved then
        local status, SystemLibrary = pcall(function() return StaticFindObject("/Script/Engine.Default__KismetSystemLibrary") end)
        if status and SystemLibrary then
            local langStatus, lang = pcall(function() return SystemLibrary:GetDefaultLanguage() end)
            if langStatus and type(lang) == "string" and lang ~= "" then
                print("[AccessoryToggler] KismetSystemLibrary string language: " .. tostring(lang))
                activeLang = lang
                langResolved = true
            elseif langStatus and type(lang) == "userdata" then
                local sStatus, s = pcall(function() return lang:ToString() end)
                if sStatus and s and s ~= "" then
                    print("[AccessoryToggler] KismetSystemLibrary userdata language: " .. tostring(s))
                    activeLang = s
                    langResolved = true
                end
            else
                print("[AccessoryToggler] KismetSystemLibrary returned invalid language type or empty string: " .. tostring(lang))
            end
        else
            print("[AccessoryToggler] Could not find KismetSystemLibrary")
        end
    end
    
    if langResolved then
        CachedLang = activeLang
        print("[AccessoryToggler] Game language locked to: " .. activeLang)
    else
        print("[AccessoryToggler] Failed to resolve any language, defaulting to: " .. activeLang)
    end
    
    return activeLang
end

function M.GetTranslation(key, default)
    if M.AllTranslations then
        local activeLang = ResolveActiveLanguage()
        local langDict = M.AllTranslations[activeLang]
        if not langDict then
            local shortLang = string.sub(activeLang, 1, 2)
            langDict = M.AllTranslations[shortLang]
        end
        if not langDict then
            langDict = M.AllTranslations["en"]
        end
        if langDict and langDict[key] and langDict[key] ~= "" then
            return langDict[key]
        end
    end
    return default or key
end

pcall(M.LoadConfig)
pcall(M.LoadTranslations)

return M
