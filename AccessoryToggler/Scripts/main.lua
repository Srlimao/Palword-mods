-- Palworld Accessory Toggler Mod
-- Built for Palworld v1.0
-- Uses UE4SS Lua Scripting API

local UEHelpers = require("UEHelpers")
local configMod = require("AccessoryToggler.config")
local toggler = require("AccessoryToggler.toggler")
local renderer = require("AccessoryToggler.renderer")
local popup = require("AccessoryToggler.popup")
local utils = require("AccessoryToggler.utils")

local CONFIG = configMod.CONFIG
local DebugPrint = configMod.DebugPrint

DebugPrint("Initializing Accessory Toggler Mod...")




local holdFrames = 0

-- Pre-allocated static FKey wrappers for edit mode to avoid per-frame GC spikes
local KeyLeft = { KeyName = FName("Left") }
local KeyRight = { KeyName = FName("Right") }
local KeyUp = { KeyName = FName("Up") }
local KeyDown = { KeyName = FName("Down") }

local KeyEquals = { KeyName = FName("Equals") }
local KeyAdd = { KeyName = FName("Add") }
local KeyRightBracket = { KeyName = FName("RightBracket") }
local KeyLeftBracket = { KeyName = FName("LeftBracket") }
local KeyBackslash = { KeyName = FName("Backslash") }

local KeyHyphen = { KeyName = FName("Hyphen") }
local KeySubtract = { KeyName = FName("Subtract") }
local KeySlash = { KeyName = FName("Slash") }
local KeyPeriod = { KeyName = FName("Period") }

-- Protected helper to adjust coordinates without anonymous closures
local function UpdateEditCoordinates(sx, sy, dx, dy, dScale, moveAmount, scaleAmount)
    local screenW = (type(sx) == "number" and sx > 0) and sx or 1920.0
    local screenH = (type(sy) == "number" and sy > 0) and sy or 1080.0

    local scale = configMod.CONFIG.HUDScale or 1.0
    local size = 56.0 * scale
    local gap = 12.0 * scale
    local slotsToShow = configMod.CONFIG.SlotsToShow or 4
    slotsToShow = math.max(1, math.min(4, math.floor(tonumber(slotsToShow) or 4)))
    local totalW = (slotsToShow * size) + ((slotsToShow - 1) * gap)

    local maxScrollX = screenW - totalW
    if maxScrollX <= 0 then maxScrollX = 1 end
    local maxScrollY = screenH - size
    if maxScrollY <= 0 then maxScrollY = 1 end

    if not configMod.CONFIG.HUDX then
        configMod.CONFIG.HUDX = 50.0
    end
    if not configMod.CONFIG.HUDY then
        local defaultY = screenH - size - 130.0
        configMod.CONFIG.HUDY = tonumber(string.format("%.1f", (defaultY / maxScrollY) * 100.0))
    end

    -- Ensure they are converted to percentage if they were absolute pixels
    if configMod.CONFIG.HUDX > 100.0 then
        configMod.CONFIG.HUDX = tonumber(string.format("%.1f", (configMod.CONFIG.HUDX / maxScrollX) * 100.0))
    end
    if configMod.CONFIG.HUDY > 100.0 then
        configMod.CONFIG.HUDY = tonumber(string.format("%.1f", (configMod.CONFIG.HUDY / maxScrollY) * 100.0))
    end

    local pctDx = (dx * moveAmount) / maxScrollX * 100.0
    local pctDy = (dy * moveAmount) / maxScrollY * 100.0

    configMod.CONFIG.HUDX = math.max(0.0, math.min(100.0, configMod.CONFIG.HUDX + pctDx))
    configMod.CONFIG.HUDY = math.max(0.0, math.min(100.0, configMod.CONFIG.HUDY + pctDy))
    
    -- Round to 1 decimal place
    configMod.CONFIG.HUDX = tonumber(string.format("%.1f", configMod.CONFIG.HUDX))
    configMod.CONFIG.HUDY = tonumber(string.format("%.1f", configMod.CONFIG.HUDY))
    
    if dScale ~= 0 then
        local currentScale = configMod.CONFIG.HUDScale or 1.0
        local newScale = math.max(0.5, math.min(3.0, currentScale + (dScale * scaleAmount)))
        configMod.CONFIG.HUDScale = tonumber(string.format("%.3f", newScale))
    end
end

local lastInputCheckTime = 0
local cachedDx = 0
local cachedDy = 0
local cachedDScale = 0
local cachedIsAnyHeld = false

-- Helper to safely adjust HUD coordinates and scale continuously
local function HandleEditModeHolding(SizeX, SizeY)
    if not configMod.EditModeActive then 
        holdFrames = 0
        return 
    end
    
    local now = os.clock()
    -- Throttle key state polling to 50Hz (every 20ms) to drastically reduce C++ reflection call overhead
    if now - lastInputCheckTime >= 0.02 then
        lastInputCheckTime = now
        
        local pc = UEHelpers.GetPlayerController()
        if not pc or not pc:IsValid() then return end
        
        local dx = 0
        local dy = 0
        local dScale = 0
        local isAnyHeld = false
        
        -- Read real-time key states directly from APlayerController using pre-allocated wrappers
        local isLeft = pc:IsInputKeyDown(KeyLeft)
        local isRight = pc:IsInputKeyDown(KeyRight)
        local isUp = pc:IsInputKeyDown(KeyUp)
        local isDown = pc:IsInputKeyDown(KeyDown)
        
        local isEquals = pc:IsInputKeyDown(KeyEquals) 
                      or pc:IsInputKeyDown(KeyAdd) 
                      or pc:IsInputKeyDown(KeyRightBracket) 
                      or pc:IsInputKeyDown(KeyLeftBracket) 
                      or pc:IsInputKeyDown(KeyBackslash)

        local isHyphen = pc:IsInputKeyDown(KeyHyphen) 
                      or pc:IsInputKeyDown(KeySubtract) 
                      or pc:IsInputKeyDown(KeySlash) 
                      or pc:IsInputKeyDown(KeyPeriod)
        
        if isLeft then dx = dx - 1; isAnyHeld = true end
        if isRight then dx = dx + 1; isAnyHeld = true end
        if isUp then dy = dy - 1; isAnyHeld = true end
        if isDown then dy = dy + 1; isAnyHeld = true end
        
        if isEquals then dScale = dScale + 1; isAnyHeld = true end
        if isHyphen then dScale = dScale - 1; isAnyHeld = true end
        
        cachedDx = dx
        cachedDy = dy
        cachedDScale = dScale
        cachedIsAnyHeld = isAnyHeld
    end
    
    if cachedIsAnyHeld then
        holdFrames = holdFrames + 1
    else
        holdFrames = 0
        return
    end
    
    -- Smooth ramp-up multiplier for fast holding traversal
    local speedMultiplier = 1.0
    if holdFrames > 45 then
        speedMultiplier = 4.0 -- Move very fast after ~0.75 seconds
    elseif holdFrames > 12 then
        speedMultiplier = 2.2 -- Speed up after ~0.2 seconds
    end
    
    -- Adjust coordinates and scale
    local moveAmount = 1.5 * speedMultiplier
    local scaleAmount = 0.005 * speedMultiplier
    
    local sx = utils.SafeUnwrap(SizeX)
    local sy = utils.SafeUnwrap(SizeY)
    
    pcall(UpdateEditCoordinates, sx, sy, cachedDx, cachedDy, cachedDScale, moveAmount, scaleAmount)
end

-- Hook into HUD Draw frame tick (ReceiveDrawHUD)
local isHUDHooked = false
local hasLoggedDraw = false
local hasLoggedHookFailure = false

local lastScanTime = 0

-- Static helper for ReceiveDrawHUD to avoid per-frame closure allocations
local function DrawHUDProtected(hud, SizeX, SizeY)
    renderer.Draw(hud, SizeX, SizeY)
    popup.Draw(hud, SizeX, SizeY)
end

local function RegisterHUDHook()
    if isHUDHooked then return end
    
    local status = pcall(function()
        RegisterHook("/Game/Pal/Blueprint/UI/BP_PalHUD_InGame.BP_PalHUD_InGame_C:ReceiveDrawHUD", function(self, SizeX, SizeY)
            if not hasLoggedDraw then
                hasLoggedDraw = true
                local sx, sy = SizeX, SizeY
                pcall(function() if type(sx) == "userdata" or type(sx) == "table" then sx = sx:get() end end)
                pcall(function() if type(sy) == "userdata" or type(sy) == "table" then sy = sy:get() end end)
                configMod.DebugPrint("ReceiveDrawHUD hook successfully firing! Screen Size: " .. tostring(sx) .. "x" .. tostring(sy))
            end
            local hud = self:get()
            if not hud or not hud:IsValid() then return end
            
            -- Apply continuous holding checks in edit mode
            HandleEditModeHolding(SizeX, SizeY)
            
            local drawStatus, drawErr = pcall(DrawHUDProtected, hud, SizeX, SizeY)
            if not drawStatus then
                print("[AccessoryToggler] ERROR in ReceiveDrawHUD draw: " .. tostring(drawErr))
            end

            -- Periodically run the accessory scan on the draw tick (prevents reload crashes)
            local now = os.clock()
            if now - lastScanTime >= ((CONFIG.ScanIntervalMs or 1500) / 1000.0) then
                lastScanTime = now
                local scanStatus, scanErr = pcall(toggler.Scan)
                if not scanStatus then
                    print("[AccessoryToggler] ERROR in Scan tick: " .. tostring(scanErr))
                end
            end
        end)
    end)
    
    if status then
        isHUDHooked = true
        configMod.DebugPrint("HUD ReceiveDrawHUD hook successfully registered via UE4SS!")
    else
        if not hasLoggedHookFailure then
            configMod.DebugPrint("Failed to register ReceiveDrawHUD hook (class might not be loaded yet). Background timer will retry silently...")
            hasLoggedHookFailure = true
        end
    end
end

-- Try to hook immediately
RegisterHUDHook()

-- Listen for new HUD objects to hook when loaded (handles level loading)
NotifyOnNewObject("/Game/Pal/Blueprint/UI/BP_PalHUD_InGame.BP_PalHUD_InGame_C", function(hudObj)
    configMod.DebugPrint("NotifyOnNewObject fired for BP_PalHUD_InGame_C!")
    RegisterHUDHook()
end)

-- Periodic scan loop is now handled directly inside ReceiveDrawHUD tick

local function GetKey(keyStr, fallbackKey)
    if not keyStr then return fallbackKey end
    return Key[keyStr] or fallbackKey
end

-- Safely resolve key bindings for different engine versions/mappings
local key1 = GetKey(CONFIG.KeyBinds and CONFIG.KeyBinds.ToggleSlot1, Key.FIVE or Key.NUM_5 or Key.N5 or Key["5"])
local key2 = GetKey(CONFIG.KeyBinds and CONFIG.KeyBinds.ToggleSlot2, Key.SIX or Key.NUM_6 or Key.N6 or Key["6"])
local key3 = GetKey(CONFIG.KeyBinds and CONFIG.KeyBinds.ToggleSlot3, Key.SEVEN or Key.NUM_7 or Key.N7 or Key["7"])
local key4 = GetKey(CONFIG.KeyBinds and CONFIG.KeyBinds.ToggleSlot4, Key.EIGHT or Key.NUM_8 or Key.N8 or Key["8"])

-- Register ALT + 5..8 key binds
if key1 then
    RegisterKeyBind(key1, {}, function()
        pcall(function() toggler.ToggleSlot(1) end)
    end)
else
    print("[AccessoryToggler] WARNING: Failed to resolve Key.FIVE")
end

if key2 then
    RegisterKeyBind(key2, {}, function()
        pcall(function() toggler.ToggleSlot(2) end)
    end)
else
    print("[AccessoryToggler] WARNING: Failed to resolve Key.SIX")
end

if key3 then
    RegisterKeyBind(key3, {}, function()
        pcall(function() toggler.ToggleSlot(3) end)
    end)
else
    print("[AccessoryToggler] WARNING: Failed to resolve Key.SEVEN")
end

if key4 then
    RegisterKeyBind(key4, {}, function()
        pcall(function() toggler.ToggleSlot(4) end)
    end)
else
    print("[AccessoryToggler] WARNING: Failed to resolve Key.EIGHT")
end

-- Start scanning (now driven by HUD draw ticks)

-- ----------------------------------------------------
-- HUD EDIT MODE INTERACTIVE CONFIGURATION KEYBINDS
-- ----------------------------------------------------
local keyF7 = GetKey(CONFIG.KeyBinds and CONFIG.KeyBinds.ToggleEditMode, Key.F7)

-- Alt+F7 toggles edit mode
if keyF7 then
    RegisterKeyBind(keyF7, { ModifierKey.ALT }, function()
        pcall(function() 
            configMod.ToggleEditMode() 
            if not configMod.EditModeActive then
                holdFrames = 0
            end
        end)
    end)
else
    configMod.DebugPrint("WARNING: Failed to resolve Key.F7")
end

local keyH = GetKey(CONFIG.KeyBinds and CONFIG.KeyBinds.ToggleUI, Key.H)

-- Alt+H toggles UI visibility
if keyH then
    RegisterKeyBind(keyH, { ModifierKey.ALT }, function()
        pcall(function()
            CONFIG.Enabled = not CONFIG.Enabled
            configMod.SaveConfig()
            if CONFIG.Enabled then
                local shownText = configMod.GetTranslation("Popup_HUDShown", "HUD Shown")
                popup.Show(shownText, 120, { R = 0.0, G = 0.96, B = 0.83, A = 1.0 })
            else
                local hiddenText = configMod.GetTranslation("Popup_HUDHidden", "HUD Hidden")
                popup.Show(hiddenText, 120, { R = 1.0, G = 0.35, B = 0.37, A = 1.0 })
            end
        end)
    end)
else
    configMod.DebugPrint("WARNING: Failed to resolve Key.H")
end

local keyR = GetKey(CONFIG.KeyBinds and CONFIG.KeyBinds.ResetCoords, Key.R)

-- Alt+R resets coordinates to default while in edit mode, or reloads config when not in edit mode
if keyR then
    RegisterKeyBind(keyR, { ModifierKey.ALT }, function()
        pcall(function()
            if configMod.EditModeActive then
                configMod.CONFIG.HUDX = nil
                configMod.CONFIG.HUDY = nil
                configMod.CONFIG.HUDScale = 1.0
                configMod.DebugPrint("HUD coordinates and scale reset to default via Alt+R!")
            else
                local status, err = pcall(function()
                    configMod.LoadConfig()
                end)
                if status then
                    print("[AccessoryToggler] Configuration reloaded successfully from central file.")
                    pcall(popup.Show, "Settings Reloaded", 120)
                else
                    print("[AccessoryToggler] ERROR: Failed to reload configuration: " .. tostring(err))
                end
            end
        end)
    end)
else
    configMod.DebugPrint("WARNING: Failed to resolve Key.R")
end

configMod.DebugPrint("Mod Loaded Successfully!")
