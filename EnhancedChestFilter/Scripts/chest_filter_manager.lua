local json = require("json")
local config = require("config")

local M = {}
local chestCache = {}
local activeWorldSaveDir = "default"

local function Log(msg)
    if config.EnableDebugLog then
        print(string.format("[%s] [Manager] %s", config.MOD_ID, tostring(msg)))
    end
end

--- Get the current active World Save Directory name or World GUID
function M.GetWorldSaveName()
    local worldDir = nil
    pcall(function()
        local worldContext = FindFirstOf("PalWorldInformation")
        if worldContext and worldContext:IsValid() and worldContext.GetWorldSaveDirectoryName then
            local wName = worldContext:GetWorldSaveDirectoryName()
            if wName then worldDir = wName:ToString() end
        end
    end)

    if not worldDir or worldDir == "" then
        pcall(function()
            local gameSetting = FindFirstOf("PalOptionWorldSave")
            if gameSetting and gameSetting:IsValid() and gameSetting.WorldSaveDirectoryName then
                local wName = gameSetting.WorldSaveDirectoryName
                if wName then worldDir = tostring(wName) end
            end
        end)
    end

    if not worldDir or worldDir == "" then
        worldDir = "default_world"
    end

    activeWorldSaveDir = worldDir
    return worldDir
end

--- Primary configuration file path per Rule 3 & per-world save directory
function M.GetConfigPath()
    local worldName = M.GetWorldSaveName()
    local localAppData = os.getenv("LOCALAPPDATA")
    if localAppData and localAppData ~= "" then
        return string.format("%s\\Pal\\Saved\\Mods\\%s\\chests_%s.json", localAppData, config.MOD_ID, worldName)
    end
    return string.format("chests_%s.json", worldName)
end

--- Load settings from disk
function M.LoadConfig()
    local filePath = M.GetConfigPath()
    local file = io.open(filePath, "r")
    if not file then
        Log("No existing config file found at: " .. filePath .. ". Starting with clean settings.")
        chestCache = {}
        return
    end

    local content = file:read("*a")
    file:close()

    if content and content ~= "" then
        local data = json.decode(content)
        if data and data.Chests then
            chestCache = data.Chests
            Log("Loaded per-chest settings from: " .. filePath)
        end
    end
end

--- Save settings to disk
function M.SaveConfig()
    local filePath = M.GetConfigPath()
    -- Ensure directory exists by attempting file write
    local file = io.open(filePath, "w")
    if not file then
        -- Fallback path if LocalAppData subfolder isn't created yet
        filePath = "chests_" .. activeWorldSaveDir .. ".json"
        file = io.open(filePath, "w")
    end

    if file then
        local data = {
            WorldSave = activeWorldSaveDir,
            Chests = chestCache
        }
        file:write(json.encode(data))
        file:close()
        Log("Saved per-chest settings to: " .. filePath)
    else
        Log("ERROR: Failed to write config file to disk!")
    end
end

--- Get strict mode setting for a specific chest GUID
function M.GetChestStrict(chestGuid)
    if not chestGuid or chestGuid == "" then return false end
    if chestCache[chestGuid] and chestCache[chestGuid].bStrictExistingOnly ~= nil then
        return chestCache[chestGuid].bStrictExistingOnly
    end
    return false
end

--- Set strict mode setting for a specific chest GUID
function M.SetChestStrict(chestGuid, bStrict)
    if not chestGuid or chestGuid == "" then return end
    chestCache[chestGuid] = {
        bStrictExistingOnly = (bStrict == true),
        lastUpdated = os.time()
    }
    Log(string.format("Chest GUID '%s' updated -> StrictMode: %s", tostring(chestGuid), tostring(bStrict)))
    M.SaveConfig()
end

return M
