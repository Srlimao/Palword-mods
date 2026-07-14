local json = require("HUDLocator.json")

local M = {}

-- Config settings
M.CONFIG = {
    Enabled = true,
    ShowPlayers = true,
    ShowRelics = true,
    ShowChests = true,
    EggFilter = "All",
    DrawBox = false,
    Debug = false,
    PlayerFontScale = 1.2,
    PlayerSmallFontScale = 0.9,
    RelicFontScale = 1.2,
    ChestFontScale = 1.2,
    EggFontScale = 1.2,
    FontCharW = 8.0,
    FontLineH = 12.0,
    TextOffsetZ = 120.0,
    ItemTextOffsetZ = 80.0,
    MaxDistance = 15000.0,
    BoxPadX = 10.0,
    BoxPadY = 6.0,
    BoxColor = { R = 0.8, G = 0.8, B = 1.0, A = 1.0 },
    BorderWidth = 1.5,
    NameColor = { R = 0.0, G = 0.0, B = 0.0, A = 1.0 },
    DistColor = { R = 0.0, G = 0.0, B = 0.0, A = 1.0 },
    BorderColor = { R = 0.0, G = 0.0, B = 0.0, A = 1.0 },
    RelicColor = { R = 0.1, G = 0.9, B = 0.9, A = 1.0 },
    ChestColor = { R = 0.9, G = 0.7, B = 0.1, A = 1.0 },
    EggColor = { R = 0.8, G = 0.5, B = 0.8, A = 1.0 },
    ScanIntervalMs = 1500,
    GraceRadiusM = 30
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
  "Enabled": true,
  "ShowPlayers": true,
  "ShowRelics": true,
  "ShowChests": true,
  "EggFilter": "All",
  "DrawBox": false,
  "Debug": false,
  "PlayerFontScale": 1.2,
  "PlayerSmallFontScale": 0.9,
  "RelicFontScale": 1.2,
  "ChestFontScale": 1.2,
  "EggFontScale": 1.2,
  "FontCharW": 8.0,
  "FontLineH": 12.0,
  "TextOffsetZ": 120.0,
  "ItemTextOffsetZ": 80.0,
  "MaxDistance": 15000.0,
  "BoxPadX": 10.0,
  "BoxPadY": 6.0,
  "BoxColor": { "R": 0.8, "G": 0.8, "B": 1.0, "A": 1.0 },
  "BorderWidth": 1.5,
  "NameColor": { "R": 0.0, "G": 0.0, "B": 0.0, "A": 1.0 },
  "DistColor": { "R": 0.0, "G": 0.0, "B": 0.0, "A": 1.0 },
  "BorderColor": { "R": 0.0, "G": 0.0, "B": 0.0, "A": 1.0 },
  "RelicColor": { "R": 0.1, "G": 0.9, "B": 0.9, "A": 1.0 },
  "ChestColor": { "R": 0.9, "G": 0.7, "B": 0.1, "A": 1.0 },
  "EggColor": { "R": 0.8, "G": 0.5, "B": 0.8, "A": 1.0 },
  "ScanIntervalMs": 1500,
  "GraceRadiusM": 30
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
        for k, v in pairs(parsed) do
            -- Handle nested tables (colors) carefully
            if type(v) == "table" and M.CONFIG[k] and type(M.CONFIG[k]) == "table" then
                for subK, subV in pairs(v) do
                    M.CONFIG[k][subK] = subV
                end
            else
                M.CONFIG[k] = v
            end
        end
        print("[HUDLocator] Config loaded successfully!")
    else
        print("[HUDLocator] Failed to parse config, using defaults.")
    end
end

-- Initialize configuration on load
pcall(M.LoadConfig)

return M
