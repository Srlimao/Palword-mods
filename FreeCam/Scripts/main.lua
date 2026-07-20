-- Palworld FreeCam Mod
-- Built for Palworld v1.0
-- Uses UE4SS Lua Scripting API

local UEHelpers = require("UEHelpers")
local camera = require("FreeCam.camera")

print("[FreeCam] Detached Camera Component Mod Loaded successfully!")

-- Speed adjustment keybinds
RegisterKeyBind(Key.PAGE_UP, {}, function()
    camera.AdjustSpeed(5.0)
end)

RegisterKeyBind(Key.PAGE_DOWN, {}, function()
    camera.AdjustSpeed(-5.0)
end)

-- Update camera movement every frame (Zero-Query Render Tick compliant)
local isHUDHooked = false
local function RegisterHUDHook()
    if isHUDHooked then return end
    
    local status = pcall(function()
        RegisterHook("/Game/Pal/Blueprint/UI/BP_PalHUD_InGame.BP_PalHUD_InGame_C:ReceiveDrawHUD", function(self, SizeX, SizeY)
            camera.UpdateCameraMovement()
        end)
    end)
    
    if status then
        isHUDHooked = true
    end
end

RegisterHUDHook()
NotifyOnNewObject("/Game/Pal/Blueprint/UI/BP_PalHUD_InGame.BP_PalHUD_InGame_C", function(hudObj)
    RegisterHUDHook()
end)

-- Hook IsInstallAtReticle to return true in FreeCam only if snap mode is enabled
pcall(function()
    RegisterHook("/Script/Pal.PalBuilderComponent:IsInstallAtReticle", function(self)
        if camera.IsSpectating() then
            local isSnap = false
            pcall(function()
                if self:IsSnapMode() then
                    isSnap = true
                end
            end)
            return isSnap
        end
    end)
    print("[FreeCam] Hooked PalBuilderComponent:IsInstallAtReticle successfully.")
end)
