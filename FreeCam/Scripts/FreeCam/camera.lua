-- FreeCam Facade Coordinator
local UEHelpers = require("UEHelpers")
local helpers = require("FreeCam.helpers")
local config = require("FreeCam.config")
local input = require("FreeCam.input_manager")
local camera_m = require("FreeCam.camera_manager")
local player_m = require("FreeCam.player_manager")
local builder_m = require("FreeCam.builder_manager")

local camera = {}

local isSpectating = false
local currentSpeed = 15.0 -- default flight speed
local currentCameraLocation = {X = 0.0, Y = 0.0, Z = 0.0}
local currentCameraRotation = {Pitch = 0.0, Yaw = 0.0, Roll = 0.0}

-- Cache active PC and Player character during spectating
local activePC = nil
local activePlayer = nil
local cachedPC = nil

local function GetPCCached()
    if not cachedPC or not cachedPC:IsValid() then
        cachedPC = UEHelpers.GetPlayerController()
    end
    return cachedPC
end

-- Pre-allocated vector variables to prevent allocations in per-frame ticks
local moveDir = {X = 0.0, Y = 0.0, Z = 0.0}
local forwardVec = { X = 0.0, Y = 0.0, Z = 0.0 }
local rightVec = { X = 0.0, Y = 0.0, Z = 0.0 }
local upVec = { X = 0.0, Y = 0.0, Z = 0.0 }
local aimLocCache = { X = 0.0, Y = 0.0, Z = 0.0 }
local lastSetAimLoc = { X = 0.0, Y = 0.0, Z = 0.0 }
local limitRadius = 5250.0
local hasLastSetAimLoc = false
local lastLogTime = 0.0

function camera.RefreshConfigCache()
    input.RefreshConfigCache()
end

function camera.IsSpectating()
    return isSpectating
end

function camera.GetReticleTargetObject()
    return builder_m.GetReticleTargetObject()
end

function camera.AdjustSpeed(amount)
    if not isSpectating then return end
    currentSpeed = currentSpeed + amount
    if currentSpeed > 150.0 then currentSpeed = 150.0 end
    if currentSpeed < 2.0 then currentSpeed = 2.0 end
end

-- Toggles Free Camera flight state
function camera.ToggleFreeCam()
    local pc = UEHelpers.GetPlayerController()
    if not pc or not pc:IsValid() then return end
    
    local localPlayer = UEHelpers.GetPlayer()
    if not localPlayer or not localPlayer:IsValid() then return end
    
    local builder = localPlayer.BuilderComponent
    if not builder or not builder:IsValid() then return end
    
    if not isSpectating then
        local inBase, baseCampObj = helpers.GetPlayerBaseCamp(localPlayer)
        if not inBase or not baseCampObj then
            print("[FreeCam] Cannot enable FreeCam: Player is not within Base Camp boundaries.")
            return
        end
        
        local range = 3500.0
        pcall(function()
            local r = baseCampObj:GetRange()
            if type(r) == "userdata" and r.get then r = r:get() end
            if type(r) == "number" and r > 0 then range = r end
        end)
        limitRadius = range * 1.5
        print(string.format("[FreeCam Debug] Enforcing flight radius limit: %.1f units (%.1f meters)", limitRadius, limitRadius / 100.0))
    end
    
    isSpectating = not isSpectating
    
    if isSpectating then
        print("[FreeCam] FreeCam Enabled.")
        activePC = pc
        activePlayer = localPlayer
        
        -- Setup sub-managers
        if not player_m.Setup(activePlayer, activePC) then
            isSpectating = false
            return
        end
        if not camera_m.Setup(activePlayer, activePC) then
            player_m.Teardown(activePlayer, activePC)
            isSpectating = false
            return
        end
        builder_m.Setup(activePlayer)
        
        -- Cache camera initial coordinates
        local camComp = camera_m.GetCameraComponent()
        if camComp and camComp:IsValid() then
            local loc = camComp:K2_GetComponentLocation()
            local rot = camComp:K2_GetComponentRotation()
            local lX, lY, lZ = loc.X, loc.Y, loc.Z
            local rP, rY, rR = rot.Pitch, rot.Yaw, rot.Roll
            if type(lX) == "userdata" and lX.get then lX = lX:get() lY = lY:get() lZ = lZ:get() end
            if type(rP) == "userdata" and rP.get then rP = rP:get() rY = rY:get() rR = rR:get() end
            
            currentCameraLocation.X, currentCameraLocation.Y, currentCameraLocation.Z = lX, lY, lZ
            currentCameraRotation.Pitch, currentCameraRotation.Yaw, currentCameraRotation.Roll = rP, rY, rR
        end
        
        hasLastSetAimLoc = false
    else
        print("[FreeCam] FreeCam Disabled.")
        
        -- Teardown sub-managers
        player_m.Teardown(activePlayer, activePC)
        camera_m.Teardown(activePlayer, activePC)
        builder_m.Teardown(activePlayer)
        
        activePC = nil
        activePlayer = nil
        hasLastSetAimLoc = false
    end
end

-- Orchestrate frame movement update (Zero-Query Render Tick compliant)
function camera.UpdateCameraMovement()
    -- Gamepad shortcut handler (Only queried if gamepad is active input mode)
    local inputMode = config.CONFIG.InputMode or "Keyboard"
    if inputMode == "Gamepad" then
        local pc = activePC or GetPCCached()
        if pc and pc:IsValid() and input.IsToggleShortcutPressed(pc) then
            print("[FreeCam] Gamepad toggle shortcut detected!")
            camera.ToggleFreeCam()
        end
    end
    
    if not isSpectating or not activePC or not activePC:IsValid() or not activePlayer or not activePlayer:IsValid() then return end
    
    local camComp = camera_m.GetCameraComponent()
    if not camComp or not camComp:IsValid() then return end
    
    -- Sync camera rotation with ControlRotation
    local controlRot = activePC:GetControlRotation()
    currentCameraRotation.Pitch = controlRot.Pitch
    currentCameraRotation.Yaw = controlRot.Yaw
    currentCameraRotation.Roll = controlRot.Roll
    
    -- Get camera direction vectors
    local ueForward = camComp:GetForwardVector()
    local ueRight = camComp:GetRightVector()
    local ueUp = camComp:GetUpVector()
    
    local fX, fY, fZ = ueForward.X, ueForward.Y, ueForward.Z
    if type(fX) == "userdata" and fX.get then fX = fX:get() fY = fY:get() fZ = fZ:get() end
    forwardVec.X, forwardVec.Y, forwardVec.Z = fX, fY, fZ
    
    local rX, rY, rZ = ueRight.X, ueRight.Y, ueRight.Z
    if type(rX) == "userdata" and rX.get then rX = rX:get() rY = rY:get() rZ = rZ:get() end
    rightVec.X, rightVec.Y, rightVec.Z = rX, rY, rZ
    
    local uX, uY, uZ = ueUp.X, ueUp.Y, ueUp.Z
    if type(uX) == "userdata" and uX.get then uX = uX:get() uY = uY:get() uZ = uZ:get() end
    upVec.X, upVec.Y, upVec.Z = uX, uY, uZ
    
    -- Poll flight inputs
    input.PollMovement(activePC, moveDir, forwardVec, rightVec, upVec)
    
    -- Apply speed
    local length = math.sqrt(moveDir.X^2 + moveDir.Y^2 + moveDir.Z^2)
    if length > 0.001 then
        currentCameraLocation.X = currentCameraLocation.X + (moveDir.X / length) * currentSpeed
        currentCameraLocation.Y = currentCameraLocation.Y + (moveDir.Y / length) * currentSpeed
        currentCameraLocation.Z = currentCameraLocation.Z + (moveDir.Z / length) * currentSpeed
    end
    
    -- Limit camera's 2D horizontal movement to 1.5x the base camp radius from its starting point
    local origLoc = player_m.GetOriginalPlayerLocation()
    if origLoc then
        local dx = currentCameraLocation.X - origLoc.X
        local dy = currentCameraLocation.Y - origLoc.Y
        local dist2D = math.sqrt(dx * dx + dy * dy)
        if dist2D > limitRadius then
            local ratio = limitRadius / dist2D
            currentCameraLocation.X = origLoc.X + dx * ratio
            currentCameraLocation.Y = origLoc.Y + dy * ratio
        end
    end
    
    -- Update camera coordinates
    camera_m.Update(currentCameraLocation, currentCameraRotation)
    
    -- Calculate reticle aim intersection location
    local aimDist, hitActor = helpers.GetAimDistanceAndLocation(activePlayer, camComp, currentCameraLocation, aimLocCache)
    
    -- Update building/dismantling snap ranges and visual outlines
    builder_m.Update(activePlayer, activePC, currentCameraRotation, aimLocCache, aimDist, hitActor)
    
    -- Teleport and re-hide player actor
    player_m.UpdateLocation(activePlayer, aimLocCache)
    
    -- Save telemetry
    lastSetAimLoc.X = aimLocCache.X
    lastSetAimLoc.Y = aimLocCache.Y
    lastSetAimLoc.Z = aimLocCache.Z
    hasLastSetAimLoc = true
end

return camera
