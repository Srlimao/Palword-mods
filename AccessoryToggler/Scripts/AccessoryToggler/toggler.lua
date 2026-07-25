local UEHelpers = require("UEHelpers")
local configMod = require("AccessoryToggler.config")
local popup = require("AccessoryToggler.popup")
local utils = require("AccessoryToggler.utils")

local M = {}

M.disabledAccessorySlots = {} -- UI Index (1..4) -> staticId (string)
M.equippedAccessories = {}    -- UI Index (1..4) -> { staticId = string, name = string, disabled = boolean }

local UIUtility = nil
local AccessoryNameCache = {}

local MasterDataUtility = nil

local function GetTranslatedItemName(staticId)
    local idStr = tostring(staticId)
    if type(staticId) == "userdata" then pcall(function() idStr = staticId:ToString() end) end

    if configMod.CONFIG.Language ~= "system" and configMod.CONFIG.Language ~= "" then return nil end
    if AccessoryNameCache[idStr] then return AccessoryNameCache[idStr] end
    
    if not MasterDataUtility then pcall(function() MasterDataUtility = StaticFindObject("/Script/Pal.Default__PalMasterDataTablesUtility") end) end
    if not UIUtility then pcall(function() UIUtility = StaticFindObject("/Script/Pal.Default__PalUIUtility") end) end
    
    local _, world = pcall(function() return UEHelpers.GetWorld() end)
    if world then
        if MasterDataUtility then
            local _, outText = pcall(function() return MasterDataUtility:GetLocalizedText(world, 11, FName("ITEM_NAME_" .. idStr)) end)
            if outText then
                local _, str = pcall(function() return outText:ToString() end)
                if str and str ~= "" then AccessoryNameCache[idStr] = str; return str end
            end
        end
        
        if UIUtility then
            local _, outText = pcall(function() return UIUtility:GetItemName(world, FName(staticId)) end)
            if outText then
                local _, str = pcall(function() return outText:ToString() end)
                if str and str ~= "" then AccessoryNameCache[staticId] = str; return str end
            end
        end
    end
    return nil
end

local ACCESSORY_SLOTS = {
    [1] = 2, -- Accessory1 (enum value 2)
    [2] = 3, -- Accessory2 (enum value 3)
    [3] = 6, -- Accessory3 (enum value 6)
    [4] = 7, -- Accessory4 (enum value 7)
}

-- Disabled states are kept in memory only per session (not saved to config)
local function LoadSavedDisabledStates()
end

local function SaveDisabledStates()
end

-- Helper to safely get size of native TArray
local function GetArrayLength(arr)
    if not arr then return 0 end
    local len = 0
    pcall(function() len = arr:Num() end)
    if not len or len == 0 then
        pcall(function() len = #arr end)
    end
    return len or 0
end

-- Helper to safely get element from native TArray
local function GetArrayElement(arr, idx)
    if not arr then return nil end
    local el = nil
    pcall(function() el = arr[idx] end)
    if not el then
        pcall(function() el = arr:Get(idx) end)
    end
    return el
end

-- Helper to safely get slot static ID
local function GetSlotStaticId(slot)
    if not slot or not slot:IsValid() then return nil end
    local staticId = nil
    pcall(function()
        local itemId = slot:GetItemId()
        if itemId then
            local sId = itemId.StaticId
            if sId then
                staticId = sId:ToString()
            end
        end
    end)
    return staticId
end

-- Helper to safely check if slot is empty
local function IsSlotEmpty(slot)
    if not slot or not slot:IsValid() then return true end
    local empty = true
    pcall(function()
        empty = slot:IsEmpty()
    end)
    return empty
end

local function GetAccessoryName(staticId)
    local trans = GetTranslatedItemName(staticId)
    if trans then return trans end

    local mapped = configMod.AccessoryNames[staticId]
    if mapped then return mapped end
    
    -- Format ID: Accessory_NonKilling -> Ring of Mercy style format
    local clean = staticId:gsub("^Accessory_", ""):gsub("_", " ")
    clean = clean:gsub("(%a)([%w]*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
    return clean
end

local cachedPlayer = nil
local cachedInventory = nil
local hasLoggedInventorySuccess = false

local function GetInventory()
    if cachedPlayer and cachedPlayer:IsValid() and cachedInventory and cachedInventory:IsValid() then
        local multiHelper = nil
        pcall(function() multiHelper = cachedInventory.InventoryMultiHelper end)
        if multiHelper and multiHelper:IsValid() then
            return cachedInventory
        end
    end
    
    local player = UEHelpers.GetPlayer()
    if not player or not player:IsValid() then
        cachedPlayer = nil
        cachedInventory = nil
        return nil
    end
    
    local playerState = player.PlayerState
    if not playerState or not playerState:IsValid() then return nil end
    
    local inventory = playerState.InventoryData
    if inventory and inventory:IsValid() then
        -- Inventory Subsystem Load Protection: Ensure InventoryMultiHelper is ready before returning
        local multiHelper = nil
        pcall(function() multiHelper = inventory.InventoryMultiHelper end)
        if not multiHelper or not multiHelper:IsValid() then return nil end

        cachedPlayer = player
        cachedInventory = inventory
        if not hasLoggedInventorySuccess then
            hasLoggedInventorySuccess = true
            configMod.DebugPrint("Successfully resolved and cached player inventory data!")
        end
        return inventory
    end
    return nil
end

local FNameCache = {}
local function GetCachedFName(str)
    if not FNameCache[str] then
        FNameCache[str] = FName(str)
    end
    return FNameCache[str]
end

-- Check if there is at least one free slot in the Common inventory bag
local function HasFreeInventorySlot(inventory)
    if not inventory or not inventory:IsValid() then return false end
    local out = {}
    local success = inventory:TryGetEmptySlot(0, out)
    local emptySlot = out.EmptySlot
    return success and emptySlot ~= nil and emptySlot:IsValid()
end

-- Scan the inventory bag to find a slot containing a specific static item ID
local function FindItemSlotInInventory(inventory, staticId)
    if not inventory or not inventory:IsValid() then return nil end
    local startTime = os.clock()
    configMod.DebugPrint(string.format("[FindItemSlotInInventory] Searching for item staticId: '%s'", tostring(staticId)))
    
    -- Optimize search by looking up the container natively first
    local out = {}
    local success = false
    pcall(function()
        success = inventory:TryGetContainerFromStaticItemID(GetCachedFName(staticId), out)
    end)
    
    local container = out.OutContainer
    if success and container and container:IsValid() then
        local slotArray = nil
        pcall(function() slotArray = container.ItemSlotArray end)
        if slotArray then
            local numSlots = GetArrayLength(slotArray)
            configMod.DebugPrint(string.format("[FindItemSlotInInventory] Native Container match! Scanning %d slots...", numSlots))
            for j = 1, numSlots do
                local slot = GetArrayElement(slotArray, j)
                if slot and slot:IsValid() and not IsSlotEmpty(slot) then
                    -- Ensure it is NOT an equipment slot
                    local isEquip = false
                    pcall(function() isEquip = inventory:IsEquipSlot(slot) end)
                    if not isEquip then
                        local sId = GetSlotStaticId(slot)
                        if sId == staticId then
                            local elapsedMs = (os.clock() - startTime) * 1000.0
                            configMod.DebugPrint(string.format("[FindItemSlotInInventory] SUCCESS: Found '%s' in Native Container slot index %d (took %.2fms)", staticId, j, elapsedMs))
                            return slot
                        end
                    end
                end
            end
        end
    end
    
    -- Fallback: Full recursive scan if the native lookup did not succeed
    configMod.DebugPrint(string.format("[FindItemSlotInInventory] Native lookup miss for '%s'. Initiating fallback container traversal...", tostring(staticId)))
    local multiHelper = nil
    pcall(function() multiHelper = inventory.InventoryMultiHelper end)
    if not multiHelper or not multiHelper:IsValid() then return nil end
    local containers = nil
    pcall(function() containers = multiHelper.Containers end)
    if not containers then return nil end
    
    local numContainers = GetArrayLength(containers)
    configMod.DebugPrint(string.format("[FindItemSlotInInventory] Traversing across %d inventory containers...", numContainers))
    for i = 1, numContainers do
        local container = GetArrayElement(containers, i)
        if container and container:IsValid() then
            local slotArray = nil
            pcall(function() slotArray = container.ItemSlotArray end)
            if slotArray then
                local numSlots = GetArrayLength(slotArray)
                for j = 1, numSlots do
                    local slot = GetArrayElement(slotArray, j)
                    if slot and slot:IsValid() and not IsSlotEmpty(slot) then
                        local isEquip = false
                        pcall(function() isEquip = inventory:IsEquipSlot(slot) end)
                        if not isEquip then
                            local sId = GetSlotStaticId(slot)
                            if sId == staticId then
                                local elapsedMs = (os.clock() - startTime) * 1000.0
                                configMod.DebugPrint(string.format("[FindItemSlotInInventory] SUCCESS: Found '%s' in Fallback Container %d slot index %d (took %.2fms)", staticId, i, j, elapsedMs))
                                return slot
                            end
                        end
                    end
                end
            end
        end
    end
    
    local elapsedMs = (os.clock() - startTime) * 1000.0
    configMod.DebugPrint(string.format("[FindItemSlotInInventory] FAILED: Item '%s' not found in any inventory bags (search duration: %.2fms)", tostring(staticId), elapsedMs))
    return nil
end

local function GetSlotIconPath(slot)
    return ""
end

local hasAttemptedInitialUnequip = false
local hasLoggedEquipScan = false

-- Main scan loop called periodically
function M.Scan()
    local scanStartTime = os.clock()
    utils.FindAndCacheFont()
    local inventory = GetInventory()
    if not inventory or not inventory:IsValid() then return end

    local foundCount = 0
    if not M.scanCount then M.scanCount = 0 end
    M.scanCount = M.scanCount + 1
    local shouldLog = (M.scanCount % 5 == 1)

    if shouldLog then
        configMod.DebugPrint(string.format("[M.Scan] --- Scan Cycle #%d Start ---", M.scanCount))
    end

    for uiIdx = 1, 4 do
        local slotType = ACCESSORY_SLOTS[uiIdx]
        local out = {}
        local success = false
        pcall(function()
            success = inventory:TryGetItemSlotFromEquipmentType(slotType, out)
        end)
        local slot = out.OutSlot
        
        local isSlotValid = slot and slot:IsValid()
        local isEmpty = IsSlotEmpty(slot)
        local staticId = GetSlotStaticId(slot) or "None"

        local isEquipped = success and isSlotValid and not isEmpty

        if isEquipped then
            foundCount = foundCount + 1
            
            -- Read-Only Background Scan Directive: Do not mutate inventory or call TryRemoveEquipment in M.Scan
            if M.disabledAccessorySlots[uiIdx] == staticId then
                configMod.DebugPrint(string.format("[M.Scan] UI Slot %d: Accessory '%s' was manually re-equipped. Clearing disabled state.", uiIdx, staticId))
                M.disabledAccessorySlots[uiIdx] = nil
                SaveDisabledStates()
            end
            
            local existing = M.equippedAccessories[uiIdx]
            if not existing or existing.staticId ~= staticId or existing.disabled ~= false then
                local accName = GetAccessoryName(staticId)
                local transType, transBuff = utils.ResolveTranslatedNames(staticId, accName)
                M.equippedAccessories[uiIdx] = {
                    staticId = staticId,
                    name = accName,
                    transType = transType,
                    transBuff = transBuff,
                    iconPath = "",
                    disabled = false
                }
            end
            if shouldLog then
                local acc = M.equippedAccessories[uiIdx]
                configMod.DebugPrint(string.format("[M.Scan] UI Slot %d [EquipType %d]: EQUIPPED item='%s' ('%s'), type='%s', buff='%s'", 
                    uiIdx, slotType, staticId, acc.name, acc.transType, acc.transBuff))
            end
        else
            -- Slot is currently empty
            local savedStaticId = M.disabledAccessorySlots[uiIdx]
            if savedStaticId then
                -- Native C++ count query avoids slow Lua iteration over all bags during Scan tick
                local hasItem = false
                pcall(function()
                    hasItem = inventory:CountItemNum(GetCachedFName(savedStaticId)) > 0
                end)
                if hasItem then
                    foundCount = foundCount + 1
                    local existing = M.equippedAccessories[uiIdx]
                    if not existing or existing.staticId ~= savedStaticId or existing.disabled ~= true then
                        local accName = GetAccessoryName(savedStaticId)
                        local transType, transBuff = utils.ResolveTranslatedNames(savedStaticId, accName)
                        M.equippedAccessories[uiIdx] = {
                            staticId = savedStaticId,
                            name = accName,
                            transType = transType,
                            transBuff = transBuff,
                            iconPath = "",
                            disabled = true
                        }
                    end
                    if shouldLog then
                        local acc = M.equippedAccessories[uiIdx]
                        configMod.DebugPrint(string.format("[M.Scan] UI Slot %d [EquipType %d]: TRACKED DISABLED item='%s' ('%s') in bags", 
                            uiIdx, slotType, savedStaticId, acc.name))
                    end
                else
                    -- Accessory is no longer in the inventory: clear state
                    configMod.DebugPrint(string.format("[M.Scan] UI Slot %d: Tracked item '%s' is no longer in inventory. Clearing state.", uiIdx, savedStaticId))
                    M.disabledAccessorySlots[uiIdx] = nil
                    M.equippedAccessories[uiIdx] = nil
                    SaveDisabledStates()
                end
            else
                M.equippedAccessories[uiIdx] = nil
                if shouldLog then
                    configMod.DebugPrint(string.format("[M.Scan] UI Slot %d [EquipType %d]: EMPTY", uiIdx, slotType))
                end
            end
        end
    end

    -- Mark that we have completed the initial startup unequip check
    hasAttemptedInitialUnequip = true

    if shouldLog then
        local scanDurationMs = (os.clock() - scanStartTime) * 1000.0
        configMod.DebugPrint(string.format("[M.Scan] --- Scan Cycle #%d Complete (Discovered %d active/tracked items, Duration: %.2fms) ---", M.scanCount, foundCount, scanDurationMs))
    end
end

-- Toggle the accessory at UI index 1..4 (Alt + 1..4)
function M.ToggleSlot(uiSlotIndex)
    local toggleStartTime = os.clock()
    configMod.DebugPrint(string.format("[M.ToggleSlot] --- Hotkey Triggered for UI Slot %d ---", uiSlotIndex))
    
    local inventory = GetInventory()
    if not inventory or not inventory:IsValid() then
        configMod.DebugPrint(string.format("[M.ToggleSlot] ERROR: Inventory data not ready for UI Slot %d", uiSlotIndex))
        popup.Show(configMod.GetTranslation("Popup_InventoryNotReady", "Inventory not ready"), 120, { R = 1.0, G = 0.35, B = 0.37, A = 1.0 })
        return
    end

    local slotType = ACCESSORY_SLOTS[uiSlotIndex]
    if not slotType then
        configMod.DebugPrint(string.format("[M.ToggleSlot] ERROR: Invalid slotType mapping for UI Slot %d", uiSlotIndex))
        return
    end

    local out = {}
    local success = false
    pcall(function()
        success = inventory:TryGetItemSlotFromEquipmentType(slotType, out)
    end)
    local slot = out.OutSlot
    local isEquipped = success and slot and slot:IsValid() and not IsSlotEmpty(slot)

    configMod.DebugPrint(string.format("[M.ToggleSlot] UI Slot %d (EquipType %d): IsEquipped=%s", uiSlotIndex, slotType, tostring(isEquipped)))

    if isEquipped then
        -- Check for free inventory space first
        if not HasFreeInventorySlot(inventory) then
            configMod.DebugPrint(string.format("[M.ToggleSlot] ABORT: Inventory bag is FULL! Cannot unequip slot %d", uiSlotIndex))
            popup.Show(configMod.GetTranslation("Popup_InventoryFull", "Inventory Full! Cannot disable accessory."), 180, { R = 1.0, G = 0.35, B = 0.37, A = 1.0 })
            return
        end

        local staticId = GetSlotStaticId(slot)
        if not staticId then
            configMod.DebugPrint(string.format("[M.ToggleSlot] ERROR: Failed to resolve staticId from equipped slot %d", uiSlotIndex))
            return
        end
        local displayName = GetAccessoryName(staticId)

        configMod.DebugPrint(string.format("[M.ToggleSlot] Unequipping '%s' (%s) from slot %d...", displayName, staticId, uiSlotIndex))
        -- Perform unequip
        local removed = false
        pcall(function()
            removed = inventory:TryRemoveEquipment(slot)
        end)
        if removed then
            M.disabledAccessorySlots[uiSlotIndex] = staticId
            SaveDisabledStates()
            local elapsedMs = (os.clock() - toggleStartTime) * 1000.0
            configMod.DebugPrint(string.format("[M.ToggleSlot] SUCCESS: Disabled '%s' in %.2fms", displayName, elapsedMs))
            popup.Show(string.format(configMod.GetTranslation("Popup_Disabled", "%s Disabled"), displayName), 120, { R = 1.0, G = 0.5, B = 0.0, A = 1.0 })
        else
            configMod.DebugPrint(string.format("[M.ToggleSlot] FAILED: TryRemoveEquipment failed for '%s' in slot %d", displayName, uiSlotIndex))
            popup.Show(string.format(configMod.GetTranslation("Popup_FailedDisable", "Failed to disable %s"), displayName), 120, { R = 1.0, G = 0.35, B = 0.37, A = 1.0 })
        end
    else
        -- Check if we have a disabled item tracked
        local staticId = M.disabledAccessorySlots[uiSlotIndex]
        if staticId then
            local displayName = GetAccessoryName(staticId)
            configMod.DebugPrint(string.format("[M.ToggleSlot] Attempting to re-equip tracked disabled accessory '%s' (%s) into slot %d...", displayName, staticId, uiSlotIndex))
            local bagSlot = FindItemSlotInInventory(inventory, staticId)
            if bagSlot then
                local equipped = false
                pcall(function()
                    equipped = inventory:TryEquipSlot(bagSlot)
                end)
                if equipped then
                    M.disabledAccessorySlots[uiSlotIndex] = nil
                    SaveDisabledStates()
                    local elapsedMs = (os.clock() - toggleStartTime) * 1000.0
                    configMod.DebugPrint(string.format("[M.ToggleSlot] SUCCESS: Re-enabled '%s' in %.2fms", displayName, elapsedMs))
                    popup.Show(string.format(configMod.GetTranslation("Popup_Enabled", "%s Enabled"), displayName), 120, { R = 0.0, G = 0.96, B = 0.83, A = 1.0 })
                else
                    configMod.DebugPrint(string.format("[M.ToggleSlot] FAILED: TryEquipSlot failed for '%s' in slot %d", displayName, uiSlotIndex))
                    popup.Show(string.format(configMod.GetTranslation("Popup_FailedEnable", "Failed to enable %s"), displayName), 120, { R = 1.0, G = 0.35, B = 0.37, A = 1.0 })
                end
            else
                M.disabledAccessorySlots[uiSlotIndex] = nil
                SaveDisabledStates()
                configMod.DebugPrint(string.format("[M.ToggleSlot] NOT FOUND: '%s' not present in player inventory bags for slot %d", displayName, uiSlotIndex))
                popup.Show(string.format(configMod.GetTranslation("Popup_NotFound", "%s not found in bags"), displayName), 120, { R = 1.0, G = 0.35, B = 0.37, A = 1.0 })
            end
        else
            configMod.DebugPrint(string.format("[M.ToggleSlot] UI Slot %d is empty and no disabled accessory is tracked.", uiSlotIndex))
        end
    end
end

return M
