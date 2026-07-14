-- Palworld Effigy Region Progress Tracker Mod
-- Built for Palworld v1.0
-- Uses UE4SS Lua Scripting API

local UEHelpers = require("UEHelpers")

local CONFIG = {
    CachePath = "C:\\Program Files (x86)\\Steam\\steamapps\\common\\Palworld\\Mods\\NativeMods\\UE4SS\\Mods\\ProgressTracker\\relics_cache.txt",
    Debug = false,
    DisplayDuration = 10.0
}

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
        "Mods/ProgressTracker/config.json",
        "Pal/Binaries/Win64/Mods/ProgressTracker/config.json",
        "config.json"
    }
    local file = nil
    for _, path in ipairs(paths) do
        file = io.open(path, "r")
        if file then break end
    end
    if not file then
        print("[ProgressTracker] Config file config.json not found, using defaults.")
        return
    end
    local content = file:read("*all")
    file:close()
    local parsed = ParseJSON(content)
    if parsed then
        for k, v in pairs(parsed) do
            CONFIG[k] = v
        end
        print("[ProgressTracker] Config loaded successfully from config.json!")
    else
        print("[ProgressTracker] Failed to parse config.json, using defaults.")
    end
end

-- Load the configurations from JSON
pcall(LoadConfig)

local RelicCache = {}
local CacheDirty = false

-- Helper to count keys in a table
local function table_size(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- Normalize GUID strings to ensure matching (strip hyphens and convert to uppercase)
local function NormalizeGuid(guidStr)
    if not guidStr then return "" end
    return guidStr:gsub("-", ""):gsub("{", ""):gsub("}", ""):upper()
end

-- Helper to convert FGuid struct (A, B, C, D) to normalized string
local function GuidToString(guid)
    if not guid then return "" end
    local raw = string.format("%08X%08X%08X%08X", guid.A, guid.B, guid.C, guid.D)
    return NormalizeGuid(raw)
end

-- Load cached relics from file
local function LoadCache()
    local file = io.open(CONFIG.CachePath, "r")
    if not file then
        print("[ProgressTracker] Cache file not found at: " .. CONFIG.CachePath .. ". A new one will be created.")
        return
    end

    for line in file:lines() do
        local guid, region = line:match("([^:]+):(.+)")
        if guid and region then
            RelicCache[NormalizeGuid(guid)] = region
        end
    end
    file:close()
    print("[ProgressTracker] Cache loaded. Total relics in cache: " .. tostring(table_size(RelicCache)))
end

-- Save cache to file
local function SaveCache()
    local file = io.open(CONFIG.CachePath, "w")
    if not file then
        print("[ProgressTracker] ERROR: Could not write cache file to " .. CONFIG.CachePath)
        return
    end

    for guid, region in pairs(RelicCache) do
        file:write(guid .. ":" .. region .. "\n")
    end
    file:close()
    CacheDirty = false
    print("[ProgressTracker] Cache saved.")
end

-- Helper to print messages to screen and console
local function DisplayScreenMessage(Message, Duration)
    Duration = Duration or CONFIG.DisplayDuration or 5.0
    local Kismet = UEHelpers.GetKismetSystemLibrary()
    local Player = UEHelpers.GetPlayer()
    if Kismet:IsValid() and Player:IsValid() then
        local Color = { R = 0.1, G = 0.9, B = 0.1, A = 1.0 } -- Bright Green
        Kismet:PrintString(Player, Message, true, true, Color, Duration, "None")
    else
        print("[ProgressTracker] " .. Message)
    end
end

-- Process and cache a single relic
local function ProcessRelic(relic)
    if not relic or not relic:IsValid() then return end
    
    local guid = relic.LevelObjectInstanceId
    local guidStr = GuidToString(guid)
    if guidStr == "" or RelicCache[guidStr] then return end

    local player = UEHelpers.GetPlayer()
    if not player or not player:IsValid() then return end

    local playerState = player.CachedPlayerState
    if not playerState or not playerState:IsValid() then return end

    local worldMapData = playerState.WorldMapData
    if not worldMapData or not worldMapData:IsValid() then return end

    local location = relic:K2_GetActorLocation()
    local regionFName = worldMapData:GetMapNameByWorldLocation(location)
    if regionFName then
        local regionStr = regionFName:ToString()
        if regionStr ~= "None" and regionStr ~= "" then
            RelicCache[guidStr] = regionStr
            CacheDirty = true
            print(string.format("[ProgressTracker] Discovered relic: %s in region: %s", guidStr, regionStr))
        end
    end
end

-- One-time full scan (called on user request)
local function OneTimeScan()
    local relics = FindAllOf("BP_LevelObject_Relic_C")
    if not relics then return end

    for _, relic in ipairs(relics) do
        ProcessRelic(relic)
    end

    if CacheDirty then
        SaveCache()
    end
end

-- Progress calculations and printout
local function ShowProgress()
    -- Run a one-time sync of loaded relics when showing progress
    print("[ProgressTracker] Performing one-time scan of loaded relics...")
    OneTimeScan()

    local player = UEHelpers.GetPlayer()
    if not player:IsValid() then
        DisplayScreenMessage("Error: Player not valid.", 3.0)
        return
    end

    local playerState = player.CachedPlayerState
    if not playerState or not playerState:IsValid() then
        DisplayScreenMessage("Error: PlayerState not valid.", 3.0)
        return
    end

    local recordData = playerState.RecordData
    if not recordData or not recordData:IsValid() then
        DisplayScreenMessage("Error: RecordData not valid.", 3.0)
        return
    end

    -- Get collected items from array
    local collectedItems = recordData.RelicObtainForInstanceFlag_CapturePower.Items
    if not collectedItems then
        DisplayScreenMessage("No collected effigies found.", 3.0)
        return
    end

    local collectedMap = {}
    local totalCollectedCount = 0
    local numCollected = collectedItems:GetArrayNum()
    
    for i = 1, numCollected do
        local item = collectedItems[i]
        if item and item:IsValid() then
            if item.Value == true then
                local keyStr = NormalizeGuid(item.Key:ToString())
                collectedMap[keyStr] = true
                totalCollectedCount = totalCollectedCount + 1
            end
        end
    end

    -- Group collected vs total in cache by region
    local regionData = {}
    
    -- Initialize all discovered regions in cache
    for _, regionName in pairs(RelicCache) do
        if not regionData[regionName] then
            regionData[regionName] = { collected = 0, total = 0 }
        end
    end

    -- Count totals
    for guid, regionName in pairs(RelicCache) do
        regionData[regionName].total = regionData[regionName].total + 1
        if collectedMap[guid] then
            regionData[regionName].collected = regionData[regionName].collected + 1
        end
    end

    -- Count unmapped collected relics
    local unmappedCount = 0
    for guid, _ in pairs(collectedMap) do
        if not RelicCache[guid] then
            unmappedCount = unmappedCount + 1
        end
    end

    -- Print output to screen and log
    print("\n--- Pal Effigy Progress Tracker ---")
    local lines = {}
    table.insert(lines, "=== Pal Effigy Progress ===")
    
    local sortedRegions = {}
    for regionName, _ in pairs(regionData) do
        table.insert(sortedRegions, regionName)
    end
    table.sort(sortedRegions)

    for _, regionName in ipairs(sortedRegions) do
        local data = regionData[regionName]
        local line = string.format("%s: %d / %d", regionName, data.collected, data.total)
        table.insert(lines, line)
        print(line)
    end

    if unmappedCount > 0 then
        local line = string.format("Other Regions (Uncached): %d", unmappedCount)
        table.insert(lines, line)
        print(line)
    end

    local summaryLine = string.format("Total Collected: %d (Discovered in Cache: %d)", totalCollectedCount, table_size(RelicCache))
    table.insert(lines, summaryLine)
    print(summaryLine)
    print("-----------------------------------\n")

    -- Print lines to player screen
    for _, line in ipairs(lines) do
        DisplayScreenMessage(line, 10.0)
    end
end

-- Initialize mod
print("[ProgressTracker] Mod Loaded!")
LoadCache()

-- Setup hotkey for manual progress check
RegisterKeyBindAsync(Key.T, {ModifierKey.CONTROL}, function()
    ShowProgress()
end)

-- Event-driven discovery: Process new relics immediately when they load into memory
NotifyOnNewObject("/Script/Pal.PalLevelObjectRelic", function(relic)
    if relic and relic:IsValid() then
        -- Wait a brief moment to ensure the actor is initialized (has location and GUID)
        ExecuteWithDelay(1000, function()
            if relic:IsValid() then
                ProcessRelic(relic)
                if CacheDirty then
                    SaveCache()
                end
            end
        end)
    end
end)

-- Hook into APalPlayerState:OnRelicNumAddedByType
RegisterHook("/Script/Pal.PalPlayerState:OnRelicNumAddedByType", function(Context, Type, AddNum)
    local actualType = Type:get()
    local actualAddNum = AddNum:get()
    print(string.format("[ProgressTracker] Relic collected: Type=%s, AddNum=%d", tostring(actualType), tostring(actualAddNum)))
    
    -- Wait briefly for save data sync, then show progress update
    ExecuteWithDelay(1000, function()
        local player = UEHelpers.GetPlayer()
        if player:IsValid() then
            local currentRegion = player.LastInsideRegionNameID:ToString()
            DisplayScreenMessage(string.format("[Effigy Collected] Region: %s", currentRegion), 5.0)
            ShowProgress()
        end
    end)
end)
