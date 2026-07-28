-- Palworld FreeCam Mod
-- Built for Palworld v1.0
-- Uses UE4SS Lua Scripting API

local UEHelpers = require("UEHelpers")
local config = require("FreeCam.config")
local camera = require("FreeCam.camera")
local ui_manager = require("FreeCam.ui_manager")

print("[FreeCam] Detached Camera Component Mod Loaded successfully!")

-- Initialize Building Window UI & Esc Key Handlers
pcall(function() ui_manager.Initialize() end)


local function GetKey(keyStr, fallbackKey)
    if not keyStr then return fallbackKey end
    return Key[keyStr] or fallbackKey
end



-- Register Keyboard Keybinds (Always registered so Keyboard and Gamepad work simultaneously)
local keyToggle = GetKey(config.CONFIG.KeyBinds and config.CONFIG.KeyBinds.ToggleFreeCam, Key.F8)
local keySpeedUp = GetKey(config.CONFIG.KeyBinds and config.CONFIG.KeyBinds.SpeedUp, Key.PAGE_UP)
local keySpeedDown = GetKey(config.CONFIG.KeyBinds and config.CONFIG.KeyBinds.SpeedDown, Key.PAGE_DOWN)

local function ResolveModifier(modStr)
    if not modStr then return { ModifierKey.ALT } end
    local upper = string.upper(modStr)
    if upper == "ALT" then
        return { ModifierKey.ALT }
    elseif upper == "CTRL" or upper == "CONTROL" then
        return { ModifierKey.CTRL }
    elseif upper == "SHIFT" then
        return { ModifierKey.SHIFT }
    elseif upper == "NONE" or upper == "" then
        return {}
    else
        return { ModifierKey.ALT }
    end
end

local modifier = config.CONFIG.KeyBinds and config.CONFIG.KeyBinds.Modifier or "ALT"
local toggleModifiers = ResolveModifier(modifier)

RegisterKeyBind(keyToggle, toggleModifiers, function()
    camera.ToggleFreeCam()
end)

RegisterKeyBind(keySpeedUp, {}, function()
    camera.AdjustSpeed(5.0)
end)

RegisterKeyBind(keySpeedDown, {}, function()
    camera.AdjustSpeed(-5.0)
end)

-- Update camera movement every frame (Zero-Query Render Tick compliant)
local function OnReceiveDrawHUD(self, SizeX, SizeY)
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
            config.DebugPrint("Hook Debug: GetDismantleTargetObject called! Target=" .. targetName)
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
            config.DebugPrint("Hook Debug: CanRequestDismantle called! Returning 0")
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

local function OnNewUIBuildingModel(self)
    if camera.IsSpectating() then
        pcall(function()
            local builder_m = require("FreeCam.builder_manager")
            builder_m.ResetSnapModeState()
            print("[FreeCam] New UIBuildingModel constructed. Reset snap tracking state.")
        end)
    end
end

-- Notify on new PalUIBuildingModel object creation to reset snap tracking when items change
NotifyOnNewObject("/Script/Pal.PalUIBuildingModel", OnNewUIBuildingModel)

local function OnUIBuildingModelRotateTarget(self, bRight)
    if camera.IsSpectating() then
        pcall(function()
            local isRight = false
            if type(bRight) == "boolean" then
                isRight = bRight
            elseif type(bRight) == "userdata" and bRight.get then
                isRight = bRight:get()
            end
            local builder_m = require("FreeCam.builder_manager")
            builder_m.RotateTarget(isRight)
        end)
    end
end

-- Hook PalUIBuildingModel:RotateTarget to capture rotation input when grid-snapped
pcall(function()
    RegisterHook("/Script/Pal.PalUIBuildingModel:RotateTarget", OnUIBuildingModelRotateTarget)
    print("[FreeCam] Hooked PalUIBuildingModel:RotateTarget successfully.")
end)
