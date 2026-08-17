local logger = require("HUDLocator.logger")

local M = {}
M.hasLoggedPlayers = false

function M.Scan(localPlayerState, playerPos)
    local newPlayers = {}
    local seen = {}
    
    if localPlayerState and localPlayerState:IsValid() then
        local playerStates = {}
        local status, res = pcall(function() return FindAllOf("PalPlayerState") end)
        if status and res then
            playerStates = res
        end
        
        for _, state in ipairs(playerStates) do
            if state:IsValid() and state ~= localPlayerState then
                pcall(function()
                    local namePrivate = state.PlayerNamePrivate
                    if namePrivate then
                        local nameStr = namePrivate:ToString()
                        if not seen[nameStr] then
                            local loc = state.CachedPlayerLocation
                            if loc then
                                local locX, locY, locZ = loc.X, loc.Y, loc.Z
                                if locX ~= 0.0 or locY ~= 0.0 or locZ ~= 0.0 then
                                    seen[nameStr] = true

                                    -- ⚡ Bolt Performance Optimization:
                                    -- Calculate math.sqrt and string concatenation here inside the scanner loop
                                    -- (which runs on a slower interval) instead of calculating it every frame
                                    -- in the ReceiveDrawHUD renderer loop to reduce CPU/GC overhead.
                                    local distSq = 0
                                    local distStr = ""
                                    if playerPos then
                                        local dx = locX - playerPos.X
                                        local dy = locY - playerPos.Y
                                        local dz = locZ - playerPos.Z
                                        distSq = dx*dx + dy*dy + dz*dz
                                        distStr = math.floor(math.sqrt(distSq) / 100.0) .. "m"
                                    end

                                    table.insert(newPlayers, {
                                        Name = nameStr,
                                        LabelStr = "@ " .. nameStr,
                                        DistSq = distSq,
                                        DistStr = distStr,
                                        BracketDistStr = "[" .. distStr .. "]",
                                        Pos = { X = locX, Y = locY, Z = locZ }
                                    })
                                end
                            end
                        end
                    end
                end)
            end
        end
    end

    if not M.hasLoggedPlayers and #newPlayers > 0 then
        M.hasLoggedPlayers = true
        logger.log("Player Scan (Initial detection): Found " .. tostring(#newPlayers) .. " other players.")
    end

    return newPlayers
end

return M
