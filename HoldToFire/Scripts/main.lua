-- Hold To Fire Mod
-- Allows holding down the trigger to fire semi-automatic weapons (converting them to fully automatic)
-- Client & Server mod

-- Force clear package cache to support clean hot-reloads
package.loaded["HoldToFire.config"] = nil
package.loaded["HoldToFire.json"] = nil

local configMod = require("HoldToFire.config")
local DebugPrint = configMod.DebugPrint
local CONFIG = configMod.CONFIG
local UEHelpers = require("UEHelpers")

print("[HoldToFire] Loading Hold To Fire Mod (Real-time HUD Hook for State Inspection)")

-- Map of weapon types to their config keys
local WeaponTypeKeys = {
    [2] = "Handgun",
    [4] = "Shotgun",
    [5] = "SniperRifle",
    [6] = "RocketLauncher",
    [9] = "BowGun",
    [13] = "LaserRifle",
    [14] = "MissileLauncher",
    [15] = "GrenadeLauncher"
}

local lastPrintTime = 0
local isHUDHooked = false

local function RegisterHUDHook()
    if isHUDHooked then return end
    
    local status, err = pcall(function()
        RegisterHook("/Game/Pal/Blueprint/UI/BP_PalHUD_InGame.BP_PalHUD_InGame_C:ReceiveDrawHUD", function(self, SizeX, SizeY)
            local localPlayer = UEHelpers.GetPlayer()
            if not localPlayer or not localPlayer:IsValid() then return end
            
            local shooter = localPlayer.ShooterComponent
            if not shooter or not shooter:IsValid() then return end
            
            local weapon = shooter.HasWeapon
            if not weapon or not weapon:IsValid() then return end
            
            local now = os.clock()
            -- Throttle print to once every 100ms so we don't spam the log too aggressively
            if now - lastPrintTime > 0.1 then
                lastPrintTime = now
                
                local wType = weapon.WeaponType
                if type(wType) == "userdata" then wType = wType:get() end
                local configKey = WeaponTypeKeys[wType] or "Unknown"
                
                -- Read flags
                local holdTrigger = shooter.bIsHoldTrigger
                local reqPullTrigger = shooter.bIsRequestPullTrigger
                local shootingHold = shooter.bIsShootingHold
                local isShooting = shooter.bIsShooting
                
                pcall(function() if type(holdTrigger) == "userdata" then holdTrigger = holdTrigger:get() end end)
                pcall(function() if type(reqPullTrigger) == "userdata" then reqPullTrigger = reqPullTrigger:get() end end)
                pcall(function() if type(shootingHold) == "userdata" then shootingHold = shootingHold:get() end end)
                pcall(function() if type(isShooting) == "userdata" then isShooting = isShooting:get() end end)
                
                print(string.format("[HoldToFire] Weapon: %s (%s) | holdTrigger: %s | reqPullTrigger: %s | shootingHold: %s | isShooting: %s",
                    tostring(configKey),
                    tostring(weapon:GetClass():GetName()),
                    tostring(holdTrigger),
                    tostring(reqPullTrigger),
                    tostring(shootingHold),
                    tostring(isShooting)
                ))
            end
        end)
    end)
    
    if status then
        isHUDHooked = true
        print("[HoldToFire] HUD ReceiveDrawHUD hook registered successfully.")
    else
        print("[HoldToFire] Failed to register HUD hook (retrying): " .. tostring(err))
        ExecuteWithDelay(3000, RegisterHUDHook)
    end
end

RegisterHUDHook()
NotifyOnNewObject("/Game/Pal/Blueprint/UI/BP_PalHUD_InGame.BP_PalHUD_InGame_C", function(hudObj)
    RegisterHUDHook()
end)

print("[HoldToFire] Hold To Fire Mod loaded successfully.")


