local UEHelpers = require("UEHelpers")
local configMod = require("AccessoryToggler.config")
local popup = require("AccessoryToggler.popup")

local M = {}

M.disabledAccessorySlots = {} -- UI Index (1..4) -> staticId (string)
M.equippedAccessories = {}    -- UI Index (1..4) -> { staticId = string, name = string, disabled = boolean }

local UIUtility = nil
local AccessoryNameCache = {}

local function GetTranslatedItemName(staticId)
    if AccessoryNameCache[staticId] then
        return AccessoryNameCache[staticId]
    end
    
    if not UIUtility then
        local status, util = pcall(function() return StaticFindObject("/Script/Pal.Default__PalUIUtility") end)
        if status and util then UIUtility = util end
    end
    
    if UIUtility then
        local statusWorld, world = pcall(function() return UEHelpers.GetWorld() end)
        if statusWorld and world then
            local statusName, outText = pcall(function()
                return UIUtility:GetItemName(world, FName(staticId))
            end)
            if statusName and outText then
                local strStatus, str = pcall(function() return outText:ToString() end)
                if strStatus and str and str ~= "" then
                    AccessoryNameCache[staticId] = str
                    return str
                end
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

-- Load previously disabled slots from config
local function LoadSavedDisabledStates()
    if configMod.CONFIG.DisabledSlots then
        for k, v in pairs(configMod.CONFIG.DisabledSlots) do
            local idx = tonumber(k)
            if idx and type(v) == "string" and v ~= "" then
                M.disabledAccessorySlots[idx] = v
            end
        end
    else
        configMod.CONFIG.DisabledSlots = {}
    end
end
pcall(LoadSavedDisabledStates)

local function SaveDisabledStates()
    configMod.CONFIG.DisabledSlots = {}
    for k, v in pairs(M.disabledAccessorySlots) do
        configMod.CONFIG.DisabledSlots[tostring(k)] = v
    end
    pcall(configMod.SaveConfig)
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

local function GetAccessoryName(staticId)
    local trans = GetTranslatedItemName(staticId)
    if trans then return trans end

    local mapped = configMod.CONFIG.AccessoryNames[staticId]
    if mapped then return mapped end
    
    -- Format ID: Accessory_NonKilling -> Ring of Mercy style format
    local clean = staticId:gsub("^Accessory_", ""):gsub("_", " ")
    clean = clean:gsub("(%a)([%w]*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
    return clean
end

local hasLoggedInventorySuccess = false
local function GetInventory()
    local player = UEHelpers.GetPlayer()
    if not player or not player:IsValid() then return nil end
    
    local playerState = player.PlayerState
    if not playerState or not playerState:IsValid() then return nil end
    
    local inventory = playerState.InventoryData
    if inventory and inventory:IsValid() then
        if not hasLoggedInventorySuccess then
            hasLoggedInventorySuccess = true
            print("[AccessoryToggler] Successfully resolved player inventory data!")
        end
        return inventory
    end
    return nil
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
    local multiHelper = inventory.InventoryMultiHelper
    if not multiHelper or not multiHelper:IsValid() then return nil end
    local containers = multiHelper.Containers
    if not containers then return nil end
    
    local numContainers = GetArrayLength(containers)
    for i = 1, numContainers do
        local container = GetArrayElement(containers, i)
        if container and container:IsValid() then
            local slotArray = container.ItemSlotArray
            if slotArray then
                local numSlots = GetArrayLength(slotArray)
                for j = 1, numSlots do
                    local slot = GetArrayElement(slotArray, j)
                    if slot and slot:IsValid() and not slot:IsEmpty() then
                        local slotItemId = slot:GetItemId()
                        if slotItemId.StaticId:ToString() == staticId then
                            return slot
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function GetSlotIconPath(slot)
    return ""
end

local hasLoggedEquipScan = false
-- Main scan loop called periodically
function M.Scan()
    local inventory = GetInventory()
    if not inventory or not inventory:IsValid() then return end

    local foundCount = 0
    if not M.scanCount then M.scanCount = 0 end
    M.scanCount = M.scanCount + 1
    local shouldLog = (M.scanCount % 5 == 1)

    for uiIdx = 1, 4 do
        local slotType = ACCESSORY_SLOTS[uiIdx]
        local out = {}
        local success = inventory:TryGetItemSlotFromEquipmentType(slotType, out)
        local slot = out.OutSlot
        
        if shouldLog then
            local isSlotValid = slot and slot:IsValid()
            local isEmpty = isSlotValid and slot:IsEmpty()
            local staticId = (isSlotValid and not isEmpty) and slot:GetItemId().StaticId:ToString() or "None"
            configMod.DebugPrint(string.format("UI Slot %d (EquipType %d): success=%s, valid=%s, empty=%s, item=%s", 
                uiIdx, slotType, tostring(success), tostring(isSlotValid), tostring(isEmpty), staticId))
        end

        local isEquipped = success and slot and slot:IsValid() and not slot:IsEmpty()

        if isEquipped then
            local staticId = slot:GetItemId().StaticId:ToString()
            foundCount = foundCount + 1
            
            -- If this accessory is equipped but is marked in config/state as disabled:
            if M.disabledAccessorySlots[uiIdx] == staticId then
                -- Try to automatically unequip it on start/load
                if HasFreeInventorySlot(inventory) then
                    local removed = inventory:TryRemoveEquipment(slot)
                    if removed then
                        configMod.DebugPrint("Auto-unequipped accessory in slot " .. uiIdx .. " on scan: " .. staticId)
                    end
                else
                    -- No inventory space to unequip: clear disabled state so it remains active
                    M.disabledAccessorySlots[uiIdx] = nil
                    SaveDisabledStates()
                end
            else
                -- Accessory is active and working
                M.equippedAccessories[uiIdx] = {
                    staticId = staticId,
                    name = GetAccessoryName(staticId),
                    iconPath = GetSlotIconPath(slot),
                    disabled = false
                }
            end
        else
            -- Slot is currently empty
            local savedStaticId = M.disabledAccessorySlots[uiIdx]
            if savedStaticId then
                -- Check if the disabled accessory is still in the inventory bag
                local itemSlot = FindItemSlotInInventory(inventory, savedStaticId)
                if itemSlot then
                    foundCount = foundCount + 1
                    -- Show as disabled in UI
                    M.equippedAccessories[uiIdx] = {
                        staticId = savedStaticId,
                        name = GetAccessoryName(savedStaticId),
                        iconPath = GetSlotIconPath(itemSlot),
                        disabled = true
                    }
                else
                    -- Accessory is no longer in the inventory: clear state
                    M.disabledAccessorySlots[uiIdx] = nil
                    M.equippedAccessories[uiIdx] = nil
                    SaveDisabledStates()
                end
            else
                M.equippedAccessories[uiIdx] = nil
            end
        end
    end

    if foundCount > 0 and not hasLoggedEquipScan then
        hasLoggedEquipScan = true
        configMod.DebugPrint("Scan discovered " .. foundCount .. " active or tracked accessories.")
    elseif foundCount == 0 then
        hasLoggedEquipScan = false
    end
end

-- Toggle the accessory at UI index 1..4 (Alt + 1..4)
function M.ToggleSlot(uiSlotIndex)
    local inventory = GetInventory()
    if not inventory or not inventory:IsValid() then
        popup.Show(configMod.GetTranslation("Popup_InventoryNotReady", "Inventory not ready"), 120, { R = 1.0, G = 0.35, B = 0.37, A = 1.0 })
        return
    end

    local slotType = ACCESSORY_SLOTS[uiSlotIndex]
    if not slotType then return end

    local out = {}
    local success = inventory:TryGetItemSlotFromEquipmentType(slotType, out)
    local slot = out.OutSlot
    local isEquipped = success and slot and slot:IsValid() and not slot:IsEmpty()

    if isEquipped then
        -- Check for free inventory space first (User request!)
        if not HasFreeInventorySlot(inventory) then
            popup.Show(configMod.GetTranslation("Popup_InventoryFull", "Inventory Full! Cannot disable accessory."), 180, { R = 1.0, G = 0.35, B = 0.37, A = 1.0 })
            return
        end

        local staticId = slot:GetItemId().StaticId:ToString()
        local displayName = GetAccessoryName(staticId)

        -- Perform unequip
        local removed = inventory:TryRemoveEquipment(slot)
        if removed then
            M.disabledAccessorySlots[uiSlotIndex] = staticId
            SaveDisabledStates()
            popup.Show(string.format(configMod.GetTranslation("Popup_Disabled", "%s Disabled"), displayName), 120, { R = 1.0, G = 0.5, B = 0.0, A = 1.0 })
        else
            popup.Show(string.format(configMod.GetTranslation("Popup_FailedDisable", "Failed to disable %s"), displayName), 120, { R = 1.0, G = 0.35, B = 0.37, A = 1.0 })
        end
    else
        -- Check if we have a disabled item tracked
        local staticId = M.disabledAccessorySlots[uiSlotIndex]
        if staticId then
            local displayName = GetAccessoryName(staticId)
            local bagSlot = FindItemSlotInInventory(inventory, staticId)
            if bagSlot then
                local equipped = inventory:TryEquipSlot(bagSlot)
                if equipped then
                    M.disabledAccessorySlots[uiSlotIndex] = nil
                    SaveDisabledStates()
                    popup.Show(string.format(configMod.GetTranslation("Popup_Enabled", "%s Enabled"), displayName), 120, { R = 0.0, G = 0.96, B = 0.83, A = 1.0 })
                else
                    popup.Show(string.format(configMod.GetTranslation("Popup_FailedEnable", "Failed to enable %s"), displayName), 120, { R = 1.0, G = 0.35, B = 0.37, A = 1.0 })
                end
            else
                M.disabledAccessorySlots[uiSlotIndex] = nil
                SaveDisabledStates()
                popup.Show(string.format(configMod.GetTranslation("Popup_NotFound", "%s not found in bags"), displayName), 120, { R = 1.0, G = 0.35, B = 0.37, A = 1.0 })
            end
        end
    end
end

return M
