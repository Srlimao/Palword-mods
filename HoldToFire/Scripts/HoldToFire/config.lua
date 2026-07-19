local json = require("HoldToFire.json")

local M = {}

M.CONFIG = {
    Enabled = true,
    DebugMode = true,
    ScanIntervalMs = 2000,
    WeaponTypes = {
        Handgun = true,
        SniperRifle = true,
        Shotgun = true,
        RocketLauncher = true,
        BowGun = true,
        LaserRifle = true,
        MissileLauncher = true,
        GrenadeLauncher = true
    }
}

function M.DebugPrint(msg)
    if M.CONFIG.DebugMode then
        print("[HoldToFire] " .. tostring(msg))
    end
end

local function GetConfigFilePath()
    local info = debug.getinfo(1, "S")
    if info and info.source and info.source:sub(1, 1) == "@" then
        local src = info.source:sub(2)
        -- Match the parent directory of "Scripts/HoldToFire/config.lua"
        local modDir = src:match("(.*)[/\\]Scripts[/\\]HoldToFire[/\\]config%.lua")
        if modDir then
            return modDir .. "/config.json"
        end
    end
    return "Mods/HoldToFire/config.json"
end

function M.LoadConfig()
    local configPath = GetConfigFilePath()
    local paths = {
        configPath,
        "Mods/HoldToFire/config.json",
        "Mods/NativeMods/UE4SS/Mods/HoldToFireDEBUG/config.json",
        "config.json"
    }
    
    local file = nil
    for _, path in ipairs(paths) do
        file = io.open(path, "r")
        if file then break end
    end
    
    if not file then
        M.DebugPrint("Config file not found. Creating default config.json...")
        local writePath = configPath or "Mods/HoldToFire/config.json"
        local outFile = io.open(writePath, "w")
        if outFile then
            local defaultJson = [[{
    "Enabled": true,
    "DebugMode": true,
    "ScanIntervalMs": 2000,
    "WeaponTypes": {
        "Handgun": true,
        "SniperRifle": true,
        "Shotgun": true,
        "RocketLauncher": true,
        "BowGun": true,
        "LaserRifle": true,
        "MissileLauncher": true,
        "GrenadeLauncher": true
    }
}]]
            outFile:write(defaultJson)
            outFile:close()
            M.DebugPrint("Default config.json created successfully at " .. writePath)
        else
            M.DebugPrint("Failed to create default config.json at " .. writePath)
        end
        return
    end
    
    local content = file:read("*all")
    file:close()
    
    local parsed = json.parse(content)
    if parsed then
        if parsed.Enabled ~= nil then M.CONFIG.Enabled = parsed.Enabled end
        if parsed.DebugMode ~= nil then M.CONFIG.DebugMode = parsed.DebugMode end
        if parsed.ScanIntervalMs ~= nil then M.CONFIG.ScanIntervalMs = parsed.ScanIntervalMs end
        
        if parsed.WeaponTypes then
            for k, v in pairs(parsed.WeaponTypes) do
                if M.CONFIG.WeaponTypes[k] ~= nil then
                    M.CONFIG.WeaponTypes[k] = v
                end
            end
        end
        M.DebugPrint("Config loaded successfully from JSON!")
    else
        M.DebugPrint("Failed to parse config.json, using defaults.")
    end
end

-- Load it immediately
pcall(M.LoadConfig)

return M
