-- Palworld FreeCam Mod
-- Built for Palworld v1.0
-- Uses UE4SS Lua Scripting API

local UEHelpers = require("UEHelpers")
local config = require("FreeCam.config")
local camera = require("FreeCam.camera")

print("[FreeCam] Detached Camera Component Mod Loaded successfully!")

local function GetKey(keyStr, fallbackKey)
    if not keyStr then return fallbackKey end
    return Key[keyStr] or fallbackKey
end

-- Always register ESC key as a universal exit key for FreeCam (Keyboard + Gamepad)
RegisterKeyBind(Key.ESCAPE, {}, function()
    if camera.IsSpectating() then
        print("[FreeCam] Universal ESC key pressed: Exiting FreeCam.")
        camera.ToggleFreeCam()
    end
end)

-- Keybinds (Registered if InputMode is Keyboard)
local inputMode = config.CONFIG.InputMode or "Keyboard"
if inputMode == "Keyboard" then
    local keyToggle = GetKey(config.CONFIG.KeyBinds and config.CONFIG.KeyBinds.ToggleFreeCam, Key.F8)
    local keySpeedUp = GetKey(config.CONFIG.KeyBinds and config.CONFIG.KeyBinds.SpeedUp, Key.PAGE_UP)
    local keySpeedDown = GetKey(config.CONFIG.KeyBinds and config.CONFIG.KeyBinds.SpeedDown, Key.PAGE_DOWN)

    local useAlt = config.CONFIG.KeyBinds and config.CONFIG.KeyBinds.UseAltModifier
    local toggleModifiers = (useAlt == false) and {} or {ModifierKey.ALT}

    RegisterKeyBind(keyToggle, toggleModifiers, function()
        camera.ToggleFreeCam()
    end)

    RegisterKeyBind(keySpeedUp, {}, function()
        camera.AdjustSpeed(5.0)
    end)

    RegisterKeyBind(keySpeedDown, {}, function()
        camera.AdjustSpeed(-5.0)
    end)
end

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

-- Hook IsInstallAtReticle to return true in FreeCam for snap and dismantle modes
pcall(function()
    RegisterHook("/Script/Pal.PalBuilderComponent:IsInstallAtReticle", function(self)
        if camera.IsSpectating() then
            local active = false
            pcall(function()
                if self:IsSnapMode() or self:IsDismantling() or self:GetCurrentMode() == 2 then
                    active = true
                end
            end)
            return active
        end
    end)
    print("[FreeCam] Hooked PalBuilderComponent:IsInstallAtReticle successfully.")
end)
