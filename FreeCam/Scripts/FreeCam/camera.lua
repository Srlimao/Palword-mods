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

local lastSetAimLoc = nil
local lastLogTime = 0.0

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
    local pc = UEHelpers.GetPlayerController()
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
        -- Also hide attached actors (weapons, gliders, backpack)
        pcall(function()
            local outActors = {}
            local attachedActors = localPlayer:GetAttachedActors(outActors, true, true)
            
            -- UE4SS sometimes returns the array, sometimes populates the passed table
            local toHide = attachedActors
            if type(toHide) ~= "table" and type(toHide) ~= "userdata" then
                toHide = outActors
            end
            
            if toHide then
                for i = 1, #toHide do
                    local attached = toHide[i]
                    if attached and attached:IsValid() then
                        print("[FreeCam Debug] Attached Actor: " .. attached:GetFullName())
                        attached:SetActorHiddenInGame(true)
                    end
                end
            end
            
            -- Debug log components
            local comps = localPlayer:K2_GetComponentsByClass(StaticFindObject("/Script/Engine.SceneComponent"))
            if comps then
                for i = 1, #comps do
                    local c = comps[i]
                    if c and c:IsValid() then
                        local cName = c:GetFullName()
                        if string.find(cName, "Light") or string.find(cName, "Particle") or string.find(cName, "Niagara") then
                            print("[FreeCam Debug] Found visual component: " .. cName)
                            c:SetVisibility(false, true)
                        end
                    end
                end
            end
            
            -- Also explicitly hide the weapon if accessible
            local shooter = localPlayer.ShooterComponent
            if shooter and shooter:IsValid() then
                local weapon = shooter:GetHasWeapon()
                if weapon and weapon:IsValid() then
                    weapon:SetActorHiddenInGame(true)
                end
            end
        end)
        
        -- Use RelativeScale3D to make the mesh microscopic and effectively invisible
        pcall(function()
            if localPlayer.Mesh and localPlayer.Mesh:IsValid() then
                localPlayer.Mesh:SetRelativeScale3D({X = 0.001, Y = 0.001, Z = 0.001})
            end
        end)
    else
        print("[FreeCam] FreeCam Disabled.")
        
        -- Re-enable movement input
        pc:SetIgnoreMoveInput(false)
        
        -- Restore rotation flag
        localPlayer.bUseControllerRotationYaw = originalRotationYaw
        
        -- 1. Re-enable player character collision FIRST
        localPlayer:SetActorEnableCollision(true)
        
        -- 2. Restore player character location to its original position, offset slightly upwards
        -- to prevent clipping into newly constructed foundations or structures
        if originalPlayerLocation then
            local safeLoc = {
                X = originalPlayerLocation.X,
                Y = originalPlayerLocation.Y,
                Z = originalPlayerLocation.Z + 120.0
            }
            localPlayer:K2_SetActorLocation(safeLoc, false, {}, true)
        end
        
        -- 3. Restore player character movement mode after being safely placed and collision active
        local movement = localPlayer.CharacterMovement
        if movement and movement:IsValid() then
            movement:SetMovementMode(originalMoveMode, originalCustomMode)
        end
        
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
        pcall(function()
            local outActors = {}
            local attachedActors = localPlayer:GetAttachedActors(outActors, true, true)
            
            local toUnhide = attachedActors
            if type(toUnhide) ~= "table" and type(toUnhide) ~= "userdata" then
                toUnhide = outActors
            end
            
            if toUnhide then
                for i = 1, #toUnhide do
                    local attached = toHide[i] or toUnhide[i]
                    if attached and attached:IsValid() then
                        attached:SetActorHiddenInGame(false)
                    end
                end
            end
            
            -- Also explicitly unhide the weapon if accessible
            local shooter = localPlayer.ShooterComponent
            if shooter and shooter:IsValid() then
                local weapon = shooter:GetHasWeapon()
                if weapon and weapon:IsValid() then
                    weapon:SetActorHiddenInGame(false)
                end
            end
        end)
        
        pcall(function()
            if localPlayer.Mesh and localPlayer.Mesh:IsValid() then
                localPlayer.Mesh:SetRelativeScale3D({X = 1.0, Y = 1.0, Z = 1.0})
            end
        end)
        
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
    local ueForward = cameraComponent:GetForwardVector()
    local ueRight = cameraComponent:GetRightVector()
    local ueUp = cameraComponent:GetUpVector()
    
    local fX, fY, fZ = ueForward.X, ueForward.Y, ueForward.Z
    if type(fX) == "userdata" and fX.get then fX = fX:get() fY = fY:get() fZ = fZ:get() end
    local forward = { X = fX, Y = fY, Z = fZ }
    
    local rX, rY, rZ = ueRight.X, ueRight.Y, ueRight.Z
    if type(rX) == "userdata" and rX.get then rX = rX:get() rY = rY:get() rZ = rZ:get() end
    local right = { X = rX, Y = rY, Z = rZ }
    
    local uX, uY, uZ = ueUp.X, ueUp.Y, ueUp.Z
    if type(uX) == "userdata" and uX.get then uX = uX:get() uY = uY:get() uZ = uZ:get() end
    local up = { X = uX, Y = uY, Z = uZ }
    
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
    
    -- Diagnostic: Check if player position was reset since last frame
    local timeNow = os.clock()
    if lastSetAimLoc and activePlayer and activePlayer:IsValid() then
        local currentLoc = activePlayer:K2_GetActorLocation()
        local curX, curY, curZ = currentLoc.X, currentLoc.Y, currentLoc.Z
        if type(curX) == "userdata" and curX.get then curX = curX:get() curY = curY:get() curZ = curZ:get() end
        local distDiff = math.sqrt((curX - lastSetAimLoc.X)^2 + (curY - lastSetAimLoc.Y)^2 + (curZ - lastSetAimLoc.Z)^2)
        if distDiff > 1.0 and (timeNow - lastLogTime) > 1.0 then
            lastLogTime = timeNow
            print(string.format("[FreeCam Debug] Pos mismatch! Diff = %.2f. Expected: (%.1f, %.1f, %.1f), Got: (%.1f, %.1f, %.1f)", distDiff, lastSetAimLoc.X, lastSetAimLoc.Y, lastSetAimLoc.Z, curX, curY, curZ))
        end
    end

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
            
            -- When snap mode is off, adjust character Z position to align the blueprint's 3D center with the reticle
            pcall(function()
                local checker = builder.InstallChecker
                if checker and checker:IsValid() then
                    local preview = checker.TargetBuildObject
                    if preview and preview:IsValid() then
                        local bounds = preview.LocalBounds
                        if bounds then
                            local xMin = bounds.Min.X
                            local xMax = bounds.Max.X
                            local yMin = bounds.Min.Y
                            local yMax = bounds.Max.Y
                            local zMin = bounds.Min.Z
                            local zMax = bounds.Max.Z
                            if type(xMin) == "userdata" and xMin.get then xMin = xMin:get() end
                            if type(xMax) == "userdata" and xMax.get then xMax = xMax:get() end
                            if type(yMin) == "userdata" and yMin.get then yMin = yMin:get() end
                            if type(yMax) == "userdata" and yMax.get then yMax = yMax:get() end
                            if type(zMin) == "userdata" and zMin.get then zMin = zMin:get() end
                            if type(zMax) == "userdata" and zMax.get then zMax = zMax:get() end
                            
                            local xCenter = (xMin + xMax) / 2.0
                            local yCenter = (yMin + yMax) / 2.0
                            local zCenter = (zMin + zMax) / 2.0
                            
                            local forward = preview:GetActorForwardVector()
                            local right = preview:GetActorRightVector()
                            local up = preview:GetActorUpVector()
                            
                            local fX, fY, fZ = forward.X, forward.Y, forward.Z
                            local rX, rY, rZ = right.X, right.Y, right.Z
                            local uX, uY, uZ = up.X, up.Y, up.Z
                            
                            if type(fX) == "userdata" and fX.get then fX = fX:get() fY = fY:get() fZ = fZ:get() end
                            if type(rX) == "userdata" and rX.get then rX = rX:get() rY = rY:get() rZ = rZ:get() end
                            if type(uX) == "userdata" and uX.get then uX = uX:get() uY = uY:get() uZ = uZ:get() end
                            
                            local worldOffsetX = fX * xCenter + rX * yCenter + uX * zCenter
                            local worldOffsetY = fY * xCenter + rY * yCenter + uY * zCenter
                            local worldOffsetZ = fZ * xCenter + rZ * yCenter + uZ * zCenter
                            
                            -- Dynamically measure the game's building system forward/pivot offset
                            -- Temporarily disabled to debug the sliding feedback loop
                            local relX, relY, relZ = 0.0, 0.0, 0.0
                            --[[
                            local previewLoc = preview:K2_GetActorLocation()
                            local playerLoc = activePlayer:K2_GetActorLocation()
                            if previewLoc and playerLoc then
                                local pX, pY, pZ = previewLoc.X, previewLoc.Y, previewLoc.Z
                                local cX, cY, cZ = playerLoc.X, playerLoc.Y, playerLoc.Z
                                
                                if type(pX) == "userdata" and pX.get then pX = pX:get() pY = pY:get() pZ = pZ:get() end
                                if type(cX) == "userdata" and cX.get then cX = cX:get() cY = cY:get() cZ = cZ:get() end
                                
                                relX = pX - cX
                                relY = pY - cY
                                relZ = pZ - cZ
                                
                                local dist = math.sqrt(relX^2 + relY^2 + relZ^2)
                                if dist > 1500.0 then
                                    relX = 0.0
                                    relY = 0.0
                                    relZ = 0.0
                                end
                            end
                            ]]
                            
                            aimLoc.X = aimLoc.X - worldOffsetX - relX
                            aimLoc.Y = aimLoc.Y - worldOffsetY - relY
                            aimLoc.Z = aimLoc.Z - worldOffsetZ - relZ
                        end
                    end
                end
            end)
        end
    end
    
    -- Save the location we are about to set for diagnostics
    lastSetAimLoc = {X = aimLoc.X, Y = aimLoc.Y, Z = aimLoc.Z}

    -- Teleport the hidden player character to the exact aim hit location on the ground/surface.
    activePlayer:K2_SetActorLocation(aimLoc, false, {}, true)
    
    -- Enforce hiding every frame to fight the building hologram override
    pcall(function()
        activePlayer:SetActorHiddenInGame(true)
        if activePlayer.Mesh and activePlayer.Mesh:IsValid() then
            activePlayer.Mesh:SetHiddenInGame(true)
        end
        local shooter = activePlayer.ShooterComponent
        if shooter and shooter:IsValid() then
            local weapon = shooter:GetHasWeapon()
            if weapon and weapon:IsValid() then
                weapon:SetActorHiddenInGame(true)
            end
        end
    end)
end

return camera
