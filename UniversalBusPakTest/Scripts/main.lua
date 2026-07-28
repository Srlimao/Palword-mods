-- main.lua: Minimal UniversalBusPak Example Mod
print("[UniversalBusPakTest] Mod loaded.")

local bus = require("bus_helper")
local MOD_ID = "UniversalBusPakTest"

-- ============================================================================
-- 1. SERVER HANDLER
-- ============================================================================
-- Listens for incoming RPC events sent by client players over the network
bus.RegisterServerHandler(MOD_ID, "Ping", function(playerController, data)
    local playerName = "Unknown"
    pcall(function()
        if playerController and playerController.PlayerState and playerController.PlayerState:IsValid() then
            local pName = playerController.PlayerState:GetPlayerName()
            if pName then playerName = pName:ToString() end
        end
    end)

    print(string.format("[UniversalBusPakTest] [SERVER SUCCESS] Received 'Ping' RPC from player '%s'! Message: '%s'",
        playerName, tostring(data.message)))
end)

-- ============================================================================
-- 2. CLIENT HOTKEY (F8)
-- ============================================================================
-- Only registered on client instances (skipped on dedicated server console)
if not bus.IsDedicatedServer() then
    pcall(RegisterKeyBind, Key.F8, function()
        pcall(ExecuteInGameThread, function()
            print("[UniversalBusPakTest] [CLIENT] F8 Hotkey Pressed: Sending 'Ping' RPC to server...")

            local sent = bus.SendToServer(MOD_ID, "Ping", {
                message = "Hello Dedicated Server!",
                timestamp = os.time()
            })

            if sent then
                print("[UniversalBusPakTest] [CLIENT SUCCESS] 'Ping' RPC sent to server!")
            else
                print("[UniversalBusPakTest] [CLIENT ERROR] SendToServer failed (not in game world).")
            end
        end)
    end)
    print("[UniversalBusPakTest] Press F8 in-game to test client-to-server RPC!")
end
