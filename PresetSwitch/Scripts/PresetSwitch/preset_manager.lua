local M = {}

local palUtil = require("PresetSwitch.pal_utility")
local popup = require("PresetSwitch.popup")
local configMod = require("PresetSwitch.config")

-- Helper function to safely extract FPalInstanceID from reflected struct wrappers
local function ExtractPalInstanceID(elem)
    if not elem then return nil end
    local uElem = palUtil.unwrap(elem) or elem

    -- 1. Try accessing PalInstanceID property
    local id = nil
    pcall(function() id = uElem.PalInstanceID end)
    if not id then
        pcall(function() id = uElem["PalInstanceID"] end)
    end

    if id then
        local uId = palUtil.unwrap(id) or id
        return uId
    end

    -- 2. Check if uElem itself is FPalInstanceID (contains InstanceId or PlayerUId)
    local isInst = false
    pcall(function()
        isInst = (uElem.InstanceId ~= nil or uElem.PlayerUId ~= nil)
    end)
    if isInst then
        return uElem
    end

    return nil
end

function M.SwitchPreset(presetIndex)
    configMod.DebugPrint("===========================================")
    configMod.DebugPrint(string.format("PRESET SWITCH TRIGGERED: Preset %d", presetIndex))
    configMod.DebugPrint("===========================================")

    -- 1. Loading screen protection check
    local status, hudCheck = pcall(function() return FindFirstOf("BP_PalHUD_InGame_C") end)
    if not status or not hudCheck or not hudCheck:IsValid() then
        configMod.DebugPrint("BP_PalHUD_InGame_C invalid (on title or loading screen). Aborting.")
        return
    end

    -- Force pre-loading of Pal Box container under the hood
    palUtil.EnsurePalBoxLoaded()

    local zeroBasedIndex = presetIndex - 1

    -- ------------------------------------------------------------------------
    -- STEP 1: Inspect PlayerState & Network Character Component
    -- ------------------------------------------------------------------------
    local playerState = palUtil.GetPlayerState()
    configMod.DebugPrint(string.format("PlayerState valid: %s", tostring(playerState ~= nil and playerState:IsValid())))

    local playerUId = palUtil.GetPlayerUId()
    configMod.DebugPrint(string.format("PlayerUId resolved: %s", tostring(playerUId)))

    local netComp = palUtil.GetNetworkCharacterComponent()
    configMod.DebugPrint(string.format("NetworkCharacterComponent valid: %s", tostring(netComp ~= nil and netComp:IsValid())))

    -- ------------------------------------------------------------------------
    -- STEP 2: Inspect Active UI Widget Instances
    -- ------------------------------------------------------------------------
    local widgetInstances = {}
    pcall(function()
        local list1 = FindAllOf("UWBP_IngameMenu_PalBox_Preset_C")
        if list1 then
            for _, w in ipairs(list1) do
                if w and w:IsValid() then table.insert(widgetInstances, w) end
            end
        end
    end)

    pcall(function()
        local list2 = FindAllOf("PalUIOtomoLoadoutBase")
        if list2 then
            for _, w in ipairs(list2) do
                if w and w:IsValid() then table.insert(widgetInstances, w) end
            end
        end
    end)

    configMod.DebugPrint(string.format("Active UI Preset Widget instances count: %d", #widgetInstances))

    local appliedViaWidget = false
    for idx, w in ipairs(widgetInstances) do
        configMod.DebugPrint(string.format("Widget #%d Name: %s", idx, w:GetFullName()))

        -- Inspect CurrentLoadoutData on active widget
        pcall(function()
            local currentData = w.CurrentLoadoutData
            local t = palUtil.TArrayToTable(currentData)
            configMod.DebugPrint(string.format("Widget #%d CurrentLoadoutData count: %d", idx, #t))
        end)

        -- Safely attempt RequestApplyLoadoutData on ACTIVE RUNTIME WIDGET INSTANCE ONLY
        configMod.DebugPrint(string.format("Invoking RequestApplyLoadoutData(%d) on runtime widget #%d...", zeroBasedIndex, idx))
        local wOk, wErr = pcall(function()
            w:RequestApplyLoadoutData(zeroBasedIndex)
        end)
        configMod.DebugPrint(string.format("Widget RequestApplyLoadoutData result: ok=%s, err=%s", tostring(wOk), tostring(wErr)))
        if wOk then
            appliedViaWidget = true
        end
    end

    if appliedViaWidget then
        popup.Show(string.format("Applied Preset %d", presetIndex), 140, { R = 0.0, G = 0.96, B = 0.83, A = 1.0 })
        configMod.DebugPrint("Success applying preset via active UI widget instance.")
        return
    end

    -- ------------------------------------------------------------------------
    -- STEP 3: Inspect PalLocalWorldSaveGame
    -- ------------------------------------------------------------------------
    local foundPresets = {}
    pcall(function()
        local saveGame = FindFirstOf("PalLocalWorldSaveGame")
        if saveGame and saveGame:IsValid() then
            configMod.DebugPrint(string.format("PalLocalWorldSaveGame found: %s", saveGame:GetFullName()))
            local rawData = saveGame.SaveData.Local_OtomoLoadoutSaveData
            local t = palUtil.TArrayToTable(rawData)
            configMod.DebugPrint(string.format("SaveGame Local_OtomoLoadoutSaveData count: %d", #t))
            if #t > 0 then
                foundPresets = t
            end
        else
            configMod.DebugPrint("PalLocalWorldSaveGame not found via FindFirstOf.")
        end
    end)

    -- ------------------------------------------------------------------------
    -- STEP 4: Apply via Network RPC if preset data found
    -- ------------------------------------------------------------------------
    if #foundPresets > 0 then
        local targetPreset = foundPresets[presetIndex]
        if targetPreset then
            local presetName = "Preset " .. presetIndex
            pcall(function()
                if targetPreset.PresetName then
                    local pName = targetPreset.PresetName
                    if type(pName) == "userdata" and pName.ToString then
                        presetName = pName:ToString()
                    elseif type(pName) == "string" then
                        presetName = pName
                    end
                end
            end)

            local loadoutPalIds = {}
            pcall(function()
                local rawElements = targetPreset.LoadoutPals
                local elementsTable = palUtil.TArrayToTable(rawElements)
                for _, elem in ipairs(elementsTable) do
                    local palId = ExtractPalInstanceID(elem)
                    if palId then
                        table.insert(loadoutPalIds, palId)
                    end
                end
            end)

            configMod.DebugPrint(string.format("Found Preset %d ('%s') with %d valid Pal IDs.", presetIndex, presetName, #loadoutPalIds))

            -- MANDATORY CRASH GUARD: Do NOT invoke RPC if loadoutPalIds is empty!
            if #loadoutPalIds == 0 then
                configMod.DebugPrint(string.format("Preset Slot %d has 0 valid Pal IDs. Aborting RPC to prevent server crash.", presetIndex))
                popup.Show(string.format("Preset Slot %d is empty!", presetIndex), 120, { R = 1.0, G = 0.75, B = 0.0, A = 1.0 })
                return
            end

            if netComp and netComp:IsValid() and playerUId then
                configMod.DebugPrint(string.format("Invoking RequestApplyPalLoadoutData_ToServer for %d Pals...", #loadoutPalIds))
                local rpcOk, rpcErr = pcall(function()
                    netComp:RequestApplyPalLoadoutData_ToServer(playerUId, loadoutPalIds)
                end)
                configMod.DebugPrint(string.format("RequestApplyPalLoadoutData_ToServer result: ok=%s, err=%s", tostring(rpcOk), tostring(rpcErr)))
                if rpcOk then
                    popup.Show(string.format("Applied Preset %d: %s", presetIndex, presetName), 140, { R = 0.0, G = 0.96, B = 0.83, A = 1.0 })
                    return
                end
            else
                configMod.DebugPrint("Network component or PlayerUId missing for RPC call.")
            end
        else
            configMod.DebugPrint(string.format("Preset Slot %d is empty in save data (Total Presets found: %d).", presetIndex, #foundPresets))
            popup.Show(string.format("Preset Slot %d is empty!", presetIndex), 120, { R = 1.0, G = 0.75, B = 0.0, A = 1.0 })
            return
        end
    end

    popup.Show(string.format("Preset %d", presetIndex), 120, { R = 0.0, G = 0.96, B = 0.83, A = 1.0 })
    configMod.DebugPrint("===== PRESET SWITCH COMPLETE =====")
end

return M
