-- Palworld RelicFinder Mod
-- Built for Palworld v1.0
-- Uses UE4SS Lua Scripting API

local UEHelpers = require("UEHelpers")

-- Configuration Options
local CONFIG = {
    Enabled = true,             -- Set to true to enable the mod by default
    MaxDistance = 15000.0,      -- Maximum distance to scan and draw (in centimeters, e.g. 150 meters)
    FontScale = 1.2,            -- Scale of the HUD overlay text
    TextOffsetZ = 80.0,         -- Z offset in centimeters to draw the text above the object (80cm)
    ScanIntervalMs = 1500,      -- How often to scan for objects in background (1.5 seconds is lag-free)
    Debug = true,               -- Set to true to output debug information to the UE4SS log/console (only prints initialization/errors)
    
    -- Relics (Lifmunk Effigies) Options
    ShowRelics = true,
    RelicColor = { R = 0.1, G = 0.9, B = 0.9, A = 1.0 }, -- Cyan color
    
    -- Treasure Chests Options
    ShowChests = true,
    ChestColor = { R = 0.9, G = 0.7, B = 0.1, A = 1.0 } -- Yellow/Gold color
}

-- Debug print helper
local function DebugPrint(msg)
    if CONFIG.Debug then
        print("[RelicFinder] " .. tostring(msg))
    end
end

-- Lightweight JSON parser in pure Lua
local function ParseJSON(str)
    str = str:gsub("//[^\n]*", ""):gsub("/%*.-%*/", "")
    local pos = 1
    local function skip_whitespace()
        while pos <= #str do
            local c = str:sub(pos, pos)
            if c == ' ' or c == '\t' or c == '\n' or c == '\r' then
                pos = pos + 1
            else
                break
            end
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
                while pos <= #str and str:sub(pos, pos) ~= '"' do
                    pos = pos + 1
                end
                local key = str:sub(start, pos - 1)
                pos = pos + 1
                skip_whitespace()
                if str:sub(pos, pos) ~= ':' then
                    error("Expected ':' at position " .. pos)
                end
                pos = pos + 1
                skip_whitespace()
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
            if c == '"' and str:sub(pos - 1, pos - 1) ~= '\\' then
                break
            end
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
            if c:match("[%d%.%-eE%+]") then
                pos = pos + 1
            else
                break
            end
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

local function LoadConfig()
    local paths = {
        "Mods/RelicFinder/config.json",
        "Pal/Binaries/Win64/Mods/RelicFinder/config.json",
        "config.json"
    }
    local file = nil
    for _, path in ipairs(paths) do
        file = io.open(path, "r")
        if file then break end
    end
    if not file then
        print("[RelicFinder] Config file config.json not found, using defaults.")
        return
    end
    local content = file:read("*all")
    file:close()
    local parsed = ParseJSON(content)
    if parsed then
        for k, v in pairs(parsed) do
            CONFIG[k] = v
        end
        print("[RelicFinder] Config loaded successfully from config.json!")
    else
        print("[RelicFinder] Failed to parse config.json, using defaults.")
    end
end

-- Initialize config loading
pcall(LoadConfig)

DebugPrint("Initializing Mod...")

-- Cached player reference to prevent GetPlayer overhead on draw ticks
local cachedPlayer = nil

-- Cached active coordinates (plain Lua tables of numbers to prevent GObject thread locking during draw ticks)
local activeRelics = {}
local activeChests = {}

-- Helper to safely check if a relic has been picked up
local function IsRelicPicked(relic)
    local status, picked = pcall(function()
        if relic:IsValid() then
            return relic.bPickedInClient
        end
        return true
    end)
    if status then
        return picked
    else
        return true
    end
end

-- Helper to safely check if a chest is already opened
local function IsChestOpened(chest)
    local status, opened = pcall(function()
        if chest:IsValid() then
            local model = chest.MapObjectModel
            if model and model:IsValid() then
                local concrete = model.ConcreteModel
                if concrete and concrete:IsValid() then
                    return concrete.bOpened
                end
            end
        end
        return true
    end)
    if status then
        return opened
    else
        return true
    end
end

-- Periodic scanner to find unobtained relics and chests in the world
-- Runs on a slow interval to offload all heavy memory operations
local function ScanObjects()
    if not CONFIG.Enabled then 
        activeRelics = {}
        activeChests = {}
        return 
    end
    
    cachedPlayer = UEHelpers.GetPlayer()
    local player = cachedPlayer
    if not player or not player:IsValid() then return end
    
    local playerPos = player:K2_GetActorLocation()
    if not playerPos then return end
    
    local maxDistSq = CONFIG.MaxDistance * CONFIG.MaxDistance
    
    -- 1. Scan Relics
    local newRelics = {}
    if CONFIG.ShowRelics then
        local relics = FindAllOf("PalLevelObjectRelic") or {}
        for _, relic in ipairs(relics) do
            if relic:IsValid() and not IsRelicPicked(relic) then
                pcall(function()
                    local relicPos = relic:K2_GetActorLocation()
                    if relicPos then
                        local dx = relicPos.X - playerPos.X
                        local dy = relicPos.Y - playerPos.Y
                        local dz = relicPos.Z - playerPos.Z
                        local distSq = dx*dx + dy*dy + dz*dz
                        
                        -- Filter and cache only the coordinates
                        if distSq <= maxDistSq then
                            table.insert(newRelics, { X = relicPos.X, Y = relicPos.Y, Z = relicPos.Z })
                        end
                    end
                end)
            end
        end
    end
    activeRelics = newRelics
    
    -- 2. Scan Chests
    local newChests = {}
    if CONFIG.ShowChests then
        local chests = FindAllOf("PalMapObjectTreasureBox") or {}
        for _, chest in ipairs(chests) do
            if chest:IsValid() and not IsChestOpened(chest) then
                pcall(function()
                    local chestPos = chest:K2_GetActorLocation()
                    if chestPos then
                        local dx = chestPos.X - playerPos.X
                        local dy = chestPos.Y - playerPos.Y
                        local dz = chestPos.Z - playerPos.Z
                        local distSq = dx*dx + dy*dy + dz*dz
                        
                        -- Filter and cache only the coordinates
                        if distSq <= maxDistSq then
                            table.insert(newChests, { X = chestPos.X, Y = chestPos.Y, Z = chestPos.Z })
                        end
                    end
                end)
            end
        end
    end
    activeChests = newChests
end

-- Render center-aligned 3D floating text above the item location
local function DrawTextAbove(hud, pos, textStr, color)
    local textWorldPos = { X = pos.X, Y = pos.Y, Z = pos.Z + CONFIG.TextOffsetZ }
    local textScreen = hud:Project(textWorldPos, false)
    
    if textScreen.Z > 0.0 then
        local width = 0
        local height = 0
        pcall(function()
            width, height = hud:GetTextSize(textStr, nil, CONFIG.FontScale)
        end)
        
        -- Fallback default font character metrics if GetTextSize fails
        if not width or width == 0 then
            width = #textStr * 8.0 * CONFIG.FontScale
            height = 12.0 * CONFIG.FontScale
        end
        
        -- Center-align text relative to the projected screen position
        local drawX = textScreen.X - (width / 2.0)
        local drawY = textScreen.Y - (height / 2.0)
        
        hud:DrawText(textStr, color, drawX, drawY, nil, CONFIG.FontScale, false)
    end
end

-- Hook into HUD Draw frame tick (ReceiveDrawHUD)
-- Highly optimized drawing loop running on cached player & coordinate data
local isHUDHooked = false

local function RegisterHUDHook()
    if isHUDHooked then return end
    
    local status = pcall(function()
        RegisterHook("/Game/Pal/Blueprint/UI/BP_PalHUD_InGame.BP_PalHUD_InGame_C:ReceiveDrawHUD", function(self, SizeX, SizeY)
            local hud = self:get()
            if not hud or not hud:IsValid() then return end
            if not CONFIG.Enabled then return end
            
            local player = cachedPlayer
            if not player or not player:IsValid() then return end
            
            local playerPos = player:K2_GetActorLocation()
            if not playerPos then return end
            
            -- 1. Draw Relic Markers
            if CONFIG.ShowRelics then
                for _, pos in ipairs(activeRelics) do
                    local dx = pos.X - playerPos.X
                    local dy = pos.Y - playerPos.Y
                    local dz = pos.Z - playerPos.Z
                    local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
                    
                    local distMeters = math.floor(dist / 100.0)
                    local textStr = "Relic [" .. distMeters .. "m]"
                    
                    DrawTextAbove(hud, pos, textStr, CONFIG.RelicColor)
                end
            end
            
            -- 2. Draw Chest Markers
            if CONFIG.ShowChests then
                for _, pos in ipairs(activeChests) do
                    local dx = pos.X - playerPos.X
                    local dy = playerPos.Y - playerPos.Y
                    local dz = pos.Z - playerPos.Z
                    local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
                    
                    local distMeters = math.floor(dist / 100.0)
                    local textStr = "Chest [" .. distMeters .. "m]"
                    
                    DrawTextAbove(hud, pos, textStr, CONFIG.ChestColor)
                end
            end
        end)
    end)
    
    if status then
        isHUDHooked = true
        DebugPrint("HUD ReceiveDrawHUD hook successfully registered!")
    else
        DebugPrint("Failed to register ReceiveDrawHUD hook (class might not be loaded yet).")
    end
end

-- Try to hook immediately (handles mid-game mod reloading)
RegisterHUDHook()

-- Listen for new HUD objects to hook when loaded (handles startup / level load)
NotifyOnNewObject("/Game/Pal/Blueprint/UI/BP_PalHUD_InGame.BP_PalHUD_InGame_C", function(hudObj)
    RegisterHUDHook()
end)

-- Scanner loop setup (runs in background)
local function StartPeriodicScan()
    local function loop()
        pcall(ScanObjects)
        ExecuteWithDelay(CONFIG.ScanIntervalMs, loop)
    end
    ExecuteWithDelay(CONFIG.ScanIntervalMs, loop)
end

-- Thread-safe hotkey bind (Alt + F8) to toggle lines
RegisterKeyBind(Key.F8, {ModifierKey.ALT}, function()
    CONFIG.Enabled = not CONFIG.Enabled
    if CONFIG.Enabled then
        print("[RelicFinder] Enabled showing lines to relics and chests.")
    else
        print("[RelicFinder] Disabled showing lines to relics and chests.")
        activeRelics = {}
        activeChests = {}
    end
end)

-- Start background scanner loop
StartPeriodicScan()

print("[RelicFinder] Mod Loaded Successfully!")
