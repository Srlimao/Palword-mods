-- EnhancedChestFilter main.lua
print("[EnhancedChestFilter] Mod initializing...")

local config = require("config")
local manager = require("chest_filter_manager")
local ui_injector = require("ui_injector")
local bus = require("bus_helper")

-- ============================================================================
-- 1. SERVER RPC HANDLER
-- ============================================================================
-- Listens for incoming RPC events sent by client players over UniversalBusPak
bus.RegisterServerHandler(config.MOD_ID, "SetChestFilterState", function(playerController, data)
    local playerName = "Host / Local Player"
    pcall(function()
        if playerController and playerController.PlayerState and playerController.PlayerState:IsValid() then
            local pName = playerController.PlayerState:GetPlayerName()
            if pName then playerName = pName:ToString() end
        end
    end)

    if data and data.chestGuid then
        print(string.format("[%s] [SERVER RPC SUCCESS] Received 'SetChestFilterState' from '%s' | Chest GUID: '%s' -> bStrict: %s",
            config.MOD_ID, playerName, tostring(data.chestGuid), tostring(data.bStrictExistingOnly)))

        -- Update server-side manager and persist to server world save JSON
        manager.SetChestStrict(data.chestGuid, data.bStrictExistingOnly)
    end
end)

-- ============================================================================
-- 2. INITIALIZE CHEST FILTER MANAGER & UI HOOKS
-- ============================================================================
local success, err = pcall(function()
    manager.LoadConfig()
    ui_injector.InitializeHooks()
end)
if not success then
    print(string.format("[%s] FATAL ERROR during initialization: %s", config.MOD_ID, tostring(err)))
end

print(string.format("[%s] Mod successfully loaded v%s!", config.MOD_ID, config.MOD_VERSION))
