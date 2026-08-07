local configMod = require("HUDLocator.config")
local utils = require("HUDLocator.utils")
local logger = require("HUDLocator.logger")

local M = {}
M.hasLoggedRelics = false

function M.Scan(playerPos, maxDistSq)
    local newRelics = {}
    local relics = FindAllOf("PalLevelObjectRelic") or {}
    for _, relic in ipairs(relics) do
        if relic:IsValid() then
            pcall(function()
                local ueRelicPos = relic:K2_GetActorLocation()
                if ueRelicPos then
                    local within, distSq = utils.IsWithinDistanceSq(ueRelicPos, playerPos, maxDistSq)
                    if within then
                        -- ⚡ Bolt Performance Optimization:
                        -- Defer C++ reflection property checks until AFTER distance is confirmed.
                        if utils.IsRelicPicked(relic) then return end

                        local name = nil
                        local statusType, relicType = pcall(function() return relic:GetRelicType() end)
                        if not statusType or not relicType then
                            statusType, relicType = pcall(function() return relic.RelicType end)
                        end
                        local resolvedType = (statusType and relicType) and relicType or 0
                        local trans = utils.GetTranslatedRelicName(resolvedType)
                        if trans then
                            name = trans
                        else
                            name = configMod.GetTranslation("Relic", "Relic")
                        end
                        local distStr = math.floor(math.sqrt(distSq) / 100.0) .. "m"
                        table.insert(newRelics, { X = ueRelicPos.X, Y = ueRelicPos.Y, Z = ueRelicPos.Z, Name = name, DistStr = distStr })
                    end
                end
            end)
        end
    end
    if not M.hasLoggedRelics and #newRelics > 0 then
        M.hasLoggedRelics = true
        logger.log("Relic Scan (Initial detection): Found " .. tostring(#newRelics) .. " relics.")
    end
    return newRelics
end

return M
