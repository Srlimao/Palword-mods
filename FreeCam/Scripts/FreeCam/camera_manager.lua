-- FreeCam Camera Manager component
local camera_manager = {}

local cameraComponent = nil
local originalParent = nil
local originalSocket = FName("None")
local originalRelativeLocation = {X = 0.0, Y = 0.0, Z = 0.0}
local originalRelativeRotation = {Pitch = 0.0, Yaw = 0.0, Roll = 0.0}

function camera_manager.GetCameraComponent()
    return cameraComponent
end

-- Detach camera from character mesh and store original values
function camera_manager.Setup(player, pc)
    if not player or not player:IsValid() then return false end
    
    -- Find and detach CameraComponent
    cameraComponent = player:GetComponentByClass(StaticFindObject("/Script/Engine.CameraComponent"))
    if not cameraComponent or not cameraComponent:IsValid() then
        print("[FreeCam Error] CameraComponent not found on local player!")
        return false
    end
    
    originalParent = cameraComponent:GetAttachParent()
    originalSocket = cameraComponent:GetAttachSocketName()
    
    local relLoc = cameraComponent.RelativeLocation
    local relRot = cameraComponent.RelativeRotation
    local rX, rY, rZ = relLoc.X, relLoc.Y, relLoc.Z
    local rP, rYaw, rRoll = relRot.Pitch, relRot.Yaw, relRot.Roll
    
    if type(rX) == "userdata" and rX.get then rX = rX:get() rY = rY:get() rZ = rZ:get() end
    if type(rP) == "userdata" and rP.get then rP = rP:get() rYaw = rYaw:get() rRoll = rRoll:get() end
    
    originalRelativeLocation = {X = rX, Y = rY, Z = rZ}
    originalRelativeRotation = {Pitch = rP, Yaw = rYaw, Roll = rRoll}
    
    -- Detach camera component (EDetachmentRule::KeepWorld = 1 for location/rotation/scale)
    cameraComponent:K2_DetachFromComponent(1, 1, 1, false)
    return true
end

local config = require("FreeCam.config")

-- Re-attach camera component to its original parent (EAttachmentRule::KeepRelative = 0) and restore transform
function camera_manager.Teardown(player, pc)
    config.DebugPrint(string.format("Camera Teardown: cameraComponent exists = %s, originalParent exists = %s", 
        tostring(cameraComponent ~= nil), tostring(originalParent ~= nil)))
    if cameraComponent and cameraComponent:IsValid() and originalParent and originalParent:IsValid() then
        local targetSocket = originalSocket or FName("None")
        local status, err = pcall(function()
            cameraComponent:K2_AttachToComponent(originalParent, targetSocket, 0, 0, 0, false)
            if originalRelativeLocation then
                cameraComponent:K2_SetRelativeLocationAndRotation(originalRelativeLocation, originalRelativeRotation, false, {}, false)
            end
        end)
        config.DebugPrint(string.format("Camera re-attach status: %s, error: %s", tostring(status), tostring(err)))
    end
    
    cameraComponent = nil
    originalParent = nil
end

-- Update camera world position and rotation
function camera_manager.Update(currentCameraLocation, currentCameraRotation)
    if not cameraComponent or not cameraComponent:IsValid() then return end
    cameraComponent:K2_SetWorldLocationAndRotation(currentCameraLocation, currentCameraRotation, false, {}, false)
end

return camera_manager
