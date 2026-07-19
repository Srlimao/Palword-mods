-- IdleServerShutdown Mod
-- Shuts down the server if no players are logged in for a specified time

local IDLE_THRESHOLD_MINUTES = 30
local CHECK_INTERVAL_MS = 60000 -- 1 minute

local idleMinutes = 0

local function ShutdownServer()
    print("[IdleServerShutdown] Server has been empty for " .. IDLE_THRESHOLD_MINUTES .. " minutes. Shutting down gracefully...")
    
    local KismetSystemLibrary = StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
    local world = FindFirstOf("World")
    
    if KismetSystemLibrary and world and world:IsValid() then
        -- QuitGame(WorldContextObject, SpecificPlayer, QuitPreference (0=Quit), bIgnorePlatformRestrictions)
        KismetSystemLibrary:QuitGame(world, nil, 0, false)
    else
        print("[IdleServerShutdown] Error: Could not find KismetSystemLibrary or World. Unable to shutdown.")
    end
end

local function CheckPlayerCount()
    local success, stopLoop = pcall(function()
        local players = FindAllOf("PalPlayerState")
        local playerCount = 0
        
        if players then
            for i, playerState in ipairs(players) do
                if playerState:IsValid() then
                    playerCount = playerCount + 1
                end
            end
        end
        
        if playerCount == 0 then
            idleMinutes = idleMinutes + 1
            local statusMsg = "[IdleServerShutdown] No players online. Idle time: " .. idleMinutes .. " / " .. IDLE_THRESHOLD_MINUTES .. " minutes."
            print(statusMsg)
            
            -- Broadcast to server chat/logs if idle for 5+ minutes
            if idleMinutes >= 5 then
                local KismetSystemLibrary = StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
                local world = FindFirstOf("World")
                if KismetSystemLibrary and world and world:IsValid() then
                    KismetSystemLibrary:ExecuteConsoleCommand(world, "Broadcast " .. statusMsg, nil)
                end
            end
            
            if idleMinutes >= IDLE_THRESHOLD_MINUTES then
                ShutdownServer()
                return true -- Stop looping after shutdown triggers
            end
        else
            if idleMinutes > 0 then
                local resetMsg = "[IdleServerShutdown] Player detected. Resetting idle timer."
                print(resetMsg)
                
                -- If we were previously broadcasting, let them know it's aborted
                if idleMinutes >= 5 then
                    local KismetSystemLibrary = StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
                    local world = FindFirstOf("World")
                    if KismetSystemLibrary and world and world:IsValid() then
                        KismetSystemLibrary:ExecuteConsoleCommand(world, "Broadcast " .. resetMsg, nil)
                    end
                end
            end
            idleMinutes = 0
        end
        return false
    end)
    
    if not success then
        print("[IdleServerShutdown] Error during idle check: " .. tostring(stopLoop))
    end
    
    -- Continue the loop unless shutdown was triggered
    if not success or not stopLoop then
        ExecuteWithDelay(CHECK_INTERVAL_MS, CheckPlayerCount)
    end
end

-- Start the loop
print("[IdleServerShutdown] Mod loaded. Starting idle check loop (Threshold: " .. IDLE_THRESHOLD_MINUTES .. " minutes).")
ExecuteWithDelay(CHECK_INTERVAL_MS, CheckPlayerCount)
