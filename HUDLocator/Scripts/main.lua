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
        
        pcall(tracker.scan)
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

-- Alt+I: Dump Item Database
RegisterKeyBind(Key.I, {ModifierKey.ALT}, function()
    local status, err = pcall(function()
        local utils = require("HUDLocator.utils")
        
        -- Load Item Data Table Path from PalEditorSetting CDO
        local path = "/Game/Pal/DataTable/Item/DT_ItemDataTable.DT_ItemDataTable"
        local statusCDO, cdo = pcall(function() return StaticFindObject("/Script/Pal.Default__PalEditorSetting") end)
        if statusCDO and cdo and cdo.ItemDataTableAssetPath then
            pcall(function() path = cdo.ItemDataTableAssetPath.AssetPathName:ToString() end)
        end
        
        print("[HUDLocator] Loading Item Data Table from: " .. tostring(path))
        local dt = StaticFindObject(path)
        if not dt then
            dt = StaticLoadObject(path)
        end
        
        if not dt then
            error("Could not load Item Data Table at path: " .. tostring(path))
        end
        
        local rows = dt:GetRowNames()
        if not rows then
            error("GetRowNames returned nil on the Item Data Table")
        end
        
        local itemList = {}
        for _, rowName in ipairs(rows) do
            local itemId = nil
            if type(rowName) == "string" then
                itemId = rowName
            elseif type(rowName) == "userdata" or type(rowName) == "table" then
                local stringifyStatus, stringifyVal = pcall(function() return rowName:ToString() end)
                if stringifyStatus and stringifyVal then
                    itemId = stringifyVal
                else
                    itemId = tostring(rowName)
                end
            else
                itemId = tostring(rowName)
            end

            if itemId and itemId ~= "" and itemId ~= "None" then
                local transName = utils.GetTranslatedItemName(itemId)
                if not transName or transName == "" then
                    transName = itemId
                end
                table.insert(itemList, { Id = itemId, Name = transName })
            end
        end
        
        -- Sort alphabetically by ID
        table.sort(itemList, function(a, b) return a.Id < b.Id end)
        
        -- Write as JSON
        local lines = {}
        table.insert(lines, "[")
        for i, item in ipairs(itemList) do
            local comma = (i < #itemList) and "," or ""
            table.insert(lines, string.format("  { \"id\": \"%s\", \"name\": \"%s\" }%s", item.Id, item.Name, comma))
        end
        table.insert(lines, "]")
        
        local f = io.open("D:\\Mods\\Palword\\HUDLocator\\item_list.json", "w")
        if f then
            f:write(table.concat(lines, "\n"))
            f:close()
            print("[HUDLocator] Item database successfully dumped to D:\\Mods\\Palword\\HUDLocator\\item_list.json")
            pcall(popup.Show, "Item Database Dumped!", 120)
        else
            error("Failed to open output file for writing.")
        end
    end)
    
    if not status then
        print("[HUDLocator] ERROR dumping item database: " .. tostring(err))
        pcall(popup.Show, "Database Dump Failed", 120)
    end
end)

-- Start scanning
StartPeriodicScan()

print("[HUDLocator] Mod Loaded Successfully!")

