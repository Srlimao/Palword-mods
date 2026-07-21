local UEHelpers = require("UEHelpers")

local KismetCache = nil
local PalUtilityCache = nil

local helpers = {}

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
    return baseCamp and baseCamp:IsValid()
end

-- Helper to check if the player character is inside a base camp boundary
function helpers.IsPlayerInBaseCamp(localPlayer)
    if not localPlayer or not localPlayer:IsValid() then return false end
    local success, inBaseCamp = pcall(CheckPlayerInBaseCampInternal, localPlayer)
    return success and inBaseCamp
end

local function PerformLineTrace(Kismet, activePlayer, cameraComponent, currentCameraLocation)
    local forward = cameraComponent:GetForwardVector()
    local startPos = currentCameraLocation
    local endPos = {
        X = currentCameraLocation.X + forward.X * 25000.0,
        Y = currentCameraLocation.Y + forward.Y * 25000.0,
        Z = currentCameraLocation.Z + forward.Z * 25000.0
    }

    local hitResult = {}
    -- TraceTypeQuery1 = 1 (Visibility channel - hits terrain and building static meshes like foundations)
    local hasHit = Kismet:LineTraceSingle(activePlayer, startPos, endPos, 1, false, {}, 0, hitResult, true, {}, {}, 0.0)
    return hasHit, hitResult, forward
end

-- Helper to find the terrain or structure intersection point in the camera look direction
function helpers.GetAimDistanceAndLocation(activePlayer, cameraComponent, currentCameraLocation)
    local defaultDist = 2000.0
    local defaultLoc = {
        X = currentCameraLocation.X,
        Y = currentCameraLocation.Y,
        Z = currentCameraLocation.Z
    }

    local Kismet, _ = helpers.GetEngineHelpers()
    if not Kismet or not Kismet:IsValid() or not activePlayer or not activePlayer:IsValid() or not cameraComponent or not cameraComponent:IsValid() then
        return defaultDist, defaultLoc
    end

    local success, hasHit, hitResult, forward = pcall(PerformLineTrace, Kismet, activePlayer, cameraComponent,
        currentCameraLocation)
    if not success then
        return defaultDist, defaultLoc
    end

    local maxAimDistance = 3000.0 -- 30 meters maximum distance from camera to aim location

    if hasHit and hitResult and hitResult.Location then
        local loc = hitResult.Location
        local dx = loc.X - currentCameraLocation.X
        local dy = loc.Y - currentCameraLocation.Y
        local dz = loc.Z - currentCameraLocation.Z
        local totalDist = math.sqrt(dx^2 + dy^2 + dz^2)

        if totalDist > maxAimDistance then
            defaultDist = math.sqrt((forward.X * maxAimDistance)^2 + (forward.Y * maxAimDistance)^2)
            defaultLoc = {
                X = currentCameraLocation.X + forward.X * maxAimDistance,
                Y = currentCameraLocation.Y + forward.Y * maxAimDistance,
                Z = currentCameraLocation.Z + forward.Z * maxAimDistance
            }
        else
            defaultDist = math.sqrt(dx^2 + dy^2)
            defaultLoc = { X = loc.X, Y = loc.Y, Z = loc.Z }
        end
    else
        -- If looking at sky, default to maxAimDistance in front of the camera
        local targetDist = math.min(defaultDist, maxAimDistance)
        local dx = forward.X * targetDist
        local dy = forward.Y * targetDist
        defaultDist = math.sqrt(dx^2 + dy^2)

        defaultLoc = {
            X = currentCameraLocation.X + forward.X * targetDist,
            Y = currentCameraLocation.Y + forward.Y * targetDist,
            Z = currentCameraLocation.Z + forward.Z * targetDist
        }
    end

    local hitActor = nil
    if hasHit and hitResult and hitResult.Actor and hitResult.Actor:IsValid() then
        hitActor = hitResult.Actor
    end

    return defaultDist, defaultLoc, hitActor
end

return helpers
