-- Palworld HUDLocator Mod (Merged & Modularized)
-- Built for Palworld v1.0
-- Uses UE4SS Lua Scripting API

local UEHelpers = require("UEHelpers")
local configMod = require("HUDLocator.config")
local tracker = require("HUDLocator.tracker")
local renderer = require("HUDLocator.renderer")

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
                tracker.cachedLocalPlayer
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
        pcall(tracker.scan)
        ExecuteWithDelay(CONFIG.ScanIntervalMs, loop)
    end
    ExecuteWithDelay(CONFIG.ScanIntervalMs, loop)
end

-- Setup hotkeys
-- 1. Toggle Player Locator (Alt + F7)
RegisterKeyBind(Key.F7, {ModifierKey.ALT}, function()
    CONFIG.ShowPlayers = not CONFIG.ShowPlayers
    if CONFIG.ShowPlayers then
        print("[HUDLocator] Enabled player locator.")
    else
        print("[HUDLocator] Disabled player locator.")
        tracker.activePlayers = {}
    end
end)

-- 2. Toggle Items Finder (Alt + F8)
RegisterKeyBind(Key.F8, {ModifierKey.ALT}, function()
    local toggleVal = not (CONFIG.ShowRelics or CONFIG.ShowChests or CONFIG.ShowEggs)
    CONFIG.ShowRelics = toggleVal
    CONFIG.ShowChests = toggleVal
    CONFIG.ShowEggs = toggleVal
    if toggleVal then
        print("[HUDLocator] Enabled items locator.")
    else
        print("[HUDLocator] Disabled items locator.")
        tracker.activeRelics = {}
        tracker.activeChests = {}
        tracker.activeEggs = {}
    end
end)

-- 3. Toggle Player Nameplate Box style (Alt + F10)
RegisterKeyBind(Key.F10, {ModifierKey.ALT}, function()
    CONFIG.DrawBox = not CONFIG.DrawBox
    if CONFIG.DrawBox then
        print("[HUDLocator] Full box display enabled.")
    else
        print("[HUDLocator] Simple text display enabled.")
    end
end)

-- Start scanning
StartPeriodicScan()

print("[HUDLocator] Mod Loaded Successfully!")
