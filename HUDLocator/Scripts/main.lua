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

local function RegisterHUDHook()
    if isHUDHooked then return end
    
    local status = pcall(function()
        RegisterHook("/Game/Pal/Blueprint/UI/BP_PalHUD_InGame.BP_PalHUD_InGame_C:ReceiveDrawHUD", function(self, SizeX, SizeY)
            local hud = self:get()
            if not hud or not hud:IsValid() then return end
            
            renderer.draw(
                hud, 
                tracker.activePlayers, 
                tracker.activeRelics, 
                tracker.activeChests, 
                tracker.activeEggs,
                tracker.activeCaves,
                tracker.cachedLocalPlayer,
                SizeX, SizeY
            )
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

-- Start periodic background scan loop
local function StartPeriodicScan()
    local function loop()
        -- Robust hook retry to bypass NotifyOnNewObject bugs
        if not isHUDHooked then
            RegisterHUDHook()
        end
        
        pcall(tracker.scan)
        ExecuteWithDelay(CONFIG.ScanIntervalMs, loop)
    end
    ExecuteWithDelay(CONFIG.ScanIntervalMs, loop)
end

-- Setup hotkeys

-- 5. HUD Config Menu Toggle (Alt + F6)
RegisterKeyBind(Key.F6, {ModifierKey.ALT}, function()
    menu.Toggle()
end)

-- 6. HUD Config Menu Navigation
RegisterKeyBind(Key.UP_ARROW, {ModifierKey.ALT}, function()
    if menu.isOpen then menu.Navigate("up") end
end)

RegisterKeyBind(Key.DOWN_ARROW, {ModifierKey.ALT}, function()
    if menu.isOpen then menu.Navigate("down") end
end)

RegisterKeyBind(Key.LEFT_ARROW, {ModifierKey.ALT}, function()
    if menu.isOpen then menu.Navigate("left") end
end)

RegisterKeyBind(Key.RIGHT_ARROW, {ModifierKey.ALT}, function()
    if menu.isOpen then menu.Navigate("right") end
end)

-- Start scanning
StartPeriodicScan()

print("[HUDLocator] Mod Loaded Successfully!")
