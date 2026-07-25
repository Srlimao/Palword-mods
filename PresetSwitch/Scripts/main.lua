-- ============================================================================
-- PresetSwitch - Main Script (UE4SS Lua)
-- Provides zero-UI remote switching for native in-game Pal presets
-- ============================================================================

print("[PresetSwitch] Initializing PresetSwitch Mod...")

local configMod = require("PresetSwitch.config")
local presetMgr = require("PresetSwitch.preset_manager")
local popup = require("PresetSwitch.popup")

-- Load initial configuration from %LOCALAPPDATA%/Pal/Saved/Mods/PresetSwitch/config.json
configMod.LoadConfig()

if not configMod.CONFIG.Enabled then
    print("[PresetSwitch] Mod is disabled in config.json. Keybindings will not be registered.")
    return
end

local modifier = configMod.ResolveModifier(configMod.CONFIG.KeyBinds and configMod.CONFIG.KeyBinds.Modifier or "ALT")

-- Resolve keys for Presets 1..5
local key1 = configMod.GetKey(configMod.CONFIG.KeyBinds and configMod.CONFIG.KeyBinds.SwitchPreset1, Key.FIVE or Key.NUM_5 or Key["5"] or 0x35)
local key2 = configMod.GetKey(configMod.CONFIG.KeyBinds and configMod.CONFIG.KeyBinds.SwitchPreset2, Key.SIX or Key.NUM_6 or Key["6"] or 0x36)
local key3 = configMod.GetKey(configMod.CONFIG.KeyBinds and configMod.CONFIG.KeyBinds.SwitchPreset3, Key.SEVEN or Key.NUM_7 or Key["7"] or 0x37)
local key4 = configMod.GetKey(configMod.CONFIG.KeyBinds and configMod.CONFIG.KeyBinds.SwitchPreset4, Key.EIGHT or Key.NUM_8 or Key["8"] or 0x38)
local key5 = configMod.GetKey(configMod.CONFIG.KeyBinds and configMod.CONFIG.KeyBinds.SwitchPreset5, Key.NINE or Key.NUM_9 or Key["9"] or 0x39)

-- Helper function to register keybindings with thread synchronization & pcall safety
local function RegisterPresetKeyBind(key, presetIndex, keyLabel)
    if key then
        RegisterKeyBind(key, modifier, function()
            pcall(ExecuteInGameThread, function()
                presetMgr.SwitchPreset(presetIndex)
            end)
        end)
        configMod.DebugPrint(string.format("Registered hotkey for Preset %d (Key: %s)", presetIndex, keyLabel))
    else
        print(string.format("[PresetSwitch] WARNING: Failed to resolve key for Preset %d", presetIndex))
    end
end

RegisterPresetKeyBind(key1, 1, "SwitchPreset1")
RegisterPresetKeyBind(key2, 2, "SwitchPreset2")
RegisterPresetKeyBind(key3, 3, "SwitchPreset3")
RegisterPresetKeyBind(key4, 4, "SwitchPreset4")
RegisterPresetKeyBind(key5, 5, "SwitchPreset5")

-- ----------------------------------------------------------------------------
-- HUD Hook for On-Screen Toast Notifications
-- ----------------------------------------------------------------------------
local function OnReceiveDrawHUD(hud, canvas)
    -- Early zero-cost exit if no popup is active
    if popup.FramesRemaining <= 0 then
        return
    end

    -- Protection during loading screens
    local status, hudCheck = pcall(function() return FindFirstOf("BP_PalHUD_InGame_C") end)
    if not status or not hudCheck or not hudCheck:IsValid() then
        return
    end

    popup.Draw(hud, canvas)
end

-- Register HUD draw hook
RegisterHook("/Script/Engine.HUD:ReceiveDrawHUD", OnReceiveDrawHUD)

print("[PresetSwitch] Mod initialized successfully! Registered hotkeys for Presets 1-5.")
