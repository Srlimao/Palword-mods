local utils = require("HUDLocator.utils")
local logger = require("HUDLocator.logger")

local M = {}
M.hasLoggedPals = false

local function EvaluatePalRule(rule, palName, charIdStr, isShiny, isBoss, palPassives)
    if not rule then return false, 0 end
    if type(rule) == "string" then
        rule = { palname = rule }
    end

    if rule.palname and rule.palname ~= "" and rule.palname ~= "*" then
        local targetName = string.lower(rule.palname)
        local lowerPalName = string.lower(palName or "")
        local lowerCharId = string.lower(charIdStr or "")
        if not string.find(lowerPalName, targetName, 1, true) and not string.find(lowerCharId, targetName, 1, true) then
            return false, 0
        end
    end

    if rule.shiny == true and not isShiny then
        return false, 0
    end

    if rule.boss == true and not isBoss then
        return false, 0
    end

    local matchedPassivesCount = 0
    local matchedPassiveNames = {}
    if rule.passive and type(rule.passive) == "table" then
        local requiredList = rule.passive.passives
        local minThreshold = rule.passive.min_passive_threshold or 1

        if requiredList and type(requiredList) == "table" and #requiredList > 0 then
            local palPassiveMap = {}
            for _, pName in ipairs(palPassives) do
                palPassiveMap[string.lower(tostring(pName))] = true
            end

            for _, reqP in ipairs(requiredList) do
                local lowerReq = string.lower(tostring(reqP))
                if palPassiveMap[lowerReq] then
                    matchedPassivesCount = matchedPassivesCount + 1
                    table.insert(matchedPassiveNames, reqP)
                end
            end

            if matchedPassivesCount < minThreshold then
                return false, 0
            end
        end
    end

    return true, matchedPassivesCount, matchedPassiveNames
end

function M.Scan(playerPos, maxDistSq, palConfig)
    local newPals = {}
    local actors = {}
    local status, res = pcall(function() return FindAllOf("BP_MonsterBase_C") end)
    if status and res then
        actors = res
    else
        status, res = pcall(function() return FindAllOf("PalMonsterCharacter") end)
        if status and res then
            actors = res
        end
    end
    
    local filterMode = palConfig.FilterMode or "TrackerListOnly"
    local rulesList = palConfig.TrackerPals or {}
    local showPassives = palConfig.ShowPassives ~= false
    local showLevel = palConfig.ShowLevel ~= false

    for _, actor in ipairs(actors) do
        if actor:IsValid() then
            pcall(function()
                local uePos = actor:K2_GetActorLocation()
                if uePos then
                    local within, distSq = utils.IsWithinDistanceSq(uePos, playerPos, maxDistSq)
                    if within then
                        local charParam = nil
                        pcall(function() charParam = actor:GetCharacterParameterComponent() end)

                        local staticParam = nil
                        pcall(function() staticParam = actor.StaticCharacterParameterComponent end)

                        local indivParam = nil
                        if charParam and charParam:IsValid() then
                            pcall(function() indivParam = charParam:GetIndividualParameter() end)
                        end

                        local isDead = false
                        if indivParam and indivParam:IsValid() then
                            pcall(function() isDead = indivParam:IsDead() end)
                        end

                        local isOwned = false
                        pcall(function()
                            if indivParam and indivParam:IsValid() then
                                local ownerUid = indivParam:GetOwnerPlayerUId()
                                if ownerUid and ownerUid:IsValid() then
                                    isOwned = true
                                end
                            end
                        end)
                        pcall(function()
                            if not isOwned and charParam and charParam:IsValid() then
                                if charParam:IsOtomo() then
                                    isOwned = true
                                end
                            end
                        end)

                        if not isDead and not isOwned then
                            local isShiny = false
                            if indivParam and indivParam:IsValid() then
                                pcall(function() isShiny = indivParam:IsRarePal() end)
                            elseif staticParam and staticParam:IsValid() then
                                pcall(function() isShiny = staticParam:IsRarePal() end)
                            end

                            local isBoss = false
                            if staticParam and staticParam:IsValid() then
                                pcall(function() isBoss = staticParam.IsBoss_Database or staticParam:IsBossPal_Database() end)
                            end

                            local charIdStr = ""
                            if indivParam and indivParam:IsValid() then
                                pcall(function()
                                    local cId = indivParam:GetCharacterID()
                                    if cId then charIdStr = cId:ToString() end
                                end)
                            end

                            if string.find(charIdStr, "Boss_") then
                                isBoss = true
                            end

                            local palName = utils.GetTranslatedPalName(charIdStr)

                            local level = nil
                            if indivParam and indivParam:IsValid() then
                                pcall(function() level = indivParam:GetLevel() end)
                            elseif charParam and charParam:IsValid() then
                                pcall(function() level = charParam:GetLevel() end)
                            end

                            local rank = 0
                            if indivParam and indivParam:IsValid() then
                                pcall(function() rank = indivParam:GetRank() end)
                            end

                            local rawPassives = {}
                            if indivParam and indivParam:IsValid() then
                                pcall(function()
                                    local pList = indivParam:GetPassiveSkillList()
                                    rawPassives = utils.TArrayToTable(pList)
                                end)
                                if #rawPassives == 0 then
                                    pcall(function()
                                        local pList = indivParam.PassiveSkillList
                                        rawPassives = utils.TArrayToTable(pList)
                                    end)
                                end
                            end

                            local palPassivesStr = {}
                            local translatedPassives = {}
                            for _, pName in ipairs(rawPassives) do
                                local strP = utils.FNameToString(pName)
                                if strP and strP ~= "" and strP ~= "None" then
                                    table.insert(palPassivesStr, strP)
                                    local transP = utils.GetTranslatedPassiveName(strP)
                                    if transP and transP ~= "" then
                                        table.insert(translatedPassives, transP)
                                    end
                                end
                            end

                            local shouldTrack = false
                            local matchedPassiveCount = 0

                            if filterMode == "All" then
                                shouldTrack = true
                            elseif filterMode == "ShinyOnly" then
                                shouldTrack = isShiny
                            elseif filterMode == "BossOnly" then
                                shouldTrack = isBoss
                            elseif filterMode == "ShinyOrBoss" then
                                shouldTrack = isShiny or isBoss
                            elseif filterMode == "TrackerListOnly" then
                                for _, rule in ipairs(rulesList) do
                                    local pass, count = EvaluatePalRule(rule, palName, charIdStr, isShiny, isBoss, palPassivesStr)
                                    if pass then
                                        shouldTrack = true
                                        if count > matchedPassiveCount then
                                            matchedPassiveCount = count
                                        end
                                        break
                                    end
                                end
                            end

                            if shouldTrack then
                                local labelParts = { palName }

                                if showLevel and level then
                                    table.insert(labelParts, "lv." .. tostring(level))
                                end

                                if rank and rank > 0 then
                                    local stars = string.rep("*", rank)
                                    table.insert(labelParts, stars)
                                end

                                if isShiny then
                                    table.insert(labelParts, "Shiny")
                                end

                                if isBoss then
                                    table.insert(labelParts, "Boss")
                                end

                                if matchedPassiveCount > 0 then
                                    table.insert(labelParts, "(" .. tostring(matchedPassiveCount) .. ")")
                                end

                                local formattedLabel = table.concat(labelParts, " ")
                                local distStr = math.floor(math.sqrt(distSq) / 100.0) .. "m"

                                table.insert(newPals, {
                                    X = uePos.X, Y = uePos.Y, Z = uePos.Z,
                                    Name = formattedLabel,
                                    PalName = palName,
                                    Level = level,
                                    IsShiny = isShiny,
                                    IsBoss = isBoss,
                                    Passives = showPassives and translatedPassives or {},
                                    DistStr = distStr
                                })
                            end
                        end
                    end
                end
            end)
        end
    end

    if not M.hasLoggedPals and #newPals > 0 then
        M.hasLoggedPals = true
        logger.log("Pal Scan (Initial detection): Found " .. tostring(#newPals) .. " tracked Pals.")
    end

    return newPals
end

return M
