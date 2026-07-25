local json = require("FreeCam.json")

local M = {}

M.CONFIG = {
    Debug = false,
    DefaultSpeed = 15.0,
    BaseOnly = true,
    MaxRange = 50.0,
    KeyBinds = {
        ToggleFreeCam = "F8",
        Modifier = "ALT",
        FlyUp = "SpaceBar",
        FlyDown = "LeftShift",
        SpeedUp = "PAGE_UP",
        SpeedDown = "PAGE_DOWN"
    },
    Gamepad = {
        ModifierButton = "Gamepad_LeftTrigger",
        ToggleButton = "Gamepad_Special_Right",
        FlyUpButton = "Gamepad_RightThumbstick",
        FlyDownButton = "Gamepad_LeftThumbstick"
    }
}

function M.DebugPrint(msg)
    if M.CONFIG.Debug then
        print("[FreeCam] " .. tostring(msg))
    end
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
    path = string.gsub(path, "\\", "/")
    return path
end

local function GetNewConfigFilePath()
    return GetModConfigsDir() .. "/FreeCam/config.json"
end

local function GetConfigFilePath()
    local info = debug.getinfo(1, "S")
    if info and info.source and info.source:sub(1, 1) == "@" then
        local src = info.source:sub(2)
        local modDir = src:match("(.*)[/\\]Scripts[/\\]FreeCam[/\\]config%.lua")
        if modDir then
            return modDir .. "/config.json"
        end
    end
    return "Mods/FreeCam/config.json"
end

function M.LoadConfig()
    local primaryPath = GetNewConfigFilePath()
    local localPath = GetConfigFilePath()
    local paths = {
        primaryPath,
        localPath,
        "Mods/FreeCam/config.json",
        "Mods/NativeMods/UE4SS/Mods/FreeCamDEBUG/config.json",
        "config.json"
    }
    
    local file = nil
    local loadedPath = nil
    for _, path in ipairs(paths) do
        file = io.open(path, "r")
        if file then
            loadedPath = path
            break
        end
    end
    
    -- Ensure the AppData directory is created
    local modConfigDir = GetModConfigsDir() .. "/FreeCam"
    pcall(function() os.execute('mkdir "' .. string.gsub(modConfigDir, "/", "\\") .. '" >nul 2>nul') end)
    
    if not file then
        M.DebugPrint("Config file not found. Creating default config.json...")
        local outFile = io.open(primaryPath, "w")
        if outFile then
            local defaultJson = [[{
  "Debug": false,
  "DefaultSpeed": 15.0,
  "BaseOnly": true,
  "MaxRange": 50.0,
  "KeyBinds": {
    "ToggleFreeCam": "F8",
    "Modifier": "ALT",
    "FlyUp": "SpaceBar",
    "FlyDown": "LeftShift",
    "SpeedUp": "PAGE_UP",
    "SpeedDown": "PAGE_DOWN"
  },
  "Gamepad": {
    "ModifierButton": "Gamepad_LeftTrigger",
    "ToggleButton": "Gamepad_Special_Right",
    "FlyUpButton": "Gamepad_RightThumbstick",
    "FlyDownButton": "Gamepad_LeftThumbstick"
  }
}]]
            outFile:write(defaultJson)
            outFile:close()
            M.DebugPrint("Default config.json created successfully at " .. primaryPath)
        else
            M.DebugPrint("Failed to create default config.json at " .. primaryPath)
        end
        return
    end
    
    local content = file:read("*all")
    file:close()
    
    -- If we loaded it from somewhere else, write it to primaryPath (AppData) so it is initialized there
    if loadedPath ~= primaryPath then
        local outFile = io.open(primaryPath, "w")
        if outFile then
            outFile:write(content)
            outFile:close()
            M.DebugPrint("Successfully initialized config file at central path: " .. primaryPath)
        else
            M.DebugPrint("Failed to copy config file to central path: " .. primaryPath)
        end
    end
    
    local parsed = json.parse(content)
    if parsed then
        if parsed.Debug ~= nil then M.CONFIG.Debug = parsed.Debug end
        if parsed.DefaultSpeed ~= nil then M.CONFIG.DefaultSpeed = parsed.DefaultSpeed end
        if parsed.BaseOnly ~= nil then M.CONFIG.BaseOnly = (parsed.BaseOnly == true) end
        if parsed.MaxRange ~= nil then M.CONFIG.MaxRange = tonumber(parsed.MaxRange) or 50.0 end
        if parsed.KeyBinds then
            if parsed.KeyBinds.ToggleFreeCam ~= nil then M.CONFIG.KeyBinds.ToggleFreeCam = parsed.KeyBinds.ToggleFreeCam end
            if parsed.KeyBinds.Modifier ~= nil then
                M.CONFIG.KeyBinds.Modifier = parsed.KeyBinds.Modifier
            elseif parsed.KeyBinds.UseAltModifier ~= nil then
                M.CONFIG.KeyBinds.Modifier = parsed.KeyBinds.UseAltModifier and "ALT" or "NONE"
            end
            if parsed.KeyBinds.FlyUp ~= nil then M.CONFIG.KeyBinds.FlyUp = parsed.KeyBinds.FlyUp end
            if parsed.KeyBinds.FlyDown ~= nil then M.CONFIG.KeyBinds.FlyDown = parsed.KeyBinds.FlyDown end
            if parsed.KeyBinds.SpeedUp ~= nil then M.CONFIG.KeyBinds.SpeedUp = parsed.KeyBinds.SpeedUp end
            if parsed.KeyBinds.SpeedDown ~= nil then M.CONFIG.KeyBinds.SpeedDown = parsed.KeyBinds.SpeedDown end
        end
        if parsed.Gamepad then
            if parsed.Gamepad.ModifierButton ~= nil then M.CONFIG.Gamepad.ModifierButton = parsed.Gamepad.ModifierButton end
            if parsed.Gamepad.ToggleButton ~= nil then M.CONFIG.Gamepad.ToggleButton = parsed.Gamepad.ToggleButton end
            if parsed.Gamepad.FlyUpButton ~= nil then M.CONFIG.Gamepad.FlyUpButton = parsed.Gamepad.FlyUpButton end
            if parsed.Gamepad.FlyDownButton ~= nil then M.CONFIG.Gamepad.FlyDownButton = parsed.Gamepad.FlyDownButton end
        end
        M.DebugPrint("Config loaded successfully from JSON!")
        -- Save back immediately to prune invalid keys and add missing keys
        pcall(M.SaveConfig)
    else
        M.DebugPrint("Failed to parse config.json, using defaults.")
    end
end

function M.SaveConfig()
    local configPath = GetNewConfigFilePath()
    local outFile = io.open(configPath, "w")
    if outFile then
        local str = json.stringify(M.CONFIG)
        outFile:write(str)
        outFile:close()
        M.DebugPrint("Configuration saved successfully to central path: " .. configPath)
    end
end

-- Load it immediately
pcall(M.LoadConfig)

return M
