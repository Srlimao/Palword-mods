local UEHelpers = require("UEHelpers")
local helpers = require("FreeCam.helpers")

local camera = {}

local isSpectating = false
local cameraComponent = nil
local originalParent = nil
local originalSocket = FName("None")
local originalRelativeLocation = {X = 0.0, Y = 0.0, Z = 0.0}
local originalRelativeRotation = {Pitch = 0.0, Yaw = 0.0, Roll = 0.0}

local originalMoveMode = 1
local originalCustomMode = 0
local originalRotationYaw = true
local originalPlayerLocation = nil
local originalInstallDistance = 400.0
local originalPitchMin = -60.0
local originalPitchMax = 60.0
local currentSpeed = 15.0 -- default camera speed

local currentCameraLocation = {X = 0.0, Y = 0.0, Z = 0.0}
local currentCameraRotation = {Pitch = 0.0, Yaw = 0.0, Roll = 0.0}

-- Cache active PlayerController and Character to avoid query lag every frame
local activePC = nil
local activePlayer = nil

-- State tracking to print logs only on change
local wasPreviewValid = false

-- Pre-allocate FNames to prevent massive string table/allocation lag every frame
local KeyW = FName("W")
local KeyS = FName("S")
local KeyA = FName("A")
local KeyD = FName("D")
local KeySpace = FName("SpaceBar")
local KeyLShift = FName("LeftShift") -- Changed to LeftShift to prevent conflicts with LCtrl/C

function camera.IsSpectating()
    return isSpectating
end

function camera.AdjustSpeed(amount)
    if not isSpectating then return end
    currentSpeed = currentSpeed + amount
    if currentSpeed > 150.0 then currentSpeed = 150.0 end
    if currentSpeed < 2.0 then currentSpeed = 2.0 end
end

-- Toggle Free Camera Mode
function camera.ToggleFreeCam()
    local pc = UEHelpers:GetPlayerController()
    if not pc or not pc:IsValid() then return end
    
    local localPlayer = UEHelpers.GetPlayer()
    if not localPlayer or not localPlayer:IsValid() then return end
    
    local builder = localPlayer.BuilderComponent
    if not builder or not builder:IsValid() then
        return
    end
    
    isSpectating = not isSpectating
    
    if isSpectating then
        -- Enforce base camp restriction for activation
        if not helpers.IsPlayerInBaseCamp(localPlayer) then
            print("[FreeCam] FreeCam can only be enabled inside a Base Camp.")
            isSpectating = false
            return
        end
        
        print("[FreeCam] FreeCam Enabled.")
        
        -- Get the active camera component the builder is using
        cameraComponent = builder.OwnerCamera
        if not cameraComponent or not cameraComponent:IsValid() then
            print("[FreeCam] Error: Active OwnerCamera component not found.")
            isSpectating = false
            return
        end
        
        -- Cache active PlayerController and Player Character for the update tick
        activePC = pc
        activePlayer = localPlayer
        
        -- Cache original player character location before flying
        local playerLoc = localPlayer:K2_GetActorLocation()
        originalPlayerLocation = {X = playerLoc.X, Y = playerLoc.Y, Z = playerLoc.Z}
        
        -- Cache and set camera pitch limits to allow looking straight down (90 degrees down)
        local cameraManager = pc.PlayerCameraManager
        if cameraManager and cameraManager:IsValid() then
            originalPitchMin = cameraManager.ViewPitchMin
            originalPitchMax = cameraManager.ViewPitchMax
            pcall(function() if type(originalPitchMin) == "userdata" then originalPitchMin = originalPitchMin:get() end end)
            pcall(function() if type(originalPitchMax) == "userdata" then originalPitchMax = originalPitchMax:get() end end)
            
            cameraManager.ViewPitchMin = -89.0
            cameraManager.ViewPitchMax = 89.0
        end
        
        -- Disable collision on the player character so it doesn't block the building line traces
        localPlayer:SetActorEnableCollision(false)
        
        -- Cache original attach information and relative transform of the camera
        originalParent = cameraComponent:GetAttachParent()
        originalSocket = cameraComponent:GetAttachSocketName()
        
        local relLoc = cameraComponent.RelativeLocation
        originalRelativeLocation = {X = relLoc.X, Y = relLoc.Y, Z = relLoc.Z}
        
        local relRot = cameraComponent.RelativeRotation
        originalRelativeRotation = {Pitch = relRot.Pitch, Yaw = relRot.Yaw, Roll = relRot.Roll} -- Fixed typo where Yaw was assigned relRot.Roll
        
        -- Cache current world transform before detaching
        local worldLoc = cameraComponent:K2_GetComponentLocation()
        currentCameraLocation = {X = worldLoc.X, Y = worldLoc.Y, Z = worldLoc.Z}
        
        local worldRot = cameraComponent:K2_GetComponentRotation()
        currentCameraRotation = {Pitch = worldRot.Pitch, Yaw = worldRot.Yaw, Roll = worldRot.Roll}
        
        -- Detach camera component (EDetachmentRule::KeepWorld = 1 for location/rotation/scale)
        cameraComponent:K2_DetachFromComponent(1, 1, 1, false)
        
        -- Ignore movement inputs on player character
        pc:SetIgnoreMoveInput(true)
        
        -- Cache player movement component and state
        local movement = localPlayer.CharacterMovement
        if movement and movement:IsValid() then
            originalMoveMode = movement.MovementMode
            pcall(function() if type(originalMoveMode) == "userdata" then originalMoveMode = originalMoveMode:get() end end)
            
            originalCustomMode = movement.CustomMovementMode
            pcall(function() if type(originalCustomMode) == "userdata" then originalCustomMode = originalCustomMode:get() end end)
            
            -- Disable character movement physics (prevents falling and collision issues)
            movement:SetMovementMode(0, 0) -- MOVE_None
        end
        
        -- Cache and disable character rotation matching mouse yaw
        originalRotationYaw = localPlayer.bUseControllerRotationYaw
        pcall(function() if type(originalRotationYaw) == "userdata" then originalRotationYaw = originalRotationYaw:get() end end)
        localPlayer.bUseControllerRotationYaw = false
        
        -- Cache original installation distance
        originalInstallDistance = builder.InstallDistanceNormalFromOwner
        pcall(function() if type(originalInstallDistance) == "userdata" then originalInstallDistance = originalInstallDistance:get() end end)
        
        -- Hide the player character model and attached items
        localPlayer:SetActorHiddenInGame(true)
    else
        print("[FreeCam] FreeCam Disabled.")
        
        -- Re-enable movement input
        pc:SetIgnoreMoveInput(false)
        
        -- Restore player character movement mode
        local movement = localPlayer.CharacterMovement
        if movement and movement:IsValid() then
            movement:SetMovementMode(originalMoveMode, originalCustomMode)
        end
        
        -- Restore rotation flag
        localPlayer.bUseControllerRotationYaw = originalRotationYaw
        
        -- Restore player character location to its original position before flying
        if originalPlayerLocation then
            localPlayer:K2_SetActorLocation(originalPlayerLocation, false, {}, true)
        end
        
        -- Re-enable player character collision
        localPlayer:SetActorEnableCollision(true)
        
        -- Restore original camera pitch limits
        local cameraManager = pc.PlayerCameraManager
        if cameraManager and cameraManager:IsValid() then
            if originalPitchMin then cameraManager.ViewPitchMin = originalPitchMin end
            if originalPitchMax then cameraManager.ViewPitchMax = originalPitchMax end
        end
        
        -- Restore original installation distance
        local builder = localPlayer.BuilderComponent
        if builder and builder:IsValid() and originalInstallDistance then
            builder.InstallDistanceNormalFromOwner = originalInstallDistance
        end
        
        -- Show the player character model again
        localPlayer:SetActorHiddenInGame(false)
        
        -- Re-attach camera component to its original parent (EAttachmentRule::KeepRelative = 0)
        if cameraComponent and cameraComponent:IsValid() and originalParent and originalParent:IsValid() then
            cameraComponent:K2_AttachToComponent(originalParent, originalSocket, 0, 0, 0, false)
            cameraComponent:K2_SetRelativeLocationAndRotation(originalRelativeLocation, originalRelativeRotation, false, {}, false)
        end
        
        cameraComponent = nil
        originalParent = nil
        originalPlayerLocation = nil
        activePC = nil
        activePlayer = nil
    end
end

local cachedPlayer = nil
local function GetPlayerCached()
    if not cachedPlayer or not cachedPlayer:IsValid() then
        cachedPlayer = UEHelpers.GetPlayer()
    end
    return cachedPlayer
end

local function CheckPreviewActive(localPlayer)
    if not localPlayer or not localPlayer:IsValid() then return false end
    local builder = localPlayer.BuilderComponent
    if not builder or not builder:IsValid() then return false end
    local checker = builder.InstallChecker
    if not checker or not checker:IsValid() then return false end
    local preview = checker.TargetBuildObject
    return preview and preview:IsValid()
end

local function CheckIsSnapMode(builder)
    return builder:IsSnapMode()
end

-- Update camera movement every frame (Zero-Query Render Tick compliant)
function camera.UpdateCameraMovement()
    -- Check if player has a building blueprint active dynamically
    local localPlayer = GetPlayerCached()
    local success, hasPreview = pcall(CheckPreviewActive, localPlayer)
    hasPreview = success and hasPreview
    
    -- Print state changes to console for debug logs
    if hasPreview ~= wasPreviewValid then
        wasPreviewValid = hasPreview
        print(string.format("[FreeCam] Construction Preview State Changed: hasPreview=%s, isSpectating=%s", tostring(hasPreview), tostring(isSpectating)))
    end
    
    -- Auto-toggle logic
    if hasPreview and not isSpectating then
        if helpers.IsPlayerInBaseCamp(localPlayer) then
            print("[FreeCam] Auto-triggering FreeCam (Structure selected inside Base Camp)")
            camera.ToggleFreeCam()
        end
    elseif not hasPreview and isSpectating then
        print("[FreeCam] Auto-disabling FreeCam (No structure selected)")
        camera.ToggleFreeCam()
    end
    
    -- If not currently spectating, do not run flight updates
    if not isSpectating or not cameraComponent or not cameraComponent:IsValid() or not activePC or not activePC:IsValid() or not activePlayer or not activePlayer:IsValid() then return end
    
    -- Sync camera rotation with the current mouse look (ControlRotation)
    local controlRot = activePC:GetControlRotation()
    currentCameraRotation = {Pitch = controlRot.Pitch, Yaw = controlRot.Yaw, Roll = controlRot.Roll}
    
    -- Get direction vectors from the camera component itself
    local forward = cameraComponent:GetForwardVector()
    local right = cameraComponent:GetRightVector()
    local up = cameraComponent:GetUpVector()
    
    -- Calculate movement direction
    local moveDir = {X = 0.0, Y = 0.0, Z = 0.0}
    
    if activePC:IsInputKeyDown({ KeyName = KeyW }) then
        moveDir.X = moveDir.X + forward.X
        moveDir.Y = moveDir.Y + forward.Y
        moveDir.Z = moveDir.Z + forward.Z
    end
    if activePC:IsInputKeyDown({ KeyName = KeyS }) then
        moveDir.X = moveDir.X - forward.X
        moveDir.Y = moveDir.Y - forward.Y
        moveDir.Z = moveDir.Z - forward.Z
    end
    if activePC:IsInputKeyDown({ KeyName = KeyD }) then
        moveDir.X = moveDir.X + right.X
        moveDir.Y = moveDir.Y + right.Y
        moveDir.Z = moveDir.Z + right.Z
    end
    if activePC:IsInputKeyDown({ KeyName = KeyA }) then
        moveDir.X = moveDir.X - right.X
        moveDir.Y = moveDir.Y - right.Y
        moveDir.Z = moveDir.Z - right.Z
    end
    if activePC:IsInputKeyDown({ KeyName = KeySpace }) then
        moveDir.X = moveDir.X + up.X
        moveDir.Y = moveDir.Y + up.Y
        moveDir.Z = moveDir.Z + up.Z
    end
    if activePC:IsInputKeyDown({ KeyName = KeyLShift }) then
        moveDir.X = moveDir.X - up.X
        moveDir.Y = moveDir.Y - up.Y
        moveDir.Z = moveDir.Z - up.Z
    end
    
    -- Normalize and apply speed
    local length = math.sqrt(moveDir.X^2 + moveDir.Y^2 + moveDir.Z^2)
    if length > 0.001 then
        currentCameraLocation = {
            X = currentCameraLocation.X + (moveDir.X / length) * currentSpeed,
            Y = currentCameraLocation.Y + (moveDir.Y / length) * currentSpeed,
            Z = currentCameraLocation.Z + (moveDir.Z / length) * currentSpeed
        }
    end
    
    -- Apply the world position and rotation to the detached camera component
    cameraComponent:K2_SetWorldLocationAndRotation(currentCameraLocation, currentCameraRotation, false, {}, false)
    
    -- Dynamically query terrain range and location in look direction
    local aimDist, aimLoc = helpers.GetAimDistanceAndLocation(activePlayer, cameraComponent, currentCameraLocation)
    
    -- Set the builder installation distance dynamically.
    local builder = activePlayer.BuilderComponent
    if builder and builder:IsValid() then
        local isSnap = false
        local successSnap, resSnap = pcall(CheckIsSnapMode, builder)
        if successSnap and resSnap then
            isSnap = true
        end
        
        if isSnap then
            builder.InstallDistanceNormalFromOwner = originalInstallDistance * 15.0
        else
            builder.InstallDistanceNormalFromOwner = 0.0
        end
    end
    
    -- Teleport the hidden player character to the exact aim hit location on the ground/surface.
    activePlayer:K2_SetActorLocation(aimLoc, false, {}, true)
end

return camera
