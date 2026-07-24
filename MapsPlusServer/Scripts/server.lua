-- server.lua
local M = {}
local json = require("json")

-- State persistence directory
local function GetSaveDirectory()
    local root = os.getenv("LOCALAPPDATA")
    if not root or root == "" then root = os.getenv("APPDATA") end
    if not root or root == "" then return nil end
    local path = root .. "/Pal/Saved/Mods/MapsPlusServer"
    return string.gsub(path, "\\", "/")
end

local SAVE_DIR = GetSaveDirectory()
local SAVE_PATH = SAVE_DIR and (SAVE_DIR .. "/base_names.json") or nil
local base_names = {}

-- Safely convert reflected TArray to standard table (Adheres to AGENTS.md GC principles)
local function TArrayToTable(arrayVal)
    local t = {}
    if not arrayVal then return t end
    if type(arrayVal) == "table" then return arrayVal end
    if type(arrayVal) == "userdata" and arrayVal.ForEach then
        pcall(function()
            arrayVal:ForEach(function(arg1, arg2)
                local val = (type(arg1) ~= "number") and arg1 or arg2
                if val then table.insert(t, val) end
            end)
        end)
    end
    return t
end

local function LoadServerNames()
    if not SAVE_PATH then return end
    local file = io.open(SAVE_PATH, "r")
    if file then
        local content = file:read("*a")
        file:close()
        base_names = json.decode(content) or {}
        local count = 0
        for _ in pairs(base_names) do count = count + 1 end
        print("[MapsPlusServer] Loaded " .. tostring(count) .. " base names from json database.")
    else
        print("[MapsPlusServer] No base name database found. Starting fresh.")
    end
end

local function SaveServerNames()
    if not SAVE_PATH or not SAVE_DIR then return end
    
    -- Ensure save directory exists (silent mkdir)
    pcall(function()
        os.execute('mkdir "' .. string.gsub(SAVE_DIR, "/", "\\") .. '" >nul 2>nul')
    end)

    local file = io.open(SAVE_PATH, "w")
    if file then
        file:write(json.encode(base_names))
        file:close()
        print("[MapsPlusServer] Successfully saved base names database.")
    else
        print("[MapsPlusServer] Error: Failed to open database file for writing: " .. SAVE_PATH)
    end
end

-- Safely unpack FGuid components
local function GetGuidParts(guid)
    if not guid then return 0, 0, 0, 0 end
    local a, b, c, d = 0, 0, 0, 0
    pcall(function() a = guid.A end)
    pcall(function() b = guid.B end)
    pcall(function() c = guid.C end)
    pcall(function() d = guid.D end)
    if type(a) == "userdata" and a.get then pcall(function() a = a:get() end) end
    if type(b) == "userdata" and b.get then pcall(function() b = b:get() end) end
    if type(c) == "userdata" and c.get then pcall(function() c = c:get() end) end
    if type(d) == "userdata" and d.get then pcall(function() d = d:get() end) end
    a = tonumber(a) or 0
    b = tonumber(b) or 0
    c = tonumber(c) or 0
    d = tonumber(d) or 0
    return a, b, c, d
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
    local a, b, c, d = GetGuidParts(guid)
    return string.format("%08X-%08X-%08X-%08X", a, b, c, d)
end

-- Resolve base camp model by string ID
local function FindBaseCampModel(world, guid_str)
    local palUtility = StaticFindObject("/Script/Pal.Default__PalUtility")
    if not palUtility then return nil end
    local baseCampManager = palUtility:GetBaseCampManager(world)
    if not baseCampManager then return nil end

    local ids = {}
    baseCampManager:GetBaseCampIds(ids)
    local idTable = TArrayToTable(ids)

    print("[MapsPlusServer] Searching base camp model for target GUID='" .. tostring(guid_str) .. "'. Server registered camps count=" .. tostring(#idTable))

    for _, id in ipairs(idTable) do
        local current_str = GuidToString(id)
        print(string.format("[MapsPlusServer] Candidate Base Camp GUID: %s (Match=%s)", tostring(current_str), tostring(current_str and string.upper(current_str) == string.upper(guid_str))))

        if current_str and string.upper(current_str) == string.upper(guid_str) then
            local success, model = baseCampManager:TryGetModel(id)
            if success and model and model:IsValid() then
                return model
            end
        end
    end
    return nil
end

local function GetStringFromProp(prop)
    if not prop then return nil end
    if type(prop) == "string" then return prop end
    if type(prop) == "userdata" then
        local str = nil
        pcall(function() str = prop:ToString() end)
        if str and type(str) == "string" and str ~= "" then return str end

        pcall(function()
            if prop.get then
                local g = prop:get()
                if type(g) == "string" and g ~= "" then
                    str = g
                elseif type(g) == "userdata" and g.ToString then
                    str = g:ToString()
                end
            end
        end)
        if str and type(str) == "string" and str ~= "" then return str end
    end
    return nil
end

function M.Initialize()
    print("[MapsPlusServer] Server Module loaded.")
    LoadServerNames()

    -- 1. Restore base names on startup when world is ready
    RegisterHook("/Script/Engine.PlayerController:ClientRestart", function(self)
        pcall(function()
            local pc = self:get()
            if pc and pc:IsValid() then
                local world = FindFirstOf("World")
                if world and world:IsValid() then
                    local count = 0
                    for guid_str, name in pairs(base_names) do
                        local model = FindBaseCampModel(world, guid_str)
                        if model then
                            model.BaseCampName = name
                            count = count + 1
                        end
                    end
                    if count > 0 then
                        print("[MapsPlusServer] Restored " .. tostring(count) .. " base camp names to current world.")
                    end
                end
            end
        end)
    end)

    -- 2. Secret payload receiver via Chat RPC (APalPlayerState:EnterChat & APalPlayerController:EnterChat_Receive)
    local function HandleChatPayload(message)
        local msgStr = GetStringFromProp(message)
        if not msgStr and type(message) == "userdata" and message.get then
            pcall(function() msgStr = message:get():ToString() end)
        end

        print("[MapsPlusServer] Server: Chat hook received msg = " .. tostring(msgStr))

        if msgStr and type(msgStr) == "string" then
            local cleanMsg = msgStr
            if cleanMsg:sub(1, 1) == "\x02" then
                cleanMsg = cleanMsg:sub(2)
            end

            if cleanMsg:sub(1, 11) == "renamebase:" then
                print("[MapsPlusServer] Intercepted Base Rename Payload: " .. cleanMsg)
                local parts = {}
                for part in string.gmatch(cleanMsg:sub(12), "[^:]+") do
                    table.insert(parts, part)
                end

                local guid_str = parts[1]
                local new_name = parts[2]

                if guid_str and new_name then
                    local world = FindFirstOf("World")
                    if world and world:IsValid() then
                        local model = FindBaseCampModel(world, guid_str)
                        if model then
                            print("[MapsPlusServer] Server: Successfully renamed base GUID " .. guid_str .. " -> '" .. new_name .. "'")
                            model.BaseCampName = new_name
                            base_names[guid_str] = new_name
                            SaveServerNames()
                        else
                            print("[MapsPlusServer] Server Error: Base camp model not found for GUID=" .. guid_str)
                        end
                    end
                else
                    print("[MapsPlusServer] Server Error: Failed to parse payload parts from " .. cleanMsg)
                end

                return true -- Block chat execution so message is never saved, broadcasted, or shown!
            end
        end
    end

    RegisterHook("/Script/Pal.PalPlayerState:EnterChat", function(self, message, category)
        return HandleChatPayload(message)
    end)

    RegisterHook("/Script/Pal.PalPlayerController:EnterChat_Receive", function(self, message, category)
        return HandleChatPayload(message)
    end)
end

return M
