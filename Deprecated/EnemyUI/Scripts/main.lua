-- Palworld Enemy HP Bar Customization Mod (Optimized Version)
-- Built for Palworld v1.0
-- Uses UE4SS Lua Scripting API

local UEHelpers = require("UEHelpers")

-- Configuration Options
local CONFIG = {
    ShowAllHPBars = true,      
    ShowThroughWalls = true,   
    MaxDistance = 15000.0,     
    HideTime = 10.0,           
    ScanIntervalMs = 1000,     -- Optimized from 3000 to 1000
    Debug = true               
}

local function DebugPrint(msg)
    if CONFIG.Debug then
        print("[EnemyUI] " .. tostring(msg))
    end
end

-- Lightweight JSON parser in pure Lua
local function ParseJSON(str)
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

local function LoadConfig()
    local paths = {
        "Mods/EnemyUI/config.json",
        "Pal/Binaries/Win64/Mods/EnemyUI/config.json",
        "config.json"
    }
    local file = nil
    for _, path in ipairs(paths) do
        file = io.open(path, "r")
        if file then break end
    end
    if not file then return end
    local content = file:read("*all")
    file:close()
    local parsed = ParseJSON(content)
    if parsed then
        for k, v in pairs(parsed) do CONFIG[k] = v end
    end
end
pcall(LoadConfig)

-- Fast Event-Driven Caches
local ActiveCharacters = {}
local CachedCanvas = nil
local isHooked = false

-- 1. Cache Characters as they spawn
NotifyOnNewObject("/Script/Pal.PalCharacter", function(char)
    ActiveCharacters[char] = true
end)

-- 2. Cache Canvas when it spawns and setup hooks
NotifyOnNewObject("/Game/Pal/Blueprint/UI/NPCHPGauge/WBP_PalNPCHPGaugeCanvas.WBP_PalNPCHPGaugeCanvas_C", function(canvas)
    CachedCanvas = canvas
    
    if isHooked then return end
    isHooked = true
    
    DebugPrint("WBP_PalNPCHPGaugeCanvas loaded. Registering optimized hooks...")

    RegisterHook("/Game/Pal/Blueprint/UI/NPCHPGauge/WBP_PalNPCHPGaugeCanvas.WBP_PalNPCHPGaugeCanvas_C:Setup", function(self)
        local cObj = self:get()
        if cObj and cObj:IsValid() then
            cObj.HideTime = CONFIG.HideTime
        end
    end)

    RegisterHook("/Game/Pal/Blueprint/UI/NPCHPGauge/WBP_PalNPCHPGaugeCanvas.WBP_PalNPCHPGaugeCanvas_C:Is Display Distance", function(self, Distance, TargetCharacter, isDisplay)
        if CONFIG.ShowAllHPBars then
            local distVal = Distance:get()
            if distVal and distVal <= CONFIG.MaxDistance then
                isDisplay:set(true)
            end
        end
    end)

    RegisterHook("/Game/Pal/Blueprint/UI/NPCHPGauge/WBP_PalNPCHPGaugeCanvas.WBP_PalNPCHPGaugeCanvas_C:Is Sight Display", function(self, Actor, Return)
        if CONFIG.ShowThroughWalls then Return:set(true) end
    end)

    RegisterHook("/Game/Pal/Blueprint/UI/NPCHPGauge/WBP_PalNPCHPGaugeCanvas.WBP_PalNPCHPGaugeCanvas_C:IsDisplayGaugeByPlayerRotation", function(self, TargetCharacter, isDisplay)
        if CONFIG.ShowAllHPBars then isDisplay:set(true) end
    end)
end)

-- Zero-Garbage Background Scanner
local function ScanAndAddGauges()
    if not CONFIG.ShowAllHPBars then return end
    if not CachedCanvas or not CachedCanvas:IsValid() then return end
    
    local player = UEHelpers.GetPlayer()
    if not player or not player:IsValid() then return end
    local playerPos = player:K2_GetActorLocation()
    if not playerPos then return end
    
    local maxDistSq = CONFIG.MaxDistance * CONFIG.MaxDistance
    
    -- Iterate our lightweight cache instead of the massive engine UObject array
    for char, _ in pairs(ActiveCharacters) do
        if not char:IsValid() then
            -- Safely drop dead pointers (fixes crashes)
            ActiveCharacters[char] = nil
        else
            -- We just pass them to the canvas and calculate distance to avoid UI bloat
            pcall(function()
                local charPos = char:K2_GetActorLocation()
                if charPos then
                    local dx = charPos.X - playerPos.X
                    local dy = charPos.Y - playerPos.Y
                    local dz = charPos.Z - playerPos.Z
                    local distSq = dx*dx + dy*dy + dz*dz
                    
                    if distSq <= maxDistSq then
                        CachedCanvas["Try Process DIsplay Gauge"](CachedCanvas, char)
                    end
                end
            end)
        end
    end
end

-- Recurrent loop scanner
local function StartPeriodicScan()
    local function loop()
        pcall(ScanAndAddGauges)
        ExecuteWithDelay(CONFIG.ScanIntervalMs, loop)
    end
    ExecuteWithDelay(CONFIG.ScanIntervalMs, loop)
end

-- Setup toggle hotkey (Alt + F9)
RegisterKeyBind(Key.F9, {ModifierKey.ALT}, function()
    CONFIG.ShowAllHPBars = not CONFIG.ShowAllHPBars
    if CONFIG.ShowAllHPBars then print("[EnemyUI] Enabled showing all enemy HP bars.")
    else print("[EnemyUI] Disabled showing all enemy HP bars.") end
end)

StartPeriodicScan()
DebugPrint("Optimized Mod Loaded Successfully!")
