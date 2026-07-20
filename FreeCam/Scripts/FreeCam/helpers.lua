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
    
    local success, hasHit, hitResult, forward = pcall(PerformLineTrace, Kismet, activePlayer, cameraComponent, currentCameraLocation)
    if not success then
        return defaultDist, defaultLoc
    end
    
    if hasHit and hitResult and hitResult.Location then
        local loc = hitResult.Location
        
        -- Calculate 2D horizontal distance (hypotenuse projection correction)
        local dx = loc.X - currentCameraLocation.X
        local dy = loc.Y - currentCameraLocation.Y
        defaultDist = math.sqrt(dx^2 + dy^2)
        
        defaultLoc = {X = loc.X, Y = loc.Y, Z = loc.Z}
    else
        -- If looking at sky, default to a reasonable distance in front of the camera
        local dx = forward.X * defaultDist
        local dy = forward.Y * defaultDist
        defaultDist = math.sqrt(dx^2 + dy^2)
        
        defaultLoc = {
            X = currentCameraLocation.X + forward.X * defaultDist,
            Y = currentCameraLocation.Y + forward.Y * defaultDist,
            Z = currentCameraLocation.Z + forward.Z * defaultDist
        }
    end
    
    return defaultDist, defaultLoc
end

return helpers
