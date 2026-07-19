-- ModConfigurator Config Module
-- Handles directory resolution, User ID tracking, and local mod configurations

local M = {}

M.CONFIG = {
    ApiBaseUrl = "http://localhost:3000",
    UserId = "" -- Persisted globally
}

-- Returns the absolute path of the old documents folder (for migration lookup)
function M.GetOldDocumentsConfigsDir()
    local userProfile = os.getenv("USERPROFILE")
    if not userProfile or userProfile == "" then
        local drive = os.getenv("HOMEDRIVE") or "C:"
        local path = os.getenv("HOMEPATH") or "/Users/Default"
        userProfile = drive .. path
    end
    
    local docsPath = userProfile .. "/Documents"
    
    -- If OneDrive is active, the documents directory is usually redirected to OneDrive/Documents
    local oneDrive = os.getenv("OneDrive") or os.getenv("OneDriveConsumer")
    if oneDrive and oneDrive ~= "" then
        docsPath = oneDrive .. "/Documents"
    end
    
    local path = docsPath .. "/My Games/Palworld/ModConfigs"
    -- Standardize path separator to forward slash for Lua compatibility
    path = string.gsub(path, "\\", "/")
    return path
end

-- Returns the absolute path of the user's ModConfigs folder
function M.GetModConfigsDir()
    local localAppData = os.getenv("LOCALAPPDATA")
    if not localAppData or localAppData == "" then
        local userProfile = os.getenv("USERPROFILE")
        if not userProfile or userProfile == "" then
            local drive = os.getenv("HOMEDRIVE") or "C:"
            local path = os.getenv("HOMEPATH") or "/Users/Default"
            userProfile = drive .. path
        end
        localAppData = userProfile .. "/AppData/Local"
    end
    
    local path = localAppData .. "/Pal/Saved/Mods"
    -- Standardize path separator to forward slash for Lua compatibility
    path = string.gsub(path, "\\", "/")
    return path
end

-- Try to create the ModConfigs directory
function M.EnsureConfigsDirectoryExists()
    local path = M.GetModConfigsDir()
    pcall(function()
        -- Silent folder creation on Windows
        os.execute('mkdir "' .. string.gsub(path, "/", "\\") .. '" >nul 2>nul')
    end)
end

-- Returns the absolute path of a specific mod's configuration file
function M.GetModConfigPath(modName)
    return M.GetModConfigsDir() .. "/" .. modName .. "/config.json"
end

-- Returns the absolute path of a specific mod's write key file
function M.GetModWriteKeyPath(modName)
    return M.GetModConfigsDir() .. "/" .. modName .. "/write_key.txt"
end


-- Ensures that the specific mod's configuration directory exists silently via the daemon helper
function M.EnsureModDirectoryExists(modName, callback)
    local utils = require("ModConfigurator.utils")
    local path = M.GetModConfigsDir() .. "/" .. modName
    utils.MakeDir(path, callback)
end


-- Generates a fallback 16-char random hex user ID if no Steam ID is resolved
local function GenerateFallbackId()
    local chars = "0123456789abcdef"
    local id = ""
    for i = 1, 16 do
        local idx = math.random(1, #chars)
        id = id .. string.sub(chars, idx, idx)
    end
    return id
end

-- Resolves the unique Player ID (SteamID64 / Account ID / Fallback)
function M.ResolveUserId()
    local resolvedId = nil
    
    -- 1. Try resolving via PocketpairUserSubsystem first (live check)
    local Subsystem = FindFirstOf("PocketpairUserSubsystem")
    if Subsystem and Subsystem:IsValid() then
        pcall(function()
            local uid = Subsystem:GetSaveDataUserId()
            if uid then
                local uidStr = uid:ToString()
                if uidStr and uidStr ~= "" and uidStr ~= "0" and uidStr:len() > 10 then
                    resolvedId = uidStr
                end
            end
        end)
    end
    
    -- 2. If live check succeeds, save it to file and return it
    if resolvedId then
        M.CONFIG.UserId = resolvedId
        local globalConfigPath = M.GetModConfigsDir() .. "/mcm.json"
        local outFile = io.open(globalConfigPath, "w")
        if outFile then
            outFile:write('{\n  "UserId": "' .. resolvedId .. '"\n}')
            outFile:close()
        end
        return resolvedId
    end
    
    -- 3. Fallback to cached ID if live check fails
    if M.CONFIG.UserId and M.CONFIG.UserId ~= "" then
        return M.CONFIG.UserId
    end
    
    local globalConfigPath = M.GetModConfigsDir() .. "/mcm.json"
    local file = io.open(globalConfigPath, "r")
    if file then
        local content = file:read("*all")
        file:close()
        local id = content:match('"UserId"%s*:%s*"([^"]+)"')
        if id and id ~= "" then
            M.CONFIG.UserId = id
            return id
        end
    end
    
    -- 3b. Try migrating from old Documents config
    local oldGlobalConfigPath = M.GetOldDocumentsConfigsDir() .. "/mod_configurator_global.json"
    local oFile = io.open(oldGlobalConfigPath, "r")
    if oFile then
        local content = oFile:read("*all")
        oFile:close()
        local id = content:match('"UserId"%s*:%s*"([^"]+)"')
        if id and id ~= "" then
            M.CONFIG.UserId = id
            -- Save to new location
            local outFile = io.open(globalConfigPath, "w")
            if outFile then
                outFile:write('{\n  "UserId": "' .. id .. '"\n}')
                outFile:close()
            end
            -- Clean up old global config
            os.remove(oldGlobalConfigPath)
            print("[ModConfigurator] Migrated User ID from legacy Documents folder to mcm.json")
            return id
        end
    end
    
    -- 4. If no cached ID and live check failed (e.g. Title screen), generate a temporary fallback
    local tempId = GenerateFallbackId()
    M.CONFIG.UserId = tempId
    return tempId
end


-- Initialize folders
M.EnsureConfigsDirectoryExists()
pcall(M.ResolveUserId)

return M
