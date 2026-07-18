-- ModConfigurator Main Script (Production Integration Test Version)
-- Handles central config syncing, directory provisioning, and local server integration tests

print("[ModConfigurator] Initializing ModConfigurator Client...")

local configManager = require("ModConfigurator.config")
local utils = require("ModConfigurator.utils")

local function GetModPath()
    local info = debug.getinfo(1, "S")
    if info and info.source and info.source:sub(1, 1) == "@" then
        local src = info.source:sub(2)
        local modDir = src:match("(.*)[/\\]Scripts[/\\]main%.lua")
        if modDir then
            return modDir
        end
    end
    return "Mods/ModConfiguratorDEBUG"
end

local modPath = GetModPath()
local rawDaemonPath = modPath .. "/Scripts/ModConfigurator/run_daemon.vbs"
local daemonPath = string.gsub(rawDaemonPath, "\\", "/")

-- Boot up daemon
print("[ModConfigurator] Spawning daemon: " .. daemonPath)
pcall(function()
    local status, SystemLibrary = pcall(function() return StaticFindObject("/Script/Engine.Default__KismetSystemLibrary") end)
    if status and SystemLibrary then
        SystemLibrary:LaunchURL("file:///" .. daemonPath)
    else
        -- Fallback to os.execute if LaunchURL isn't available
        os.execute('start /B "" wscript.exe "' .. string.gsub(daemonPath, "/", "\\") .. '"')
    end
end)

-- Alt+D: Fetch Config (GET) and Save locally
RegisterKeyBind(Key.D, {ModifierKey.ALT}, function()
    local userId = configManager.ResolveUserId()
    local baseUrl = configManager.CONFIG.ApiBaseUrl
    local modName = "HUDLocator"
    
    local url = baseUrl .. "/api/config/get?userId=" .. userId .. "&mod=" .. modName
    print("[ModConfigurator] GET request triggered for " .. modName .. " (User ID: " .. userId .. ")")
    
    utils.MakeAPIRequest("GET", url, nil, function(data, err)
        if err then
            print("[ModConfigurator] Fetch failed: " .. tostring(err))
        else
            print("[ModConfigurator] Fetch completed successfully!")
            
            local json = require("ModConfigurator.json")
            local responseData = nil
            if type(data) == "table" then
                responseData = data
            else
                responseData = json.parse(data)
            end
            
            if responseData and responseData.config then
                local configData = responseData.config
                local writeKey = responseData.writeKey
                
                -- Save to \ModConfigs\HUDLocator\config.json (silently in background)
                configManager.EnsureModDirectoryExists(modName, function(dirSuccess)
                    if dirSuccess then
                        local savePath = configManager.GetModConfigPath(modName)
                        local file = io.open(savePath, "w")
                        if file then
                            file:write(json.stringify(configData))
                            file:close()
                            print("[ModConfigurator] Fetched configuration written to: " .. savePath)
                        else
                            print("[ModConfigurator] ERROR: Failed to write fetched config to path: " .. savePath)
                        end
                        
                        -- Save writeKey
                        if writeKey and writeKey ~= "" then
                            local keyPath = configManager.GetModWriteKeyPath(modName)
                            local kFile = io.open(keyPath, "w")
                            if kFile then
                                kFile:write(writeKey)
                                kFile:close()
                                print("[ModConfigurator] Verification writeKey updated locally.")
                            end
                        end
                    else
                        print("[ModConfigurator] ERROR: Silent directory creation failed.")
                    end
                end)
            else
                print("[ModConfigurator] ERROR: Failed to parse configuration and writeKey from response.")
            end
        end
    end)
end)

-- Alt+F: Save Config (POST) from local file
RegisterKeyBind(Key.F, {ModifierKey.ALT}, function()
    local userId = configManager.ResolveUserId()
    local baseUrl = configManager.CONFIG.ApiBaseUrl
    local modName = "HUDLocator"
    local json = require("ModConfigurator.json")
    
    local url = baseUrl .. "/api/config/save"
    local savePath = configManager.GetModConfigPath(modName)
    local keyPath = configManager.GetModWriteKeyPath(modName)
    
    -- Load the writeKey signature
    local kFile = io.open(keyPath, "r")
    local writeKey = nil
    if kFile then
        writeKey = kFile:read("*all")
        kFile:close()
        -- Trim whitespace
        writeKey = string.gsub(writeKey, "%s+", "")
    end
    
    if not writeKey or writeKey == "" then
        print("[ModConfigurator] ERROR: No write key found. Please sync configs (Alt+D) once first to authorize saves.")
        return
    end
    
    local function sendPayload(configTable)
        print("[ModConfigurator] POST request triggered to save " .. modName .. " config from: " .. savePath)
        local payload = {
            userId = userId,
            mod = modName,
            writeKey = writeKey,
            config = configTable
        }
        utils.MakeAPIRequest("POST", url, payload, function(data, err)
            if err then
                print("[ModConfigurator] Save failed: " .. tostring(err))
            else
                print("[ModConfigurator] Save completed successfully!")
                if type(data) == "table" then
                    print("[ModConfigurator] Response: " .. json.stringify(data))
                else
                    print("[ModConfigurator] Raw Response: " .. tostring(data))
                end
            end
        end)
    end
    
    -- Ensure local config exists, write default if missing
    local file = io.open(savePath, "r")
    if file then
        local content = file:read("*all")
        file:close()
        local localConfig = json.parse(content)
        sendPayload(localConfig)
    else
        print("[ModConfigurator] Local config not found. Creating default local config silently...")
        local defaultConfig = {
            Global = {
                Enabled = true,
                Language = "en-us",
                ScanIntervalMs = 1000
            },
            Players = {
                Enabled = true,
                MaxDistance = 8000
            }
        }
        
        -- Silently create parent directories before writing
        configManager.EnsureModDirectoryExists(modName, function(dirSuccess)
            if dirSuccess then
                local wFile = io.open(savePath, "w")
                if wFile then
                    wFile:write(json.stringify(defaultConfig))
                    wFile:close()
                end
                sendPayload(defaultConfig)
            else
                print("[ModConfigurator] ERROR: Failed to create mod directory silently.")
            end
        end)
    end
end)



print("[ModConfigurator] Client initialized successfully!")
print("[ModConfigurator]   Resolved User ID: " .. configManager.ResolveUserId())
print("[ModConfigurator]   Mod Configs Folder: " .. configManager.GetModConfigsDir())
print("[ModConfigurator] Use Alt+F to test POST (Save) and Alt+D to test GET (Fetch).")

