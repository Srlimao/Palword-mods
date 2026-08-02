local UEHelpers = require("UEHelpers")

local KismetCache = nil
local PalUtilityCache = nil

local helpers = {}

function helpers.SafeIsActorHidden(actor)
    if not actor or not actor:IsValid() then return true end
    local isHidden = true
    
    if actor.IsActorHiddenInGame then
        local success, res = pcall(function() return actor:IsActorHiddenInGame() end)
        if success and res ~= nil then
            if type(res) == "userdata" and res.get then
                return res:get()
            else
                return res
            end
        end
    end
    
    if actor.bHidden ~= nil then
        local success, res = pcall(function() return actor.bHidden end)
        if success and res ~= nil then
            if type(res) == "userdata" and res.get then
                return res:get()
            else
                return res
            end
        end
    end
    
    return isHidden
end

function helpers.TArrayToTable(arrayVal)
    local t = {}
    if not arrayVal then return t end
    
    local function processElement(val)
        if val then
            local hasGet = false
            local hasIsValid = false
            local hasGetFullName = false
            pcall(function() hasGet = (val.get ~= nil) end)
            pcall(function() hasIsValid = (val.IsValid ~= nil) end)
            pcall(function() hasGetFullName = (val.GetFullName ~= nil) end)
            
            local needGet = false
            if hasGet and not hasIsValid and not hasGetFullName then
                needGet = true
            end
            if needGet then
                pcall(function() val = val:get() end)
            end
            table.insert(t, val)
        end
    end

    if type(arrayVal) == "table" then
        for i = 1, #arrayVal do
            processElement(arrayVal[i])
        end
        if #t == 0 then
            for _, val in pairs(arrayVal) do
                processElement(val)
            end
        end
    elseif type(arrayVal) == "userdata" then
        if arrayVal.ForEach then
            pcall(function()
                arrayVal:ForEach(function(arg1, arg2)
                    local val = nil
                    if type(arg1) ~= "number" then val = arg1 else val = arg2 end
                    processElement(val)
                end)
            end)
        else
            for i = 0, 100 do
                local elem = nil
                local success = pcall(function() elem = arrayVal[i] end)
                if not success or not elem then break end
                processElement(elem)
            end
        end
    end
    return t
end

-- Pre-allocate tables for zero garbage collection overhead in hot path (LineTrace)
local endPosCache = { X = 0.0, Y = 0.0, Z = 0.0 }
local hitResultCache = {}
local emptyTableCache = {}
local forwardCache = { X = 0.0, Y = 0.0, Z = 0.0 }
local ignoreActorsCache = {}

-- Globally cache engine helper objects to prevent per-frame StaticFindObject lookup lag
function helpers.GetEngineHelpers()
    if not KismetCache or not KismetCache:IsValid() then
        KismetCache = StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
    end
    if not PalUtilityCache or not PalUtilityCache:IsValid() then
        PalUtilityCache = StaticFindObject("/Script/Pal.Default__PalUtility")
    end
    return KismetCache, PalUtilityCache
end

local function CheckPlayerInBaseCampInternal(localPlayer)
    local _, PalUtility = helpers.GetEngineHelpers()
    if not PalUtility or not PalUtility:IsValid() then return false end

    local manager = PalUtility:GetBaseCampManager(localPlayer)
    if not manager or not manager:IsValid() then return false end

    local playerLoc = localPlayer:K2_GetActorLocation()
    local baseCamp = manager:GetInRangedBaseCamp(playerLoc, 0.0)
    return baseCamp and baseCamp:IsValid(), baseCamp
end

-- Helper to retrieve player's current base camp object
function helpers.GetPlayerBaseCamp(localPlayer)
    if not localPlayer or not localPlayer:IsValid() then return false, nil end
    local success, inBaseCamp, baseCampObj = pcall(CheckPlayerInBaseCampInternal, localPlayer)
    if success and inBaseCamp then
        return true, baseCampObj
    end
    return false, nil
end

-- Helper to check if the player character is inside a base camp boundary
function helpers.IsPlayerInBaseCamp(localPlayer)
    local inBase, _ = helpers.GetPlayerBaseCamp(localPlayer)
    return inBase
end

local function PerformLineTrace(Kismet, activePlayer, cameraComponent, currentCameraLocation)
    local forward = cameraComponent:GetForwardVector()
    local fX, fY, fZ = forward.X, forward.Y, forward.Z
    if type(fX) == "userdata" and fX.get then fX = fX:get() fY = fY:get() fZ = fZ:get() end
    forwardCache.X, forwardCache.Y, forwardCache.Z = fX, fY, fZ

    endPosCache.X = currentCameraLocation.X + fX * 25000.0
    endPosCache.Y = currentCameraLocation.Y + fY * 25000.0
    endPosCache.Z = currentCameraLocation.Z + fZ * 25000.0

    -- Clear hitResultCache keys from previous frame instead of allocating a new table
    for k in pairs(hitResultCache) do
        hitResultCache[k] = nil
    end

    -- TraceTypeQuery1 = 1 (Visibility channel - hits terrain and building static meshes like foundations)
    ignoreActorsCache[1] = activePlayer
    local hasHit = Kismet:LineTraceSingle(activePlayer, currentCameraLocation, endPosCache, 1, false, ignoreActorsCache, 0, hitResultCache, true, emptyTableCache, emptyTableCache, 0.0)
    return hasHit, hitResultCache, forwardCache
end

-- Helper to find the terrain or structure intersection point in the camera look direction
function helpers.GetAimDistanceAndLocation(activePlayer, cameraComponent, currentCameraLocation, outAimLoc)
    local defaultDist = 2000.0
    outAimLoc.X = currentCameraLocation.X
    outAimLoc.Y = currentCameraLocation.Y
    outAimLoc.Z = currentCameraLocation.Z

    local Kismet, _ = helpers.GetEngineHelpers()
    if not Kismet or not Kismet:IsValid() or not activePlayer or not activePlayer:IsValid() or not cameraComponent or not cameraComponent:IsValid() then
        return defaultDist, nil
    end

    local success, hasHit, hitResult, forward = pcall(PerformLineTrace, Kismet, activePlayer, cameraComponent, currentCameraLocation)
    if not success then
        return defaultDist, nil
    end

    local maxAimDistance = 3000.0 -- 30 meters maximum distance from camera to aim location

    if hasHit and hitResult and hitResult.Location then
        local loc = hitResult.Location
        local locX, locY, locZ = loc.X, loc.Y, loc.Z
        if type(locX) == "userdata" and locX.get then locX = locX:get() locY = locY:get() locZ = locZ:get() end

        local dx = locX - currentCameraLocation.X
        local dy = locY - currentCameraLocation.Y
        local dz = locZ - currentCameraLocation.Z

        -- Optimize: Use multiplication instead of exponentiation (`^2`) and squared distance check
        local totalDistSq = dx * dx + dy * dy + dz * dz

        if totalDistSq > (maxAimDistance * maxAimDistance) then
            -- Optimize: Use multiplication instead of exponentiation (`^2`)
            local fxd = forward.X * maxAimDistance
            local fyd = forward.Y * maxAimDistance
            defaultDist = math.sqrt(fxd * fxd + fyd * fyd)
            outAimLoc.X = currentCameraLocation.X + fxd
            outAimLoc.Y = currentCameraLocation.Y + fyd
            outAimLoc.Z = currentCameraLocation.Z + forward.Z * maxAimDistance
        else
            -- Optimize: Use multiplication instead of exponentiation (`^2`)
            defaultDist = math.sqrt(dx * dx + dy * dy)
            outAimLoc.X = locX
            outAimLoc.Y = locY
            outAimLoc.Z = locZ
        end
    else
        -- If looking at sky, default to maxAimDistance in front of the camera
        local targetDist = math.min(defaultDist, maxAimDistance)
        local dx = forward.X * targetDist
        local dy = forward.Y * targetDist

        -- Optimize: Use multiplication instead of exponentiation (`^2`)
        defaultDist = math.sqrt(dx * dx + dy * dy)

        outAimLoc.X = currentCameraLocation.X + dx
        outAimLoc.Y = currentCameraLocation.Y + dy
        outAimLoc.Z = currentCameraLocation.Z + forward.Z * targetDist
    end

    local hitActor = nil
    if hasHit and hitResult and hitResult.Actor and hitResult.Actor:IsValid() then
        local actor = hitResult.Actor
        if actor ~= activePlayer then
            hitActor = actor
        end
    end

    return defaultDist, hitActor
end

return helpers
