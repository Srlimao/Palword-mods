local M = {}
M.ConfigLoadedOnce = false

-- Default configuration settings
M.CONFIG = {
    Enabled = true,
    Debug = false,
    KeyBinds = {
        Modifier = "ALT",
        SwitchPreset1 = "FIVE",
        SwitchPreset2 = "SIX",
        SwitchPreset3 = "SEVEN",
        SwitchPreset4 = "EIGHT",
        SwitchPreset5 = "NINE"
    }
}

function M.DebugPrint(msg)
    if M.CONFIG.Debug then
        print("[PresetSwitch] " .. tostring(msg))
    end
end

-- Lightweight JSON parser/stringifier in pure Lua
local json = {}

function json.parse(str)
    if not str or type(str) ~= "string" or #str == 0 then return nil end
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
            if c == '}' then
                pos = pos + 1
                return obj
            end
            if c == ',' then
                pos = pos + 1
                skip_whitespace()
                c = str:sub(pos, pos)
            end
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
            else
                pos = pos + 1
            end
        end
        return obj
    end
    local function parse_array()
        local arr = {}
        pos = pos + 1
        while pos <= #str do
            skip_whitespace()
            local c = str:sub(pos, pos)
            if c == ']' then
                pos = pos + 1
                return arr
            end
            if c == ',' then
                pos = pos + 1
                skip_whitespace()
            end
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
        if c == '{' then
            return parse_object()
        elseif c == '[' then
            return parse_array()
        elseif c == '"' then
            return parse_string()
        elseif c == 't' and str:sub(pos, pos + 3) == 'true' then
            pos = pos + 4
            return true
        elseif c == 'f' and str:sub(pos, pos + 4) == 'false' then
            pos = pos + 5
            return false
        elseif c == 'n' and str:sub(pos, pos + 3) == 'null' then
            pos = pos + 4
            return nil
        elseif c:match("[%d%.%-]") then
            return parse_number()
        else
            error("Unexpected character '" .. c .. "' at position " .. pos)
        end
    end
    local status, val = pcall(parse_value)
    if status then return val else return nil end
end

function json.stringify(val, indent)
    indent = indent or 0
    local indent_str = string.rep("  ", indent)
    local next_indent_str = string.rep("  ", indent + 1)

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
            if #val == 0 and maxIndex == 0 then return "[]" end
            local parts = {}
            for i = 1, #val do
                table.insert(parts, json.stringify(val[i], indent + 1))
            end
            return "[\n" .. next_indent_str .. table.concat(parts, ",\n" .. next_indent_str) .. "\n" .. indent_str .. "]"
        else
            local parts = {}
            for k, v in pairs(val) do
                table.insert(parts, string.format("%q: %s", tostring(k), json.stringify(v, indent + 1)))
            end
            if #parts == 0 then return "{}" end
            return "{\n" .. next_indent_str .. table.concat(parts, ",\n" .. next_indent_str) .. "\n" .. indent_str .. "}"
        end
    elseif t == "string" then
        return string.format("%q", val)
    elseif t == "number" or t == "boolean" then
        return tostring(val)
    else
        return "null"
    end
end

M.json = json

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
    return string.gsub(path, "\\", "/")
end

local function GetNewConfigFilePath()
    return GetModConfigsDir() .. "/PresetSwitch/config.json"
end

local function GetConfigFilePath()
    local info = debug.getinfo(1, "S")
    if info and info.source and info.source:sub(1, 1) == "@" then
        local src = info.source:sub(2)
        local modDir = src:match("(.*)[/\\]Scripts[/\\]PresetSwitch[/\\]config%.lua")
        if modDir then
            return modDir .. "/config.json"
        end
    end
    return "Mods/PresetSwitch/config.json"
end

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

function M.LoadConfig()
    local newPath = GetNewConfigFilePath()
    local file = io.open(newPath, "r")
    local pathUsed = newPath

    if not file then
        local localPath = GetConfigFilePath()
        file = io.open(localPath, "r")
        pathUsed = localPath
    end

    if file then
        local content = file:read("*a")
        file:close()
        local parsed = json.parse(content)
        if parsed then
            MergeConfig(M.CONFIG, parsed)
            print("[PresetSwitch] Configuration loaded successfully from: " .. pathUsed)
            M.ConfigLoadedOnce = true
            return true
        end
    end

    print("[PresetSwitch] Configuration file not found. Creating default at: " .. newPath)
    M.SaveConfig()
    M.ConfigLoadedOnce = true
    return false
end

function M.SaveConfig()
    local path = GetNewConfigFilePath()
    local file = io.open(path, "w")
    if not file then
        -- Fallback directory creation if path does not exist yet
        local dirPath = GetModConfigsDir() .. "/PresetSwitch"
        local winDirPath = string.gsub(dirPath, "/", "\\")
        pcall(function() os.execute('cmd /c if not exist "' .. winDirPath .. '" mkdir "' .. winDirPath .. '"') end)
        file = io.open(path, "w")
    end

    if file then
        file:write(json.stringify(M.CONFIG))
        file:close()
        print("[PresetSwitch] Configuration saved to: " .. path)
        return true
    else
        print("[PresetSwitch] ERROR: Failed to write configuration to: " .. path)
        return false
    end
end

-- Key & Modifier resolution helpers
function M.ResolveModifier(modStr)
    if not modStr or type(modStr) ~= "string" then
        return { ModifierKey.ALT }
    end
    local upper = string.upper(modStr)
    if upper == "NONE" or upper == "OFF" or upper == "" then
        return {}
    elseif upper == "SHIFT" then
        return { ModifierKey.SHIFT }
    elseif upper == "CTRL" or upper == "CONTROL" then
        return { ModifierKey.CONTROL }
    else
        return { ModifierKey.ALT }
    end
end

function M.GetKey(keyName, defaultKey)
    if not keyName or type(keyName) ~= "string" or keyName == "" then
        return defaultKey
    end
    local upper = string.upper(keyName)
    if Key[upper] then
        return Key[upper]
    end
    -- Numeric string fallback
    if upper == "5" or upper == "FIVE" then return Key.FIVE or Key.NUM_5 or Key["5"] end
    if upper == "6" or upper == "SIX" then return Key.SIX or Key.NUM_6 or Key["6"] end
    if upper == "7" or upper == "SEVEN" then return Key.SEVEN or Key.NUM_7 or Key["7"] end
    if upper == "8" or upper == "EIGHT" then return Key.EIGHT or Key.NUM_8 or Key["8"] end
    if upper == "9" or upper == "NINE" then return Key.NINE or Key.NUM_9 or Key["9"] end
    return defaultKey
end

return M
