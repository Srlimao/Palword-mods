local helpers = require("FreeCam.helpers")
local config = require("FreeCam.config")

local player_manager = {}

local originalMoveMode = 1
local originalCustomMode = 0
local originalRotationYaw = true
local originalPlayerLocation = nil
local FreeCamFlag = FName("FreeCam")

-- Caches original states and disables player movement inputs and visibility
function player_manager.Setup(player, pc)
    if not player or not player:IsValid() or not pc or not pc:IsValid() then return false end
    
    -- Capture original player location before flying
    local status, err = pcall(function()
        local loc = player:K2_GetActorLocation()
        local lX, lY, lZ = loc.X, loc.Y, loc.Z
        if type(lX) == "userdata" and lX.get then lX = lX:get() lY = lY:get() lZ = lZ:get() end
        originalPlayerLocation = {X = lX, Y = lY, Z = lZ}
        config.DebugPrint(string.format("Captured original player location: (%.1f, %.1f, %.1f)", lX, lY, lZ))
    end)
    if not status then
        print("[FreeCam Error] Failed to capture original player location: " .. tostring(err))
    end
    
    -- Disable player character collision during flight so it doesn't block building previews
    player:SetActorEnableCollision(false)
    
    -- Suppression flags on player character input
    pc:SetIgnoreMoveInput(true)
    pcall(function() player:DisableInput(pc) end)
    pcall(function() player:SetDisablePlayerInput(FreeCamFlag, true) end)
    
    -- Freeze character movement physics (prevents falling and collision triggers)
    local movement = player.CharacterMovement
    if movement and movement:IsValid() then
        pcall(function() movement:SetInputDisableFlag(FreeCamFlag, true) end)
        originalMoveMode = movement.MovementMode
        pcall(function()
            if originalMoveMode and originalMoveMode.get then
                originalMoveMode = originalMoveMode:get()
            end
        end)
        
        originalCustomMode = movement.CustomMovementMode
        pcall(function()
            if originalCustomMode and originalCustomMode.get then
                originalCustomMode = originalCustomMode:get()
            end
        end)
        
        movement:SetMovementMode(0, 0) -- MOVE_None
    end
    
    -- Cache and disable character rotation matching mouse look Yaw
    originalRotationYaw = player.bUseControllerRotationYaw
    pcall(function()
        if originalRotationYaw and originalRotationYaw.get then
            originalRotationYaw = originalRotationYaw:get()
        end
    end)
    player.bUseControllerRotationYaw = false
    
    -- Make player skeletal mesh microscopic (hides character model and attached weapon/glider/accessory meshes cleanly)
    if player.Mesh and player.Mesh:IsValid() then
        pcall(function() player.Mesh:SetRelativeScale3D({X = 0.001, Y = 0.001, Z = 0.001}) end)
    end
    
    return true
end

-- Restores original inputs, movement modes, and character visibility
function player_manager.Teardown(player, pc)
    if not player or not player:IsValid() then return end
    
    -- Re-enable controller input
    if pc and pc:IsValid() then
        pc:SetIgnoreMoveInput(false)
        pcall(function() player:EnableInput(pc) end)
    end
    
    -- Restore suppression flags and rotation yaw safely
    pcall(function() player:SetDisablePlayerInput(FreeCamFlag, false) end)
    player.bUseControllerRotationYaw = originalRotationYaw
    
    
    -- Re-enable player character collision FIRST
    player:SetActorEnableCollision(true)
    
    -- Restore player character location to its original position before flying
    config.DebugPrint(string.format("Teardown: originalPlayerLocation exists = %s", tostring(originalPlayerLocation ~= nil)))
    if originalPlayerLocation then
        local safeLoc = {
            X = originalPlayerLocation.X,
            Y = originalPlayerLocation.Y,
            Z = originalPlayerLocation.Z + 120.0
        }
        config.DebugPrint(string.format("Teleporting player to: (%.1f, %.1f, %.1f)", safeLoc.X, safeLoc.Y, safeLoc.Z))
        local success = player:K2_SetActorLocation(safeLoc, false, {}, true)
        config.DebugPrint(string.format("Teleport success = %s", tostring(success)))
    end
    originalPlayerLocation = nil
    
    -- Restore character movement mode
    local movement = player.CharacterMovement
    if movement and movement:IsValid() then
        pcall(function() movement:SetInputDisableFlag(FreeCamFlag, false) end)
        if originalMoveMode then
            movement:SetMovementMode(originalMoveMode, originalCustomMode or 0)
        end
    end
    
    -- Restore player skeletal mesh scale to normal (automatically restores weapons/glider/accessories visibility)
    if player.Mesh and player.Mesh:IsValid() then
        pcall(function() player.Mesh:SetRelativeScale3D({X = 1.0, Y = 1.0, Z = 1.0}) end)
    end
end

-- Keeps/maintains player character stationary at original starting location during flight,
-- only rotating their Yaw horizontally to face the aim location.
function player_manager.UpdateLocation(player, aimLoc)
    if not player or not player:IsValid() or not originalPlayerLocation then return end
    
    local currentLoc = player:K2_GetActorLocation()
    local curX, curY, curZ = currentLoc.X, currentLoc.Y, currentLoc.Z
    if type(curX) == "userdata" and curX.get then curX = curX:get() curY = curY:get() curZ = curZ:get() end
    
    local dx = originalPlayerLocation.X - curX
    local dy = originalPlayerLocation.Y - curY
    local dz = originalPlayerLocation.Z - curZ
    local distSq = dx*dx + dy*dy + dz*dz
    
    -- Calculate look-at Yaw rotation from character to aimLoc, or use TargetSnapYaw if snap-building
    local targetRot = player:K2_GetActorRotation()
    local builder_m = require("FreeCam.builder_manager")
    if builder_m and builder_m.TargetSnapYaw then
        targetRot = {Pitch = 0.0, Yaw = builder_m.TargetSnapYaw, Roll = 0.0}
    elseif aimLoc then
        local deltaX = aimLoc.X - originalPlayerLocation.X
        local deltaY = aimLoc.Y - originalPlayerLocation.Y
        if type(deltaX) == "userdata" and deltaX.get then deltaX = deltaX:get() end
        if type(deltaY) == "userdata" and deltaY.get then deltaY = deltaY:get() end
        local yaw = math.deg(math.atan(deltaY, deltaX))
        targetRot = {Pitch = 0.0, Yaw = yaw, Roll = 0.0}
    end
    
    -- Teleport back to original starting coordinates only if player drifts/falls
    if distSq > 4.0 then
        player:K2_TeleportTo(originalPlayerLocation, targetRot)
    else
        player:K2_SetActorRotation(targetRot, false)
    end
    
    -- Re-enforce microscopic scale to prevent any engine resets
    if player.Mesh and player.Mesh:IsValid() then
        pcall(function() player.Mesh:SetRelativeScale3D({X = 0.001, Y = 0.001, Z = 0.001}) end)
    end
end

-- Retrieve captured starting coordinates
function player_manager.GetOriginalPlayerLocation()
    return originalPlayerLocation
end

return player_manager

