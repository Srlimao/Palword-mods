-- ModConfigurator Utilities Module
-- Handles silent background API requests, JSON operations, and file IO

local M = {}
local json = require("ModConfigurator.json")

local function GetModPath()
    local info = debug.getinfo(1, "S")
    if info and info.source and info.source:sub(1, 1) == "@" then
        local src = info.source:sub(2)
        local modDir = src:match("(.*)[/\\]Scripts[/\\]ModConfigurator[/\\]utils%.lua")
        if modDir then
            return modDir
        end
    end
    return "Mods/ModConfiguratorDEBUG"
end

local modPath = GetModPath()
local requestPath = modPath .. "/Scripts/ModConfigurator/request.json"
local payloadPath = modPath .. "/Scripts/ModConfigurator/payload.json"
local responsePath = modPath .. "/Scripts/ModConfigurator/response.json"

-- Perform an asynchronous background HTTP API request via the daemon helper
function M.MakeAPIRequest(verb, url, payloadTable, callback)
    -- Clean up any old files to prevent state leaks
    pcall(os.remove, requestPath)
    pcall(os.remove, payloadPath)
    pcall(os.remove, responsePath)
    
    -- If a POST payload is supplied, write it to payload.json
    if verb == "POST" and payloadTable then
        local pFile = io.open(payloadPath, "w")
        if pFile then
            pFile:write(json.stringify(payloadTable))
            pFile:close()
        else
            print("[ModConfigurator] ERROR: Failed to write payload.json")
            if callback then callback(nil, "Failed to write payload") end
            return
        end
    end
    
    -- Dispatch request to daemon
    local rFile = io.open(requestPath, "w")
    if not rFile then
        print("[ModConfigurator] ERROR: Failed to write request.json")
        if callback then callback(nil, "Failed to write request") end
        return
    end
    rFile:write(verb .. "\n")
    rFile:write(url .. "\n")
    rFile:close()
    
    -- Poll for daemon response in the background
    local function checkResponse()
        local resFile = io.open(responsePath, "r")
        if resFile then
            local content = resFile:read("*all")
            resFile:close()
            
            -- Clean up response and payload files
            pcall(os.remove, responsePath)
            pcall(os.remove, payloadPath)
            
            if callback then
                -- Parse JSON response automatically if valid, otherwise return raw string
                local data = json.parse(content)
                if data then
                    callback(data, nil)
                else
                    callback(content, nil)
                end
            end
        else
            -- Check again in 200ms
            ExecuteWithDelay(200, checkResponse)
        end
    end
    
    ExecuteWithDelay(200, checkResponse)
end

-- Performs a silent background directory creation
function M.MakeDir(path, callback)
    local winPath = string.gsub(path, "/", "\\")
    
    pcall(os.remove, requestPath)
    
    local rFile = io.open(requestPath, "w")
    if not rFile then
        if callback then callback(false, "Failed to write request") end
        return
    end
    rFile:write("MKDIR\n")
    rFile:write(winPath .. "\n")
    rFile:close()
    
    local function checkCompleted()
        local rFileCheck = io.open(requestPath, "r")
        if not rFileCheck then
            -- requestPath has been deleted by daemon, meaning it completed!
            if callback then callback(true, nil) end
        else
            rFileCheck:close()
            ExecuteWithDelay(150, checkCompleted)
        end
    end
    ExecuteWithDelay(150, checkCompleted)
end

return M

