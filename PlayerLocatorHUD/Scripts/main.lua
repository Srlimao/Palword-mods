-- Palworld PlayerLocatorHUD Mod
-- Built for Palworld v1.0
-- Uses UE4SS Lua Scripting API

local UEHelpers = require("UEHelpers")

local CONFIG = {
    Enabled = true,
    DrawBox = true,             -- Toggle for drawing the full background box
    Debug = false,
    FontScale = 1.2,            -- Name line font size (default font friendly)
    SmallFontScale = 0.9,       -- Distance line font size (default font friendly)
    FontCharW  = 8.0,           -- Estimated px width per character per unit of FontScale
    FontLineH  = 12.0,          -- Estimated px line height per unit of FontScale
    TextOffsetZ = 120.0,        -- Draw above their head (1.2 metres)
    -- Nameplate box
    BoxPadX = 10.0,             -- Horizontal inner padding
    BoxPadY = 6.0,              -- Vertical inner padding
    BoxColor   = { R = 0.8, G = 0.8, B = 1.00, A = 1 }, -- Light blue, half-transparent
    BorderWidth = 1.5,          -- Thickness of the border
    -- Fixed nameplate colours
    NameColor   = { R = 0.0,  G = 0.0,  B = 0.0,  A = 1.00 }, -- Dark blue for player name
    DistColor   = { R = 0.0,  G = 0.0,  B = 0.0,  A = 1.00 }, -- Slightly lighter blue for distance
    BorderColor = { R = 0.0,  G = 0.0,  B = 0.0,  A = 1.00 }, -- Solid black border
    ScanIntervalMs = 2000, -- Scan every 2 seconds for fresher positions while staying smooth
    GraceRadiusM = 30      -- Hide labels within this many metres (avoids own name / crowded close-quarters)
}

local function DebugPrint(msg)
    if CONFIG.Debug then
        print("[PlayerLocatorHUD] " .. tostring(msg))
    end
end

-- Lightweight JSON parser in pure Lua (handles nested tables/objects)
local function ParseJSON(str)
    -- Strip comments if present
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
        pos = pos + 1 -- skip '{'
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
                pos = pos + 1 -- skip '"'
                skip_whitespace()
                if str:sub(pos, pos) ~= ':' then
                    error("Expected ':' at position " .. pos)
                end
                pos = pos + 1 -- skip ':'
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
        pos = pos + 1 -- skip '['
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
        pos = pos + 1 -- skip quote
        local start = pos
        while pos <= #str do
            local c = str:sub(pos, pos)
            if c == '"' and str:sub(pos - 1, pos - 1) ~= '\\' then
                break
            end
            pos = pos + 1
        end
        local val = str:sub(start, pos - 1)
        pos = pos + 1 -- skip quote
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
    if status then
        return val
    else
        return nil
    end
end

local function GetConfigFilePath()
    local info = debug.getinfo(1, "S")
    if info and info.source and info.source:sub(1, 1) == "@" then
        local src = info.source:sub(2)
        -- Match the parent directory of "Scripts/main.lua"
        local modDir = src:match("(.*)[/\\]Scripts[/\\]main%.lua")
        if modDir then
            return modDir .. "/playerlocatorhud.modconfig.json"
        end
    end
    -- Fallback
    return "Mods/PlayerLocatorHUD/config.json"
end

local function LoadConfig()
    local configPath = GetConfigFilePath()
    
    -- Try the dynamic path first
    local paths = {
        configPath,
        "Mods/ManagedMods/PlayerLocatorHUD/playerlocatorhud.modconfig.json",
        "Mods/NativeMods/UE4SS/Mods/PlayerLocatorHUD/playerlocatorhud.modconfig.json",
        "playerlocatorhud.modconfig.json"
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
        print("[PlayerLocatorHUD] Config file not found. Generating default at: " .. configPath)
        local outFile = io.open(configPath, "w")
        
        -- Fallback if we can't write to the dynamic path
        if not outFile then
            configPath = "playerlocatorhud.modconfig.json"
            outFile = io.open(configPath, "w")
        end
        
        if outFile then
            outFile:write([[{
  "Enabled": true,
  "DrawBox": true,
  "Debug": false,
  "FontScale": 1.2,
  "SmallFontScale": 0.9,
  "FontCharW": 8.0,
  "FontLineH": 12.0,
  "TextOffsetZ": 120.0,
  "BoxPadX": 10.0,
  "BoxPadY": 6.0,
  "BoxColor": {
    "R": 0.8,
    "G": 0.8,
    "B": 1.0,
    "A": 1.0
  },
  "BorderWidth": 1.5,
  "NameColor": {
    "R": 0.0,
    "G": 0.0,
    "B": 0.0,
    "A": 1.0
  },
  "DistColor": {
    "R": 0.0,
    "G": 0.0,
    "B": 0.0,
    "A": 1.0
  },
  "BorderColor": {
    "R": 0.0,
    "G": 0.0,
    "B": 0.0,
    "A": 1.0
  },
  "ScanIntervalMs": 2000,
  "GraceRadiusM": 30
}
]])
            outFile:close()
            print("[PlayerLocatorHUD] Default config generated at " .. configPath)
        else
            print("[PlayerLocatorHUD] Failed to generate default config.")
        end
        return
    end
    
    local content = file:read("*all")
    file:close()
    
    local parsed = ParseJSON(content)
    if parsed then
        for k, v in pairs(parsed) do
            CONFIG[k] = v
        end
        print("[PlayerLocatorHUD] Config loaded successfully from config.json!")
    else
        print("[PlayerLocatorHUD] Failed to parse config.json, using defaults.")
    end
end

-- Initialise config loading
pcall(LoadConfig)

DebugPrint("Initializing Mod...")

local activePlayers = {}
local cachedLocalPlayer = nil

local function ScanPlayers()
    if not CONFIG.Enabled then
        activePlayers = {}
        return
    end
    
    -- Safety check: Only scan when HUD is active (in-world)
    local hudCheck = FindFirstOf("BP_PalHUD_InGame_C")
    if not hudCheck or not hudCheck:IsValid() then
        activePlayers = {}
        return
    end
    
    local localPlayer = UEHelpers.GetPlayer()
    if not localPlayer or not localPlayer:IsValid() then return end
    
    -- Cache local player reference to avoid calling GetPlayer() on the frame tick
    cachedLocalPlayer = localPlayer
    
    local localPlayerState = localPlayer.PlayerState
    if not localPlayerState or not localPlayerState:IsValid() then return end
    
    -- Find all PlayerState actors in memory
    local playerStates = FindAllOf("PalPlayerState") or {}
    local newPlayers = {}
    local seen = {} -- Deduplicate: ghost states linger after disconnect, same name can appear twice
    
    for _, state in ipairs(playerStates) do
        if state:IsValid() and state ~= localPlayerState then
            pcall(function()
                local namePrivate = state.PlayerNamePrivate
                if namePrivate then
                    local nameStr = namePrivate:ToString()
                    -- Skip if we already have an entry for this name (ghost/duplicate state)
                    if not seen[nameStr] then
                        local loc = state.CachedPlayerLocation
                        if loc and (loc.X ~= 0.0 or loc.Y ~= 0.0 or loc.Z ~= 0.0) then
                            seen[nameStr] = true
                            table.insert(newPlayers, {
                                Name = nameStr,
                                Pos = { X = loc.X, Y = loc.Y, Z = loc.Z }
                            })
                        end
                    end
                end
            end)
        end
    end
    
    activePlayers = newPlayers
end


-- Hook into HUD Draw frame tick (ReceiveDrawHUD)
local isHUDHooked = false

local function RegisterHUDHook()
    if isHUDHooked then return end
    
    local status = pcall(function()
        RegisterHook("/Game/Pal/Blueprint/UI/BP_PalHUD_InGame.BP_PalHUD_InGame_C:ReceiveDrawHUD", function(self, SizeX, SizeY)
            local hud = self:get()
            if not hud or not hud:IsValid() then return end
            if not CONFIG.Enabled then return end
            
            -- Use the cached player reference to eliminate GetPlayer() overhead entirely
            local player = cachedLocalPlayer
            if not player or not player:IsValid() then return end
            
            local playerPos = player:K2_GetActorLocation()
            if not playerPos then return end
            
            for _, otherPlayer in ipairs(activePlayers) do
                local dx = otherPlayer.Pos.X - playerPos.X
                local dy = otherPlayer.Pos.Y - playerPos.Y
                local dz = otherPlayer.Pos.Z - playerPos.Z
                local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
                local distMeters = math.floor(dist / 100.0)
                
                -- Skip anyone within the grace radius
                if distMeters > CONFIG.GraceRadiusM then
                    local nameStr = otherPlayer.Name
                    local distStr = distMeters .. "m"
                    
                    local textWorldPos = { X = otherPlayer.Pos.X, Y = otherPlayer.Pos.Y, Z = otherPlayer.Pos.Z + CONFIG.TextOffsetZ }
                    local textScreen = hud:Project(textWorldPos, false)
                    
                    if textScreen.Z > 0.0 then
                        -- Person icon prefix on the name line
                        local iconStr = "@ " -- Plain ASCII person indicator (safe for UE4 DrawText)
                        local labelStr = iconStr .. nameStr

                        -- Estimate dimensions for two-line layout
                        -- FontCharW / FontLineH tune the box to match the active font's metrics
                        local nameW  = #labelStr * CONFIG.FontCharW * CONFIG.FontScale
                        local distW  = #distStr  * CONFIG.FontCharW * CONFIG.SmallFontScale
                        local nameH  = CONFIG.FontLineH * CONFIG.FontScale
                        local distH  = CONFIG.FontLineH * CONFIG.SmallFontScale
                        local lineGap = 4.0
                        local bw     = CONFIG.BorderWidth
                        
                        local contentW = math.max(nameW, distW)
                        local contentH = nameH + lineGap + distH
                        local boxW = contentW + CONFIG.BoxPadX * 2
                        local boxH = contentH + CONFIG.BoxPadY * 2
                        
                        -- Centre box on the projected world point
                        local boxX = textScreen.X - boxW * 0.5
                        local boxY = textScreen.Y - boxH * 0.5

                        if CONFIG.DrawBox then
                            -- Border colour: solid black
                            -- 1. Border rect (drawn first, slightly larger than the fill box)
                            hud:DrawRect(CONFIG.BorderColor, boxX - bw, boxY - bw, boxW + bw * 2, boxH + bw * 2)

                            -- 2. Background fill box
                            hud:DrawRect(CONFIG.BoxColor, boxX, boxY, boxW, boxH)
                            
                            -- 3. Name + icon (top line, centred)
                            local nameX = textScreen.X - nameW * 0.5
                            local nameY = boxY + CONFIG.BoxPadY
                            
                            -- 4. Distance (bottom line, smaller, centred)
                            local distX = textScreen.X - distW * 0.5
                            local distY = nameY + nameH + lineGap

                            hud:DrawText(labelStr, CONFIG.NameColor, nameX, nameY, nil, CONFIG.FontScale, false)
                            hud:DrawText(distStr, CONFIG.DistColor, distX, distY, nil, CONFIG.SmallFontScale, false)
                        else
                            -- Simple single-line format: Name [Distance]
                            local simpleStr = nameStr .. " [" .. distStr .. "]"
                            
                            -- Estimate width and height
                            local simpleW = #simpleStr * CONFIG.FontCharW * CONFIG.FontScale
                            local simpleH = CONFIG.FontLineH * CONFIG.FontScale
                            
                            local simpleX = textScreen.X - simpleW * 0.5
                            local simpleY = textScreen.Y - simpleH * 0.5
                            
                            local nameCol = { R = 1.0, G = 1.0, B = 1.0, A = 1.0 }
                            local borderCol = { R = 0.0, G = 0.0, B = 0.0, A = 0.8 }
                            local off = 1.0
                            
                            -- Draw soft borders
                            hud:DrawText(simpleStr, borderCol, simpleX - off, simpleY - off, nil, CONFIG.FontScale, false)
                            hud:DrawText(simpleStr, borderCol, simpleX + off, simpleY - off, nil, CONFIG.FontScale, false)
                            hud:DrawText(simpleStr, borderCol, simpleX - off, simpleY + off, nil, CONFIG.FontScale, false)
                            hud:DrawText(simpleStr, borderCol, simpleX + off, simpleY + off, nil, CONFIG.FontScale, false)
                            
                            -- Draw main text
                            hud:DrawText(simpleStr, nameCol, simpleX, simpleY, nil, CONFIG.FontScale, false)
                        end
                    end
                end
            end
        end)
    end)
    
    if status then
        isHUDHooked = true
        DebugPrint("HUD hook successfully registered!")
    else
        DebugPrint("Failed to register HUD hook.")
    end
end

RegisterHUDHook()

NotifyOnNewObject("/Game/Pal/Blueprint/UI/BP_PalHUD_InGame.BP_PalHUD_InGame_C", function(hudObj)
    RegisterHUDHook()
end)

-- Start periodic scanner loop (interval controlled by CONFIG.ScanIntervalMs)
local function StartPeriodicScan()
    local function loop()
        pcall(ScanPlayers)
        ExecuteWithDelay(CONFIG.ScanIntervalMs, loop)
    end
    ExecuteWithDelay(CONFIG.ScanIntervalMs, loop)
end

-- Setup toggle hotkey (Alt + F7)
RegisterKeyBind(Key.F7, {ModifierKey.ALT}, function()
    CONFIG.Enabled = not CONFIG.Enabled
    if CONFIG.Enabled then
        print("[PlayerLocatorHUD] Enabled player locator.")
    else
        print("[PlayerLocatorHUD] Disabled player locator.")
        activePlayers = {}
    end
end)

-- Setup toggle hotkey for the box (Alt + F10)
RegisterKeyBind(Key.F10, {ModifierKey.ALT}, function()
    CONFIG.DrawBox = not CONFIG.DrawBox
    if CONFIG.DrawBox then
        print("[PlayerLocatorHUD] Full box display enabled.")
    else
        print("[PlayerLocatorHUD] Simple text display enabled.")
    end
end)

StartPeriodicScan()

print("[PlayerLocatorHUD] Mod Loaded Successfully!")
