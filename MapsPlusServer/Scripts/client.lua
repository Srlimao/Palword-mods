-- client.lua
local M = {}
local urpc = require("urpc")
local active_base_camp_guid = nil
local palUtility = nil

local registered_ok1 = false
local registered_ok2 = false

-- Helper: Convert FGuid to string format matching the original mod
local function GetGuidPart(val)
    if not val then return 0 end
    pcall(function()
        if type(val) == "userdata" and val.get then
            val = val:get()
        end
    end)
    val = tonumber(val) or 0
    if val < 0 then val = val + 4294967296 end
    return val
end

local function GuidToString(guid)
    if not guid then return nil end
    local guidLib = StaticFindObject("/Script/Engine.Default__KismetGuidLibrary")
    if guidLib and guidLib:IsValid() then
        local str = nil
        pcall(function() str = guidLib:Conv_GuidToString(guid) end)
        if str then
            if type(str) == "string" then return str end
            if type(str) == "userdata" and str.ToString then return str:ToString() end
        end
    end
    local a = GetGuidPart(guid.A)
    local b = GetGuidPart(guid.B)
    local c = GetGuidPart(guid.C)
    local d = GetGuidPart(guid.D)
    return string.format("%08X-%08X-%08X-%08X", a, b, c, d)
end

local function start_registration_retry()
    -- Hook 1: Hover tooltip to capture base camp ID and display server name
    if not registered_ok1 then
        local ok1 = pcall(RegisterHook, "/Game/Pal/Blueprint/UI/UserInterface/Map/WBP_MapPoint_Info.WBP_MapPoint_Info_C:SetCampInfo", function(self, can_teleport, base_camp_id)
            if base_camp_id then
                active_base_camp_guid = base_camp_id:get()
            end
        end, function(self, can_teleport, base_camp_id)
            if not palUtility or not palUtility:IsValid() then
                palUtility = StaticFindObject("/Script/Pal.Default__PalUtility")
            end
            if not palUtility then return end
            
            local widget = self:get()
            if not widget or not widget:IsValid() then return end
            
            local baseCampManager = palUtility:GetBaseCampManager(widget)
            if baseCampManager and base_camp_id then
                local guid = base_camp_id:get()
                local success, baseCampModel = baseCampManager:TryGetModel(guid)
                if success and baseCampModel:IsValid() then
                    local serverName = baseCampModel.BaseCampName
                    if serverName and serverName ~= "" then
                        local textBlock = widget.BP_PalRichTextBlock_C_139
                        if textBlock and textBlock:IsValid() then
                            textBlock:SetText(FText(serverName))
                        end
                    end
                end
            end
        end)
        
        if ok1 then
            registered_ok1 = true
        end
    end

    -- Hook 2: Capture confirm button click to send rename payload
    if not registered_ok2 then
        local BUTTON_EVENT = "/Game/Pal/Blueprint/UI/UserInterface/CharacterCreation/WBP_CharaCre_PlayerNameEdit.WBP_CharaCre_PlayerNameEdit_C:BndEvt__WBP_CharaCre_PlayerNameEdit_WBP_CommonButton_K2Node_ComponentBoundEvent_2_OnClicked__DelegateSignature"
        local ok2 = pcall(RegisterHook, BUTTON_EVENT, function(self)
            print("[MapsPlusServer] Confirm dialog button clicked.")
            if not active_base_camp_guid then
                print("[MapsPlusServer] Client Error: active_base_camp_guid is nil!")
                return
            end
            
            local widget = self:get()
            if not widget or not widget:IsValid() then
                print("[MapsPlusServer] Client Error: self:get() returned nil or invalid widget!")
                return
            end
            
            local textBox = widget.PalEditableTextBox_83
            if not textBox or not textBox:IsValid() then
                print("[MapsPlusServer] Client Error: textBox (PalEditableTextBox_83) is nil or invalid on widget!")
                return
            end
            local newName = textBox:GetText():ToString()
            
            local guidStr = GuidToString(active_base_camp_guid)
            print("[MapsPlusServer] Preparing rename. Base GUID: " .. tostring(guidStr) .. " | New Name: '" .. tostring(newName) .. "'")
            if guidStr and newName ~= "" then
                local sent = urpc.SendToServer("MapsPlusServer", "RenameBase", {
                    guid = guidStr,
                    name = newName
                })
                if sent then
                    print(string.format("[MapsPlusServer] Client: Sent RenameBase RPC via UniversalRPCBus (GUID=%s, Name='%s')", guidStr, newName))
                else
                    print("[MapsPlusServer] Client Error: urpc.SendToServer returned false.")
                end
            else
                print("[MapsPlusServer] Rename aborted. GUID or New Name is empty.")
            end
        end)
        
        if ok2 then
            registered_ok2 = true
        end
    end

    if not registered_ok1 or not registered_ok2 then
        print(string.format("[MapsPlusServer] Client UI hooks not fully loaded yet (H1=%s, H2=%s), retrying in 1s...", 
            tostring(registered_ok1), tostring(registered_ok2)))
        ExecuteWithDelay(1000, start_registration_retry)
    else
        print("[MapsPlusServer] Client UI hooks successfully registered!")
    end
end

function M.Initialize()
    print("[MapsPlusServer] Client Module loaded. Commencing UI hook registration...")
    palUtility = StaticFindObject("/Script/Pal.Default__PalUtility")
    start_registration_retry()
end

return M
