-- FreeCam Builder Manager component
local builder_manager = {}

local originalInstallDistance = 400.0
local lastBuilderMode = -1
local lastDismantleTarget = nil
local lastLogTime = 0.0

local function SafeCheckIsSnapMode(builder)
    return builder:IsSnapMode()
end

local function SafeSetDismantleVisual(actor, state)
    if actor and actor:IsValid() and actor.OnChangeVisualForDismantle then
        actor:OnChangeVisualForDismantle(state)
    end
end

function builder_manager.GetReticleTargetObject()
    return lastDismantleTarget
end

-- Cache original installation distance
function builder_manager.Setup(player)
    if not player or not player:IsValid() then return false end
    
    local builder = player.BuilderComponent
    if not builder or not builder:IsValid() then return false end
    
    originalInstallDistance = builder.InstallDistanceNormalFromOwner
    pcall(function() if type(originalInstallDistance) == "userdata" then originalInstallDistance = originalInstallDistance:get() end end)
    
    lastBuilderMode = -1
    lastDismantleTarget = nil
    lastLogTime = 0.0
    return true
end

-- Restore builder distance and clear outlines
function builder_manager.Teardown(player)
    if not player or not player:IsValid() then return end
    
    local builder = player.BuilderComponent
    if builder and builder:IsValid() then
        builder.InstallDistanceNormalFromOwner = originalInstallDistance
    end
    
    if lastDismantleTarget and lastDismantleTarget:IsValid() then
        pcall(SafeSetDismantleVisual, lastDismantleTarget, false)
        lastDismantleTarget.bDismantleTargetInLocal = false
    end
    
    pcall(SafeSetDismantleVisual, player, false)
    lastDismantleTarget = nil
    lastBuilderMode = -1
end

-- Update building ranges, dismantle outlines, and preview alignments
function builder_manager.Update(player, pc, cameraRotation, aimLocation, aimDistance, hitActor)
    if not player or not player:IsValid() or not pc or not pc:IsValid() then return end
    
    local builder = player.BuilderComponent
    if not builder or not builder:IsValid() then return end
    
    local mode = builder:GetCurrentMode()
    local modeNum = 0
    if type(mode) == "number" then
        modeNum = mode
    elseif type(mode) == "userdata" and mode.get then
        modeNum = mode:get()
    end
    
    local timeNow = os.clock()
    if modeNum ~= lastBuilderMode then
        lastBuilderMode = modeNum
        print(string.format("[FreeCam Debug] Builder Mode Changed: mode = %d (0=None, 1=Building, 2=Dismantling, 3=Painting)", modeNum))
    end
    
    local success, isSnap = pcall(SafeCheckIsSnapMode, builder)
    isSnap = success and isSnap
    
    local isDismantle = (modeNum == 2)
    if isSnap or isDismantle then
        builder.InstallDistanceNormalFromOwner = originalInstallDistance * 15.0
    else
        builder.InstallDistanceNormalFromOwner = 0.0
    end
    
    if modeNum == 2 then
        pc:SetControlRotation(cameraRotation)
        local checker = builder.DismantleChecker
        
        -- Clear previous dismantle visual outline if target changed
        if lastDismantleTarget and lastDismantleTarget:IsValid() and lastDismantleTarget ~= hitActor then
            pcall(SafeSetDismantleVisual, lastDismantleTarget, false)
            lastDismantleTarget.bDismantleTargetInLocal = false
            lastDismantleTarget = nil
        end

        if hitActor and hitActor:IsValid() and hitActor ~= player then
            if checker and checker:IsValid() then
                checker.TargetBuildObject = hitActor
            end
            pcall(SafeSetDismantleVisual, hitActor, true)
            hitActor.bDismantleTargetInLocal = true
            lastDismantleTarget = hitActor
        end
        
        if (timeNow - lastLogTime) > 1.5 then
            lastLogTime = timeNow
            local targetName = "None"
            local hitActorName = (hitActor and hitActor:IsValid()) and hitActor:GetFullName() or "None"
            local targetObj = builder:GetDismantleTargetObject()
            if targetObj and targetObj:IsValid() then
                targetName = targetObj:GetFullName()
            end
            print(string.format("[FreeCam Debug] Dismantle Mode: hitActor=%s, GetDismantleTarget=%s", hitActorName, targetName))
        end
    else
        if lastDismantleTarget and lastDismantleTarget:IsValid() then
            pcall(SafeSetDismantleVisual, lastDismantleTarget, false)
            lastDismantleTarget.bDismantleTargetInLocal = false
            lastDismantleTarget = nil
        end
    end
    
    if not isSnap then
        -- Adjust Z offset of the character location to center blueprint previews with the reticle target
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
                    
                    local pfX, pfY, pfZ = forward.X, forward.Y, forward.Z
                    local prX, prY, prZ = right.X, right.Y, right.Z
                    local puX, puY, puZ = up.X, up.Y, up.Z
                    
                    if type(pfX) == "userdata" and pfX.get then pfX = pfX:get() pfY = pfY:get() pfZ = pfZ:get() end
                    if type(prX) == "userdata" and prX.get then prX = prX:get() prY = prY:get() prZ = prZ:get() end
                    if type(puX) == "userdata" and puX.get then puX = puX:get() puY = puY:get() puZ = puZ:get() end
                    
                    local worldOffsetX = pfX * xCenter + prX * yCenter + puX * zCenter
                    local worldOffsetY = pfY * xCenter + prY * yCenter + puY * zCenter
                    local worldOffsetZ = pfZ * xCenter + prZ * yCenter + puZ * zCenter
                    
                    aimLocation.X = aimLocation.X - worldOffsetX
                    aimLocation.Y = aimLocation.Y - worldOffsetY
                    aimLocation.Z = aimLocation.Z - worldOffsetZ
                end
            end
        end
    end
end

return builder_manager
