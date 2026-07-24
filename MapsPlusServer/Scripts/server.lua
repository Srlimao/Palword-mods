-- server.lua
local M = {}
local json = require("json")
local urpc = require("urpc")

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

local function CleanGuid(str)
    if not str then return "" end
    return string.gsub(string.upper(tostring(str)), "[^%w]", "")
end

-- Resolve base camp model by string ID
local function FindBaseCampModel(world, guid_str)
    local targetClean = CleanGuid(guid_str)
    if targetClean == "" then return nil end

    local palUtility = StaticFindObject("/Script/Pal.Default__PalUtility")
    if not palUtility then return nil end
    local baseCampManager = palUtility:GetBaseCampManager(world)
    if not baseCampManager then return nil end

    local ids = {}
    pcall(function() baseCampManager:GetBaseCampIds(ids) end)
    local idTable = TArrayToTable(ids)

    print("[MapsPlusServer] Searching base camp model for target GUID='" .. tostring(guid_str) .. "' (Clean=" .. targetClean .. "). Server registered camps count=" .. tostring(#idTable))

    for _, id in ipairs(idTable) do
        local current_str = nil
        pcall(function() current_str = GuidToString(id) end)
        local currentClean = CleanGuid(current_str)

        print(string.format("[MapsPlusServer] Candidate Base Camp GUID: %s (Clean=%s | Match=%s)", tostring(current_str), currentClean, tostring(currentClean == targetClean)))

        if currentClean ~= "" and currentClean == targetClean then
            local model = nil
            pcall(function()
                local success, res = baseCampManager:TryGetModel(id)
                if success and res and res:IsValid() then
                    model = res
                end
            end)
            if model then
                return model
            end
        end
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

    -- 2. Register RPC handler via UniversalRPCBus
    urpc.RegisterServerHandler("MapsPlusServer", "RenameBase", function(senderPC, data)
        if not data or type(data) ~= "table" then return end
        local guid_str = data.guid
        local new_name = data.name

        if guid_str and new_name then
            local world = FindFirstOf("World")
            if world and world:IsValid() then
                local model = FindBaseCampModel(world, guid_str)
                if model then
                    print("[MapsPlusServer] Server: Successfully renamed base GUID " .. tostring(guid_str) .. " -> '" .. tostring(new_name) .. "'")
                    model.BaseCampName = new_name
                    base_names[guid_str] = new_name
                    SaveServerNames()
                else
                    print("[MapsPlusServer] Server Error: Base camp model not found for GUID=" .. tostring(guid_str))
                end
            end
        else
            print("[MapsPlusServer] Server Error: Failed to process RenameBase payload (missing guid or name).")
        end
    end)
    print("[MapsPlusServer] Server: UniversalRPCBus handler registered successfully for 'RenameBase'.")
end

return M


