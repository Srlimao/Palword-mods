-- ============================================================================
-- Mod: ButcherImplantDrops (Server-Only)
-- Description: Grants 1 exact matching disposable passive skill implant upon
--              butchering a Pal using the Meat Cleaver.
-- ============================================================================

local MOD_NAME = "ButcherImplantDrops"
local LOCALAPPDATA = os.getenv("LOCALAPPDATA") or ""
local CONFIG_PATH = string.format("%s\\Pal\\Saved\\Mods\\%s\\config.json", LOCALAPPDATA, MOD_NAME)

local CONFIG = {
    DirectToInventory = true,
    GrantAllPassives = false, -- If true, grants 1 implant for EVERY valid passive on the Pal. If false, grants 1 random valid passive implant.
    DebugLogging = true
}

local function Log(msg)
    if CONFIG.DebugLogging then
        print(string.format("[%s] %s", MOD_NAME, tostring(msg)))
    end
end

-- Safely unwrap RemoteUnrealParam or FPalDataTableRowName struct to raw string
local function UnwrapToNameString(val)
    if not val then return "" end
    if type(val) == "string" then return val end
    
    if type(val) == "userdata" and val.get then
        pcall(function()
            local u = val:get()
            if u ~= nil then val = u end
        end)
    end

    if type(val) == "string" then return val end

    local str = ""
    pcall(function()
        if type(val) == "userdata" then
            if val.PassiveSkillId then
                str = UnwrapToNameString(val.PassiveSkillId)
            elseif val.SkillId then
                str = UnwrapToNameString(val.SkillId)
            elseif val.Key then
                str = UnwrapToNameString(val.Key)
            elseif val.RowName then
                str = UnwrapToNameString(val.RowName)
            elseif val.Name then
                str = UnwrapToNameString(val.Name)
            elseif val.Value then
                str = UnwrapToNameString(val.Value)
            elseif val.ToString then
                str = val:ToString()
            end
        end
    end)
    return str
end

-- Safely convert TArray to standard Lua table with element unwrapping
local function TArrayToTable(arrayVal)
    local t = {}
    if not arrayVal then return t end
    if type(arrayVal) == "table" then return arrayVal end
    if type(arrayVal) == "userdata" then
        if arrayVal.ForEach then
            pcall(function()
                arrayVal:ForEach(function(arg1, arg2)
                    local val = nil
                    if type(arg1) ~= "number" then val = arg1 else val = arg2 end
                    if val ~= nil then
                        table.insert(t, val)
                    end
                end)
            end)
        else
            for i = 0, 100 do
                local elem = nil
                local success = pcall(function() elem = arrayVal[i] end)
                if not success or not elem then break end
                table.insert(t, elem)
            end
        end
    end
    return t
end

-- Helper to get valid WorldContextObject
local function GetWorldContext(providedCtx)
    if providedCtx and type(providedCtx) == "userdata" and providedCtx.IsValid and providedCtx:IsValid() then
        return providedCtx
    end
    local hud = FindFirstOf("BP_PalHUD_InGame_C")
    if hud and hud:IsValid() then return hud end
    local player = FindFirstOf("PalPlayerCharacter")
    if player and player:IsValid() then return player end
    return nil
end

-- Master Explicit Mapping: Pal Passive Skill ID -> Implant Item Static ID
local MasterPassiveToImplantMap = {
    -- 1. Work Speed / Crafting
    ["CraftSpeed_up1"] = "PalPassiveSkillChange_CraftSpeed_up1",
    ["CraftSpeed_up2"] = "PalPassiveSkillChange_CraftSpeed_up2",
    ["CraftSpeed_up3"] = "PalPassiveSkillChange_Consumable_CraftSpeed_up3",
    ["PAL_CorporateSlave"] = "PalPassiveSkillChange_PAL_CorporateSlave",

    -- 2. Swift & King of the Waves / Speed
    ["MoveSpeed_up_1"] = "PalPassiveSkillChange_MoveSpeed_up_1",
    ["MoveSpeed_up_2"] = "PalPassiveSkillChange_MoveSpeed_up_2",
    ["MoveSpeed_up_3"] = "PalPassiveSkillChange_Consumable_MoveSpeed_up_3",
    ["SwimSpeed_up_1"] = "PalPassiveSkillChange_SwimSpeed_up_1",
    ["SwimSpeed_up_2"] = "PalPassiveSkillChange_SwimSpeed_up_2",
    ["SwimSpeed_up_3"] = "PalPassiveSkillChange_Consumable_SwimSpeed_up_3",

    -- 3. Demon God / Ferocious Attack
    ["PAL_ALLAttack_up1"] = "PalPassiveSkillChange_PAL_ALLAttack_up1",
    ["PAL_ALLAttack_up2"] = "PalPassiveSkillChange_PAL_ALLAttack_up2",
    ["PAL_ALLAttack_up3"] = "PalPassiveSkillChange_Consumable_PAL_ALLAttack_up3",
    ["Noukin"] = "PalPassiveSkillChange_Noukin",

    -- 4. Diamond Body / Defense
    ["Deffence_up1"] = "PalPassiveSkillChange_Deffence_up1",
    ["Deffence_up2"] = "PalPassiveSkillChange_Deffence_up2",
    ["Deffence_up3"] = "PalPassiveSkillChange_Consumable_Deffence_up3",

    -- 5. Special, Legendary & Raid Boss Passives
    ["Rare"] = "PalPassiveSkillChange_Consumable_Rare",
    ["Legend"] = "PalPassiveSkillChange_Consumable_Legend",
    ["Witch"] = "PalPassiveSkillChange_Consumable_Witch",
    ["EternalFlame"] = "PalPassiveSkillChange_Consumable_EternalFlame",
    ["Invader"] = "PalPassiveSkillChange_Consumable_Invader",
    ["Vampire"] = "PalPassiveSkillChange_Consumable_Vampire",
    ["Nushi"] = "PalPassiveSkillChange_Consumable_Nushi",
    ["Salvation"] = "PalPassiveSkillChange_Consumable_Salvation",
    ["Serenity"] = "PalPassiveSkillChange_Consumable_Salvation",
    ["Nocturnal"] = "PalPassiveSkillChange_Nocturnal",
    ["NonKilling"] = "PalPassiveSkillChange_NonKilling",
    ["HatchingSpeed_Up"] = "PalPassiveSkillChange_HatchingSpeed_Up",

    -- 6. Mastery of Fasting & Heart of the Immovable King
    ["PAL_FullStomach_Down_1"] = "PalPassiveSkillChange_PAL_FullStomach_Down_1",
    ["PAL_FullStomach_Down_2"] = "PalPassiveSkillChange_PAL_FullStomach_Down_2",
    ["PAL_FullStomach_Down_3"] = "PalPassiveSkillChange_Consumable_PAL_FullStomach_Down_3",
    ["PAL_Sanity_Down_1"] = "PalPassiveSkillChange_PAL_Sanity_Down_1",
    ["PAL_Sanity_Down_2"] = "PalPassiveSkillChange_PAL_Sanity_Down_2",
    ["PAL_Sanity_Down_3"] = "PalPassiveSkillChange_Consumable_PAL_Sanity_Down_3",

    -- 7. Eternal Engine & Cooldowns
    ["Stamina_Up_1"] = "PalPassiveSkillChange_Stamina_Up_1",
    ["Stamina_Up_2"] = "PalPassiveSkillChange_Stamina_Up_2",
    ["Stamina_Up_3"] = "PalPassiveSkillChange_Consumable_Stamina_Up_3",
    ["CoolTimeReduction_Up_1"] = "PalPassiveSkillChange_CoolTimeReduction_Up_1",
    ["CoolTimeReduction_Up_2"] = "PalPassiveSkillChange_CoolTimeReduction_Up_2",

    -- 8. World Tree / End Game Implants
    ["WorldTree_ATK"] = "PalPassiveSkillChange_Consumable_WorldTree_ATK",
    ["WorldTree_DEF"] = "PalPassiveSkillChange_Consumable_WorldTree_DEF",
    ["WorldTree_CraftSpeed"] = "PalPassiveSkillChange_Consumable_WorldTree_CraftSpeed",
    ["WorldTree_FullStomach"] = "PalPassiveSkillChange_Consumable_WorldTree_FullStomach",
    ["WorldTree_Sanity"] = "PalPassiveSkillChange_Consumable_WorldTree_Sanity",
    ["WorldTree_MoveSpeed"] = "PalPassiveSkillChange_Consumable_WorldTree_MoveSpeed",
    ["WorldTree_ATK_DEF"] = "PalPassiveSkillChange_Consumable_WorldTree_ATK_DEF",

    -- 9. Sakurajima Mutation Implants
    ["MutationPal_Babysitter"] = "PalPassiveSkillChange_Consumable_MutationPal_Babysitter",
    ["MutationPal_Mutant"] = "PalPassiveSkillChange_Consumable_MutationPal_Mutant",
    ["MutationPal_Immortal"] = "PalPassiveSkillChange_Consumable_MutationPal_Immortal",
    ["MutationPal_ExplosionResist"] = "PalPassiveSkillChange_Consumable_MutationPal_ExplosionResist",
    ["RideJumpCount_Increase2"] = "PalPassiveSkillChange_Consumable_RideJumpCount_Increase2",

    -- 10. Trainer / Player Stat Implants
    ["TrainerATK_UP_1"] = "PalPassiveSkillChange_TrainerATK_UP_1",
    ["TrainerDEF_UP_1"] = "PalPassiveSkillChange_TrainerDEF_UP_1",
    ["TrainerWorkSpeed_UP_1"] = "PalPassiveSkillChange_TrainerWorkSpeed_UP_1",
    ["SalePrice_Up_1"] = "PalPassiveSkillChange_SalePrice_Up_1",
    ["SalePrice_Up_2"] = "PalPassiveSkillChange_SalePrice_Up_2",
    ["TrainerMining_up1"] = "PalPassiveSkillChange_TrainerMining_up1",
    ["TrainerLogging_up1"] = "PalPassiveSkillChange_TrainerLogging_up1"
}

-- Map of all discovered PalPassiveSkillChange items in Palworld
local PassiveItemCache = {}
local bCacheInitialized = false

local function CachePassiveChangeItems(worldContext)
    if bCacheInitialized then return end

    pcall(function()
        local dts = FindAllOf("DataTable")
        if dts then
            for _, dt in ipairs(dts) do
                local fullName = ""
                pcall(function() fullName = dt:GetFullName() end)
                if string.find(fullName, "ItemData") or string.find(fullName, "DT_ItemData") then
                    local rowNames = dt:GetRowNames()
                    local namesTable = TArrayToTable(rowNames)
                    for _, rName in ipairs(namesTable) do
                        local itemStr = UnwrapToNameString(rName)
                        if string.find(itemStr, "PalPassiveSkillChange_") or string.find(itemStr, "PassiveSkillChange") then
                            PassiveItemCache[itemStr] = FName(itemStr)
                        end
                    end
                end
            end
        end

        bCacheInitialized = true
    end)
end

-- Pending butcher action map
local pendingButchers = {}

-- Resolve passive skill name string -> implant item FName
local function GetImplantItemIdForPassive(passiveNameStr, worldContext)
    if not passiveNameStr or passiveNameStr == "" or passiveNameStr == "None" then return nil end

    Log("Resolving passive skill: " .. passiveNameStr)

    CachePassiveChangeItems(worldContext)

    local itemResult = nil

    -- 1. Check direct Consumable candidate first (e.g. PalPassiveSkillChange_Consumable_Rare, MoveSpeed_up_3, Vampire, etc.)
    local consCand = "PalPassiveSkillChange_Consumable_" .. passiveNameStr
    if PassiveItemCache[consCand] then
        itemResult = PassiveItemCache[consCand]
        Log(string.format("Matched Consumable Implant: '%s' -> '%s'", passiveNameStr, consCand))
    end

    -- 2. Check Master Explicit Mapping
    if not itemResult then
        local explicitItemStr = MasterPassiveToImplantMap[passiveNameStr]
        if explicitItemStr and PassiveItemCache[explicitItemStr] then
            itemResult = PassiveItemCache[explicitItemStr]
            Log(string.format("Matched Master Map Implant: '%s' -> '%s'", passiveNameStr, explicitItemStr))
        end
    end

    -- 3. Check direct Key Item candidate (e.g. PalPassiveSkillChange_MoveSpeed_up_1, CraftSpeed_up1, etc.)
    if not itemResult then
        local keyCand = "PalPassiveSkillChange_" .. passiveNameStr
        if PassiveItemCache[keyCand] then
            itemResult = PassiveItemCache[keyCand]
            Log(string.format("Matched Key Item Implant: '%s' -> '%s'", passiveNameStr, keyCand))
        end
    end

    if not itemResult then
        Log(string.format("[SKIPPED DROP] Passive skill '%s' has no valid implant item in database.", passiveNameStr))
    end

    return itemResult
end

-- Comprehensive Passive Skill Extractor from Target Character
local function ExtractPassivesFromPal(targetPal)
    local passives = {}
    if not targetPal or not targetPal:IsValid() then return passives end

    pcall(function()
        local paramComp = targetPal.CharacterParameterComponent
        if not paramComp or not paramComp:IsValid() then
            paramComp = targetPal:GetCharacterParameterComponent()
        end
        if paramComp and paramComp:IsValid() then
            local indParam = paramComp.IndividualParameter
            if indParam and indParam:IsValid() then
                local passList = indParam:GetPassiveSkillList()
                local rawTable = TArrayToTable(passList)
                Log(string.format("Extracted %d raw passive elements from Pal character", #rawTable))
                for _, rawVal in ipairs(rawTable) do
                    local nameStr = UnwrapToNameString(rawVal)
                    if nameStr ~= "" and nameStr ~= "None" then
                        table.insert(passives, nameStr)
                    end
                end
            end
        end
    end)

    return passives
end

-- Helper to grant implant item directly to player inventory
local function GrantImplantToPlayer(playerChar, implantId)
    if not playerChar or not playerChar:IsValid() or not implantId then return false end
    local success = false
    pcall(function()
        local pc = nil
        pcall(function() pc = playerChar.Controller end)
        if not pc or not pc:IsValid() then
            pcall(function() pc = playerChar:GetPalPlayerController() end)
        end

        if pc and pc:IsValid() and pc.PlayerState and pc.PlayerState:IsValid() then
            local inventoryData = nil
            pcall(function() inventoryData = pc.PlayerState.InventoryData end)
            if inventoryData and inventoryData:IsValid() then
                local res = nil
                local impStr = UnwrapToNameString(implantId)
                
                pcall(function()
                    res = inventoryData:AddItem_ServerInternal(implantId, 1, false, 0.0, true)
                end)
                Log(string.format("Granted implant '%s' to player inventory, AddItem_ServerInternal result: %s", impStr, tostring(res)))
                
                if tostring(res) == "Success" or tostring(res) == "0" then
                    success = true
                end
            else
                Log("InventoryData not valid on PlayerState.")
            end
        else
            Log("PlayerController or PlayerState not valid.")
        end
    end)
    return success
end

-- Dedicated Server Native Butchering Hook
RegisterHook("/Script/Pal.PalUtility:GiftItem_FromOtomoCutMeat", function(selfParam, OtomoParam, TrainerParam)
    pcall(function()
        Log("GiftItem_FromOtomoCutMeat hook fired on Server!")

        local otomo = nil
        if OtomoParam then pcall(function() otomo = OtomoParam:get() end) end
        
        local trainer = nil
        if TrainerParam then pcall(function() trainer = TrainerParam:get() end) end

        -- Fallback in case UE4SS drops the self param for static functions
        if not trainer or not trainer:IsValid() then
            if OtomoParam then pcall(function() trainer = OtomoParam:get() end) end
            if selfParam then pcall(function() otomo = selfParam:get() end) end
        end

        if not otomo or not otomo:IsValid() then
            Log("Target Pal (Otomo) not valid in GiftItem hook.")
            return
        end

        if not trainer or not trainer:IsValid() then
            Log("Player character (Trainer) not valid in GiftItem hook.")
            return
        end
        
        Log("Target Pal object: " .. otomo:GetFullName())
        Log("Player Char object: " .. trainer:GetFullName())

        -- Extract passive skill strings from butchered Pal
        local passivesTable = ExtractPassivesFromPal(otomo)

        for idx, passStr in ipairs(passivesTable) do
            Log(string.format("Extracted passive #%d: '%s'", idx, passStr))
        end

        local validImplants = {}
        for _, passStr in ipairs(passivesTable) do
            local implantId = GetImplantItemIdForPassive(passStr, trainer)
            if implantId then
                table.insert(validImplants, implantId)
            end
        end

        if #validImplants > 0 then
            local implantsToGrant = {}
            if CONFIG.GrantAllPassives then
                implantsToGrant = validImplants
            else
                math.randomseed(os.time() + math.random(1, 10000))
                table.insert(implantsToGrant, validImplants[math.random(1, #validImplants)])
            end

            Log(string.format("Selected %d Implant(s) for drop.", #implantsToGrant))
            for _, impId in ipairs(implantsToGrant) do
                GrantImplantToPlayer(trainer, impId)
            end
        else
            Log("[SKIPPED DROP] No valid passive implants found on butchered Pal.")
        end
    end)
end)

-- Auto-Patch broken Pocketpair implants so they appear in the Surgery Table
local bSurgeryPatchApplied = false
local function ApplySurgeryTablePatch()
    if bSurgeryPatchApplied then return end
    pcall(function()
        Log("=== Starting Surgery Table Patch ===")
        local itemManager = FindFirstOf("PalItemIDManager")
        if not itemManager or not itemManager:IsValid() then
            Log("PalItemIDManager not found. Aborting patch.")
            return
        end
        
        -- Ensure the cache of all implants is built first
        CachePassiveChangeItems(nil)
        
        local patchedCount = 0
        -- Iterate over EVERY single implant item found in the game files
        for itemStr, fName in pairs(PassiveItemCache) do
            local staticData = itemManager:GetStaticItemData(fName)
            if staticData and staticData:IsValid() then
                local changed = false
                
                -- 6 = EPalItemTypeA::Consume
                if staticData.TypeA ~= 6 then
                    staticData.TypeA = 6
                    changed = true
                end
                -- 72 = EPalItemTypeB::ConsumePassiveSkillChange
                if staticData.TypeB ~= 72 then
                    staticData.TypeB = 72
                    changed = true
                end
                
                -- Force Legal in Game
                if staticData.bLegalInGame == false then
                    staticData.bLegalInGame = true
                    changed = true
                end
                
                -- Fix missing Passive Skill mapping
                local pass = UnwrapToNameString(staticData.PassiveSkill)
                if pass == "" or pass == "None" then
                    -- Guess the passive skill name by stripping the item prefix
                    local guessedPassive = itemStr:gsub("PalPassiveSkillChange_Consumable_", "")
                    guessedPassive = guessedPassive:gsub("PalPassiveSkillChange_", "")
                    staticData.PassiveSkill = FName(guessedPassive)
                    changed = true
                end
                
                -- Custom Sell Prices based on Implant Tier (Rarity)
                local rarity = 0
                pcall(function() rarity = staticData.Rarity end)
                
                local oldPrice = 0
                pcall(function() oldPrice = staticData.Price end)
                
                if rarity >= 4 then
                    staticData.Price = 2500000 -- Rainbow (Sells for 250,000)
                elseif rarity == 3 then
                    staticData.Price = 1500000 -- Tier 3 (Sells for 150,000)
                elseif rarity == 2 then
                    staticData.Price = 500000  -- Tier 2 (Sells for 50,000)
                elseif rarity == 1 then
                    staticData.Price = 350000  -- Tier 1 (Sells for 35,000)
                else
                    staticData.Price = 100000  -- Red Tier / Unknown (Sells for 10,000)
                end
                
                if oldPrice ~= staticData.Price then
                    changed = true
                end
                
                if changed then
                    patchedCount = patchedCount + 1
                    Log(string.format("Patched %s: Rarity=%d | Price %d -> %d", itemStr, rarity, oldPrice, staticData.Price))
                end
            end
        end
        Log(string.format("Surgery Table Patch Complete: %d total implants updated.", patchedCount))
        bSurgeryPatchApplied = true
    end)
end

RegisterHook("/Script/Engine.PlayerController:ClientRestart", function(selfParam)
    ApplySurgeryTablePatch()
end)

ExecuteWithDelay(5000, function()
    ApplySurgeryTablePatch()
end)

-- Hotkey F8: Dump all Disposable Implant Item IDs and Passives
RegisterKeyBind(Key.F8, function()
    pcall(ExecuteInGameThread, function()
        Log("=================================================================")
        Log("=== F8: DUMPING MASTER PASSIVE & IMPLANT DICTIONARY ===")
        Log("=================================================================")

        local dts = FindAllOf("DataTable")
        if dts then
            for dIdx, dt in ipairs(dts) do
                local fullName = ""
                pcall(function() fullName = dt:GetFullName() end)
                if string.find(fullName, "ItemData") or string.find(fullName, "DT_ItemData") then
                    Log(string.format("Target Item DataTable Found: %s", fullName))
                    local rowNames = dt:GetRowNames()
                    local namesTable = TArrayToTable(rowNames)
                    local count = 0
                    for rIdx, rName in ipairs(namesTable) do
                        local itemStr = UnwrapToNameString(rName)
                        if string.find(itemStr, "PalPassiveSkillChange_") or string.find(itemStr, "PassiveSkillChange") then
                            count = count + 1
                            Log(string.format("Implant Item #%d: '%s'", count, itemStr))
                        end
                    end
                    Log(string.format("=== Total Disposable Implant Item IDs Found: %d ===", count))
                end
            end
        end

        Log("=================================================================")
    end)
end)

print(string.format("[%s] Mod loaded successfully (Meat Cleaver Only Active).", MOD_NAME))
