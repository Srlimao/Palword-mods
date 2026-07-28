-- Palworld HUDLocator Mod - Completionist Tracker Engine
-- Module for managing per-region and save-wide completion stats:
-- Effigies, Alphas, Fast Travels, Watch Towers, and Bounties.

local UEHelpers = require("UEHelpers")
local configMod = require("HUDLocator.config")

local M = {}

-- Defined Palworld Regions with map coordinate bounds
M.Regions = {
    {
        id = "grasslands",
        name = "Grasslands & Central Isles",
        icon = "🌱",
        bounds = { minX = -450000, maxX = 200000, minY = -450000, maxY = 200000 },
        totals = { effigies = 48, alphas = 18, fastTravels = 24, towers = 1, bounties = 6 }
    },
    {
        id = "volcano",
        name = "Mount Obsidian (Volcano)",
        icon = "🌋",
        bounds = { minX = -850000, maxX = -450000, minY = -800000, maxY = -100000 },
        totals = { effigies = 24, alphas = 8, fastTravels = 12, towers = 1, bounties = 4 }
    },
    {
        id = "desert",
        name = "Desecrated Desert",
        icon = "🏜️",
        bounds = { minX = 200000, maxX = 850000, minY = 150000, maxY = 850000 },
        totals = { effigies = 18, alphas = 6, fastTravels = 9, towers = 1, bounties = 3 }
    },
    {
        id = "snow",
        name = "Astral Mountains (Snow)",
        icon = "❄️",
        bounds = { minX = -450000, maxX = 200000, minY = 200000, maxY = 850000 },
        totals = { effigies = 26, alphas = 9, fastTravels = 11, towers = 2, bounties = 4 }
    },
    {
        id = "sakurajima",
        name = "Sakurajima Island",
        icon = "🌸",
        bounds = { minX = -850000, maxX = -450000, minY = -100000, maxY = 350000 },
        totals = { effigies = 22, alphas = 7, fastTravels = 10, towers = 1, bounties = 4 }
    },
    {
        id = "feybreak",
        name = "Feybreak Island",
        icon = "✨",
        bounds = { minX = -100000, maxX = 650000, minY = -850000, maxY = -450000 },
        totals = { effigies = 20, alphas = 6, fastTravels = 8, towers = 1, bounties = 3 }
    },
    {
        id = "sanctuaries",
        name = "Wildlife Sanctuaries",
        icon = "🏝️",
        bounds = { minX = -900000, maxX = 900000, minY = -900000, maxY = 900000 },
        totals = { effigies = 6, alphas = 3, fastTravels = 3, towers = 0, bounties = 2 }
    }
}

-- Current active player state & stats cache
M.currentRegionId = "grasslands"
M.currentRegionName = "Grasslands & Central Isles"
M.cachedRegionStats = {}
M.globalSaveProgress = {
    unlockedFastTravels = 0,
    totalFastTravels = 77,
    defeatedAlphas = 0,
    totalAlphas = 57,
    defeatedTowers = 0,
    totalTowers = 7,
    clearedBounties = 0,
    totalBounties = 26,
    collectedEffigies = 0,
    totalEffigies = 164,
    overallPercent = 0
}

-- Helper to safely extract boolean/int key-values from reflected RepInfo arrays
local function ParseRepInfoArray(repInfoArray, outMap)
    if not repInfoArray or not outMap then return end
    pcall(function()
        local items = repInfoArray.Items
        if items and items.ForEach then
            items:ForEach(function(_, elem)
                pcall(function()
                    if elem and elem.Key then
                        local keyStr = elem.Key:ToString()
                        local val = elem.Value
                        outMap[keyStr] = val
                    end
                end)
            end)
        end
    end)
end

-- Resolve current region from player 2D world position
function M.ResolveRegion(x, y)
    if not x or not y then return M.Regions[1] end
    
    -- Check specific region bounds
    for _, reg in ipairs(M.Regions) do
        local b = reg.bounds
        if x >= b.minX and x <= b.maxX and y >= b.minY and y <= b.maxY then
            -- Special sanctuary check for outer corners
            if reg.id == "sanctuaries" then
                local isCorner = (x < -600000 or x > 600000 or y < -600000 or y > 600000)
                if isCorner then return reg end
            else
                return reg
            end
        end
    end
    
    return M.Regions[1]
end

-- Main periodic scan method to extract completion data from UPalPlayerRecordData
function M.ScanCompletionData()
    if not configMod.CONFIG.Global.Enabled then return end
    if configMod.CONFIG.Completionist and not configMod.CONFIG.Completionist.Enabled then return end

    local localPlayer = UEHelpers.GetPlayer()
    if not localPlayer or not localPlayer:IsValid() then return end

    -- Update active region from player location
    pcall(function()
        local loc = localPlayer:K2_GetActorLocation()
        if loc then
            local activeReg = M.ResolveRegion(loc.X, loc.Y)
            M.currentRegionId = activeReg.id
            M.currentRegionName = activeReg.name
        end
    end)

    -- Access UPalPlayerRecordData
    local playerState = localPlayer.PlayerState
    if not playerState or not playerState:IsValid() then return end

    local recordData = nil
    pcall(function()
        if playerState.GetRecordData then
            recordData = playerState:GetRecordData()
        else
            recordData = playerState.RecordData
        end
    end)

    if not recordData or not recordData:IsValid() then return end

    -- Temporary maps for active save state
    local fastTravelsMap = {}
    local alphasMap = {}
    local towersMap = {}
    local bountiesMap = {}
    local effigiesMap = {}

    -- Decode flags from reflected arrays
    pcall(function() ParseRepInfoArray(recordData.FastTravelPointUnlockFlag, fastTravelsMap) end)
    pcall(function() ParseRepInfoArray(recordData.NormalBossDefeatFlag, alphasMap) end)
    pcall(function() ParseRepInfoArray(recordData.TowerBossDefeatFlag, towersMap) end)
    pcall(function() ParseRepInfoArray(recordData.SpecificBossDefeatFlag, bountiesMap) end)
    pcall(function() ParseRepInfoArray(recordData.RelicObtainForInstanceFlag_CapturePower, effigiesMap) end)

    -- Count total unlocked/defeated items
    local ftCount, alphaCount, towerCount, bountyCount, effigyCount = 0, 0, 0, 0, 0

    for _, v in pairs(fastTravelsMap) do
        if v == true or v == 1 then ftCount = ftCount + 1 end
    end
    for _, v in pairs(alphasMap) do
        if v == true or v == 1 then alphaCount = alphaCount + 1 end
    end
    for _, v in pairs(towersMap) do
        if v == true or v == 1 then towerCount = towerCount + 1 end
    end
    for k, v in pairs(bountiesMap) do
        if v and v > 0 then bountyCount = bountyCount + 1 end
    end
    for _, v in pairs(effigiesMap) do
        if v == true or v == 1 then effigyCount = effigyCount + 1 end
    end

    -- Fallback: Use native C++ methods on UPalPlayerRecordData if available
    pcall(function()
        if recordData.GetRelicPossessNumByType then
            local rel = recordData:GetRelicPossessNumByType(0)
            if rel and rel > effigyCount then effigyCount = rel end
        end
    end)

    -- Update global save progress
    M.globalSaveProgress.unlockedFastTravels = ftCount
    M.globalSaveProgress.defeatedAlphas = alphaCount
    M.globalSaveProgress.defeatedTowers = towerCount
    M.globalSaveProgress.clearedBounties = bountyCount
    M.globalSaveProgress.collectedEffigies = effigyCount

    local totalItems = M.globalSaveProgress.totalFastTravels + M.globalSaveProgress.totalAlphas + 
                       M.globalSaveProgress.totalTowers + M.globalSaveProgress.totalBounties + 
                       M.globalSaveProgress.totalEffigies
    local unlockedItems = ftCount + alphaCount + towerCount + bountyCount + effigyCount
    M.globalSaveProgress.overallPercent = (totalItems > 0) and math.floor((unlockedItems / totalItems) * 100) or 0

    -- Populate per-region breakdown stats
    local newRegionStats = {}
    for idx, reg in ipairs(M.Regions) do
        -- Approximate regional distribution ratios
        local regRatio = reg.totals.fastTravels / M.globalSaveProgress.totalFastTravels
        local rFT = math.min(reg.totals.fastTravels, math.floor(ftCount * regRatio + 0.5))
        local rAlpha = math.min(reg.totals.alphas, math.floor(alphaCount * (reg.totals.alphas / M.globalSaveProgress.totalAlphas) + 0.5))
        local rTower = math.min(reg.totals.towers, math.floor(towerCount * (reg.totals.towers / math.max(1, M.globalSaveProgress.totalTowers)) + 0.5))
        local rBounty = math.min(reg.totals.bounties, math.floor(bountyCount * (reg.totals.bounties / M.globalSaveProgress.totalBounties) + 0.5))
        local rEffigy = math.min(reg.totals.effigies, math.floor(effigyCount * (reg.totals.effigies / M.globalSaveProgress.totalEffigies) + 0.5))

        local regUnlocked = rFT + rAlpha + rTower + rBounty + rEffigy
        local regTotal = reg.totals.fastTravels + reg.totals.alphas + reg.totals.towers + reg.totals.bounties + reg.totals.effigies
        local regPct = (regTotal > 0) and math.floor((regUnlocked / regTotal) * 100) or 0

        newRegionStats[reg.id] = {
            name = reg.name,
            icon = reg.icon,
            isCurrent = (reg.id == M.currentRegionId),
            percent = regPct,
            fastTravels = { unlocked = rFT, total = reg.totals.fastTravels },
            alphas = { defeated = rAlpha, total = reg.totals.alphas },
            towers = { defeated = rTower, total = reg.totals.towers },
            bounties = { cleared = rBounty, total = reg.totals.bounties },
            effigies = { collected = rEffigy, total = reg.totals.effigies }
        }
    end

    M.cachedRegionStats = newRegionStats
end

return M
