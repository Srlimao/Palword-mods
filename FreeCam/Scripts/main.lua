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

local statUnitExecuted = false

-- Update camera movement every frame (Zero-Query Render Tick compliant)
local function OnReceiveDrawHUD(self, SizeX, SizeY)
    if not statUnitExecuted then
        statUnitExecuted = true
        if config.CONFIG.Debug then
            local KismetSystemLibrary = StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
            local world = FindFirstOf("World")
            if KismetSystemLibrary and world and world:IsValid() then
                pcall(function()
                    KismetSystemLibrary:ExecuteConsoleCommand(world, "stat unit", nil)
                end)
                print("[FreeCam] Executed console command 'stat unit' for performance diagnostics.")
            end
        end
    end
    camera.UpdateCameraMovement()
end

local isHUDHooked = false

local function AttemptRegisterHUDHook()
    RegisterHook("/Game/Pal/Blueprint/UI/BP_PalHUD_InGame.BP_PalHUD_InGame_C:ReceiveDrawHUD", OnReceiveDrawHUD)
end

local function RegisterHUDHook()
    if isHUDHooked then return end
    local status = pcall(AttemptRegisterHUDHook)
    if status then
        isHUDHooked = true
    end
end

RegisterHUDHook()

local function OnNewPalHUD(hudObj)
    RegisterHUDHook()
end

NotifyOnNewObject("/Game/Pal/Blueprint/UI/BP_PalHUD_InGame.BP_PalHUD_InGame_C", OnNewPalHUD)

local function SafeCheckInstallAtReticle(self)
    local mode = self:GetCurrentMode()
    local modeNum = 0
    if type(mode) == "number" then
        modeNum = mode
    elseif type(mode) == "userdata" and mode.get then
        modeNum = mode:get()
    end
    return self:IsSnapMode() or self:IsDismantling() or modeNum == 2
end

local function OnIsInstallAtReticle(self)
    if camera.IsSpectating() then
        if not self or not self:IsValid() then return false end
        local success, active = pcall(SafeCheckInstallAtReticle, self)
        return success and active
    end
end

-- Hook IsInstallAtReticle to return true in FreeCam for snap and dismantle modes
pcall(function()
    RegisterHook("/Script/Pal.PalBuilderComponent:IsInstallAtReticle", OnIsInstallAtReticle)
    print("[FreeCam] Hooked PalBuilderComponent:IsInstallAtReticle successfully.")
end)

local lastHookLogTime = 0

local function OnGetDismantleTargetObject(self)
    if camera.IsSpectating() then
        local target = camera.GetReticleTargetObject()
        local now = os.clock()
        if (now - lastHookLogTime) > 1.0 then
            lastHookLogTime = now
            local targetName = "Nil"
            if target and target:IsValid() then
                targetName = target:GetFullName()
            end
            print("[FreeCam Hook Debug] GetDismantleTargetObject called! Target=" .. targetName)
        end
        if target and target:IsValid() then
            return target
        end
    end
end

-- Hook PalBuilderComponent:GetDismantleTargetObject to return the reticle target in FreeCam
pcall(function()
    RegisterHook("/Script/Pal.PalBuilderComponent:GetDismantleTargetObject", OnGetDismantleTargetObject)
    print("[FreeCam] Hooked PalBuilderComponent:GetDismantleTargetObject successfully.")
end)

local lastDismantleLogTime = 0

local function OnCanRequestDismantle(self)
    if camera.IsSpectating() then
        local now = os.clock()
        if (now - lastDismantleLogTime) > 1.5 then
            lastDismantleLogTime = now
            print("[FreeCam Hook Debug] CanRequestDismantle called! Returning 0")
        end
        return 0 -- EPalMapObjectOperationResult::Success = 0
    end
end

-- Hook PalBuilderComponent:CanRequestDismantle to allow dismantling from FreeCam distance
pcall(function()
    RegisterHook("/Script/Pal.PalBuilderComponent:CanRequestDismantle", OnCanRequestDismantle)
    print("[FreeCam] Hooked PalBuilderComponent:CanRequestDismantle successfully.")
end)

local function OnIsEnableDismantle(self)
    if camera.IsSpectating() then
        return true
    end
end

-- Hook PalBuilderComponent:IsEnableDismantle to return true in FreeCam
pcall(function()
    RegisterHook("/Script/Pal.PalBuilderComponent:IsEnableDismantle", OnIsEnableDismantle)
    print("[FreeCam] Hooked PalBuilderComponent:IsEnableDismantle successfully.")
end)
