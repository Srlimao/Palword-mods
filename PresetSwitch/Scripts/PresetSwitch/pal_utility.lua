local M = {}

-- Safely unwrap RemoteUnrealParam or wrapper objects
local function unwrap(val)
    if val and type(val) == "userdata" and val.get then
        local success, unwrapped = pcall(function() return val:get() end)
        if success and unwrapped then
            return unwrapped
        end
    end
    return val
end
M.unwrap = unwrap

-- Helper to safely convert reflected TArray userdata to standard Lua table
function M.TArrayToTable(arrayVal)
    local t = {}
    if not arrayVal then return t end
    if type(arrayVal) == "table" then return arrayVal end
    if type(arrayVal) == "userdata" then
        if arrayVal.ForEach then
            pcall(function()
                arrayVal:ForEach(function(arg1, arg2)
                    local val = (type(arg1) ~= "number") and arg1 or arg2
                    if val then
                        table.insert(t, val)
                    end
                end)
            end)
        else
            for i = 0, 100 do
                local elem = nil
                local success, res = pcall(function() return arrayVal[i] end)
                if not success or not res then break end
                table.insert(t, res)
            end
        end
    end
    return t
end

-- Get PalUtility Default CDO
function M.GetPalUtility()
    local status, util = pcall(function()
        return StaticFindObject("/Script/Pal.Default__PalUtility")
    end)
    if status and util and util:IsValid() then
        return util
    end
    return nil
end

-- Get Local Player Controller & Character
function M.GetPlayer()
    local util = M.GetPalUtility()
    if util then
        local status, player = pcall(function() return util:GetPlayerCharacter(nil) end)
        if status and player and player:IsValid() then
            return player
        end
    end
    local status, player = pcall(function() return FindFirstOf("PalPlayerCharacter") end)
    if status and player and player:IsValid() then
        return player
    end
    return nil
end

function M.GetPlayerState()
    local player = M.GetPlayer()
    if player and player:IsValid() then
        local status, ps = pcall(function() return unwrap(player.PlayerState) end)
        if status and ps and ps:IsValid() then
            return ps
        end
    end
    local status, ps = pcall(function() return FindFirstOf("PalPlayerState") end)
    if status and ps and ps:IsValid() then
        return ps
    end
    return nil
end

function M.GetPlayerUId()
    local playerState = M.GetPlayerState()
    if playerState and playerState:IsValid() then
        local status, uid = pcall(function() return playerState.DebugPlayerUId end)
        if status and uid then
            return uid
        end
    end
    return nil
end

-- Retrieve Network Character Component
function M.GetNetworkCharacterComponent()
    local playerState = M.GetPlayerState()
    if playerState and playerState:IsValid() then
        local status, comp = pcall(function() return unwrap(playerState.NetworkCharacterComponent) end)
        if status and comp and comp:IsValid() then
            return comp
        end
    end
    local status, comp = pcall(function() return FindFirstOf("PalNetworkCharacterComponent") end)
    if status and comp and comp:IsValid() then
        return comp
    end
    return nil
end

return M
