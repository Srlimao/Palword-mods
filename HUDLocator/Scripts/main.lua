-- Palworld HUDLocator Mod (Merged & Modularized)
-- Built for Palworld v1.0
-- Uses UE4SS Lua Scripting API

local UEHelpers = require("UEHelpers")
local configMod = require("HUDLocator.config")
local tracker = require("HUDLocator.tracker")
local renderer = require("HUDLocator.renderer")
local popup = require("HUDLocator.popup")
local menu = require("HUDLocator.menu")

local CONFIG = configMod.CONFIG
local DebugPrint = configMod.DebugPrint

DebugPrint("Initializing Mod...")

-- Hook into HUD Draw frame tick (ReceiveDrawHUD)
local isHUDHooked = false
local hasLoggedDraw = false
local hasLoggedHookFailure = false

local function RegisterHUDHook()
    if isHUDHooked then return end
    
    local status = pcall(function()
        RegisterHook("/Game/Pal/Blueprint/UI/BP_PalHUD_InGame.BP_PalHUD_InGame_C:ReceiveDrawHUD", function(self, SizeX, SizeY)
            if not hasLoggedDraw then
                hasLoggedDraw = true
                local sx, sy = SizeX, SizeY
                pcall(function() if type(sx) == "userdata" or type(sx) == "table" then sx = sx:get() end end)
                pcall(function() if type(sy) == "userdata" or type(sy) == "table" then sy = sy:get() end end)
                DebugPrint("ReceiveDrawHUD hook successfully firing! Screen Size: " .. tostring(sx) .. "x" .. tostring(sy))
            end
            local hud = self:get()
            if not hud or not hud:IsValid() then return end
            
            renderer.draw(
                hud, 
                tracker.activePlayers, 
                tracker.activeRelics, 
                tracker.activeChests, 
                tracker.activeEggs,
                tracker.activeCaves,
                tracker.activeLoot,
                tracker.cachedLocalPlayer,
                SizeX, SizeY
            )
        end)
    end)
    
    if status then
        isHUDHooked = true
        DebugPrint("HUD ReceiveDrawHUD hook successfully registered via UE4SS!")
    else
        if not hasLoggedHookFailure then
            DebugPrint("Failed to register ReceiveDrawHUD hook (class might not be loaded yet). Background timer will retry silently...")
            hasLoggedHookFailure = true
        end
    end
end

-- Try to hook immediately (handles mid-game mod reloading)
RegisterHUDHook()

-- Listen for new HUD objects to hook when loaded (handles startup / level load)
NotifyOnNewObject("/Game/Pal/Blueprint/UI/BP_PalHUD_InGame.BP_PalHUD_InGame_C", function(hudObj)
    RegisterHUDHook()
end)

-- Start periodic background scan loop
local function StartPeriodicScan()
    local function loop()
        -- Robust hook retry to bypass NotifyOnNewObject bugs
        if not isHUDHooked then
            RegisterHUDHook()
        end
        
        local status, err = pcall(tracker.scan)
        if not status then
            print("[HUDLocator] ERROR in Scan loop: " .. tostring(err))
        end
        ExecuteWithDelay(CONFIG.Global.ScanIntervalMs, loop)
    end
    ExecuteWithDelay(CONFIG.Global.ScanIntervalMs, loop)
end

-- Setup hotkeys

local function GetKey(keyStr, fallbackKey)
    if not keyStr then return fallbackKey end
    return Key[keyStr] or fallbackKey
end

-- 5. HUD Config Menu Toggle (Alt + F6)
RegisterKeyBind(GetKey(CONFIG.Global.KeyBinds and CONFIG.Global.KeyBinds.ToggleMenu, Key.F6), {ModifierKey.ALT}, function()
    menu.Toggle()
end)

-- 6. HUD Config Menu Navigation
RegisterKeyBind(GetKey(CONFIG.Global.KeyBinds and CONFIG.Global.KeyBinds.MenuUp, Key.UP_ARROW), {ModifierKey.ALT}, function()
    if menu.isOpen then menu.Navigate("up") end
end)

RegisterKeyBind(GetKey(CONFIG.Global.KeyBinds and CONFIG.Global.KeyBinds.MenuDown, Key.DOWN_ARROW), {ModifierKey.ALT}, function()
    if menu.isOpen then menu.Navigate("down") end
end)

RegisterKeyBind(GetKey(CONFIG.Global.KeyBinds and CONFIG.Global.KeyBinds.MenuLeft, Key.LEFT_ARROW), {ModifierKey.ALT}, function()
    if menu.isOpen then menu.Navigate("left") end
end)

RegisterKeyBind(GetKey(CONFIG.Global.KeyBinds and CONFIG.Global.KeyBinds.MenuRight, Key.RIGHT_ARROW), {ModifierKey.ALT}, function()
    if menu.isOpen then menu.Navigate("right") end
end)

-- Alt+R: Manual Config Reload from file
RegisterKeyBind(Key.R, {ModifierKey.ALT}, function()
    if menu.isOpen then return end
    
    local status, err = pcall(function()
        configMod.LoadConfig()
    end)
    
    if status then
        print("[HUDLocator] Configuration reloaded successfully from central file.")
        pcall(popup.Show, "HUD Settings Reloaded", 120)
    else
        print("[HUDLocator] ERROR: Failed to manually reload configuration: " .. tostring(err))
    end
end)

-- Alt+I: Dump Map Object Database and Translations
RegisterKeyBind(Key.I, {ModifierKey.ALT}, function()
    local status, err = pcall(function()
        local world = UEHelpers.GetWorld()
        local util = StaticFindObject("/Script/Pal.Default__PalMasterDataTablesUtility")
        
        local dt = nil
        local statusDT, res = pcall(function() return util:GetMapObjectDataTable(world) end)
        if statusDT and res and res:IsValid() then
            dt = res
            print("[HUDLocator] Successfully retrieved Map Object Data Table via MasterDataTablesUtility CDO.")
        else
            -- Fallback
            local path = "/Game/Pal/DataTable/MapObject/DT_MapObjectDataTable.DT_MapObjectDataTable"
            print("[HUDLocator] Falling back to loading Map Object Data Table from path: " .. tostring(path))
            dt = StaticFindObject(path)
            if not dt then
                dt = StaticLoadObject(path)
            end
        end
        
        if not dt or not dt:IsValid() then
            error("Could not retrieve or load Map Object Data Table.")
        end
        
        local rows = dt:GetRowNames()
        if not rows then
            error("GetRowNames returned nil on the Map Object Data Table")
        end
        
        print("[HUDLocator] Dumping all Treasure/Box map objects and translations:")
        for _, rowName in ipairs(rows) do
            local rowStr = nil
            if type(rowName) == "string" then
                rowStr = rowName
            else
                pcall(function() rowStr = rowName:ToString() end)
            end
            if not rowStr then rowStr = tostring(rowName) end

            if string.find(rowStr, "Treasure") or string.find(rowStr, "Box") then
                local key = "MAPOBJECT_NAME_" .. rowStr
                local tStatus, outText = pcall(function() return util:GetLocalizedText(world, 13, FName(key)) end)
                local trans = "ERROR"
                if tStatus and outText then
                    pcall(function() trans = outText:ToString() end)
                end
                print(string.format("[HUDLocator DEBUG] Row: %s | Key: %s | Translation: %s", rowStr, key, trans))
            end
        end
        pcall(popup.Show, "Map Object DB Dumped to Console!", 120)
    end)
    
    if not status then
        print("[HUDLocator] ERROR dumping map object database: " .. tostring(err))
        pcall(popup.Show, "Database Dump Failed", 120)
    end
end)

-- Start scanning
StartPeriodicScan()

print("[HUDLocator] Mod Loaded Successfully!")

